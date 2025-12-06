# frozen_string_literal: true

module Jsonc
  module Merge
    # High-level merger for JSON/JSONC content.
    # Orchestrates parsing, analysis, and conflict resolution.
    #
    # @example Basic usage
    #   merger = SmartMerger.new(template_content, dest_content)
    #   merged_string = merger.merge
    #   File.write("merged.json", merged_string)
    #
    # @example With full result object
    #   merger = SmartMerger.new(template, dest)
    #   result = merger.merge_result
    #   puts result.statistics
    #   File.write("merged.json", result.content)
    #
    # @example With options
    #   merger = SmartMerger.new(template, dest,
    #     signature_match_preference: :template,
    #     add_template_only_nodes: true)
    #   merged_string = merger.merge
    class SmartMerger
      # @return [String] Template JSON content
      attr_reader :template_content

      # @return [String] Destination JSON content
      attr_reader :dest_content

      # @return [Hash] Merge options
      attr_reader :options

      # Creates a new SmartMerger
      #
      # @param template_content [String] Template JSON content
      # @param dest_content [String] Destination JSON content
      # @param options [Hash] Merge options
      # @option options [Symbol] :signature_match_preference (:destination)
      #   Which version to prefer when nodes have matching signatures
      # @option options [Boolean] :add_template_only_nodes (false)
      #   Whether to add nodes only found in template
      def initialize(template_content, dest_content, **options)
        @template_content = template_content
        @dest_content = dest_content
        @options = {
          signature_match_preference: :destination,
          add_template_only_nodes: false,
        }.merge(options)
      end

      # Perform the merge
      #
      # @return [String] The merged content as a string
      def merge
        merge_result.content
      end

      # Perform the merge and return the full result object
      #
      # @return [MergeResult] The merged result with statistics and decisions
      def merge_result
        return @merge_result if @merge_result

        @merge_result = DebugLogger.time("SmartMerger#merge") do
          perform_merge
        end
      end

      private

      def perform_merge
        # Analyze both files
        template_analysis = analyze_content(@template_content, "template")
        dest_analysis = analyze_content(@dest_content, "destination")

        # Create result and resolver
        result = MergeResult.new
        resolver = ConflictResolver.new(
          template_analysis,
          dest_analysis,
          signature_match_preference: @options[:signature_match_preference],
          add_template_only_nodes: @options[:add_template_only_nodes]
        )

        # Perform resolution
        resolver.resolve(result)

        DebugLogger.debug("Merge complete", {
          lines: result.line_count,
          decisions: result.statistics,
        })

        result
      end

      def analyze_content(content, name)
        DebugLogger.time("Analyze #{name}") do
          FileAnalysis.new(content)
        end
      rescue ParseError => e
        DebugLogger.debug("Parse error in #{name}", {error: e.message})
        raise
      end
    end
  end
end
