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
    class CommentTracker < Ast::Merge::Comment::CStyleTrackerBase
      # Initialize comment tracker by scanning the source
      #
      # @param source [String] JSONC source code
      def initialize(source)
        @source = source
        super(source.lines.map(&:chomp))
      end

      private

      def owner_line_num(owner)
        return owner.start_line if owner.respond_to?(:start_line) && owner.start_line
        return owner.key.start_line if owner.respond_to?(:key) && owner.key&.respond_to?(:start_line) && owner.key.start_line

        nil
      end
    end
  end
end
