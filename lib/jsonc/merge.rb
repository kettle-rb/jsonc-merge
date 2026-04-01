# frozen_string_literal: true

# Compatibility shim: jsonc-merge now forwards to json-merge.
# Keep the legacy namespace and require paths available for callers that
# still depend on jsonc-merge while all merge behavior lives in json-merge.
require "version_gem"
require "ast/merge"

module Jsonc
  # Legacy namespace kept for compatibility.
  module Merge
    require "json/merge"
    require_relative "merge/version"

    Error = Json::Merge::Error
    ParseError = Json::Merge::ParseError
    TemplateParseError = Json::Merge::TemplateParseError
    DestinationParseError = Json::Merge::DestinationParseError

    CommentTracker = Json::Merge::CommentTracker
    DebugLogger = Json::Merge::DebugLogger
    Emitter = Json::Merge::Emitter
    FreezeNode = Json::Merge::FreezeNode
    FileAnalysis = Json::Merge::FileAnalysis
    MergeResult = Json::Merge::MergeResult
    NodeWrapper = Json::Merge::NodeWrapper
    ConflictResolver = Json::Merge::ConflictResolver
    SmartMerger = Json::Merge::SmartMerger
  end
end

# Register with ast-merge's MergeGemRegistry for RSpec dependency tags
# Only register if MergeGemRegistry is loaded (i.e., in test environment)
if defined?(Ast::Merge::RSpec::MergeGemRegistry)
  Ast::Merge::RSpec::MergeGemRegistry.register(
    :jsonc_merge,
    require_path: "jsonc/merge",
    merger_class: "Jsonc::Merge::SmartMerger",
    test_source: "// comment\n{\"key\": \"value\"}",
    category: :data,
  )
end

Jsonc::Merge::Version.class_eval do
  extend VersionGem::Basic
end
