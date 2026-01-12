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
      def emit_array_start(key = nil)
        add_comma_if_needed
        @lines << if key
          "#{current_indent}\"#{key}\": ["
        else
          "#{current_indent}["
        end
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
      def emit_nested_object_start(key)
        add_comma_if_needed
        @lines << "#{current_indent}\"#{key}\": {"
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
