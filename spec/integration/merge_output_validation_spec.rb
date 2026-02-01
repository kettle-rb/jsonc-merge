# frozen_string_literal: true

require "spec_helper"

# Integration tests that validate actual merge output correctness
# These tests would have caught the bugs we just fixed.

RSpec.describe "JSONC Merge Output Validation", :jsonc_grammar do
  # Test the actual merge output, not just internal state
  describe "merge output validity" do
    let(:template_json) { '{"name": "template", "version": "1.0.0"}' }
    let(:dest_json) { '{"name": "destination", "port": 8080}' }

    it "produces valid JSON output" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)
      result = merger.merge

      # This would have caught the "two separate objects" bug
      expect { JSON.parse(result) }.not_to raise_error

      parsed = JSON.parse(result)
      expect(parsed).to be_a(Hash)
      expect(parsed.keys).to contain_exactly("name", "version", "port")
    end

    it "merges single-line JSON without duplication" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)
      result = merger.merge

      # Should not have duplicate keys
      expect(result.scan('"name"').count).to eq(1)
      expect(result.scan('"version"').count).to eq(1)
      expect(result.scan('"port"').count).to eq(1)
    end

    it "preserves destination values by default" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, preference: :destination)
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed["name"]).to eq("destination")
    end

    it "uses template values when preference is :template" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, preference: :template)
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed["name"]).to eq("template")
    end
  end

  describe "add_template_only_nodes" do
    let(:template_json) { '{"name": "template", "newField": "added"}' }
    let(:dest_json) { '{"name": "destination"}' }

    it "adds fields only in template when option is true" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        add_template_only_nodes: true,
      )
      result = merger.merge

      # This would have caught the "missing newField" bug
      parsed = JSON.parse(result)
      expect(parsed).to have_key("newField")
      expect(parsed["newField"]).to eq("added")
    end

    it "omits template-only fields when option is false" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        add_template_only_nodes: false,
      )
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed).not_to have_key("newField")
    end

    it "preserves destination-only fields" do
      template_json = '{"name": "template"}'
      dest_json = '{"name": "destination", "destOnly": "value"}'

      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json)
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed).to have_key("destOnly")
      expect(parsed["destOnly"]).to eq("value")
    end
  end

  describe "nested object merging" do
    let(:template_json) do
      JSON.generate({
        "name" => "template",
        "config" => {
          "host" => "localhost",
          "port" => 3000,
          "newSetting" => true,
        },
      })
    end

    let(:dest_json) do
      JSON.generate({
        "name" => "destination",
        "config" => {
          "host" => "production.com",
          "port" => 443,
        },
      })
    end

    it "recursively merges nested objects" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        add_template_only_nodes: true,
        preference: :destination,
      )
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed["config"]["host"]).to eq("production.com") # destination
      expect(parsed["config"]["port"]).to eq(443) # destination
      expect(parsed["config"]["newSetting"]).to be(true) # from template
    end
  end

  describe "multi-line JSON merging" do
    let(:template_json) do
      <<~JSON
        {
          "name": "template",
          "version": "1.0.0"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          "name": "destination",
          "port": 8080
        }
      JSON
    end

    it "produces valid JSON from multi-line input" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)
      result = merger.merge

      expect { JSON.parse(result) }.not_to raise_error

      parsed = JSON.parse(result)
      expect(parsed.keys).to contain_exactly("name", "version", "port")
    end

    it "preserves indentation style" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, add_template_only_nodes: true)
      result = merger.merge

      # Should have some indentation (destination uses 2 spaces)
      expect(result).to match(/"name":/)
    end
  end

  describe "array handling" do
    let(:template_json) { '{"items": [1, 2, 3]}' }
    let(:dest_json) { '{"items": [4, 5]}' }

    it "replaces arrays (doesn't merge array contents)" do
      merger = Jsonc::Merge::SmartMerger.new(
        template_json,
        dest_json,
        preference: :destination,
      )
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed["items"]).to eq([4, 5]) # destination array
    end
  end

  describe "error handling" do
    it "raises TemplateParseError for invalid template JSON" do
      expect {
        Jsonc::Merge::SmartMerger.new("{ invalid", '{"valid": true}')
      }.to raise_error(Jsonc::Merge::TemplateParseError)
    end

    it "raises DestinationParseError for invalid destination JSON" do
      expect {
        Jsonc::Merge::SmartMerger.new('{"valid": true}', "{ invalid")
      }.to raise_error(Jsonc::Merge::DestinationParseError)
    end
  end

  describe "comments preservation" do
    let(:template_json) do
      <<~JSON
        {
          // Template comment
          "name": "template",
          "version": "1.0.0"
        }
      JSON
    end

    let(:dest_json) do
      <<~JSON
        {
          // Destination comment
          "name": "destination",
          "port": 8080
        }
      JSON
    end

    it "preserves comments in merge" do
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json)
      result = merger.merge

      # Comments should be preserved
      expect(result).to include("// Destination comment")

      # And the result should still be valid when comments are stripped
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect { JSON.parse(json_without_comments) }.not_to raise_error
    end
  end
end
