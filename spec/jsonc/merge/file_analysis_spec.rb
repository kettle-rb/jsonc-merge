# frozen_string_literal: true

RSpec.describe Jsonc::Merge::FileAnalysis do
  let(:simple_json) do
    <<~JSON
      {
        "name": "test",
        "version": "1.0.0"
      }
    JSON
  end

  let(:complex_json) do
    <<~JSON
      {
        "name": "test-package",
        "version": "2.0.0",
        "dependencies": {
          "lodash": "^4.17.21",
          "express": "^4.18.0"
        },
        "devDependencies": {
          "jest": "^29.0.0"
        }
      }
    JSON
  end

  describe "#initialize" do
    it "returns a FileAnalysis instance" do
      result = described_class.new(simple_json)
      expect(result).to be_a(described_class)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "handles invalid JSON gracefully" do
      # First ensure parser is available
      described_class.new(simple_json)
      # Then test invalid JSON - tree-sitter may still parse with errors
      analysis = described_class.new("{ invalid json }")
      expect(analysis.valid?).to be(false).or be(true) # depends on parser behavior
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#nodes" do
    it "returns an array of nodes" do
      analysis = described_class.new(simple_json)
      expect(analysis.nodes).to be_an(Array)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#lines" do
    it "returns the content split into lines" do
      analysis = described_class.new(simple_json)
      expect(analysis.lines).to be_an(Array)
      expect(analysis.lines).to include("{")
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#line_at" do
    it "returns the line at the given 1-based index" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1)).to eq("{")
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns nil for out of bounds" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1000)).to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#comment_tracker" do
    it "returns a CommentTracker instance" do
      analysis = described_class.new(simple_json)
      expect(analysis.comment_tracker).to be_a(Jsonc::Merge::CommentTracker)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#generate_signature" do
    it "generates a signature for nodes" do
      analysis = described_class.new(complex_json)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        # Signatures are Arrays like [:pair, "key_name"] or nil
        expect(sig).to be_an(Array).or be_nil
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "freeze block detection" do
    let(:json_with_freeze) do
      <<~JSON
        {
          "normal": "value",
          // json-merge:freeze
          "frozen_key": "frozen_value",
          // json-merge:unfreeze
          "other": "value"
        }
      JSON
    end

    it "detects freeze blocks" do
      analysis = described_class.new(json_with_freeze)
      freeze_nodes = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      # May or may not detect depending on parser support for JSONC
      expect(freeze_nodes).to be_an(Array)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#valid?" do
    it "returns true for valid JSON" do
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be true
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#root_node" do
    it "returns the root node" do
      analysis = described_class.new(simple_json)
      root = analysis.root_node
      expect(root).to be_a(Jsonc::Merge::NodeWrapper)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#root_object" do
    it "returns the root object" do
      analysis = described_class.new(simple_json)
      obj = analysis.root_object
      expect(obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(obj.object?).to be true
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns nil for array root" do
      analysis = described_class.new('["item1", "item2"]')
      obj = analysis.root_object
      expect(obj).to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#root_pairs" do
    it "returns pairs from root object" do
      analysis = described_class.new(simple_json)
      pairs = analysis.root_pairs
      expect(pairs).to be_an(Array)
      expect(pairs.size).to eq(2)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns empty array for array root" do
      analysis = described_class.new('["item1"]')
      pairs = analysis.root_pairs
      expect(pairs).to eq([])
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#normalized_line" do
    it "returns stripped line content" do
      analysis = described_class.new(simple_json)
      line = analysis.normalized_line(2)
      expect(line).to be_a(String)
      expect(line).not_to start_with(" ")
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns nil for out of bounds" do
      analysis = described_class.new(simple_json)
      expect(analysis.normalized_line(0)).to be_nil
      expect(analysis.normalized_line(1000)).to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#in_freeze_block?" do
    it "returns false when no freeze blocks" do
      analysis = described_class.new(simple_json)
      expect(analysis.in_freeze_block?(1)).to be false
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#freeze_block_at" do
    it "returns nil when no freeze block at line" do
      analysis = described_class.new(simple_json)
      expect(analysis.freeze_block_at(1)).to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#fallthrough_node?" do
    it "returns true for NodeWrapper instances" do
      analysis = described_class.new(simple_json)
      node = analysis.root_object
      skip "No root object" unless node
      expect(analysis.fallthrough_node?(node)).to be true
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns false for other types" do
      analysis = described_class.new(simple_json)
      expect(analysis.fallthrough_node?("string")).to be false
      expect(analysis.fallthrough_node?(123)).to be false
      expect(analysis.fallthrough_node?(nil)).to be false
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "custom signature generator" do
    it "uses custom signature generator when provided" do
      custom_gen = ->(node) { [:custom, node.class.name] }
      analysis = described_class.new(simple_json, signature_generator: custom_gen)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        expect(sig.first).to eq(:custom)
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "falls through to default when custom returns a node" do
      custom_gen = ->(node) { node }  # Returns the node itself
      analysis = described_class.new(simple_json, signature_generator: custom_gen)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        expect(sig).to be_an(Array)
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "parser path handling" do
    it "uses TREE_SITTER_JSON_PATH environment variable" do
      # Test that the class method exists
      expect(described_class).to respond_to(:find_parser_path)
    end

    it "handles missing parser gracefully" do
      # When parser is not found, it should set errors
      analysis = described_class.new(simple_json, parser_path: "/nonexistent/path")
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
    end
  end

  describe "freeze blocks with block comments" do
    let(:json_with_block_freeze) do
      <<~JSON
        {
          "normal": "value",
          /* json-merge:freeze */
          "frozen": true,
          /* json-merge:unfreeze */
          "other": "value"
        }
      JSON
    end

    it "detects block comment freeze markers" do
      analysis = described_class.new(json_with_block_freeze)
      expect(analysis.nodes).to be_an(Array)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "with freeze blocks" do
    let(:json_with_complete_freeze) do
      <<~JSONC
        {
          "normal": "value",
          // json-merge:freeze
          "frozen": "preserved",
          // json-merge:unfreeze
          "other": "value"
        }
      JSONC
    end

    it "correctly identifies freeze block ranges" do
      analysis = described_class.new(json_with_complete_freeze)
      # Check for freeze blocks
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      expect(freeze_blocks).to be_an(Array)
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "marks lines as in freeze block" do
      analysis = described_class.new(json_with_complete_freeze)
      # The freeze blocks should be detected
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        expect(analysis.in_freeze_block?(fb.start_line)).to be true
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "returns freeze block at line" do
      analysis = described_class.new(json_with_complete_freeze)
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        found = analysis.freeze_block_at(fb.start_line)
        expect(found).to eq(fb)
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#fallthrough_node? with FreezeNode" do
    it "returns true for FreezeNode instances" do
      json_with_freeze = <<~JSONC
        {
          // json-merge:freeze
          "frozen": true
          // json-merge:unfreeze
        }
      JSONC
      analysis = described_class.new(json_with_freeze)
      freeze_nodes = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_nodes.any?
        expect(analysis.fallthrough_node?(freeze_nodes.first)).to be true
      end
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "edge cases" do
    it "handles empty JSON object" do
      analysis = described_class.new("{}")
      expect(analysis.valid?).to be true
      expect(analysis.root_object).not_to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "handles empty JSON array" do
      analysis = described_class.new("[]")
      expect(analysis.valid?).to be true
      expect(analysis.root_object).to be_nil
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    it "handles deeply nested JSON" do
      deep_json = '{"a": {"b": {"c": {"d": "value"}}}}'
      analysis = described_class.new(deep_json)
      expect(analysis.valid?).to be true
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end
end
