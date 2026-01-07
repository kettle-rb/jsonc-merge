# frozen_string_literal: true

# std libs
require "set"

# External gems
# TreeHaver provides a unified cross-Ruby interface to tree-sitter.
# It handles grammar discovery and backend selection automatically
# via parser_for(:jsonc). No manual registration needed.
require "tree_haver"
require "version_gem"

# Shared merge infrastructure
require "ast/merge"

# This gem
require_relative "merge/version"

# Jsonc::Merge provides a generic JSONC file smart merge system using tree-sitter AST analysis.
# It intelligently merges template and destination JSON/JSONC files by identifying matching
# keys and resolving differences using structural signatures.
#
# JSONC (JSON with Comments) support allows merging configuration files that include
# comments (like devcontainer.json, tsconfig.json, VS Code settings, etc.).
#
# @example Basic usage
#   template = File.read("template.json")
#   destination = File.read("destination.json")
#   merger = Jsonc::Merge::SmartMerger.new(template, destination)
#   result = merger.merge
#
# @example With debug information
#   merger = Jsonc::Merge::SmartMerger.new(template, destination)
#   debug_result = merger.merge_with_debug
#   puts debug_result[:content]
#   puts debug_result[:statistics]
module Jsonc
  # Smart merge system for JSONC files using tree-sitter AST analysis.
  # Provides intelligent merging by understanding JSON structure
  # rather than treating files as plain text.
  #
  # @see SmartMerger Main entry point for merge operations
  # @see FileAnalysis Analyzes JSON structure
  # @see ConflictResolver Resolves content conflicts
  module Merge
    # Base error class for Jsonc::Merge
    # Inherits from Ast::Merge::Error for consistency across merge gems.
    class Error < Ast::Merge::Error; end

    # Raised when a JSON/JSONC file has parsing errors.
    # Inherits from Ast::Merge::ParseError for consistency across merge gems.
    #
    # @example Handling parse errors
    #   begin
    #     analysis = FileAnalysis.new(json_content)
    #   rescue ParseError => e
    #     puts "JSON syntax error: #{e.message}"
    #     e.errors.each { |error| puts "  #{error}" }
    #   end
    class ParseError < Ast::Merge::ParseError
      # @param message [String, nil] Error message (auto-generated if nil)
      # @param content [String, nil] The JSON source that failed to parse
      # @param errors [Array] Parse errors from tree-sitter
      def initialize(message = nil, content: nil, errors: [])
        super(message, errors: errors, content: content)
      end
    end

    # Raised when the template file has syntax errors.
    #
    # @example Handling template parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue TemplateParseError => e
    #     puts "Template syntax error: #{e.message}"
    #     e.errors.each do |error|
    #       puts "  #{error.message}"
    #     end
    #   end
    class TemplateParseError < ParseError; end

    # Raised when the destination file has syntax errors.
    #
    # @example Handling destination parse errors
    #   begin
    #     merger = SmartMerger.new(template, destination)
    #     result = merger.merge
    #   rescue DestinationParseError => e
    #     puts "Destination syntax error: #{e.message}"
    #     e.errors.each do |error|
    #       puts "  #{error.message}"
    #     end
    #   end
    class DestinationParseError < ParseError; end

    autoload :CommentTracker, "jsonc/merge/comment_tracker"
    autoload :DebugLogger, "jsonc/merge/debug_logger"
    autoload :Emitter, "jsonc/merge/emitter"
    autoload :FreezeNode, "jsonc/merge/freeze_node"
    autoload :FileAnalysis, "jsonc/merge/file_analysis"
    autoload :MergeResult, "jsonc/merge/merge_result"
    autoload :NodeWrapper, "jsonc/merge/node_wrapper"
    autoload :ConflictResolver, "jsonc/merge/conflict_resolver"
    autoload :SmartMerger, "jsonc/merge/smart_merger"
  end
end

Jsonc::Merge::Version.class_eval do
  extend VersionGem::Basic
end
