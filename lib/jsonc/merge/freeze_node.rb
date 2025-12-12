# frozen_string_literal: true

module Jsonc
  module Merge
    # Wrapper to represent freeze blocks as first-class nodes in JSON/JSONC files.
    # A freeze block is a section marked with freeze/unfreeze comment markers that
    # should be preserved from the destination during merges.
    #
    # Inherits from Ast::Merge::FreezeNodeBase for shared functionality including
    # the Location struct, InvalidStructureError, and configurable marker patterns.
    #
    # Uses the `:c_style_line` or `:c_style_block` pattern types for JSONC files
    # (// comments and /* */ comments).
    #
    # @example Freeze block with single-line comments
    #   // json-merge:freeze
    #   "secret_key": "my-secret-value",
    #   "api_endpoint": "https://custom.example.com"
    #   // json-merge:unfreeze
    #
    # @example Freeze block with block comments
    #   /* json-merge:freeze */
    #   "secret_key": "my-secret-value"
    #   /* json-merge:unfreeze */
    class FreezeNode < Ast::Merge::FreezeNodeBase
      # Inherit InvalidStructureError from base class
      InvalidStructureError = Ast::Merge::FreezeNodeBase::InvalidStructureError

      # Inherit Location from base class
      Location = Ast::Merge::FreezeNodeBase::Location

      # @param start_line [Integer] Line number of freeze marker
      # @param end_line [Integer] Line number of unfreeze marker
      # @param lines [Array<String>] All source lines
      # @param start_marker [String, nil] The freeze start marker text
      # @param end_marker [String, nil] The freeze end marker text
      # @param pattern_type [Symbol] Pattern type for marker matching (defaults to :c_style_line)
      def initialize(start_line:, end_line:, lines:, start_marker: nil, end_marker: nil, pattern_type: :c_style_line)
        # Extract lines for the entire block (lines param is all source lines)
        block_lines = (start_line..end_line).map { |ln| lines[ln - 1] }

        super(
          start_line: start_line,
          end_line: end_line,
          lines: block_lines,
          start_marker: start_marker,
          end_marker: end_marker,
          pattern_type: pattern_type
        )

        validate_structure!
      end

      # Returns a stable signature for this freeze block.
      # Signature includes the normalized content to detect changes.
      # @return [Array] Signature array
      def signature
        # Normalize by stripping each line and joining
        normalized = @lines.map { |l| l&.strip }.compact.reject(&:empty?).join("\n")
        [:FreezeNode, normalized]
      end

      # Check if this is an object node (always false for FreezeNode)
      # @return [Boolean]
      def object?
        false
      end

      # Check if this is an array node (always false for FreezeNode)
      # @return [Boolean]
      def array?
        false
      end

      # Check if this is a pair node (always false for FreezeNode)
      # @return [Boolean]
      def pair?
        false
      end

      # String representation for debugging
      # @return [String]
      def inspect
        "#<#{self.class.name} lines=#{start_line}..#{end_line} content_length=#{slice&.length || 0}>"
      end

      private

      def validate_structure!
        validate_line_order!

        if @lines.empty? || @lines.all?(&:nil?)
          raise InvalidStructureError.new(
            "Freeze block is empty",
            start_line: @start_line,
            end_line: @end_line,
          )
        end
      end
    end
  end
end
