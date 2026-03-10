# frozen_string_literal: true

# Shared examples for SmartMerger across different backends
#
# These examples test SmartMerger behavior that should be consistent
# regardless of which tree-sitter backend is used (MRI, FFI, Rust, Java).

RSpec.shared_examples "basic initialization" do
  let(:template_json) do
    <<~JSON
      {
        "name": "template-package",
        "version": "2.0.0",
        "description": "A template package"
      }
    JSON
  end

  let(:dest_json) do
    <<~JSON
      {
        "name": "my-package",
        "version": "1.0.0",
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

    it "accepts template and destination content" do
      merger = described_class.new(template_json, dest_json)
      expect(merger).to be_a(described_class)
    end

    it "has template_analysis" do
      merger = described_class.new(template_json, dest_json)
      expect(merger.template_analysis).to be_a(Jsonc::Merge::FileAnalysis)
    end

    it "has dest_analysis" do
      merger = described_class.new(template_json, dest_json)
      expect(merger.dest_analysis).to be_a(Jsonc::Merge::FileAnalysis)
    end

    it "accepts optional preference" do
      merger = described_class.new(template_json, dest_json, preference: :template)
      expect(merger.preference).to eq(:template)
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
end

RSpec.shared_examples "basic merge operation" do
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

  describe "#merge" do
    it "returns a MergeResult" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end

    it "performs merge and returns MergeResult" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result

      expect(result).to be_a(Jsonc::Merge::MergeResult)
      output = result.to_json
      expect(output).not_to be_empty
    end

    it "produces result with lines" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      expect(result).to respond_to(:lines)
      expect(result.lines).not_to be_empty
    end

    it "preserves destination customizations by default" do
      merger = described_class.new(template_json, dest_json)
      result = merger.merge_result
      output = result.to_json
      expect(output).to include("custom")
    end
  end
end

RSpec.shared_examples "template preference" do
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

  describe "with template preference" do
    it "uses template values when preference is :template" do
      merger = described_class.new(
        template_json,
        dest_json,
        preference: :template,
      )
      result = merger.merge_result

      expect(result).to be_a(Jsonc::Merge::MergeResult)
    end
  end
end

RSpec.shared_examples "add template-only nodes" do
  let(:template_json_with_extras) do
    <<~JSON
      {
        "name": "template",
        "newField": "from-template",
        "description": "A description"
      }
    JSON
  end

  let(:simple_dest_json) do
    <<~JSON
      {
        "name": "destination"
      }
    JSON
  end

  describe "with add_template_only_nodes enabled" do
    it "adds template-only nodes when option is enabled" do
      merger = described_class.new(
        template_json_with_extras,
        simple_dest_json,
        add_template_only_nodes: true,
      )
      result = merger.merge_result

      output = result.to_json
      expect(output).to include("newField")
      expect(output).to include("description")
    end

    it "adds template-only nodes" do
      template_json = <<~JSON
        {
          "name": "template-package",
          "version": "2.0.0",
          "description": "A template package",
          "dependencies": {
            "lodash": "^4.18.0"
          }
        }
      JSON

      dest_json = <<~JSON
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

      merger = described_class.new(
        template_json,
        dest_json,
        add_template_only_nodes: true,
      )
      result = merger.merge_result
      expect(result.to_json).to include("description")
    end

    it "skips template-only nodes when option is disabled" do
      merger = described_class.new(
        template_json_with_extras,
        simple_dest_json,
        add_template_only_nodes: false,
      )
      result = merger.merge_result

      output = result.to_json
      expect(output).not_to include("newField")
      expect(output).not_to include("description")
    end
  end
end

RSpec.shared_examples "destination-only nodes preservation" do
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
    merger = described_class.new(template_json, dest_json)
    result = merger.merge_result

    output = result.to_json
    expect(output).to include("customField")
    expect(output).to include("dest-only-value")
  end
end

RSpec.shared_examples "invalid template detection" do
  let(:dest_json) { '{"name": "test"}' }
  let(:invalid_template) { '{ "unclosed": ' }

  describe "error handling" do
    # Note: Tree-sitter parsers may have different error recovery modes
    # Some backends may not raise errors for certain invalid JSON
    # This behavior can vary between MRI, FFI, Rust, and Java backends
    it "raises TemplateParseError for invalid template" do
      expect {
        described_class.new(invalid_template, dest_json)
      }.to raise_error(Jsonc::Merge::TemplateParseError)
    end

    it "includes error details in TemplateParseError" do
      expect {
        described_class.new("{ invalid json }", dest_json)
      }.to raise_error(Jsonc::Merge::TemplateParseError) do |error|
        expect(error.message).to include("ERROR")
        expect(error.content).to eq("{ invalid json }")
      end
    end
  end
end

RSpec.shared_examples "invalid destination detection" do
  let(:template_json) { '{"name": "test"}' }
  let(:invalid_dest) { '{ "unclosed": ' }

  describe "error handling" do
    # Note: Tree-sitter parsers may have different error recovery modes
    # Some backends may not raise errors for certain invalid JSON
    # This behavior can vary between MRI, FFI, Rust, and Java backends
    it "raises DestinationParseError for invalid destination" do
      expect {
        described_class.new(template_json, invalid_dest)
      }.to raise_error(Jsonc::Merge::DestinationParseError)
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
end

RSpec.shared_examples "JSONC support" do
  describe "JSONC support" do
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
      json_output = result.to_json
      expect(json_output).to be_a(String)
      expect(json_output.length).to be > 0
    end

    it "handles block comments" do
      merger = described_class.new(jsonc_template, jsonc_dest)
      result = merger.merge_result
      json_output = result.to_json
      expect(json_output).to be_a(String)
      expect(json_output).to include("name")
    end
  end
end

RSpec.shared_examples "document boundary comments" do
  describe "document boundary comments" do
    it "preserves destination header and footer comments around a root object merge" do
      template = <<~JSON
        {
          "name": "template"
        }
      JSON
      dest = <<~JSON
        // Destination header

        {
          "name": "destination"
        }

        // Destination footer
      JSON

      merger = described_class.new(template, dest)
      result = merger.merge

      expect(result).to include("// Destination header")
      expect(result).to include("// Destination footer")
      expect(result).to include("// Destination header\n\n{")
      expect(result).to end_with("}\n\n// Destination footer\n")
    end

    it "preserves destination header and footer comments around a root array merge" do
      template = <<~JSON
        [
          1,
          2
        ]
      JSON
      dest = <<~JSON
        // Destination header

        [
          9,
          8
        ]

        // Destination footer
      JSON

      merger = described_class.new(template, dest)
      result = merger.merge

      expect(result).to include("// Destination header")
      expect(result).to include("// Destination footer")
      expect(result).to include("// Destination header\n\n[")
      expect(result).to end_with("]\n\n// Destination footer\n")
    end

    it "preserves a comment-only destination when no structural nodes exist" do
      template = <<~JSON
        {
          "name": "template"
        }
      JSON
      dest = <<~JSON
        // Destination docs

        // More destination docs
      JSON

      merger = described_class.new(template, dest)
      result = merger.merge

      expect(result).to eq(dest)
    end
  end
end

RSpec.shared_examples "matched and removed pair comments" do
  describe "pair comment preservation" do
    it "preserves destination leading and inline comments when a matched template-preferred pair wins" do
      template = <<~JSON
        {
          "keep": 1,
          "shared": "template"
        }
      JSON
      dest = <<~JSON
        {
          "keep": 1,
          // Shared docs
          "shared": "destination" // destination inline
        }
      JSON

      merger = described_class.new(template, dest, preference: :template)
      result = merger.merge

      expect(result).to include("// Shared docs")
      expect(result).to include('"shared": "template" // destination inline')
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect { JSON.parse(json_without_comments) }.not_to raise_error
      expect(result).to include('"keep": 1,')
    end

    it "preserves comments for removed destination-only pairs when removal is enabled" do
      template = <<~JSON
        {
          "keep": 1,
          "tail": 3
        }
      JSON
      dest = <<~JSON
        {
          "keep": 1,
          // Remove docs
          "remove": 2, // remove inline
          "tail": 3
        }
      JSON

      merger = described_class.new(
        template,
        dest,
        remove_template_missing_nodes: true,
      )
      result = merger.merge

      expect(result).to include("// Remove docs")
      expect(result).to include("// remove inline")
      expect(result).not_to include('"remove": 2')
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect { JSON.parse(json_without_comments) }.not_to raise_error
      expect(result).to include('"keep": 1,')
    end
  end
end

RSpec.shared_examples "nested object comments" do
  describe "nested object comment preservation" do
    it "keeps commas before inline comments when nested template-preferred pairs win" do
      template = <<~JSON
        {
          "config": {
            "keep": 1,
            "add": 2
          }
        }
      JSON
      dest = <<~JSON
        {
          "config": {
            // Keep docs
            "keep": 9 // keep inline
          }
        }
      JSON

      merger = described_class.new(template, dest, preference: :template, add_template_only_nodes: true)
      result = merger.merge

      expect(result).to include('"keep": 1, // keep inline')
      expect(result).to include('"add": 2')
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect { JSON.parse(json_without_comments) }.not_to raise_error
    end

    it "preserves blank lines between nested leading comment blocks and content" do
      template = <<~JSON
        {
          "config": {
            "keep": 1,
            "add": 2
          }
        }
      JSON
      dest = <<~JSON
        {
          "config": {
            // Keep docs
            // More keep docs

            "keep": 9
          }
        }
      JSON

      merger = described_class.new(template, dest, preference: :template, add_template_only_nodes: true)
      result = merger.merge

      expect(result).to include("// Keep docs\n    // More keep docs\n\n    \"keep\": 1")
    end
  end
end

RSpec.shared_examples "mixed object and array comments" do
  describe "mixed object/array comment preservation" do
    it "recursively merges keyed arrays of objects without duplicating the array key" do
      template = <<~JSON
        {
          "items": [
            {
              "name": "shared",
              "enabled": true
            },
            {
              "id": "added",
              "enabled": true
            }
          ]
        }
      JSON
      dest = <<~JSON
        {
          "items": [
            {
              // Shared docs
              "name": "shared",
              "enabled": false // inline note
            }
          ]
        }
      JSON

      merger = described_class.new(template, dest, preference: :template, add_template_only_nodes: true)
      result = merger.merge

      expect(result.scan('"items":').count).to eq(1)
      expect(result).to include("// Shared docs")
      expect(result).to include('"enabled": true // inline note')
      expect(result).to include('"id": "added"')
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect { JSON.parse(json_without_comments) }.not_to raise_error
    end

    it "preserves comments for removed destination-only array items when removal is enabled" do
      template = <<~JSON
        {
          "items": [
            1,
            3
          ]
        }
      JSON
      dest = <<~JSON
        {
          "items": [
            1,
            // Remove docs
            2, // remove inline
            3
          ]
        }
      JSON

      merger = described_class.new(
        template,
        dest,
        remove_template_missing_nodes: true,
      )
      result = merger.merge

      expect(result).to include("// Remove docs")
      expect(result).to include("// remove inline")
      json_without_comments = result.gsub(%r{//.*$}, "")
      expect(JSON.parse(json_without_comments).fetch("items")).to eq([1, 3])
    end
  end
end
