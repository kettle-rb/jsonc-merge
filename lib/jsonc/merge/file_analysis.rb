# frozen_string_literal: true

module Jsonc
  module Merge
    # Analyzes JSON/JSONC file structure, extracting nodes, comments, and freeze blocks.
    # This is the main analysis class that prepares JSON content for merging.
    #
    # Supports JSONC (JSON with Comments) which allows single-line (//) and
    # multi-line (/* */) comments in JSON files. This is commonly used in
    # configuration files like tsconfig.json, VS Code settings, etc.
    #
    # @example Basic usage
    #   analysis = FileAnalysis.new(json_source)
    #   analysis.valid? # => true
    #   analysis.nodes # => [NodeWrapper, FreezeNodeBase, ...]
    #   analysis.freeze_blocks # => [FreezeNodeBase, ...]
    class FileAnalysis
      include Ast::Merge::FileAnalyzable

      # Default freeze token for identifying freeze blocks
      DEFAULT_FREEZE_TOKEN = "json-merge"

      # @return [CommentTracker] Comment tracker for this file
      attr_reader :comment_tracker

      # @return [TreeHaver::Tree, nil] Parsed AST
      attr_reader :ast

      # @return [Array] Parse errors if any
      attr_reader :errors

      class << self
        # Find the parser library path using TreeHaver::GrammarFinder
        #
        # Note: JSONC uses the tree-sitter-json library (not tree-sitter-jsonc)
        #
        # @return [String, nil] Path to the parser library or nil if not found
        def find_parser_path
          return unless defined?(TreeHaver::GrammarFinder)

          TreeHaver::GrammarFinder.new(:jsonc).find_library_path
        end
      end

      # Initialize file analysis
      #
      # @param source [String] JSON/JSONC source code to analyze
      # @param freeze_token [String] Token for freeze block markers
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param parser_path [String, nil] Path to tree-sitter-json parser library
      # @param options [Hash] Additional options (forward compatibility - ignored by FileAnalysis)
      def initialize(source, freeze_token: DEFAULT_FREEZE_TOKEN, signature_generator: nil, parser_path: nil, **options)
        @source = source
        @lines = source.lines.map(&:chomp)
        @freeze_token = freeze_token
        @signature_generator = signature_generator
        @parser_path = parser_path || self.class.find_parser_path
        @errors = []
        # **options captures any additional parameters (e.g., node_typing) for forward compatibility

        # Initialize comment tracking
        @comment_tracker = CommentTracker.new(source)

        # Parse the JSON
        DebugLogger.time("FileAnalysis#parse_json") { parse_json }

        # Extract freeze blocks and integrate with nodes
        @freeze_blocks = extract_freeze_blocks
        @nodes = integrate_nodes_and_freeze_blocks

        DebugLogger.debug("FileAnalysis initialized", {
          signature_generator: signature_generator ? "custom" : "default",
          nodes_count: @nodes.size,
          freeze_blocks: @freeze_blocks.size,
          valid: valid?,
        })
      end

      # Check if parse was successful
      # @return [Boolean]
      def valid?
        @errors.empty? && !@ast.nil?
      end

      # The base module uses 'statements' - provide both names for compatibility
      # @return [Array<NodeWrapper, FreezeNode>]
      def statements
        @nodes ||= []
      end

      # Alias for convenience - json-merge prefers "nodes" terminology
      alias_method :nodes, :statements

      # Check if a line is within a freeze block.
      #
      # @param line_num [Integer] 1-based line number
      # @return [Boolean]
      def in_freeze_block?(line_num)
        @freeze_blocks.any? { |fb| fb.location.cover?(line_num) }
      end

      # Get the freeze block containing the given line.
      #
      # @param line_num [Integer] 1-based line number
      # @return [FreezeNode, nil]
      def freeze_block_at(line_num)
        @freeze_blocks.find { |fb| fb.location.cover?(line_num) }
      end

      # Override to detect tree-sitter nodes for signature generator fallthrough
      # @param value [Object] The value to check
      # @return [Boolean] true if this is a fallthrough node
      def fallthrough_node?(value)
        value.is_a?(NodeWrapper) || value.is_a?(FreezeNode) || super
      end

      # Get the root node of the parse tree
      # @return [NodeWrapper, nil]
      def root_node
        return unless valid?

        NodeWrapper.new(@ast.root_node, lines: @lines, source: @source)
      end

      # Get the root object if the JSON document is an object
      # @return [NodeWrapper, nil]
      def root_object
        return unless valid?

        root = @ast.root_node
        return unless root

        # JSON root should be a document containing an object or array
        root.each do |child|
          if child.type.to_s == "object"
            return NodeWrapper.new(child, lines: @lines, source: @source)
          end
        end
        nil
      end

      # Get the opening brace line of the root object (the line containing `{`)
      # @return [String, nil]
      def root_object_open_line
        obj = root_object
        return unless obj&.start_line

        line_at(obj.start_line)&.chomp
      end

      # Get the closing brace line of the root object (the line containing `}`)
      # @return [String, nil]
      def root_object_close_line
        obj = root_object
        return unless obj&.end_line

        line_at(obj.end_line)&.chomp
      end

      # Get key-value pairs from the root object
      # @return [Array<NodeWrapper>]
      def root_pairs
        obj = root_object
        return [] unless obj

        obj.pairs
      end

      private

      def parse_json
        # Check if TreeHaver is available
        unless defined?(TreeHaver)
          error_msg = "TreeHaver not available. Install tree_haver gem."
          @errors << error_msg
          @ast = nil
          return
        end

        begin
          # Determine which language to use (do this BEFORE creating parser)
          language = if @parser_path
            # Custom parser path was explicitly provided
            if File.exist?(@parser_path)
              # Use the provided path
              TreeHaver::Language.from_library(@parser_path, symbol: "tree_sitter_jsonc", name: "jsonc")
            else
              # Explicit path doesn't exist - this is an error
              @errors << "Provided parser path does not exist: #{@parser_path}"
              @ast = nil
              return
            end
          elsif TreeHaver::Language.respond_to?(:json)
            # Use registered json language (from GrammarFinder)
            TreeHaver::Language.json
          else
            # No language available
            error_msg = if defined?(TreeHaver::GrammarFinder)
              TreeHaver::GrammarFinder.new(:jsonc).not_found_message
            else
              "tree-sitter json/jsonc parser not found. Install tree-sitter-json or set TREE_SITTER_JSONC_PATH."
            end
            @errors << error_msg
            @ast = nil
            return
          end

          # Use TreeHaver's unified interface
          parser = TreeHaver::Parser.new
          parser.language = language
          @ast = parser.parse(@source)

          # Check for parse errors in the tree
          if @ast&.root_node&.has_error?
            collect_parse_errors(@ast.root_node)
          end
        rescue StandardError => e
          @errors << e
          @ast = nil
        end
      end

      def collect_parse_errors(node)
        # Collect ERROR and MISSING nodes from the tree
        if node.type.to_s == "ERROR" || node.missing?
          @errors << {
            type: node.type.to_s,
            start_point: node.start_point,
            end_point: node.end_point,
            text: node.to_s,
          }
        end

        node.each { |child| collect_parse_errors(child) }
      end

      def extract_freeze_blocks
        # JSONC supports both // and /* */ comments
        # We look for freeze markers in both styles
        freeze_starts = []
        freeze_ends = []

        # Pattern for single-line comments: // json-merge:freeze
        single_line_pattern = %r{^\s*//\s*#{Regexp.escape(@freeze_token)}:(freeze|unfreeze)\b}i

        # Pattern for block comments: /* json-merge:freeze */
        block_pattern = %r{^\s*/\*\s*#{Regexp.escape(@freeze_token)}:(freeze|unfreeze)\b.*\*/}i

        @lines.each_with_index do |line, idx|
          line_num = idx + 1

          marker_type = nil
          if (match = line.match(single_line_pattern))
            marker_type = match[1]&.downcase
          elsif (match = line.match(block_pattern))
            marker_type = match[1]&.downcase
          end

          next unless marker_type

          if marker_type == "freeze"
            freeze_starts << {line: line_num, marker: line}
          elsif marker_type == "unfreeze"
            freeze_ends << {line: line_num, marker: line}
          end
        end

        # Match freeze starts with ends
        blocks = []
        freeze_starts.each do |start_info|
          # Find the next unfreeze after this freeze
          matching_end = freeze_ends.find { |e| e[:line] > start_info[:line] }
          next unless matching_end

          # Remove used end marker
          freeze_ends.delete(matching_end)

          blocks << FreezeNode.new(
            start_line: start_info[:line],
            end_line: matching_end[:line],
            lines: @lines,
            start_marker: start_info[:marker],
            end_marker: matching_end[:marker],
          )
        end

        blocks
      end

      def integrate_nodes_and_freeze_blocks
        return @freeze_blocks.dup unless valid?

        result = []
        processed_lines = ::Set.new

        # Mark freeze block lines as processed
        @freeze_blocks.each do |fb|
          (fb.start_line..fb.end_line).each { |ln| processed_lines << ln }
          result << fb
        end

        # Add root-level key-value pairs that aren't in freeze blocks
        root_pairs.each do |pair|
          next unless pair.start_line && pair.end_line

          # Skip if any part of this pair is in a freeze block
          pair_lines = (pair.start_line..pair.end_line).to_a
          next if pair_lines.any? { |ln| processed_lines.include?(ln) }

          result << pair
        end

        # Sort by start line
        result.sort_by { |node| node.start_line || 0 }
      end

      def compute_node_signature(node)
        case node
        when FreezeNode
          node.signature
        when NodeWrapper
          node.signature
        end
      end
    end
  end
end
