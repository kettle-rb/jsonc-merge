# frozen_string_literal: true

module Jsonc
  module Merge
    # Custom JSON emitter that preserves comments and formatting.
    # This class provides utilities for emitting JSON while maintaining
    # the original structure, comments, and style choices.
    #
    # @example Basic usage
    #   emitter = Emitter.new
    #   emitter.emit_object_start
    #   emitter.emit_pair("key", '"value"')
    #   emitter.emit_object_end
    class Emitter
      # @return [Array<String>] Output lines
      attr_reader :lines

      # @return [Integer] Current indentation level
      attr_reader :indent_level

      # @return [Integer] Spaces per indent level
      attr_reader :indent_size

      # Initialize a new emitter
      #
      # @param indent_size [Integer] Number of spaces per indent level
      def initialize(indent_size: 2)
        @lines = []
        @indent_level = 0
        @indent_size = indent_size
        @needs_comma = false
      end

      # Emit a single-line comment
      #
      # @param text [String] Comment text (without //)
      # @param inline [Boolean] Whether this is an inline comment
      def emit_comment(text, inline: false)
        if inline
          # Inline comments are appended to the last line
          return if @lines.empty?

          @lines[-1] = "#{@lines[-1]} // #{text}"
        else
          @lines << "#{current_indent}// #{text}"
        end
      end

      # Emit a block comment
      #
      # @param text [String] Comment text
      def emit_block_comment(text)
        @lines << "#{current_indent}/* #{text} */"
      end

      # Emit leading comments
      #
      # @param comments [Array<Hash>] Comment hashes from CommentTracker
      def emit_leading_comments(comments)
        comments.each do |comment|
          indent = " " * (comment[:indent] || 0)
          if comment[:block]
            @lines << "#{indent}/* #{comment[:text]} */"
          else
            @lines << "#{indent}// #{comment[:text]}"
          end
        end
      end

      # Emit a blank line
      def emit_blank_line
        @lines << ""
      end

      # Emit object start
      def emit_object_start
        add_comma_if_needed
        @lines << "#{current_indent}{"
        @indent_level += 1
        @needs_comma = false
      end

      # Emit object end
      def emit_object_end
        @indent_level -= 1 if @indent_level > 0
        @lines << "#{current_indent}}"
        @needs_comma = true
      end

      # Emit array start
      #
      # @param key [String, nil] Key name if this array is a value in an object
      def emit_array_start(key = nil)
        add_comma_if_needed
        if key
          @lines << "#{current_indent}\"#{key}\": ["
        else
          @lines << "#{current_indent}["
        end
        @indent_level += 1
        @needs_comma = false
      end

      # Emit array end
      def emit_array_end
        @indent_level -= 1 if @indent_level > 0
        @lines << "#{current_indent}]"
        @needs_comma = true
      end

      # Emit a key-value pair
      #
      # @param key [String] Key name (without quotes)
      # @param value [String] Value (already formatted, e.g., '"string"', '123', 'true')
      # @param inline_comment [String, nil] Optional inline comment
      def emit_pair(key, value, inline_comment: nil)
        add_comma_if_needed
        line = "#{current_indent}\"#{key}\": #{value}"
        line += " // #{inline_comment}" if inline_comment
        @lines << line
        @needs_comma = true
      end

      # Emit an array element
      #
      # @param value [String] Value (already formatted)
      # @param inline_comment [String, nil] Optional inline comment
      def emit_array_element(value, inline_comment: nil)
        add_comma_if_needed
        line = "#{current_indent}#{value}"
        line += " // #{inline_comment}" if inline_comment
        @lines << line
        @needs_comma = true
      end

      # Emit raw lines (for preserving existing content)
      #
      # @param raw_lines [Array<String>] Lines to emit as-is
      def emit_raw_lines(raw_lines)
        raw_lines.each { |line| @lines << line.chomp }
      end

      # Get the output as a single string
      #
      # @return [String]
      def to_json
        content = @lines.join("\n")
        content += "\n" unless content.empty? || content.end_with?("\n")
        content
      end

      # Alias for consistency
      # @return [String]
      alias_method :to_s, :to_json

      # Clear the output
      def clear
        @lines = []
        @indent_level = 0
        @needs_comma = false
      end

      private

      def current_indent
        " " * (@indent_level * @indent_size)
      end

      def add_comma_if_needed
        return unless @needs_comma && @lines.any?

        # Add comma to the previous line if it doesn't already have one
        last_line = @lines.last
        return if last_line.strip.empty?
        return if last_line.rstrip.end_with?(",")
        return if last_line.rstrip.end_with?("{")
        return if last_line.rstrip.end_with?("[")

        @lines[-1] = "#{last_line},"
      end
    end
  end
end
