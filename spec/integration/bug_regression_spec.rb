# frozen_string_literal: true

require "spec_helper"

# Regression tests for bugs that were discovered during JRuby CI investigation
# These tests validate that the specific bugs we fixed stay fixed

RSpec.describe "JSONC Merge Bug Regression Tests", :jsonc_grammar do
  describe "Bug: Statements returning pairs instead of root object" do
    # This bug caused merge to concatenate objects instead of merging them

    it "returns root object in statements, not individual pairs", :jsonc_parsing do
      json = '{"name": "test", "version": "1.0.0"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)

      statements = analysis.statements

      # Should have ONE statement (the root object)
      expect(statements.size).to eq(1)

      # That statement should be the object, not a pair
      expect(statements.first.type).to eq(:object)
      expect(statements.first.container?).to be(true)
    end

    it "produces single merged object, not concatenated objects", :jsonc_parsing do
      template = '{"name": "template", "field1": "value1"}'
      dest = '{"name": "destination", "field2": "value2"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      # Should be parseable as a single JSON object
      parsed = JSON.parse(result)
      expect(parsed).to be_a(Hash)

      # Should have fields from both, not duplicate objects
      expect(parsed.keys).to contain_exactly("name", "field1", "field2")

      # Should not have structure like: object + object
      # This was the bug: result had two separate JSON objects concatenated
      expect(result.scan("{").count).to be <= 1, "Should have at most one opening brace at root"
    end
  end

  describe "Bug: Root objects not matching due to different keys" do
    # Root objects with different keys got different signatures, preventing merge

    it "merges root objects even with different keys", :jsonc_parsing do
      template = '{"name": "template", "newKey": "value"}'
      dest = '{"name": "destination", "oldKey": "value"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      parsed = JSON.parse(result)

      # Should have merged, not kept both objects
      expect(parsed.keys).to contain_exactly("name", "newKey", "oldKey")
      expect(parsed["name"]).to eq("destination") # preference default
    end

    it "gives root objects matching signatures", :jsonc_parsing do
      template_json = '{"a": 1, "b": 2}'
      dest_json = '{"a": 1}'

      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      template_sig = template_analysis.generate_signature(template_analysis.statements.first)
      dest_sig = dest_analysis.generate_signature(dest_analysis.statements.first)

      # Root objects should have same signature for matching
      expect(template_sig).to eq(dest_sig),
        "Root objects should have matching signatures regardless of keys"
    end
  end

  describe "Bug: Single-line containers duplicating content" do
    # opening_line/closing_line returned full object line, causing duplication

    it "doesn't duplicate single-line object content", :jsonc_parsing do
      template = '{"name": "template"}'
      dest = '{"name": "destination"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest)
      result = merger.merge

      # Should only see "destination" once, not multiple times
      expect(result.scan("destination").count).to eq(1),
        "Should not duplicate content when merging single-line objects"
    end

    it "opening_line returns just bracket for single-line objects", :jsonc_parsing do
      json = '{"name": "test"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      obj = analysis.root_object

      expect(obj.opening_line).to eq("{"),
        "Single-line object opening_line should return just '{'"
      expect(obj.closing_line).to eq("}"),
        "Single-line object closing_line should return just '}'"
    end
  end

  describe "Bug: Single-line pairs duplicating parent object" do
    # Pairs in single-line JSON emitted the full object line instead of just pair text

    it "doesn't duplicate parent object when emitting pairs", :jsonc_parsing do
      template = '{"name": "template", "new": "field"}'
      dest = '{"name": "destination"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      # Each field should appear exactly once
      expect(result.scan('"name"').count).to eq(1)
      expect(result.scan('"new"').count).to eq(1)

      # Should not have duplicate entire object
      expect(result.scan("destination").count).to eq(1)
    end
  end

  describe "Bug: FFI backend field access missing" do
    # FFI backend doesn't support child_by_field_name, causing nil keys

    it "extracts key names on FFI backend", :ffi_backend, :jsonc_grammar do
      TreeHaver.with_backend(:ffi) do
        json = '{"name": "test", "version": "1.0.0"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        obj = analysis.root_object

        pairs = obj.pairs
        expect(pairs.size).to eq(2)

        # Should be able to get key names even on FFI
        key_names = pairs.map(&:key_name).compact
        expect(key_names).to contain_exactly("name", "version"),
          "FFI backend should extract key names using fallback iteration"
      end
    end

    it "merges correctly on FFI backend", :ffi_backend, :jsonc_grammar do
      TreeHaver.with_backend(:ffi) do
        template = '{"name": "template", "new": "field"}'
        dest = '{"name": "destination"}'

        merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
        result = merger.merge

        # Should produce valid JSON with template-only field
        parsed = JSON.parse(result)
        expect(parsed).to have_key("new"),
          "FFI backend should add template-only nodes"
        expect(parsed["new"]).to eq("field")
      end
    end
  end

  describe "Bug: Missing commas between pairs" do
    # Without using Emitter, commas weren't added automatically
    # NOTE: This test will fail until we complete Emitter refactoring

    it "produces valid JSON with commas between pairs", :jsonc_parsing do
      template = '{"a": 1, "b": 2, "c": 3}'
      dest = '{"a": 1, "d": 4}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      # Must be valid JSON (this checks commas are correct)
      expect { JSON.parse(result) }.not_to raise_error

      parsed = JSON.parse(result)
      expect(parsed.keys.size).to be >= 3, "Should have multiple fields requiring commas"
    end
  end

  describe "Bug: Template-only nodes not being added" do
    # Root cause was statements returning pairs, preventing container merge

    it "adds template-only nodes when option is true", :jsonc_parsing do
      template = '{"name": "template", "onlyInTemplate": "value", "another": "field"}'
      dest = '{"name": "destination"}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      parsed = JSON.parse(result)

      # Should have both template-only fields
      expect(parsed).to have_key("onlyInTemplate"),
        "Should add template-only fields"
      expect(parsed).to have_key("another"),
        "Should add all template-only fields"

      expect(parsed["onlyInTemplate"]).to eq("value")
      expect(parsed["another"]).to eq("field")
    end

    it "adds template-only nested objects", :jsonc_parsing do
      template = '{"config": {"templateSetting": true}}'
      dest = '{"config": {"destSetting": false}}'

      merger = Jsonc::Merge::SmartMerger.new(template, dest, add_template_only_nodes: true)
      result = merger.merge

      parsed = JSON.parse(result)
      expect(parsed["config"]).to have_key("templateSetting"),
        "Should add template-only nested fields"
      expect(parsed["config"]["templateSetting"]).to be(true)
    end
  end

  describe "Bug: Invalid JSON in error messages" do
    # Parse errors should be raised before producing invalid output

    it "raises error for malformed template before attempting merge", :jsonc_parsing do
      expect {
        Jsonc::Merge::SmartMerger.new('{ "unclosed":', '{"valid": true}')
      }.to raise_error(Jsonc::Merge::TemplateParseError)
    end

    it "raises error for malformed destination before attempting merge", :jsonc_parsing do
      expect {
        Jsonc::Merge::SmartMerger.new('{"valid": true}', '{ "unclosed":')
      }.to raise_error(Jsonc::Merge::DestinationParseError)
    end

    it "detects errors on all backends", :jsonc_grammar do
      invalid_json = '{ "missing": }'

      [:mri, :ffi, :rust, :java].each do |backend|
        begin
          next unless TreeHaver::Backends.const_get(backend.to_s.capitalize).available?
        rescue
          false
        end

        TreeHaver.with_backend(backend) do
          analysis = Jsonc::Merge::FileAnalysis.new(invalid_json)
          expect(analysis.valid?).to be(false),
            "#{backend} backend should detect invalid JSON"
          expect(analysis.errors).not_to be_empty,
            "#{backend} backend should report errors"
        end
      end
    end
  end
end
