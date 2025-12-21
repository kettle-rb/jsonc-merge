# frozen_string_literal: true

module Jsonc
  module Merge
    # High-level merger for JSONC (JSON with Comments) content.
    # Orchestrates parsing, analysis, and conflict resolution.
    #
    # @example Basic usage
    #   merger = SmartMerger.new(template_content, dest_content)
    #   merged_string = merger.merge
    #   File.write("merged.jsonc", merged_string)
    #
    # @example With full result object
    #   merger = SmartMerger.new(template, dest)
    #   result = merger.merge_result
    #   puts result.statistics
    #   File.write("merged.jsonc", result.content)
    #
    # @example With options
    #   merger = SmartMerger.new(template, dest,
    #     preference: :template,
    #     add_template_only_nodes: true)
    #   merged_string = merger.merge
    #
    # @example With node_typing for per-node-type preferences
    #   merger = SmartMerger.new(template, dest,
    #     node_typing: { "object" => ->(n) { NodeTyping.with_merge_type(n, :config) } },
    #     preference: { default: :destination, config: :template })
    class SmartMerger < ::Ast::Merge::SmartMergerBase
      # Creates a new SmartMerger
      #
      # @param template_content [String] Template JSONC content
      # @param dest_content [String] Destination JSONC content
      # @param signature_generator [Proc, nil] Custom signature generator
      # @param preference [Symbol, Hash] :destination, :template, or per-type Hash
      # @param add_template_only_nodes [Boolean] Whether to add nodes only found in template
      # @param freeze_token [String, nil] Token for freeze block markers
      # @param match_refiner [#call, nil] Match refiner for fuzzy matching
      # @param regions [Array<Hash>, nil] Region configurations for nested merging
      # @param region_placeholder [String, nil] Custom placeholder for regions
      # @param node_typing [Hash{Symbol,String => #call}, nil] Node typing configuration
      #   for per-node-type merge preferences
      def initialize(
        template_content,
        dest_content,
        signature_generator: nil,
        preference: :destination,
        add_template_only_nodes: false,
        freeze_token: nil,
        match_refiner: nil,
        regions: nil,
        region_placeholder: nil,
        node_typing: nil
      )
        super(
          template_content,
          dest_content,
          signature_generator: signature_generator,
          preference: preference,
          add_template_only_nodes: add_template_only_nodes,
          freeze_token: freeze_token,
          match_refiner: match_refiner,
          regions: regions,
          region_placeholder: region_placeholder,
          node_typing: node_typing,
        )
      end

      # Backward-compatible options hash
      #
      # @return [Hash] The merge options
      def options
        {
          preference: @preference,
          add_template_only_nodes: @add_template_only_nodes,
          match_refiner: @match_refiner,
        }
      end

      protected

      # @return [Class] The analysis class for JSONC files
      def analysis_class
        FileAnalysis
      end

      # @return [String] The default freeze token
      def default_freeze_token
        "jsonc-merge"
      end

      # @return [Class] The resolver class for JSONC files
      def resolver_class
        ConflictResolver
      end

      # @return [Class] The result class for JSONC files
      def result_class
        MergeResult
      end

      # Perform the JSONC-specific merge
      #
      # @return [MergeResult] The merge result
      def perform_merge
        @resolver.resolve(@result)

        DebugLogger.debug("Merge complete", {
          lines: @result.line_count,
          decisions: @result.statistics,
        })

        @result
      end

      # Build the resolver with JSONC-specific configuration
      def build_resolver
        ConflictResolver.new(
          @template_analysis,
          @dest_analysis,
          preference: @preference,
          add_template_only_nodes: @add_template_only_nodes,
          match_refiner: @match_refiner,
        )
      end

      # Build the result (no-arg constructor for JSONC)
      def build_result
        MergeResult.new
      end

      # @return [Class] The template parse error class for JSONC
      def template_parse_error_class
        TemplateParseError
      end

      # @return [Class] The destination parse error class for JSONC
      def destination_parse_error_class
        DestinationParseError
      end

      private

      # JSONC FileAnalysis only accepts signature_generator, not freeze_token
      def build_full_analysis_options
        {signature_generator: @signature_generator}
      end
    end
  end
end
