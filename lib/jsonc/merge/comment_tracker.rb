# frozen_string_literal: true

module Jsonc
  module Merge
    # Extracts and tracks comments with their line numbers from JSONC source.
    # JSONC supports both single-line (//) and multi-line (/* */) comments.
    #
    # @example Basic usage
    #   tracker = CommentTracker.new(jsonc_source)
    #   tracker.comments # => [{line: 1, indent: 0, text: "This is a comment"}]
    #   tracker.comment_at(1) # => {line: 1, indent: 0, text: "This is a comment"}
    #
    # @example Comment types
    #   // Single-line comment
    #   /* Block comment */
    #   "key": "value" // Inline comment
    class CommentTracker
      # Regex to match full-line single-line comments
      SINGLE_LINE_COMMENT_REGEX = %r{\A(\s*)//\s?(.*)\z}

      # Regex to match full-line block comments (single line)
      BLOCK_COMMENT_SINGLE_REGEX = %r{\A(\s*)/\*\s?(.*?)\s?\*/\s*\z}

      # Regex to match inline single-line comments
      INLINE_COMMENT_REGEX = %r{\s+//\s?(.*)$}

      # @return [Array<Hash>] All extracted comments with metadata
      attr_reader :comments

      # @return [Array<String>] Source lines
      attr_reader :lines

      # Initialize comment tracker by scanning the source
      #
      # @param source [String] JSONC source code
      def initialize(source)
        @source = source
        @lines = source.lines.map(&:chomp)
        @comments = extract_comments
        @comments_by_line = @comments.group_by { |c| c[:line] }
      end

      # Get comment at a specific line
      #
      # @param line_num [Integer] 1-based line number
      # @return [Hash, nil] Comment info or nil
      def comment_at(line_num)
        @comments_by_line[line_num]&.first
      end

      # Get all supported line comments converted to shared Ast::Merge comment nodes.
      #
      # NOTE: For Slice 1 we expose shared nodes only for line-style comments.
      # Block comments are still tracked, but they are not yet normalized through
      # the shared region/attachment APIs.
      #
      # @return [Array<Ast::Merge::Comment::Line>]
      def comment_nodes
        @comment_nodes ||= shared_region_comments.map do |comment|
          Ast::Merge::Comment::TrackedHashAdapter.node(comment, style: :c_style_line)
        end
      end

      # Get a shared Ast::Merge comment node at a specific line.
      #
      # @param line_num [Integer] 1-based line number
      # @return [Ast::Merge::Comment::Line, nil]
      def comment_node_at(line_num)
        comment = comment_at(line_num)
        return unless comment && shared_region_comment?(comment)

        Ast::Merge::Comment::TrackedHashAdapter.node(comment, style: :c_style_line)
      end

      # Get all comments in a line range
      #
      # @param range [Range] Range of 1-based line numbers
      # @return [Array<Hash>] Comments in the range
      def comments_in_range(range)
        @comments.select { |c| range.cover?(c[:line]) }
      end

      # Get comments in a line range converted to a shared comment region.
      #
      # @param range [Range] Range of 1-based line numbers
      # @param kind [Symbol] Region kind (:leading, :inline, :orphan, etc.)
      # @param full_line_only [Boolean] Whether to keep only full-line comments
      # @return [Ast::Merge::Comment::Region]
      def comment_region_for_range(range, kind:, full_line_only: false)
        selected = comments_in_range(range).select { |comment| shared_region_comment?(comment) }
        selected = selected.select { |comment| comment[:full_line] } if full_line_only

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: kind,
          comments: selected,
          style: :c_style_line,
          metadata: {
            range: range,
            full_line_only: full_line_only,
            source: :comment_tracker,
          },
        )
      end

      # Get a shared leading comment region before a line.
      #
      # @param line_num [Integer] 1-based line number
      # @param comments [Array<Hash>, nil] Optional preselected comment hashes
      # @return [Ast::Merge::Comment::Region, nil]
      def leading_comment_region_before(line_num, comments: nil)
        selected = comments || leading_comments_before(line_num)
        selected = selected.select { |comment| comment[:full_line] && shared_region_comment?(comment) }
        return if selected.empty?

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: :leading,
          comments: selected,
          style: :c_style_line,
          metadata: {
            line_num: line_num,
            source: :comment_tracker,
          },
        )
      end

      # Get a shared inline comment region at a line.
      #
      # @param line_num [Integer] 1-based line number
      # @param comment [Hash, nil] Optional preselected inline comment hash
      # @return [Ast::Merge::Comment::Region, nil]
      def inline_comment_region_at(line_num, comment: nil)
        selected = [comment || inline_comment_at(line_num)].compact.select { |item| shared_region_comment?(item) }
        return if selected.empty?

        Ast::Merge::Comment::TrackedHashAdapter.region(
          kind: :inline,
          comments: selected,
          style: :c_style_line,
          metadata: {
            line_num: line_num,
            source: :comment_tracker,
          },
        )
      end

      # Build a passive shared comment attachment for an owner.
      #
      # @param owner [Object] Structural owner for the attachment
      # @param line_num [Integer, nil] Line number to use for leading/inline lookup
      # @param leading_comments [Array<Hash>, nil] Optional preselected leading comments
      # @param inline_comment [Hash, nil] Optional preselected inline comment
      # @param metadata [Hash] Additional metadata preserved on the attachment
      # @return [Ast::Merge::Comment::Attachment]
      def comment_attachment_for(owner, line_num: nil, leading_comments: nil, inline_comment: nil, **metadata)
        resolved_line_num = line_num || owner_line_num(owner)
        leading_region = if resolved_line_num
          leading_comment_region_before(resolved_line_num, comments: leading_comments)
        end
        inline_region = if resolved_line_num
          inline_comment_region_at(resolved_line_num, comment: inline_comment)
        end

        Ast::Merge::Comment::Attachment.new(
          owner: owner,
          leading_region: leading_region,
          inline_region: inline_region,
          metadata: metadata.merge(
            line_num: resolved_line_num,
            source: :comment_tracker,
          ),
        )
      end

      # Get leading comments before a line (consecutive comment lines immediately above)
      #
      # @param line_num [Integer] 1-based line number
      # @return [Array<Hash>] Leading comments
      def leading_comments_before(line_num)
        leading = []
        current = line_num - 1

        # Skip blank lines between the node and its leading comments
        current -= 1 while current >= 1 && blank_line?(current)

        while current >= 1
          comment = comment_at(current)
          break unless comment && comment[:full_line]

          leading.unshift(comment)
          current -= 1

          # Skip blank lines between consecutive comments
          current -= 1 while current >= 1 && blank_line?(current)
        end

        leading
      end

      # Get trailing comment on the same line (inline comment)
      #
      # @param line_num [Integer] 1-based line number
      # @return [Hash, nil] Inline comment or nil
      def inline_comment_at(line_num)
        comment = comment_at(line_num)
        comment if comment && !comment[:full_line]
      end

      # Check if a line is a full-line comment
      #
      # @param line_num [Integer] 1-based line number
      # @return [Boolean]
      def full_line_comment?(line_num)
        comment = comment_at(line_num)
        comment&.dig(:full_line) || false
      end

      # Check if a line is blank
      #
      # @param line_num [Integer] 1-based line number
      # @return [Boolean]
      def blank_line?(line_num)
        return false if line_num < 1 || line_num > @lines.length

        @lines[line_num - 1].strip.empty?
      end

      # Get raw line content.
      #
      # @param line_num [Integer] 1-based line number
      # @return [String, nil]
      def line_at(line_num)
        return if line_num < 1 || line_num > @lines.length

        @lines[line_num - 1]
      end

      # Build a passive shared comment augmenter for this source.
      #
      # NOTE: Slice 1 intentionally limits the shared augmentation path to
      # line-style comments. Block comments remain tracked separately and can be
      # normalized later without changing this public surface.
      #
      # @param owners [Array<#start_line,#end_line>] Structural owners for attachment inference
      # @param options [Hash] Additional augmenter options
      # @return [Ast::Merge::Comment::Augmenter]
      def augment(owners: [], **options)
        Ast::Merge::Comment::Augmenter.new(
          lines: @lines,
          comments: shared_region_comments,
          owners: owners,
          style: :c_style_line,
          total_comment_count: @comments.size,
          block_comment_count: @comments.count { |comment| comment[:block] },
          **options,
        )
      end

      private

      def owner_line_num(owner)
        return owner.start_line if owner.respond_to?(:start_line) && owner.start_line
        return owner.key.start_line if owner.respond_to?(:key) && owner.key&.respond_to?(:start_line) && owner.key.start_line

        nil
      end

      def shared_region_comments
        @shared_region_comments ||= @comments.select { |comment| shared_region_comment?(comment) }
      end

      def shared_region_comment?(comment)
        !comment[:block]
      end

      def extract_comments
        comments = []
        in_block_comment = false

        @lines.each_with_index do |line, idx|
          line_num = idx + 1

          # Handle multi-line block comments
          if in_block_comment
            if line.include?("*/")
              in_block_comment = false
              # Multi-line block comment ends - we already captured the start
            end
            next
          end

          # Check for block comment start
          if line.include?("/*") && !line.include?("*/")
            in_block_comment = true
            match = line.match(/\A(\s*)/)
            comments << {
              line: line_num,
              indent: match ? match[1].length : 0,
              text: line.sub(/\A\s*\/\*\s?/, "").strip,
              full_line: true,
              block: true,
              raw: line,
            }
            next
          end

          # Check for single-line block comment
          if (match = line.match(BLOCK_COMMENT_SINGLE_REGEX))
            comments << {
              line: line_num,
              indent: match[1].length,
              text: match[2],
              full_line: true,
              block: true,
              raw: line,
            }
            next
          end

          # Check for full-line single-line comment
          if (match = line.match(SINGLE_LINE_COMMENT_REGEX))
            comments << {
              line: line_num,
              indent: match[1].length,
              text: match[2],
              full_line: true,
              block: false,
              raw: line,
            }
            next
          end

          # Check for inline comment (after JSON content)
          # Be careful not to match // inside strings
          if line.include?("//")
            # Simple heuristic: if there's content before //, it might be inline
            # This doesn't handle all edge cases with strings containing //
            parts = line.split("//", 2)
            if parts.length == 2 && !parts[0].strip.empty?
              # Verify it's not inside a string by checking quote balance
              before_comment = parts[0]
              quote_count = before_comment.count('"') - before_comment.scan('\\"').count
              if quote_count.even?
                comments << {
                  line: line_num,
                  indent: 0,
                  text: parts[1].strip,
                  full_line: false,
                  block: false,
                  raw: "// #{parts[1].strip}",
                }
              end
            end
          end
        end

        comments
      end
    end
  end
end
