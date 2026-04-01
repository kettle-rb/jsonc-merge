# frozen_string_literal: true

require "spec_helper"
require "jsonc/merge"
require "jsonc/merge/comment_tracker"

RSpec.describe "jsonc-merge compatibility shim", :json_grammar do
  it "forwards the legacy namespace to json-merge" do
    expect(Jsonc::Merge::SmartMerger).to eq(Json::Merge::SmartMerger)
    expect(Jsonc::Merge::FileAnalysis).to eq(Json::Merge::FileAnalysis)
    expect(Jsonc::Merge::CommentTracker).to eq(Json::Merge::CommentTracker)
  end

  it "continues to merge commented JSON through the legacy require path" do
    template = <<~JSONC
      {
        "name": "template",
        "added": true
      }
    JSONC

    destination = <<~JSONC
      // shim
      {
        "name": "destination" // inline
      }
    JSONC

    merged = Jsonc::Merge::SmartMerger.new(
      template,
      destination,
      add_template_only_nodes: true,
    ).merge

    expect(merged).to include("// shim")
    expect(merged).to include("// inline")
    expect(merged).to include("\"name\": \"destination\"")
    expect(merged).to include("\"added\": true")
  end
end
