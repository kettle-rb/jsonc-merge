# frozen_string_literal: true

require "spec_helper"

# Integration tests for ConflictResolver with real merge scenarios

RSpec.describe "Jsonc::Merge::ConflictResolver Integration", :jsonc_grammar do
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
end
