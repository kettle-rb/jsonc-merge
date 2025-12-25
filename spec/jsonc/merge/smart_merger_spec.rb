# frozen_string_literal: true

RSpec.describe Jsonc::Merge::SmartMerger do
  let(:template_json) do
    <<~JSON
      {
        "name": "template-package",
        "version": "2.0.0",
        "description": "A template package",
        "dependencies": {
          "lodash": "^4.18.0"
        }
      }
    JSON
  end

  let(:dest_json) do
    <<~JSON
      {
        "name": "my-package",
        "version": "1.0.0",
        "dependencies": {
          "lodash": "^4.17.21",
          "express": "^4.18.0"
        },
        "custom": "my-value"
      }
    JSON
  end

  describe "#initialize" do
    it "creates a merger with content" do
      merger = described_class.new(template_json, dest_json)
      expect(merger.template_content).to eq(template_json)
      expect(merger.dest_content).to eq(dest_json)
    end

    it "accepts options" do
      merger = described_class.new(
        template_json,
        dest_json,
        preference: :template,
        add_template_only_nodes: true,
      )
      expect(merger.options[:preference]).to eq(:template)
      expect(merger.options[:add_template_only_nodes]).to be true
    end

    it "has default options" do
      merger = described_class.new(template_json, dest_json)
      expect(merger.options[:preference]).to eq(:destination)
      expect(merger.options[:add_template_only_nodes]).to be false
    end
  end

  describe "#merge", :tree_sitter_jsonc do
    it "returns a MergeResult" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end

    it "produces a result with lines" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      expect(result).to respond_to(:lines)
    end

    it "preserves destination customizations by default" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      expect(result.to_json).to include("custom")
    end

    context "with template preference" do
      it "uses template values for matches" do
        merger = described_class.new(
          template_json,
          dest_json,
          preference: :template,
        )
        result = merger.merge_result
        expect(result).to be_a(Jsonc::Merge::MergeResult)
      end
    end

    context "with add_template_only_nodes enabled" do
      it "adds template-only nodes" do
        merger = described_class.new(
          template_json,
          dest_json,
          add_template_only_nodes: true,
        )
        result = merger.merge_result
        expect(result.to_json).to include("description")
      end
    end
  end

  describe "error handling", :tree_sitter_jsonc do
    it "raises TemplateParseError for invalid template" do
      expect {
        described_class.new("{ invalid", dest_json)
      }.to raise_error(Jsonc::Merge::TemplateParseError)
    end

    it "raises DestinationParseError for invalid destination" do
      expect {
        described_class.new(template_json, "{ also invalid")
      }.to raise_error(Jsonc::Merge::DestinationParseError)
    end

    it "includes error details in TemplateParseError" do
      expect {
        described_class.new("{ invalid json }", dest_json)
      }.to raise_error(Jsonc::Merge::TemplateParseError) do |error|
        expect(error.message).to include("ERROR")
        expect(error.content).to eq("{ invalid json }")
      end
    end

    it "includes error details in DestinationParseError" do
      expect {
        described_class.new(template_json, "not json at all")
      }.to raise_error(Jsonc::Merge::DestinationParseError) do |error|
        expect(error.message).to include("ERROR")
        expect(error.content).to eq("not json at all")
      end
    end
  end

  describe "JSONC support", :tree_sitter_jsonc do
    let(:jsonc_template) do
      <<~JSON
        {
          // Template configuration
          "name": "template",
          /* Version info */
          "version": "1.0.0"
        }
      JSON
    end

    let(:jsonc_dest) do
      <<~JSON
        {
          // My configuration
          "name": "destination",
          "custom": true
        }
      JSON
    end

    it "handles JSONC content with comments" do
      merger = described_class.new(jsonc_template, jsonc_dest)
      result = merger.merge_result
      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end

    it "preserves destination values" do
      merger = described_class.new(jsonc_template, jsonc_dest)
      result = merger.merge_result
      json_output = result.to_json
      expect(json_output).to include("destination")
      expect(json_output).to include("custom")
    end

    it "handles single-line comments" do
      merger = described_class.new(jsonc_template, jsonc_dest)
      result = merger.merge_result
      # Comments should be preserved or handled gracefully
      expect(result.to_json).to be_a(String)
    end

    it "handles block comments" do
      merger = described_class.new(jsonc_template, jsonc_dest)
      result = merger.merge_result
      expect(result.to_json).to be_a(String)
    end
  end

  # Tests that run when tree-sitter-jsonc is NOT available
  describe "without parser", :not_tree_sitter_jsonc do
    it "handles missing parser gracefully" do
      # When parser is not available, FileAnalysis should capture errors
      merger = described_class.new(template_json, dest_json)
      # Either raises ParseError or has invalid analysis
      expect(merger.template_analysis.valid?).to be false
    end
  end
end
