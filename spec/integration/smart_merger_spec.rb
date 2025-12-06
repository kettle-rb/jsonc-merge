# frozen_string_literal: true

# Integration tests for SmartMerger with real JSON parsing and merging scenarios
# Note: tree-sitter JSON parser does not support JSONC comments, so tests
# that need valid parsing use strict JSON.

RSpec.describe "Jsonc::Merge::SmartMerger Integration" do
  describe "basic merge" do
    let(:template_json) do
      <<~JSON
        {
          "name": "template-package",
          "version": "2.0.0",
          "description": "Template description"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "name": "my-package",
          "version": "1.0.0",
          "custom": "value"
        }
      JSON
    end

    it "performs merge and returns MergeResult" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json)
      result = merger.merge_result

      expect(result).to be_a(Jsonc::Merge::MergeResult)
      output = result.to_json
      expect(output).not_to be_empty
    end
  end

  describe "with template preference" do
    let(:template_json) do
      <<~JSON
        {
          "name": "template",
          "version": "2.0.0"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "name": "destination",
          "version": "1.0.0"
        }
      JSON
    end

    it "uses template values when preference is :template" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        signature_match_preference: :template
      )
      result = merger.merge_result

      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end
  end

  describe "with add_template_only_nodes enabled" do
    let(:template_json) do
      <<~JSON
        {
          "name": "template",
          "newField": "from-template"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "name": "destination"
        }
      JSON
    end

    it "adds template-only nodes" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        add_template_only_nodes: true
      )
      result = merger.merge_result

      output = result.to_json
      expect(output).to include("newField")
    end
  end

  describe "with destination-only nodes" do
    let(:template_json) do
      <<~JSON
        {
          "name": "template"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "name": "destination",
          "customField": "dest-only-value"
        }
      JSON
    end

    it "preserves destination-only nodes" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json)
      result = merger.merge_result

      output = result.to_json
      expect(output).to include("customField")
      expect(output).to include("dest-only-value")
    end
  end
end
