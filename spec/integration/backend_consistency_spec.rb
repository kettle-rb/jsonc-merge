# frozen_string_literal: true

require "spec_helper"

# Tests that validate merge output is consistent across all backends
# Each backend should produce identical, valid JSON output

RSpec.describe "JSONC Merge Backend Consistency" do
  let(:template_json) { '{"name": "template", "version": "1.0.0", "newField": "added"}' }
  let(:dest_json) { '{"name": "destination", "port": 8080}' }
  let(:merge_options) { {add_template_only_nodes: true, preference: :destination} }

  # Helper to perform merge with specific backend
  def merge_with_backend(backend, template, dest, options)
    TreeHaver.with_backend(backend) do
      merger = Jsonc::Merge::SmartMerger.new(template, dest, **options)
      merger.merge
    end
  end

  # Helper to validate JSON output
  def validate_json_output(result, description)
    # Must be parseable
    expect { JSON.parse(result) }.not_to raise_error, "#{description}: Should produce valid JSON"

    parsed = JSON.parse(result)

    # Must be a hash
    expect(parsed).to be_a(Hash), "#{description}: Should produce a JSON object"

    # Must have expected keys
    expect(parsed.keys.sort).to eq(["name", "newField", "port", "version"].sort),
      "#{description}: Should have all expected keys"

    # Must have correct values
    expect(parsed["name"]).to eq("destination"), "#{description}: Should preserve destination value"
    expect(parsed["version"]).to eq("1.0.0"), "#{description}: Should have template value"
    expect(parsed["port"]).to eq(8080), "#{description}: Should have destination-only value"
    expect(parsed["newField"]).to eq("added"), "#{description}: Should have template-only value"

    parsed
  end

  describe "consistent output across backends" do
    it "produces valid JSON on MRI backend", :jsonc_grammar, :mri_backend do
      result = merge_with_backend(:mri, template_json, dest_json, merge_options)
      parsed = validate_json_output(result, "MRI backend")
      expect(parsed).to be_a(Hash)
    end

    it "produces valid JSON on FFI backend", :ffi_backend, :jsonc_grammar do
      result = merge_with_backend(:ffi, template_json, dest_json, merge_options)
      parsed = validate_json_output(result, "FFI backend")
      expect(parsed).to be_a(Hash)
    end

    it "produces valid JSON on Rust backend", :jsonc_grammar, :rust_backend do
      result = merge_with_backend(:rust, template_json, dest_json, merge_options)
      parsed = validate_json_output(result, "Rust backend")
      expect(parsed).to be_a(Hash)
    end

    it "produces valid JSON on Java backend", :java_backend, :jsonc_grammar do
      result = merge_with_backend(:java, template_json, dest_json, merge_options)
      parsed = validate_json_output(result, "Java backend")
      expect(parsed).to be_a(Hash)
    end
  end

  describe "backend output comparison" do
    # This test compares outputs from available backends
    # NOTE: Can only test one backend per process due to TreeHaver backend protection
    it "produces valid output on current backend", :jsonc_grammar do
      # Just validate the current/auto backend works correctly
      merger = Jsonc::Merge::SmartMerger.new(template_json, dest_json, **merge_options)
      result = merger.merge

      parsed = validate_json_output(result, "Current backend")
      expect(parsed).to be_a(Hash)
    end
  end

  describe "complex merges on all backends" do
    let(:complex_template) do
      <<~JSON
        {
          "name": "template",
          "config": {
            "host": "localhost",
            "port": 3000,
            "ssl": false
          },
          "features": {
            "newFeature": true
          }
        }
      JSON
    end

    let(:complex_dest) do
      <<~JSON
        {
          "name": "destination",
          "config": {
            "host": "production.com",
            "port": 443,
            "timeout": 5000
          },
          "version": "2.0.0"
        }
      JSON
    end

    def validate_complex_merge(result, backend_name)
      parsed = JSON.parse(result)

      # Check root level
      expect(parsed["name"]).to eq("destination")
      expect(parsed["version"]).to eq("2.0.0")

      # Check nested config object
      expect(parsed["config"]["host"]).to eq("production.com")
      expect(parsed["config"]["port"]).to eq(443)
      expect(parsed["config"]["timeout"]).to eq(5000)
      expect(parsed["config"]["ssl"]).to be(false),
        "#{backend_name}: Should add template-only nested field"

      # Check template-only object
      expect(parsed["features"]).to be_a(Hash)
      expect(parsed["features"]["newFeature"]).to be(true),
        "#{backend_name}: Should add template-only nested object"
    end

    it "handles nested objects on MRI backend", :jsonc_grammar, :mri_backend do
      result = merge_with_backend(:mri, complex_template, complex_dest, merge_options)
      validate_complex_merge(result, "MRI")
      expect(result).to be_a(String)
    end

    it "handles nested objects on FFI backend", :ffi_backend, :jsonc_grammar do
      result = merge_with_backend(:ffi, complex_template, complex_dest, merge_options)
      validate_complex_merge(result, "FFI")
      expect(result).to be_a(String)
    end

    it "handles nested objects on Rust backend", :jsonc_grammar, :rust_backend do
      result = merge_with_backend(:rust, complex_template, complex_dest, merge_options)
      validate_complex_merge(result, "Rust")
      expect(result).to be_a(String)
    end

    it "handles nested objects on Java backend", :java_backend, :jsonc_grammar do
      result = merge_with_backend(:java, complex_template, complex_dest, merge_options)
      validate_complex_merge(result, "Java")
      expect(result).to be_a(String)
    end
  end

  describe "edge cases on all backends" do
    it "handles empty objects correctly", :jsonc_parsing do
      template = "{}"
      dest = '{"key": "value"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest)
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed).to eq({"key" => "value"})
    end

    it "handles objects with only template fields", :jsonc_parsing do
      template = '{"onlyInTemplate": true}'
      dest = "{}"

      merger = Jsonc::Merge::SmartMerger.new(
        template,
        dest,
        add_template_only_nodes: true,
      )
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed).to eq({"onlyInTemplate" => true})
    end
  end
end
