# frozen_string_literal: true

module Jsonc
  module Merge
    # Wraps tree-sitter nodes with comment associations, line information, and signatures.
    # This provides a unified interface for working with JSON AST nodes during merging.
    #
    # @example Basic usage
    #   parser = TreeSitter::Parser.new
    #   parser.language = TreeSitter::Language.load("json", path)
    #   tree = parser.parse_string(nil, source)
    #   wrapper = NodeWrapper.new(tree.root_node, lines: source.lines, source: source)
    #   wrapper.signature # => [:object, ...]
    class NodeWrapper
      # @return [TreeSitter::Node] The wrapped tree-sitter node
      attr_reader :node

      # @return [Array<Hash>] Leading comments associated with this node
      attr_reader :leading_comments

      # @return [String] The original source string
      attr_reader :source

      # @return [Hash, nil] Inline/trailing comment on the same line
      attr_reader :inline_comment

      # @return [Integer] Start line (1-based)
      attr_reader :start_line

      # @return [Integer] End line (1-based)
      attr_reader :end_line

      # @return [Array<String>] Source lines
      attr_reader :lines

      # @param node [TreeSitter::Node] Tree-sitter node to wrap
      # @param lines [Array<String>] Source lines for content extraction
      # @param source [String] Original source string for byte-based text extraction
      # @param leading_comments [Array<Hash>] Comments before this node
      # @param inline_comment [Hash, nil] Inline comment on the node's line
      def initialize(node, lines:, source: nil, leading_comments: [], inline_comment: nil)
        @node = node
        @lines = lines
        @source = source || lines.join("\n")
        @leading_comments = leading_comments
        @inline_comment = inline_comment

        # Extract line information from the tree-sitter node (0-indexed to 1-indexed)
        @start_line = node.start_point.row + 1 if node.respond_to?(:start_point)
        @end_line = node.end_point.row + 1 if node.respond_to?(:end_point)

        # Handle edge case where end_line might be before start_line
        @end_line = @start_line if @start_line && @end_line && @end_line < @start_line
      end

      # Generate a signature for this node for matching purposes.
      # Signatures are used to identify corresponding nodes between template and destination.
      #
      # @return [Array, nil] Signature array or nil if not signaturable
      def signature
        compute_signature(@node)
      end

      # Check if this is a freeze node
      # @return [Boolean]
      def freeze_node?
        false
      end

      # Get the node type as a symbol
      # @return [Symbol]
      def type
        @node.type.to_sym
      end

      # Check if this node has a specific type
      # @param type_name [Symbol, String] Type to check
      # @return [Boolean]
      def type?(type_name)
        @node.type.to_s == type_name.to_s
      end

      # Check if this is a JSON object
      # @return [Boolean]
      def object?
        @node.type.to_s == "object"
      end

      # Check if this is a JSON array
      # @return [Boolean]
      def array?
        @node.type.to_s == "array"
      end

      # Check if this is a JSON string
      # @return [Boolean]
      def string?
        @node.type.to_s == "string"
      end

      # Check if this is a JSON number
      # @return [Boolean]
      def number?
        @node.type.to_s == "number"
      end

      # Check if this is a JSON boolean (true/false)
      # @return [Boolean]
      def boolean?
        %w[true false].include?(@node.type.to_s)
      end

      # Check if this is a JSON null
      # @return [Boolean]
      def null?
        @node.type.to_s == "null"
      end

      # Check if this is a key-value pair
      # @return [Boolean]
      def pair?
        @node.type.to_s == "pair"
      end

      # Check if this is a comment
      # @return [Boolean]
      def comment?
        @node.type.to_s == "comment"
      end

      # Get the key name if this is a pair node
      # @return [String, nil]
      def key_name
        return unless pair?

        # In JSON tree-sitter, pair has key and value children
        key_node = find_child_by_field("key")
        return unless key_node

        # Key is typically a string, extract its content without quotes using byte positions
        key_text = node_text(key_node)
        # Remove surrounding quotes if present
        key_text&.gsub(/\A"|"\z/, "")
      end

      # Get the value node if this is a pair
      # @return [NodeWrapper, nil]
      def value_node
        return unless pair?

        value = find_child_by_field("value")
        return unless value

        NodeWrapper.new(value, lines: @lines, source: @source)
      end

      # Get key-value pairs if this is an object
      # @return [Array<NodeWrapper>]
      def pairs
        return [] unless object?

        result = []
        @node.each do |child|
          next if child.type.to_s == "comment"
          next unless child.type.to_s == "pair"

          result << NodeWrapper.new(child, lines: @lines, source: @source)
        end
        result
      end

      # Get array elements if this is an array
      # @return [Array<NodeWrapper>]
      def elements
        return [] unless array?

        result = []
        @node.each do |child|
          child_type = child.type.to_s
          # Skip punctuation and comments
          next if child_type == "comment"
          next if child_type == ","
          next if child_type == "["
          next if child_type == "]"

          result << NodeWrapper.new(child, lines: @lines, source: @source)
        end
        result
      end

      # Get children wrapped as NodeWrappers
      # @return [Array<NodeWrapper>]
      def children
        return [] unless @node.respond_to?(:each)

        result = []
        @node.each do |child|
          result << NodeWrapper.new(child, lines: @lines, source: @source)
        end
        result
      end

      # Get mergeable children - the semantically meaningful children for tree merging
      # For objects, returns pairs. For arrays, returns elements.
      # For other node types, returns empty array (leaf nodes).
      # @return [Array<NodeWrapper>]
      def mergeable_children
        case type
        when :object
          pairs
        when :array
          elements
        else
          []
        end
      end

      # Check if this node is a container (has mergeable children)
      # @return [Boolean]
      def container?
        object? || array?
      end

      # Check if this node is a leaf (no mergeable children)
      # @return [Boolean]
      def leaf?
        !container?
      end

      # Get the opening line for a container node (the line with { or [)
      # Returns the full line content including any leading whitespace
      # @return [String, nil]
      def opening_line
        return unless container? && @start_line

        @lines[@start_line - 1]
      end

      # Get the closing line for a container node (the line with } or ])
      # Returns the full line content including any leading whitespace
      # @return [String, nil]
      def closing_line
        return unless container? && @end_line

        @lines[@end_line - 1]
      end

      # Get the opening bracket character for this container
      # @return [String, nil]
      def opening_bracket
        return "{" if object?
        return "[" if array?

        nil
      end

      # Get the closing bracket character for this container
      # @return [String, nil]
      def closing_bracket
        return "}" if object?
        return "]" if array?

        nil
      end

      # Find a child by field name
      # @param field_name [String] Field name to look for
      # @return [TreeSitter::Node, nil]
      def find_child_by_field(field_name)
        return unless @node.respond_to?(:child_by_field_name)

        @node.child_by_field_name(field_name)
      end

      # Find a child by type
      # @param type_name [String] Type name to look for
      # @return [TreeSitter::Node, nil]
      def find_child_by_type(type_name)
        return unless @node.respond_to?(:each)

        @node.each do |child|
          return child if child.type.to_s == type_name
        end
        nil
      end

      # Get the text content for this node by extracting from source using byte positions
      # @return [String]
      def text
        node_text(@node)
      end

      # Extract text from a tree-sitter node using byte positions
      # @param ts_node [TreeSitter::Node] The tree-sitter node
      # @return [String]
      def node_text(ts_node)
        return "" unless ts_node.respond_to?(:start_byte) && ts_node.respond_to?(:end_byte)

        @source[ts_node.start_byte...ts_node.end_byte] || ""
      end

      # Get the content for this node from source lines
      # @return [String]
      def content
        return "" unless @start_line && @end_line

        (@start_line..@end_line).map { |ln| @lines[ln - 1] }.compact.join("\n")
      end

      # String representation for debugging
      # @return [String]
      def inspect
        "#<#{self.class.name} type=#{@node.type} lines=#{@start_line}..#{@end_line}>"
      end

      private

      def compute_signature(node)
        node_type = node.type.to_s

        case node_type
        when "document"
          # Root document - signature based on root content type
          child = nil
          node.each { |c|
            child = c unless c.type.to_s == "comment"
            break if child
          }
          child_type = child&.type&.to_s
          [:document, child_type]
        when "object"
          # Objects identified by their keys
          keys = extract_object_keys(node)
          [:object, keys.sort]
        when "array"
          # Arrays identified by their length and first few elements
          elements_count = 0
          node.each { |c| elements_count += 1 unless %w[comment , \[ \]].include?(c.type.to_s) }
          [:array, elements_count]
        when "pair"
          # Pairs identified by their key name
          key = key_name
          [:pair, key]
        when "string"
          # Strings identified by their content
          [:string, node_text(node)]
        when "number"
          # Numbers identified by their value
          [:number, node_text(node)]
        when "true", "false"
          # Booleans
          [:boolean, node.type.to_s]
        when "null"
          [:null]
        when "comment"
          # Comments identified by their content
          [:comment, node_text(node)&.strip]
        else
          # Generic fallback
          content_preview = node_text(node)&.slice(0, 50)&.strip
          [node_type.to_sym, content_preview]
        end
      end

      def extract_object_keys(object_node)
        keys = []
        object_node.each do |child|
          next unless child.type.to_s == "pair"

          key_node = child.respond_to?(:child_by_field_name) ? child.child_by_field_name("key") : nil
          next unless key_node

          key_text = node_text(key_node)&.gsub(/\A"|"\z/, "")
          keys << key_text if key_text
        end
        keys
      end
    end
  end
end
