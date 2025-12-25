# frozen_string_literal: true

module Jsonc
  module Merge
    # Resolves conflicts between template and destination JSON content
    # using structural signatures and configurable preferences.
    #
    # Inherits from Ast::Merge::ConflictResolverBase using the :batch strategy,
    # which resolves all conflicts at once using signature maps.
    #
    # @example Basic usage
    #   resolver = ConflictResolver.new(template_analysis, dest_analysis)
    #   resolver.resolve(result)
    #
    # @see Ast::Merge::ConflictResolverBase
    class ConflictResolver < Ast::Merge::ConflictResolverBase
      # Creates a new ConflictResolver
      #
      # @param template_analysis [FileAnalysis] Analyzed template file
      # @param dest_analysis [FileAnalysis] Analyzed destination file
      # @param preference [Symbol] Which version to prefer when
      #   nodes have matching signatures:
      #   - :destination (default) - Keep destination version (customizations)
      #   - :template - Use template version (updates)
      # @param add_template_only_nodes [Boolean] Whether to add nodes only in template
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching
      # @param options [Hash] Additional options for forward compatibility
      def initialize(template_analysis, dest_analysis, preference: :destination, add_template_only_nodes: false, match_refiner: nil, **options)
        super(
          strategy: :batch,
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
          add_template_only_nodes: add_template_only_nodes,
          match_refiner: match_refiner,
          **options
        )
      end

      protected

      # Resolve conflicts and populate the result using tree-based merging
      #
      # @param result [MergeResult] Result object to populate
      def resolve_batch(result)
        DebugLogger.time("ConflictResolver#resolve") do
          template_statements = @template_analysis.statements
          dest_statements = @dest_analysis.statements

          # Merge root-level statements (typically just the root object)
          merge_node_lists(
            template_statements,
            dest_statements,
            @template_analysis,
            @dest_analysis,
            result,
          )

          DebugLogger.debug("Conflict resolution complete", {
            template_statements: template_statements.size,
            dest_statements: dest_statements.size,
            result_lines: result.line_count,
          })
        end
      end

      private

      # Recursively merge two lists of nodes (tree-based merge)
      # @param template_nodes [Array<NodeWrapper>] Template nodes
      # @param dest_nodes [Array<NodeWrapper>] Destination nodes
      # @param template_analysis [FileAnalysis] Template analysis for line access
      # @param dest_analysis [FileAnalysis] Destination analysis for line access
      # @param result [MergeResult] Result to populate
      def merge_node_lists(template_nodes, dest_nodes, template_analysis, dest_analysis, result)
        # Build signature maps for matching
        template_by_sig = build_signature_map(template_nodes, template_analysis)
        dest_by_sig = build_signature_map(dest_nodes, dest_analysis)

        # Build refined matches for nodes that don't match by signature
        refined_matches = build_refined_matches(template_nodes, dest_nodes, template_by_sig, dest_by_sig)
        refined_dest_to_template = refined_matches.invert

        # Track which nodes have been processed
        processed_template_sigs = ::Set.new
        processed_dest_sigs = ::Set.new

        # First pass: Process destination nodes
        dest_nodes.each do |dest_node|
          dest_sig = dest_analysis.generate_signature(dest_node)

          # Freeze blocks from destination are always preserved
          if freeze_node?(dest_node)
            add_node_to_result(dest_node, result, :destination, MergeResult::DECISION_FREEZE_BLOCK, dest_analysis)
            processed_dest_sigs << dest_sig if dest_sig
            next
          end

          # Check for signature match
          if dest_sig && template_by_sig[dest_sig]
            template_info = template_by_sig[dest_sig].first
            template_node = template_info[:node]

            # Both have this node - merge them (recursively if containers)
            merge_matched_nodes(template_node, dest_node, template_analysis, dest_analysis, result)

            processed_dest_sigs << dest_sig
            processed_template_sigs << dest_sig
          elsif refined_dest_to_template.key?(dest_node)
            # Found refined match
            template_node = refined_dest_to_template[dest_node]
            template_sig = template_analysis.generate_signature(template_node)

            # Merge matched nodes
            merge_matched_nodes(template_node, dest_node, template_analysis, dest_analysis, result)

            processed_dest_sigs << dest_sig if dest_sig
            processed_template_sigs << template_sig if template_sig
          else
            # Destination-only node - always keep
            add_node_to_result(dest_node, result, :destination, MergeResult::DECISION_KEPT_DEST, dest_analysis)
            processed_dest_sigs << dest_sig if dest_sig
          end
        end

        # Second pass: Add template-only nodes if configured
        return unless @add_template_only_nodes

        template_nodes.each do |template_node|
          template_sig = template_analysis.generate_signature(template_node)

          # Skip if already processed
          next if template_sig && processed_template_sigs.include?(template_sig)

          # Skip freeze blocks from template
          next if freeze_node?(template_node)

          # Add template-only node
          add_node_to_result(template_node, result, :template, MergeResult::DECISION_ADDED, template_analysis)
          processed_template_sigs << template_sig if template_sig
        end
      end

      # Merge two matched nodes - for containers, recursively merge children
      # @param template_node [NodeWrapper] Template node
      # @param dest_node [NodeWrapper] Destination node
      # @param template_analysis [FileAnalysis] Template analysis
      # @param dest_analysis [FileAnalysis] Destination analysis
      # @param result [MergeResult] Result to populate
      def merge_matched_nodes(template_node, dest_node, template_analysis, dest_analysis, result)
        if dest_node.container? && template_node.container?
          # Both are containers - recursively merge their children
          merge_container_nodes(template_node, dest_node, template_analysis, dest_analysis, result)
        elsif @preference == :destination
          # Leaf nodes or mismatched types - use preference
          add_node_to_result(dest_node, result, :destination, MergeResult::DECISION_KEPT_DEST, dest_analysis)
        else
          add_node_to_result(template_node, result, :template, MergeResult::DECISION_KEPT_TEMPLATE, template_analysis)
        end
      end

      # Build a map of refined matches from template node to destination node.
      # Uses the match_refiner to find additional pairings for nodes that didn't match by signature.
      # @param template_nodes [Array<NodeWrapper>] Template nodes
      # @param dest_nodes [Array<NodeWrapper>] Destination nodes
      # @param template_by_sig [Hash] Template signature map
      # @param dest_by_sig [Hash] Destination signature map
      # @return [Hash] Map of template_node => dest_node
      def build_refined_matches(template_nodes, dest_nodes, template_by_sig, dest_by_sig)
        return {} unless @match_refiner

        # Find unmatched nodes
        matched_sigs = template_by_sig.keys & dest_by_sig.keys
        unmatched_t_nodes = template_nodes.reject do |n|
          sig = @template_analysis.generate_signature(n)
          sig && matched_sigs.include?(sig)
        end
        unmatched_d_nodes = dest_nodes.reject do |n|
          sig = @dest_analysis.generate_signature(n)
          sig && matched_sigs.include?(sig)
        end

        return {} if unmatched_t_nodes.empty? || unmatched_d_nodes.empty?

        # Call the refiner
        matches = @match_refiner.call(unmatched_t_nodes, unmatched_d_nodes, {
          template_analysis: @template_analysis,
          dest_analysis: @dest_analysis,
        })

        # Build result map: template node -> dest node
        matches.each_with_object({}) do |match, h|
          h[match.template_node] = match.dest_node
        end
      end

      # Merge two container nodes by emitting opening, recursively merging children, then closing
      # @param template_node [NodeWrapper] Template container node
      # @param dest_node [NodeWrapper] Destination container node
      # @param template_analysis [FileAnalysis] Template analysis
      # @param dest_analysis [FileAnalysis] Destination analysis
      # @param result [MergeResult] Result to populate
      def merge_container_nodes(template_node, dest_node, template_analysis, dest_analysis, result)
        # Use destination's opening line (or template if dest doesn't have one)
        opening = dest_node.opening_line || template_node.opening_line
        result.add_line(opening, decision: MergeResult::DECISION_MERGED, source: :merged) if opening

        # Recursively merge the children
        template_children = template_node.mergeable_children
        dest_children = dest_node.mergeable_children

        merge_node_lists(
          template_children,
          dest_children,
          template_analysis,
          dest_analysis,
          result,
        )

        # Use destination's closing line (or template if dest doesn't have one)
        closing = dest_node.closing_line || template_node.closing_line
        result.add_line(closing, decision: MergeResult::DECISION_MERGED, source: :merged) if closing
      end

      # Add a node to the result (non-container or leaf node)
      # @param node [NodeWrapper] Node to add
      # @param result [MergeResult] Result to populate
      # @param source [Symbol] :template or :destination
      # @param decision [String] Decision constant
      # @param analysis [FileAnalysis] Analysis for line access
      def add_node_to_result(node, result, source, decision, analysis)
        if freeze_node?(node)
          result.add_freeze_block(node)
        elsif node.is_a?(NodeWrapper)
          add_wrapper_to_result(node, result, source, decision, analysis)
        else
          DebugLogger.debug("Unknown node type", {node_type: node.class.name})
        end
      end

      def add_wrapper_to_result(wrapper, result, source, decision, analysis)
        return unless wrapper.start_line && wrapper.end_line

        # Include leading comments
        leading = analysis.comment_tracker.leading_comments_before(wrapper.start_line)
        leading.each do |comment|
          result.add_line(comment[:raw], decision: decision, source: source, original_line: comment[:line])
        end

        # Add the node content
        (wrapper.start_line..wrapper.end_line).each do |line_num|
          line = analysis.line_at(line_num)
          next unless line

          result.add_line(line.chomp, decision: decision, source: source, original_line: line_num)
        end
      end
    end
  end
end
