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
      include ::Ast::Merge::TrailingGroups::DestIterate
      # Creates a new ConflictResolver
      #
      # @param template_analysis [FileAnalysis] Analyzed template file
      # @param dest_analysis [FileAnalysis] Analyzed destination file
      # @param preference [Symbol, Hash] Which version to prefer when
      #   nodes have matching signatures:
      #   - :destination (default) - Keep destination version (customizations)
      #   - :template - Use template version (updates)
      # @param add_template_only_nodes [Boolean] Whether to add nodes only in template
      # @param match_refiner [#call, nil] Optional match refiner for fuzzy matching
      # @param options [Hash] Additional options for forward compatibility
      # @param node_typing [Hash{Symbol,String => #call}, nil] Node typing configuration
      #   for per-node-type preferences
      def initialize(template_analysis, dest_analysis, preference: :destination, add_template_only_nodes: false, remove_template_missing_nodes: false, match_refiner: nil, node_typing: nil, **options)
        super(
          strategy: :batch,
          preference: preference,
          template_analysis: template_analysis,
          dest_analysis: dest_analysis,
          add_template_only_nodes: add_template_only_nodes,
          remove_template_missing_nodes: remove_template_missing_nodes,
          match_refiner: match_refiner,
          **options
        )
        @node_typing = node_typing
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

          emit_document_prelude(@dest_analysis, nodes: dest_statements)

          # Merge root-level statements via emitter
          merge_node_lists_to_emitter(
            template_statements,
            dest_statements,
            @template_analysis,
            @dest_analysis,
          )

          emit_document_postlude(@dest_analysis, fallback_node: dest_statements.last)

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

        consumed_template_indices = ::Set.new
        sig_cursor = Hash.new(0)

        # Pre-compute position-aware trailing groups for template-only nodes.
        dest_sigs = ::Set.new
        dest_nodes.each { |n| sig = dest_analysis.generate_signature(n); dest_sigs << sig if sig }
        refined_template_ids = ::Set.new(refined_matches.keys.map(&:object_id))

        trailing_groups, all_matched_indices = build_dest_iterate_trailing_groups(
          template_nodes: template_nodes,
          dest_sigs: dest_sigs,
          signature_for: ->(node) { template_analysis.generate_signature(node) },
          refined_template_ids: refined_template_ids,
          add_template_only_nodes: @add_template_only_nodes,
        )

        emit_prefix_trailing_group(trailing_groups, consumed_template_indices) do |info|
          next if freeze_node?(info[:node])
          emit_node(info[:node], template_analysis)
        end

        # First pass: Process destination nodes
        dest_nodes.each do |dest_node|
          dest_sig = dest_analysis.generate_signature(dest_node)

          # Freeze blocks from destination are always preserved
          if freeze_node?(dest_node)
            emit_freeze_block(dest_node)
            next
          end

          # Check for signature match
          if dest_sig && template_by_sig[dest_sig]
            candidates = template_by_sig[dest_sig]
            cursor = sig_cursor[dest_sig]
            template_info = nil

            while cursor < candidates.size
              candidate = candidates[cursor]
              unless consumed_template_indices.include?(candidate[:index])
                template_info = candidate
                break
              end
              cursor += 1
            end

            if template_info
              template_node = template_info[:node]
              merge_matched_nodes_to_emitter(template_node, dest_node, template_analysis, dest_analysis)
              consumed_template_indices << template_info[:index]
              sig_cursor[dest_sig] = cursor + 1
            else
              emit_node(dest_node, dest_analysis)
            end
          elsif refined_dest_to_template.key?(dest_node)
            template_node = refined_dest_to_template[dest_node]
            template_sig = template_analysis.generate_signature(template_node)

            if template_sig && template_by_sig[template_sig]
              template_by_sig[template_sig].each do |info|
                unless consumed_template_indices.include?(info[:index])
                  consumed_template_indices << info[:index]
                  break
                end
              end
            end

            merge_matched_nodes_to_emitter(template_node, dest_node, template_analysis, dest_analysis)
          else
            if @remove_template_missing_nodes
              emit_removed_destination_node_comments(dest_node, dest_analysis)
            else
              emit_node(dest_node, dest_analysis)
            end
          end

          # Flush interior trailing groups that are ready
          flush_ready_trailing_groups(
            trailing_groups: trailing_groups,
            matched_indices: all_matched_indices,
            consumed_indices: consumed_template_indices,
          ) do |info|
            next if freeze_node?(info[:node])
            emit_node(info[:node], template_analysis)
          end
        end

        # Emit remaining trailing groups (tail + safety net)
        emit_remaining_trailing_groups(
          trailing_groups: trailing_groups,
          consumed_indices: consumed_template_indices,
        ) do |info|
          next if freeze_node?(info[:node])
          emit_node(info[:node], template_analysis)
        end
      end

      # Override hook: freeze nodes are treated as matched for trailing group purposes.
      def trailing_group_node_matched?(node, _signature)
        freeze_node?(node)
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

          if template_value&.container? && dest_value&.container? && template_value.type == dest_value.type
            key_name = dest_node.key_name || template_node.key_name
            comment_source_node, comment_source_analysis = preferred_comment_source(
              dest_node,
              dest_analysis,
              fallback_node: template_node,
              fallback_analysis: template_analysis,
            )

            emit_leading_comments_for(comment_source_node, comment_source_analysis)
            inline_text = inline_comment_text_for(comment_source_node, comment_source_analysis)
            trailing_source_node, trailing_source_analysis = preferred_container_comment_source(
              dest_value,
              dest_analysis,
              fallback_node: template_value,
              fallback_analysis: template_analysis,
            )
            compact_source_node = trailing_source_node || dest_value || template_value

            if compact_empty_container?(template_value, compact_source_node, trailing_source_analysis)
              @emitter.emit_pair(key_name, compact_container_literal_for(template_value), inline_comment: inline_text)
            elsif template_value.object?
              @emitter.emit_nested_object_start(key_name, inline_comment: inline_text)
            elsif template_value.array?
              @emitter.emit_array_start(key_name, inline_comment: inline_text)
            end

            unless compact_empty_container?(template_value, compact_source_node, trailing_source_analysis)
              merge_node_lists_to_emitter(
                template_value.mergeable_children,
                dest_value.mergeable_children,
                template_analysis,
                dest_analysis,
              )

              emit_container_trailing_lines(trailing_source_node, trailing_source_analysis)

              if template_value.object?
                @emitter.emit_nested_object_end
              elsif template_value.array?
                @emitter.emit_array_end
              end
            end
          elsif preference_for_pair(template_node, dest_node) == :destination
            # Values are not both mergeable containers - use preference and emit
            emit_node(dest_node, dest_analysis)
          else
            emit_node(
              template_node,
              template_analysis,
              comment_source_node: dest_node,
              comment_analysis: dest_analysis,
            )
          end
        elsif preference_for_pair(template_node, dest_node) == :destination
          # Leaf nodes or mismatched types - use preference
          emit_node(dest_node, dest_analysis)
        else
          emit_node(
            template_node,
            template_analysis,
            comment_source_node: dest_node,
            comment_analysis: dest_analysis,
          )
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

        trailing_source_node, trailing_source_analysis = preferred_container_comment_source(
          dest_node,
          dest_analysis,
          fallback_node: template_node,
          fallback_analysis: template_analysis,
        )
        emit_container_trailing_lines(trailing_source_node, trailing_source_analysis)

        # Emit closing bracket
        if dest_node.object?
          @emitter.emit_object_end
        elsif dest_node.array?
          @emitter.emit_array_end
        end
      end

      def preference_for_pair(template_node, dest_node)
        return @preference unless @preference.is_a?(Hash)

        typed_template = apply_node_typing(template_node)
        typed_dest = apply_node_typing(dest_node)

        if Ast::Merge::NodeTyping.typed_node?(typed_template)
          merge_type = Ast::Merge::NodeTyping.merge_type_for(typed_template)
          return @preference.fetch(merge_type) { default_preference } if merge_type
        end

        if Ast::Merge::NodeTyping.typed_node?(typed_dest)
          merge_type = Ast::Merge::NodeTyping.merge_type_for(typed_dest)
          return @preference.fetch(merge_type) { default_preference } if merge_type
        end

        default_preference
      end

      def apply_node_typing(node)
        return node unless @node_typing
        return node unless node

        Ast::Merge::NodeTyping.process(node, @node_typing)
      end

      # Emit a single node to the emitter
      # @param node [NodeWrapper] Node to emit
      # @param analysis [FileAnalysis] Analysis for accessing source
      def emit_node(node, analysis, comment_source_node: nil, comment_analysis: analysis)
        return if freeze_node?(node) # Freeze nodes handled separately

        source_node = comment_source_node || node
        source_analysis = comment_source_node ? comment_analysis : analysis

        emit_leading_comments_for(source_node, source_analysis)

        # Emit the node content
        if node.pair?
          # Emit as pair
          key = node.key_name
          value_node = node.value_node
          source_value_node = source_node.respond_to?(:value_node) ? source_node.value_node : nil

          if value_node
            if value_node.container?
              inline_text = inline_comment_text_for(source_node, source_analysis)
              container_comment_source = source_value_node || value_node

              if compact_empty_container?(value_node, container_comment_source, source_analysis)
                @emitter.emit_pair(key, compact_container_literal_for(value_node), inline_comment: inline_text) if key
              elsif value_node.object?
                @emitter.emit_nested_object_start(key, inline_comment: inline_text)
              elsif value_node.array?
                @emitter.emit_array_start(key, inline_comment: inline_text)
              end

              unless compact_empty_container?(value_node, container_comment_source, source_analysis)
                value_node.mergeable_children.each do |child|
                  emit_node(child, analysis)
                end

                emit_container_trailing_lines(container_comment_source, source_analysis)

                if value_node.object?
                  @emitter.emit_nested_object_end
                elsif value_node.array?
                  @emitter.emit_array_end
                end
              end
            else
              inline_text = inline_comment_text_for(source_node, source_analysis)

              @emitter.emit_pair(key, value_node.text, inline_comment: inline_text) if key
            end
          end
        elsif node.container?
          if node.object?
            @emitter.emit_object_start
          elsif node.array?
            @emitter.emit_array_start
          end

          node.mergeable_children.each do |child|
            emit_node(child, analysis)
          end

          emit_container_trailing_lines(source_node, source_analysis)

          if node.object?
            @emitter.emit_object_end
          elsif node.array?
            @emitter.emit_array_end
          end
        elsif node.start_line && node.end_line
          inline_text = inline_comment_text_for(source_node, source_analysis)

          if node.start_line == node.end_line
            @emitter.emit_array_element(node.text, inline_comment: inline_text)
          else
            lines = []
            (node.start_line..node.end_line).each do |ln|
              line = analysis.line_at(ln)
              lines << line if line
            end
            @emitter.emit_raw_lines(lines)
          end
        end
      end


      def preferred_comment_source(node, analysis, fallback_node: nil, fallback_analysis: nil)
        return [node, analysis] if node_has_emittable_comments?(node, analysis)
        return [fallback_node, fallback_analysis] if fallback_node && node_has_emittable_comments?(fallback_node, fallback_analysis)

        [node, analysis]
      end

      def preferred_container_comment_source(node, analysis, fallback_node: nil, fallback_analysis: nil)
        return [node, analysis] if container_has_trailing_comments?(node, analysis)
        return [fallback_node, fallback_analysis] if fallback_node && container_has_trailing_comments?(fallback_node, fallback_analysis)

        [node, analysis]
      end

      def node_has_emittable_comments?(node, analysis)
        return false unless node&.respond_to?(:start_line) && node.start_line

        analysis.comment_tracker.leading_comments_before(node.start_line).any? ||
          !inline_comment_text_for(node, analysis).nil?
      end

      def emit_leading_comments_for(node, analysis)
        return unless node&.respond_to?(:start_line) && node.start_line

        leading = analysis.comment_tracker.leading_comments_before(node.start_line)
        emit_blank_lines_before_leading_comments(leading.first[:line], analysis) if leading.any?
        emit_tracked_comments_with_internal_blank_lines(leading, analysis)

        if leading.any?
          emit_blank_lines_in_range(leading.last[:line] + 1, node.start_line - 1, analysis)
        end
      end

      def inline_comment_text_for(node, analysis)
        return unless node&.respond_to?(:start_line) && node.start_line

        inline_comment = analysis.comment_tracker.inline_comment_at(node.end_line || node.start_line)
        inline_comment&.dig(:text)
      end

      def emit_container_trailing_lines(container_node, analysis)
        range = trailing_container_line_range(container_node)
        return unless range

        emit_comment_and_blank_lines_in_range(range.begin, range.end, analysis)
      end

      def container_has_trailing_comments?(container_node, analysis)
        range = trailing_container_line_range(container_node)
        return false unless range

        range.any? do |line_num|
          stripped = analysis.line_at(line_num).to_s.strip
          comment_like_line?(stripped)
        end
      end

      def trailing_container_line_range(container_node)
        return unless container_node&.container?
        return unless container_node.respond_to?(:start_line) && container_node.respond_to?(:end_line)
        return unless container_node.start_line && container_node.end_line

        children = container_node.mergeable_children
        start_line = if children.any?
          last_child = children.last
          (last_child.end_line || last_child.start_line) + 1
        else
          container_node.start_line + 1
        end
        end_line = container_node.end_line - 1
        return unless end_line >= start_line

        start_line..end_line
      end

      def emit_comment_and_blank_lines_in_range(start_line, end_line, analysis)
        return unless start_line && end_line
        return if end_line < start_line

        lines = []
        (start_line..end_line).each do |line_num|
          line = analysis.line_at(line_num)
          next unless line

          stripped = line.strip
          next unless stripped.empty? || comment_like_line?(stripped)

          lines << line
        end

        @emitter.emit_raw_lines(lines) if lines.any?
      end

      def comment_like_line?(stripped_line)
        stripped_line.start_with?("//", "/*", "*", "*/")
      end

      # Emit a freeze block
      # @param freeze_node [FreezeNode] Freeze block to emit
      def emit_freeze_block(freeze_node)
        @emitter.emit_raw_lines(freeze_node.lines)
      end

      def emit_removed_destination_node_comments(node, analysis)
        return unless node.respond_to?(:start_line) && node.start_line

        leading = analysis.comment_tracker.leading_comments_before(node.start_line)
        emit_blank_lines_before_leading_comments(leading.first[:line], analysis) if leading.any?
        emit_tracked_comments_with_internal_blank_lines(leading, analysis)

        inline_comment = analysis.comment_tracker.inline_comment_at(node.end_line || node.start_line)
        if inline_comment
          line = analysis.line_at(inline_comment[:line])
          indent = line.to_s[/\A\s*/].to_s.length
          @emitter.emit_tracked_comment(normalize_comment_indent(
            inline_comment.merge(
              indent: indent,
              full_line: true,
              block: false,
            ),
          ))
        end

        emit_following_removed_node_blank_lines(node, analysis)
      end

      def emit_following_removed_node_blank_lines(node, analysis)
        line_num = (node.end_line || node.start_line) + 1
        first_nonblank_line = line_num

        while first_nonblank_line <= analysis.lines.length && analysis.comment_tracker.blank_line?(first_nonblank_line)
          first_nonblank_line += 1
        end

        return if analysis.comment_tracker.full_line_comment?(first_nonblank_line)

        while line_num <= analysis.lines.length && analysis.comment_tracker.blank_line?(line_num)
          @emitter.emit_blank_line
          line_num += 1
        end
      end

      def emit_tracked_comments_with_internal_blank_lines(comments, analysis)
        Array(comments).each_with_index do |comment, index|
          @emitter.emit_tracked_comment(normalize_comment_indent(comment))

          next_comment = comments[index + 1]
          next unless next_comment

          emit_blank_lines_in_range(comment[:line] + 1, next_comment[:line] - 1, analysis)
        end
      end

      def emit_document_prelude(analysis, nodes: [])
        augmenter = document_comment_augmenter_for(analysis)
        return unless augmenter

        normalized_nodes = Array(nodes)
        regions = []
        preamble = augmenter.preamble_region
        regions << preamble if preamble && !preamble.empty?

        if normalized_nodes.any?
          first_attachment = augmenter.attachment_for(normalized_nodes.first)
          first_leading = first_attachment&.leading_region
          if first_leading && !first_leading.empty?
            duplicate = regions.any? do |region|
              region.start_line == first_leading.start_line && region.end_line == first_leading.end_line
            end
            regions << first_leading unless duplicate
          end
        end

        if normalized_nodes.empty?
          augmenter.orphan_regions.each do |region|
            regions << region if region && !region.empty?
          end
        end

        regions.each do |region|
          emit_comment_region_lines(region, analysis)
        end

        return if regions.empty?

        last_region_end = regions.last.end_line
        if normalized_nodes.any?
          first_node_start = normalized_nodes.first.start_line
          emit_blank_lines_in_range(last_region_end + 1, first_node_start - 1, analysis) if last_region_end && first_node_start
        else
          emit_blank_lines_in_range(last_region_end + 1, analysis.lines.length, analysis) if last_region_end
        end
      end

      def emit_document_postlude(analysis, fallback_node: nil)
        augmenter = document_comment_augmenter_for(analysis)
        postlude = augmenter&.postlude_region
        return unless postlude && !postlude.empty?

        if fallback_node && postlude.respond_to?(:start_line) && postlude.start_line
          emit_blank_lines_in_range(fallback_node.end_line + 1, postlude.start_line - 1, analysis) if fallback_node.respond_to?(:end_line) && fallback_node.end_line
        end

        emit_comment_region_lines(postlude, analysis)
      end

      def document_comment_augmenter_for(analysis)
        @document_comment_augmenters ||= {}
        @document_comment_augmenters[analysis.object_id] ||= analysis.comment_augmenter
      end

      def emit_comment_region_lines(region, analysis)
        return unless region&.start_line && region.end_line

        lines = (region.start_line..region.end_line).filter_map { |line_num| analysis.line_at(line_num) }
        @emitter.emit_raw_lines(lines) if lines.any?
      end

      def emit_blank_lines_in_range(start_line, end_line, analysis)
        return unless start_line && end_line
        return if end_line < start_line

        (start_line..end_line).each do |line_num|
          @emitter.emit_blank_line if analysis.comment_tracker.blank_line?(line_num)
        end
      end

      def emit_blank_lines_before_leading_comments(first_comment_line, analysis)
        return unless first_comment_line

        blank_lines = []
        line_num = first_comment_line - 1
        while line_num >= 1 && analysis.comment_tracker.blank_line?(line_num)
          blank_lines << line_num
          line_num -= 1
        end

        blank_lines.reverse_each { @emitter.emit_blank_line }
      end

      def normalize_comment_indent(comment)
        return comment unless comment

        comment.merge(indent: current_emitter_indent)
      end

      def current_emitter_indent
        @emitter.indent_level * @emitter.indent_size
      end

      def compact_empty_container?(container_node, source_node, source_analysis)
        return false unless container_node&.container?
        return false unless container_node.mergeable_children.empty?

        !container_has_trailing_comments?(source_node || container_node, source_analysis)
      end

      def compact_container_literal_for(container_node)
        container_node.object? ? "{}" : "[]"
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
