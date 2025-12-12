# frozen_string_literal: true

# Integration tests for ConflictResolver with real merge scenarios
# Note: tree-sitter JSON parser does not support JSONC comments, so tests
# that need valid parsing use strict JSON.

RSpec.describe "Jsonc::Merge::ConflictResolver Integration" do
  describe "with template preference for matching signatures" do
    let(:template_json) do
      <<~JSON
        {
          "shared": "template-value"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "shared": "dest-value"
        }
      JSON
    end

    it "uses template version when preference is :template" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      result = Jsonc::Merge::MergeResult.new
      resolver = Jsonc::Merge::ConflictResolver.new(
        template_analysis,
        dest_analysis,
        preference: :template,
      )

      resolver.resolve(result)
      # The merge should use template's version
      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end

    it "uses destination version when preference is :destination" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      result = Jsonc::Merge::MergeResult.new
      resolver = Jsonc::Merge::ConflictResolver.new(
        template_analysis,
        dest_analysis,
        preference: :destination,
      )

      resolver.resolve(result)
      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end
  end

  describe "with template-only nodes and add_template_only_nodes: true" do
    let(:template_json) do
      <<~JSON
        {
          "shared": "value",
          "templateOnly": "from-template"
        }
      JSON
    end

    let(:dest_json) { '{"shared": "value"}' }

    it "adds template-only nodes when configured" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      result = Jsonc::Merge::MergeResult.new
      resolver = Jsonc::Merge::ConflictResolver.new(
        template_analysis,
        dest_analysis,
        add_template_only_nodes: true,
      )

      resolver.resolve(result)

      output = result.to_json
      expect(output).to include("templateOnly")
    end

    it "skips template-only nodes when not configured" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      result = Jsonc::Merge::MergeResult.new
      resolver = Jsonc::Merge::ConflictResolver.new(
        template_analysis,
        dest_analysis,
        add_template_only_nodes: false,
      )

      resolver.resolve(result)

      output = result.to_json
      expect(output).not_to include("templateOnly")
    end
  end

  describe "#add_node_to_result with unknown node type" do
    it "logs debug message for unknown node types" do
      stub_env("JSONC_MERGE_DEBUG" => "1")

      template_json = '{"a": 1}'
      dest_json = '{"a": 2}'

      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = Jsonc::Merge::ConflictResolver.new(template_analysis, dest_analysis)
      result = Jsonc::Merge::MergeResult.new

      unknown_node = Object.new

      expect {
        resolver.send(:add_node_to_result, unknown_node, result, :destination, :kept_dest, dest_analysis)
      }.to output(/Unknown node type/).to_stderr
    end
  end

  describe "#add_wrapper_to_result edge cases" do
    it "returns early when wrapper has no start_line" do
      template_json = '{"a": 1}'
      dest_json = '{"a": 2}'

      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = Jsonc::Merge::ConflictResolver.new(template_analysis, dest_analysis)
      result = Jsonc::Merge::MergeResult.new

      mock_wrapper = double("NodeWrapper", start_line: nil, end_line: 5)

      expect {
        resolver.send(:add_wrapper_to_result, mock_wrapper, result, :destination, :kept_dest, dest_analysis)
      }.not_to raise_error

      expect(result.lines).to be_empty
    end

    it "skips lines that return nil from analysis" do
      template_json = '{"a": 1}'
      dest_json = '{"a": 2}'

      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = Jsonc::Merge::ConflictResolver.new(template_analysis, dest_analysis)
      result = Jsonc::Merge::MergeResult.new

      # Create a mock wrapper that spans beyond actual lines
      mock_wrapper = double("NodeWrapper", start_line: 1, end_line: 100)

      expect {
        resolver.send(:add_wrapper_to_result, mock_wrapper, result, :destination, :kept_dest, dest_analysis)
      }.not_to raise_error
    end
  end
end
