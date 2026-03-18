# frozen_string_literal: true

module Jsonc
  module Merge
    # Custom JSON emitter that preserves comments and formatting.
    # This class provides utilities for emitting JSON while maintaining
    # the original structure, comments, and style choices.
    #
    # Inherits common emitter functionality from Ast::Merge::EmitterBase.
    #
    # @example Basic usage
    #   emitter = Emitter.new
    #   emitter.emit_object_start
    #   emitter.emit_pair("key", '"value"')
    #   emitter.emit_object_end
    class Emitter < Ast::Merge::EmitterBase
      # @return [Boolean] Whether next item needs a comma
      attr_reader :needs_comma

      # Initialize subclass-specific state (comma tracking for JSON)
      def initialize_subclass_state(**options)
        @needs_comma = false
      end

      # Clear subclass-specific state
      def clear_subclass_state
        @needs_comma = false
      end

      # Emit a tracked comment from CommentTracker
      # @param comment [Hash] Comment with :text, :indent, :block
      def emit_tracked_comment(comment)
        indent = " " * (comment[:indent] || 0)
        @lines << if comment[:block]
          "#{indent}/* #{comment[:text]} */"
        else
          "#{indent}// #{comment[:text]}"
        end
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

      # Emit object start
      def emit_object_start
        add_comma_if_needed
        @lines << "#{current_indent}{"
        indent
        @needs_comma = false
      end

      # Emit object end
      def emit_object_end
        dedent
        @lines << "#{current_indent}}"
        @needs_comma = true
      end

      # Emit array start
      #
      # @param key [String, nil] Key name if this array is a value in an object
      # @param inline_comment [String, nil] Optional inline comment for the opening line
      def emit_array_start(key = nil, inline_comment: nil)
        add_comma_if_needed
        line = if key
          "#{current_indent}\"#{key}\": ["
        else
          "#{current_indent}["
        end
        line += " // #{inline_comment}" if inline_comment
        @lines << line
        indent
        @needs_comma = false
      end

      # Emit array end
      def emit_array_end
        dedent
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

      # Emit a key with opening brace for nested object
      # @param key [String] Key name
      # @param inline_comment [String, nil] Optional inline comment for the opening line
      def emit_nested_object_start(key, inline_comment: nil)
        add_comma_if_needed
        line = "#{current_indent}\"#{key}\": {"
        line += " // #{inline_comment}" if inline_comment
        @lines << line
        indent
        @needs_comma = false
      end

      # Emit closing brace for nested object
      def emit_nested_object_end
        dedent
        @lines << "#{current_indent}}"
        @needs_comma = true
      end

      # Get the output as a JSON string
      #
      # @return [String]
      def to_json
        to_s
      end

      private

      def add_comma_if_needed
        return unless @needs_comma && @lines.any?

        line_index = @lines.length - 1
        while line_index >= 0
          line = @lines[line_index]
          stripped = line.strip
          if stripped.empty? || comment_line?(stripped)
            line_index -= 1
            next
          end

          break
        end

        return if line_index.negative?

        # Add comma to the previous structural line if it doesn't already have one
        last_line = @lines[line_index]
        @lines[line_index] = add_comma_to_line(last_line)
      end

      def comment_line?(stripped_line)
        stripped_line.start_with?("//", "/*", "*", "*/")
      end

      def add_comma_to_line(line)
        return line if line.strip.empty?

        inline_match = line.match(%r{\A(?<content>.*?)(?<spacing>\s+)(?<comment>//.*)\z})
        if inline_match
          content = inline_match[:content].rstrip
          return line if content.end_with?(",", "{", "[")

          return "#{content}, #{inline_match[:comment]}"
        end

        stripped = line.rstrip
        return line if stripped.end_with?(",", "{", "[")

        "#{line},"
      end
    end
  end
end
