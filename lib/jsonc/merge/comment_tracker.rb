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

      # Get all comments in a line range
      #
      # @param range [Range] Range of 1-based line numbers
      # @return [Array<Hash>] Comments in the range
      def comments_in_range(range)
        @comments.select { |c| range.cover?(c[:line]) }
      end

      # Get leading comments before a line (consecutive comment lines immediately above)
      #
      # @param line_num [Integer] 1-based line number
      # @return [Array<Hash>] Leading comments
      def leading_comments_before(line_num)
        leading = []
        current = line_num - 1

        while current >= 1
          comment = comment_at(current)
          break unless comment && comment[:full_line]

          leading.unshift(comment)
          current -= 1
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

      private

      def extract_comments
        comments = []
        in_block_comment = false
        block_comment_start = nil
        block_comment_indent = 0

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
            block_comment_start = line_num
            match = line.match(/\A(\s*)/)
            block_comment_indent = match ? match[1].length : 0
            comments << {
              line: line_num,
              indent: block_comment_indent,
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
