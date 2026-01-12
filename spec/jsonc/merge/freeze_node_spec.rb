# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jsonc::Merge::FreezeNode do
  # Use shared examples to validate base FreezeNode integration
  subject(:freeze_node) do
    described_class.new(
      start_line: start_line,
      end_line: end_line,
      lines: all_lines,
      pattern_type: pattern_type,
    )
  end

  it_behaves_like "Ast::Merge::FreezeNodeBase" do
    let(:freeze_node_class) { described_class }
    let(:default_pattern_type) { :c_style_line }
    let(:build_freeze_node) do
      ->(start_line:, end_line:, **opts) {
        # Build enough lines to cover the requested range
        # Lines array is 0-indexed, but line numbers are 1-indexed
        lines = opts.delete(:lines) || begin
          result = []
          (1..end_line).each do |i|
            result << if i == start_line
              "// json-merge:freeze"
            elsif i == end_line
              "// json-merge:unfreeze"
            else
              %("key_#{i}": "value_#{i}",)
            end
          end
          result
        end
        freeze_node_class.new(
          start_line: start_line,
          end_line: end_line,
          lines: lines,
          pattern_type: opts[:pattern_type] || :c_style_line,
          **opts.except(:pattern_type),
        )
      }
    end
  end

  # JSON-specific tests
  # All source lines (0-indexed array, but line numbers are 1-indexed)
  let(:all_lines) do
    [
      "{",
      "  // json-merge:freeze",
      '  "frozen_key": "value",',
      '  "another": 123',
      "  // json-merge:unfreeze",
      "}",
    ]
  end
  let(:start_line) { 2 }
  let(:end_line) { 5 }
  let(:pattern_type) { :c_style_line }

  describe "#initialize" do
    it "creates a freeze node with line range" do
      expect(freeze_node.start_line).to eq(start_line)
      expect(freeze_node.end_line).to eq(end_line)
    end

    it "extracts lines from the source" do
      expect(freeze_node.lines).to be_an(Array)
      expect(freeze_node.lines.length).to eq(4)
    end
  end

  describe "#lines" do
    it "returns the extracted lines array" do
      expect(freeze_node.lines).to include("  // json-merge:freeze")
      expect(freeze_node.lines).to include('  "frozen_key": "value",')
    end

    it "returns the number of lines in the freeze block" do
      expect(freeze_node.lines.length).to eq(4)
    end
  end

  describe "JSON-specific type predicates" do
    it "returns false for object?" do
      expect(freeze_node.object?).to be false
    end

    it "returns false for array?" do
      expect(freeze_node.array?).to be false
    end

    it "returns false for pair?" do
      expect(freeze_node.pair?).to be false
    end
  end

  describe "with block comments" do
    subject(:block_freeze_node) do
      described_class.new(
        start_line: 2,
        end_line: 4,
        lines: block_lines,
        pattern_type: :c_style_block,
      )
    end

    let(:block_lines) do
      [
        "{",
        "  /* json-merge:freeze */",
        '  "frozen": true',
        "  /* json-merge:unfreeze */",
        "}",
      ]
    end

    it "handles block comment markers" do
      expect(block_freeze_node.slice).to include("/* json-merge:freeze */")
    end
  end

  describe "#freeze_node?" do
    it "returns true" do
      expect(freeze_node.freeze_node?).to be true
    end
  end

  describe "#location" do
    it "returns a location struct with start and end lines" do
      location = freeze_node.location
      expect(location).to respond_to(:start_line)
      expect(location).to respond_to(:end_line)
      expect(location.start_line).to eq(start_line)
      expect(location.end_line).to eq(end_line)
    end

    it "supports cover? method" do
      location = freeze_node.location
      expect(location.cover?(start_line)).to be true
      expect(location.cover?(end_line)).to be true
    end
  end

  describe "#slice" do
    it "returns the frozen content as a string" do
      slice = freeze_node.slice
      expect(slice).to be_a(String)
      expect(slice).to include("frozen_key")
    end
  end

  describe "#content" do
    it "returns the same as slice" do
      expect(freeze_node.content).to eq(freeze_node.slice)
    end
  end

  describe "edge cases" do
    it "handles single-line freeze block" do
      lines = ["// json-merge:freeze"]
      node = described_class.new(
        start_line: 1,
        end_line: 1,
        lines: lines,
        pattern_type: :c_style_line,
      )
      expect(node.lines.length).to eq(1)
    end

    it "handles empty content between markers" do
      lines = [
        "// json-merge:freeze",
        "// json-merge:unfreeze",
      ]
      node = described_class.new(
        start_line: 1,
        end_line: 2,
        lines: lines,
        pattern_type: :c_style_line,
      )
      expect(node.lines.length).to eq(2)
    end

    it "raises error for empty freeze block" do
      expect {
        described_class.new(
          start_line: 1,
          end_line: 1,
          lines: [],
          pattern_type: :c_style_line,
        )
      }.to raise_error(Jsonc::Merge::FreezeNode::InvalidStructureError)
    end

    it "raises error for freeze block with all nil lines" do
      expect {
        described_class.new(
          start_line: 1,
          end_line: 2,
          lines: [nil, nil],
          pattern_type: :c_style_line,
        )
      }.to raise_error(Jsonc::Merge::FreezeNode::InvalidStructureError)
    end
  end

  describe "#signature" do
    it "generates a signature for matching" do
      sig = freeze_node.signature
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:FreezeNode)
    end

    it "includes normalized content in signature" do
      sig = freeze_node.signature
      expect(sig[1]).to be_a(String)
    end
  end

  describe "#inspect" do
    it "returns debug representation" do
      result = freeze_node.inspect
      expect(result).to include("FreezeNode")
      expect(result).to include("lines=")
    end
  end
end
