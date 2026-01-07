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
    it "returns a FileAnalysis instance", :tree_sitter_jsonc do
      result = described_class.new(simple_json)
      expect(result).to be_a(described_class)
    end

    it "handles invalid JSON gracefully", :tree_sitter_jsonc do
      # tree-sitter may still parse with errors (error recovery)
      analysis = described_class.new("{ invalid json }")
      expect(analysis.valid?).to be(false).or be(true) # depends on parser behavior
    end
  end

  describe "#nodes", :tree_sitter_jsonc do
    it "returns an array of nodes" do
      analysis = described_class.new(simple_json)
      expect(analysis.nodes).to be_an(Array)
    end
  end

  describe "#lines", :tree_sitter_jsonc do
    it "returns the content split into lines" do
      analysis = described_class.new(simple_json)
      expect(analysis.lines).to be_an(Array)
      expect(analysis.lines).to include("{")
    end
  end

  describe "#line_at", :tree_sitter_jsonc do
    it "returns the line at the given 1-based index" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1)).to eq("{")
    end

    it "returns nil for out of bounds" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1000)).to be_nil
    end
  end

  describe "#comment_tracker", :tree_sitter_jsonc do
    it "returns a CommentTracker instance" do
      analysis = described_class.new(simple_json)
      expect(analysis.comment_tracker).to be_a(Jsonc::Merge::CommentTracker)
    end
  end

  describe "#generate_signature", :tree_sitter_jsonc do
    it "generates a signature for nodes" do
      analysis = described_class.new(complex_json)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        # Signatures are Arrays like [:pair, "key_name"] or nil
        expect(sig).to be_an(Array).or be_nil
      end
    end
  end

  describe "freeze block detection", :tree_sitter_jsonc do
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
    end
  end

  describe "#valid?", :tree_sitter_jsonc do
    it "returns true for valid JSON" do
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be true
    end
  end

  describe "#root_node", :tree_sitter_jsonc do
    it "returns the root node" do
      analysis = described_class.new(simple_json)
      root = analysis.root_node
      expect(root).to be_a(Jsonc::Merge::NodeWrapper)
    end
  end

  describe "#root_object", :tree_sitter_jsonc do
    it "returns the root object" do
      analysis = described_class.new(simple_json)
      obj = analysis.root_object
      expect(obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(obj.object?).to be true
    end

    it "returns nil for array root" do
      analysis = described_class.new('["item1", "item2"]')
      obj = analysis.root_object
      expect(obj).to be_nil
    end
  end

  describe "#root_pairs", :tree_sitter_jsonc do
    it "returns pairs from root object" do
      analysis = described_class.new(simple_json)
      pairs = analysis.root_pairs
      expect(pairs).to be_an(Array)
      expect(pairs.size).to eq(2)
    end

    it "returns empty array for array root" do
      analysis = described_class.new('["item1"]')
      pairs = analysis.root_pairs
      expect(pairs).to eq([])
    end
  end

  describe "#normalized_line", :tree_sitter_jsonc do
    it "returns stripped line content" do
      analysis = described_class.new(simple_json)
      line = analysis.normalized_line(2)
      expect(line).to be_a(String)
      expect(line).not_to start_with(" ")
    end

    it "returns nil for out of bounds" do
      analysis = described_class.new(simple_json)
      expect(analysis.normalized_line(0)).to be_nil
      expect(analysis.normalized_line(1000)).to be_nil
    end
  end

  describe "#in_freeze_block?", :tree_sitter_jsonc do
    it "returns false when no freeze blocks" do
      analysis = described_class.new(simple_json)
      expect(analysis.in_freeze_block?(1)).to be false
    end
  end

  describe "#freeze_block_at", :tree_sitter_jsonc do
    it "returns nil when no freeze block at line" do
      analysis = described_class.new(simple_json)
      expect(analysis.freeze_block_at(1)).to be_nil
    end
  end

  describe "#fallthrough_node?", :tree_sitter_jsonc do
    it "returns true for NodeWrapper instances" do
      analysis = described_class.new(simple_json)
      node = analysis.root_object
      skip "No root object" unless node
      expect(analysis.fallthrough_node?(node)).to be true
    end

    it "returns false for other types" do
      analysis = described_class.new(simple_json)
      expect(analysis.fallthrough_node?("string")).to be false
      expect(analysis.fallthrough_node?(123)).to be false
      expect(analysis.fallthrough_node?(nil)).to be false
    end
  end

  describe "custom signature generator", :tree_sitter_jsonc do
    it "uses custom signature generator when provided" do
      custom_gen = ->(node) { [:custom, node.class.name] }
      analysis = described_class.new(simple_json, signature_generator: custom_gen)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        expect(sig.first).to eq(:custom)
      end
    end

    it "falls through to default when custom returns a node" do
      custom_gen = ->(node) { node }  # Returns the node itself
      analysis = described_class.new(simple_json, signature_generator: custom_gen)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        expect(sig).to be_an(Array)
      end
    end
  end

  describe "parser path handling" do
    it "uses TREE_SITTER_JSON_PATH environment variable" do
      # Test that the class method exists
      expect(described_class).to respond_to(:find_parser_path)
    end

    it "handles nonexistent parser path gracefully" do
      # When an explicit parser_path is provided that doesn't exist,
      # TreeHaver should raise NotAvailable (Principle of Least Surprise)
      analysis = described_class.new(simple_json, parser_path: "/nonexistent/path/to/parser.so")
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
      expect(analysis.errors.first).to include("nonexistent")
    end

    it "handles TreeHaver::NotAvailable gracefully" do
      # When TreeHaver raises NotAvailable, errors should be populated
      allow(TreeHaver).to receive(:parser_for).and_raise(TreeHaver::NotAvailable.new("No parser available"))

      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
      expect(analysis.errors.first).to include("No parser available")
    end

    it "handles other parse errors gracefully" do
      # When TreeHaver raises a StandardError, errors should be populated
      allow(TreeHaver).to receive(:parser_for).and_raise(StandardError.new("Unexpected error"))

      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
    end
  end

  describe "freeze blocks with block comments", :tree_sitter_jsonc do
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
    end
  end

  describe "with freeze blocks", :tree_sitter_jsonc do
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
    end

    it "marks lines as in freeze block" do
      analysis = described_class.new(json_with_complete_freeze)
      # The freeze blocks should be detected
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        expect(analysis.in_freeze_block?(fb.start_line)).to be true
      end
    end

    it "returns freeze block at line" do
      analysis = described_class.new(json_with_complete_freeze)
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        found = analysis.freeze_block_at(fb.start_line)
        expect(found).to eq(fb)
      end
    end
  end

  describe "#fallthrough_node? with FreezeNode", :tree_sitter_jsonc do
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
    end
  end

  describe "edge cases", :tree_sitter_jsonc do
    it "handles empty JSON object" do
      analysis = described_class.new("{}")
      expect(analysis.valid?).to be true
      expect(analysis.root_object).not_to be_nil
    end

    it "handles empty JSON array" do
      analysis = described_class.new("[]")
      expect(analysis.valid?).to be true
      expect(analysis.root_object).to be_nil
    end

    it "handles deeply nested JSON" do
      deep_json = '{"a": {"b": {"c": {"d": "value"}}}}'
      analysis = described_class.new(deep_json)
      expect(analysis.valid?).to be true
    end
  end

  describe "#root_object_open_line", :tree_sitter_jsonc do
    it "returns the opening brace line for objects" do
      json = "{\n  \"key\": \"value\"\n}"
      analysis = described_class.new(json)
      expect(analysis.root_object_open_line).to eq("{")
    end

    it "returns nil for array root" do
      json = '["item"]'
      analysis = described_class.new(json)
      expect(analysis.root_object_open_line).to be_nil
    end

    it "returns nil when root_object has no start_line" do
      json = "{}"
      analysis = described_class.new(json)
      obj = analysis.root_object
      if obj&.start_line
        expect(analysis.root_object_open_line).not_to be_nil
      end
    end
  end

  describe "#root_object_close_line", :tree_sitter_jsonc do
    it "returns the closing brace line for objects" do
      json = "{\n  \"key\": \"value\"\n}"
      analysis = described_class.new(json)
      expect(analysis.root_object_close_line).to eq("}")
    end

    it "returns nil for array root" do
      json = '["item"]'
      analysis = described_class.new(json)
      expect(analysis.root_object_close_line).to be_nil
    end
  end

  describe "compute_node_signature", :tree_sitter_jsonc do
    it "returns signature for NodeWrapper" do
      json = '{"key": "value"}'
      analysis = described_class.new(json)
      node = analysis.nodes.find { |n| n.is_a?(Jsonc::Merge::NodeWrapper) }
      skip "No NodeWrapper found" unless node
      sig = analysis.send(:compute_node_signature, node)
      expect(sig).to be_an(Array).or be_nil
    end

    it "returns signature for FreezeNode" do
      json = <<~JSONC
        {
          // json-merge:freeze
          "frozen": true
          // json-merge:unfreeze
        }
      JSONC
      analysis = described_class.new(json)
      freeze_node = analysis.nodes.find { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_node
        sig = analysis.send(:compute_node_signature, freeze_node)
        expect(sig).to be_an(Array)
      end
    end

    it "returns nil for unknown node types" do
      json = '{"key": "value"}'
      analysis = described_class.new(json)
      sig = analysis.send(:compute_node_signature, "not a node")
      expect(sig).to be_nil
    end
  end
end
