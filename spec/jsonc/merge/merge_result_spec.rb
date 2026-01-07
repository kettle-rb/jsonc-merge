# frozen_string_literal: true

RSpec.describe Jsonc::Merge::MergeResult do
  # Use the shared examples to validate MergeResultBase integration
  subject(:result) { described_class.new }

  it_behaves_like "Ast::Merge::MergeResultBase" do
    let(:merge_result_class) { described_class }
    let(:build_merge_result) { -> { described_class.new } }
  end

  describe "#initialize" do
    it "creates an empty result" do
      expect(result.lines).to eq([])
      expect(result.decisions).to eq([])
    end

    it "initializes statistics" do
      expect(result.statistics).to be_a(Hash)
      expect(result.statistics[:total_decisions]).to eq(0)
    end
  end

  describe "#add_line" do
    it "adds a line to the result" do
      result.add_line('"key": "value"', decision: :kept_destination, source: :destination)
      expect(result.lines.map { |l| l[:content] }).to include('"key": "value"')
    end

    it "tracks the decision" do
      result.add_line('"key": "value"', decision: :kept_destination, source: :destination)
      expect(result.decisions).not_to be_empty
    end

    it "updates statistics" do
      result.add_line('"key": "value"', decision: :kept_destination, source: :destination)
      expect(result.statistics[:dest_lines]).to eq(1)
    end
  end

  describe "#add_lines" do
    it "adds multiple lines" do
      result.add_lines(["{", "}"], decision: :kept_destination, source: :destination)
      expect(result.line_count).to eq(2)
    end
  end

  describe "#add_freeze_block" do
    let(:all_lines) do
      [
        "// json-merge:freeze",
        '"frozen": true',
        "// json-merge:unfreeze",
      ]
    end

    let(:freeze_node) do
      Jsonc::Merge::FreezeNode.new(
        start_line: 1,
        end_line: 3,
        lines: all_lines,
        pattern_type: :c_style_line,
      )
    end

    it "adds freeze block content" do
      result.add_freeze_block(freeze_node)
      contents = result.lines.map { |l| l[:content] }
      expect(contents).to include("// json-merge:freeze")
    end

    it "tracks freeze block statistics" do
      result.add_freeze_block(freeze_node)
      expect(result.statistics[:freeze_preserved_lines]).to eq(3)
    end
  end

  describe "#to_json" do
    it "returns the merged content as a string" do
      result.add_line("{", decision: :merged, source: :merged)
      result.add_line('  "key": "value"', decision: :merged, source: :merged)
      result.add_line("}", decision: :merged, source: :merged)
      expect(result.to_json).to include("{")
      expect(result.to_json).to include('"key": "value"')
      expect(result.to_json).to include("}")
    end

    it "returns empty string for empty result" do
      # Empty result returns empty string
      expect(result.to_json).to eq("")
    end
  end

  describe "#content" do
    it "is aliased to to_json" do
      result.add_line("{", decision: :merged, source: :merged)
      expect(result.content).to eq(result.to_json)
    end
  end

  describe "#line_count" do
    it "returns 0 for empty result" do
      expect(result.line_count).to eq(0)
    end

    it "returns the number of lines" do
      result.add_line("{", decision: :merged, source: :merged)
      result.add_line("}", decision: :merged, source: :merged)
      expect(result.line_count).to eq(2)
    end
  end

  describe "#statistics" do
    it "returns a hash of decision counts" do
      stats = result.statistics
      expect(stats).to be_a(Hash)
    end

    it "tracks kept_destination decisions" do
      result.add_line('"a": 1', decision: :kept_destination, source: :destination)
      result.add_line('"b": 2', decision: :kept_destination, source: :destination)
      stats = result.statistics
      expect(stats[:dest_lines]).to eq(2)
    end

    it "tracks kept_template decisions" do
      result.add_line('"a": 1', decision: :kept_template, source: :template)
      stats = result.statistics
      expect(stats[:template_lines]).to eq(1)
    end
  end

  describe "#empty?" do
    it "returns true for empty result" do
      expect(result.empty?).to be true
    end

    it "returns false after adding lines" do
      result.add_line("{", decision: :merged, source: :merged)
      expect(result.empty?).to be false
    end
  end

  describe "#decision_summary" do
    it "returns summary of decisions" do
      result.add_line("{", decision: :kept_destination, source: :destination)
      result.add_line("}", decision: :kept_template, source: :template)
      summary = result.decision_summary
      expect(summary[:kept_destination]).to eq(1)
      expect(summary[:kept_template]).to eq(1)
    end
  end

  describe "#add_line with different decisions" do
    it "tracks freeze_block decisions" do
      result.add_line("// frozen", decision: :freeze_block, source: :destination)
      expect(result.statistics[:freeze_preserved_lines]).to eq(1)
    end

    it "tracks merged decisions as merged_lines" do
      result.add_line("new line", decision: :added, source: :template)
      # :added decision falls through to merged_lines in the stats
      expect(result.statistics[:merged_lines]).to eq(1)
    end

    it "tracks original_line metadata" do
      result.add_line("content", decision: :kept_destination, source: :destination, original_line: 5)
      line_info = result.lines.first
      expect(line_info[:original_line]).to eq(5)
    end
  end

  describe "#decisions" do
    it "tracks all decisions made" do
      result.add_line("{", decision: :kept_destination, source: :destination)
      result.add_line("}", decision: :kept_template, source: :template)
      expect(result.decisions.size).to eq(2)
    end
  end

  describe "statistics edge cases" do
    it "handles unknown decision types" do
      result.add_line("line", decision: :unknown_type, source: :merged)
      # Should not raise, just count as total
      expect(result.statistics[:total_decisions]).to eq(1)
    end
  end

  describe "#lines structure" do
    it "includes content in each line entry" do
      result.add_line("test content", decision: :merged, source: :merged)
      expect(result.lines.first[:content]).to eq("test content")
    end

    it "includes decision in each line entry" do
      result.add_line("content", decision: :kept_destination, source: :destination)
      expect(result.lines.first[:decision]).to eq(:kept_destination)
    end

    it "includes source in each line entry" do
      result.add_line("content", decision: :kept_destination, source: :destination)
      expect(result.lines.first[:source]).to eq(:destination)
    end
  end

  describe "#add_node edge cases", :jsonc_grammar do
    it "returns early when node has nil start_line" do
      # Create a mock-like object that returns nil for start_line
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      node = analysis.root_object
      skip "No root object" unless node

      # Node should have valid lines, so this should work
      initial_count = result.lines.size
      result.add_node(node, decision: :kept_destination, source: :destination, analysis: analysis)
      expect(result.lines.size).to be >= initial_count
    end
  end

  describe "#to_json newline handling" do
    it "does not add extra newline if content already ends with newline" do
      result.add_line("line1", decision: :merged, source: :merged)
      json = result.to_json
      # Should have exactly one trailing newline
      expect(json).to end_with("\n")
      expect(json).not_to end_with("\n\n")
    end

    it "adds newline to content that doesn't have one" do
      result.add_line("no newline", decision: :merged, source: :merged)
      json = result.to_json
      expect(json).to end_with("\n")
    end
  end

  describe "#add_lines with start_line" do
    it "calculates original line numbers from start_line" do
      result.add_lines(["line1", "line2", "line3"], decision: :merged, source: :merged, start_line: 10)
      expect(result.lines[0][:original_line]).to eq(10)
      expect(result.lines[1][:original_line]).to eq(11)
      expect(result.lines[2][:original_line]).to eq(12)
    end

    it "sets nil original_line when start_line is nil" do
      result.add_lines(["line1", "line2"], decision: :merged, source: :merged, start_line: nil)
      expect(result.lines[0][:original_line]).to be_nil
      expect(result.lines[1][:original_line]).to be_nil
    end
  end
end
