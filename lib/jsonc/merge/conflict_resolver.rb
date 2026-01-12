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
        @emitter = Emitter.new
      end

      protected

      # Resolve conflicts and populate the result using tree-based merging
      #
      # @param result [MergeResult] Result object to populate
      def resolve_batch(result)
        DebugLogger.time("ConflictResolver#resolve") do
          template_statements = @template_analysis.statements
          dest_statements = @dest_analysis.statements

          # Clear emitter for fresh merge
          @emitter.clear

          # Merge root-level statements via emitter
          merge_node_lists_to_emitter(
            template_statements,
            dest_statements,
            @template_analysis,
            @dest_analysis,
          )

          # Transfer emitter output to result
          # For now, add as single content block - we'll improve decision tracking later
          emitted_content = @emitter.to_s
          unless emitted_content.empty?
            emitted_content.lines.each do |line|
              result.add_line(line.chomp, decision: MergeResult::DECISION_MERGED, source: :merged)
            end
          end

          DebugLogger.debug("Conflict resolution complete", {
            template_statements: template_statements.size,
            dest_statements: dest_statements.size,
            result_lines: result.line_count,
          })
        end
      end

      private

      # Recursively merge two lists of nodes, emitting to emitter
      # @param template_nodes [Array<NodeWrapper>] Template nodes
      # @param dest_nodes [Array<NodeWrapper>] Destination nodes
      # @param template_analysis [FileAnalysis] Template analysis for line access
      # @param dest_analysis [FileAnalysis] Destination analysis for line access
      def merge_node_lists_to_emitter(template_nodes, dest_nodes, template_analysis, dest_analysis)
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
            emit_freeze_block(dest_node)
            processed_dest_sigs << dest_sig if dest_sig
            next
          end

          # Check for signature match
          if dest_sig && template_by_sig[dest_sig]
            template_info = template_by_sig[dest_sig].first
            template_node = template_info[:node]

            # Both have this node - merge them (recursively if containers)
            merge_matched_nodes_to_emitter(template_node, dest_node, template_analysis, dest_analysis)

            processed_dest_sigs << dest_sig
            processed_template_sigs << dest_sig
          elsif refined_dest_to_template.key?(dest_node)
            # Found refined match
            template_node = refined_dest_to_template[dest_node]
            template_sig = template_analysis.generate_signature(template_node)

            # Merge matched nodes
            merge_matched_nodes_to_emitter(template_node, dest_node, template_analysis, dest_analysis)

            processed_dest_sigs << dest_sig if dest_sig
            processed_template_sigs << template_sig if template_sig
          else
            # Destination-only node - always keep
            emit_node(dest_node, dest_analysis)
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
          emit_node(template_node, template_analysis)
          processed_template_sigs << template_sig if template_sig
        end
      end

      # Keep old merge_node_lists for now (will be removed later)
      # This allows gradual migration

      # Merge two matched nodes - for containers, recursively merge children
      # Emits to emitter instead of result
      # @param template_node [NodeWrapper] Template node
      # @param dest_node [NodeWrapper] Destination node
      # @param template_analysis [FileAnalysis] Template analysis
      # @param dest_analysis [FileAnalysis] Destination analysis
      def merge_matched_nodes_to_emitter(template_node, dest_node, template_analysis, dest_analysis)
        if dest_node.container? && template_node.container?
          # Both are containers - recursively merge their children
          merge_container_to_emitter(template_node, dest_node, template_analysis, dest_analysis)
        elsif dest_node.pair? && template_node.pair?
          # Both are pairs - check if their values are OBJECTS (not arrays) that need recursive merge
          template_value = template_node.value_node
          dest_value = dest_node.value_node

          # Only recursively merge if BOTH values are objects (not arrays)
          # Arrays are replaced atomically based on preference
          if template_value&.type == :object && dest_value&.type == :object &&
              template_value.container? && dest_value.container?
            # Both values are objects - recursively merge
            @emitter.emit_nested_object_start(dest_node.key_name)

            # Recursively merge the value objects
            merge_node_lists_to_emitter(
              template_value.mergeable_children,
              dest_value.mergeable_children,
              template_analysis,
              dest_analysis,
            )

            # Emit closing brace
            @emitter.emit_nested_object_end
          elsif @preference == :destination
            # Values are not both objects, or one/both are arrays - use preference and emit
            # Arrays are always replaced, not merged
            emit_node(dest_node, dest_analysis)
          else
            emit_node(template_node, template_analysis)
          end
        elsif @preference == :destination
          # Leaf nodes or mismatched types - use preference
          emit_node(dest_node, dest_analysis)
        else
          emit_node(template_node, template_analysis)
        end
      end

      # Merge container nodes by emitting via emitter
      # @param template_node [NodeWrapper] Template container node
      # @param dest_node [NodeWrapper] Destination container node
      # @param template_analysis [FileAnalysis] Template analysis
      # @param dest_analysis [FileAnalysis] Destination analysis
      def merge_container_to_emitter(template_node, dest_node, template_analysis, dest_analysis)
        # Emit opening bracket
        if dest_node.object?
          @emitter.emit_object_start
        elsif dest_node.array?
          @emitter.emit_array_start
        end

        # Recursively merge the children
        template_children = template_node.mergeable_children
        dest_children = dest_node.mergeable_children

        merge_node_lists_to_emitter(
          template_children,
          dest_children,
          template_analysis,
          dest_analysis,
        )

        # Emit closing bracket
        if dest_node.object?
          @emitter.emit_object_end
        elsif dest_node.array?
          @emitter.emit_array_end
        end
      end

      # Emit a single node to the emitter
      # @param node [NodeWrapper] Node to emit
      # @param analysis [FileAnalysis] Analysis for accessing source
      def emit_node(node, analysis)
        return if freeze_node?(node) # Freeze nodes handled separately

        # Emit leading comments
        if node.start_line
          leading = analysis.comment_tracker.leading_comments_before(node.start_line)
          leading.each do |comment|
            @emitter.emit_tracked_comment(comment)
          end
        end

        # Emit the node content
        if node.pair?
          # Emit as pair
          key = node.key_name
          value_node = node.value_node

          if value_node
            # Check if value is an object (not array) and needs recursive emission
            if value_node.type == :object && value_node.container?
              # Object value - emit structure recursively
              @emitter.emit_nested_object_start(key)
              # Recursively emit object children
              value_node.mergeable_children.each do |child|
                emit_node(child, analysis)
              end
              @emitter.emit_nested_object_end
            else
              # Leaf value or array - get its text and emit as simple pair
              # Arrays are emitted as raw text (not recursively) because Emitter doesn't have emit_array_start(key)
              value_text = if value_node.start_line == value_node.end_line
                value_node.text
              else
                # Multi-line value - get all lines
                lines = []
                (value_node.start_line..value_node.end_line).each do |ln|
                  lines << analysis.line_at(ln)
                end
                lines.join("\n")
              end

              @emitter.emit_pair(key, value_text) if key && value_text
            end
          end
        elsif node.start_line && node.end_line
          # Emit raw content for non-pair nodes
          if node.start_line == node.end_line
            # Single line - add directly
            @emitter.lines << node.text
          else
            # Multi-line - collect and emit
            lines = []
            (node.start_line..node.end_line).each do |ln|
              line = analysis.line_at(ln)
              lines << line if line
            end
            @emitter.emit_raw_lines(lines)
          end
        end
      end

      # Emit a freeze block
      # @param freeze_node [FreezeNode] Freeze block to emit
      def emit_freeze_block(freeze_node)
        @emitter.emit_raw_lines(freeze_node.lines)
      end

      # Build a map of refined matches using match_refiner
      # @param template_nodes [Array<NodeWrapper>] Template nodes
      # @param dest_nodes [Array<NodeWrapper>] Destination nodes
      # @param template_by_sig [Hash] Template signature map
      # @param dest_by_sig [Hash] Destination signature map
      # @return [Hash] Map of template_node => dest_node for refined matches
      def build_refined_matches(template_nodes, dest_nodes, template_by_sig, dest_by_sig)
        return {} unless @match_refiner

        # Find unmatched nodes
        matched_sigs = template_by_sig.keys & dest_by_sig.keys

        unmatched_template = template_nodes.reject do |node|
          sig = @template_analysis.generate_signature(node)
          sig && matched_sigs.include?(sig)
        end

        unmatched_dest = dest_nodes.reject do |node|
          sig = @dest_analysis.generate_signature(node)
          sig && matched_sigs.include?(sig)
        end

        return {} if unmatched_template.empty? || unmatched_dest.empty?

        # Call the match refiner
        matches = @match_refiner.call(unmatched_template, unmatched_dest, {
          template_analysis: @template_analysis,
          dest_analysis: @dest_analysis,
        })

        # Build result map: template node -> dest node
        matches.each_with_object({}) do |match, hash|
          hash[match.template_node] = match.dest_node
        end
      end
    end
  end
end
