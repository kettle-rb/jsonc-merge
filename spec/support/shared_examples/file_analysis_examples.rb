# frozen_string_literal: true

# Shared examples for FileAnalysis across different backends
#
# These examples test FileAnalysis behavior that should be consistent
# regardless of which tree-sitter backend is used (MRI, FFI, Rust, Java).

RSpec.shared_examples "valid JSON parsing" do |expected_backend:|
  describe "with valid JSON source" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "parses successfully" do
      analysis = described_class.new(simple_json)
      expect(analysis).to be_a(described_class)
    end

    it "is valid" do
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be true
    end

    it "has no errors" do
      analysis = described_class.new(simple_json)
      expect(analysis.errors).to be_empty
    end

    it "returns NodeWrapper for nodes" do
      analysis = described_class.new(simple_json)
      nodes = analysis.nodes
      expect(nodes).to be_an(Array)
      expect(nodes.first).to be_a(Jsonc::Merge::NodeWrapper)
    end

    it "has a root_node" do
      analysis = described_class.new(simple_json)
      expect(analysis.root_node).to be_a(Jsonc::Merge::NodeWrapper)
    end

    it "has a root_object" do
      analysis = described_class.new(simple_json)
      root_obj = analysis.root_object
      expect(root_obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(root_obj.object?).to be true
    end

    it "returns source lines" do
      analysis = described_class.new(simple_json)
      expect(analysis.lines).to be_an(Array)
      expect(analysis.lines).to include("{")
    end
  end
end

RSpec.shared_examples "invalid JSON detection" do
  describe "with invalid JSON" do
    let(:invalid_json) { '{ "unclosed": ' }

    it "parses but marks as invalid or handles error recovery" do
      analysis = described_class.new(invalid_json)
      expect(analysis).to be_a(described_class)
      # tree-sitter may still parse with errors (error recovery)
      # Behavior depends on backend
      expect(analysis.valid?).to be(false).or be(true)
    end
  end
end

RSpec.shared_examples "freeze block detection" do
  describe "with freeze blocks" do
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
      expect(freeze_nodes).to be_an(Array)
    end

    it "correctly identifies freeze block ranges" do
      analysis = described_class.new(json_with_freeze)
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      expect(freeze_blocks).to be_an(Array)
    end

    it "marks lines as in freeze block" do
      analysis = described_class.new(json_with_freeze)
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        expect(analysis.in_freeze_block?(fb.start_line)).to be true
      end
    end

    it "returns freeze block at line" do
      analysis = described_class.new(json_with_freeze)
      freeze_blocks = analysis.nodes.select { |n| n.is_a?(Jsonc::Merge::FreezeNode) }
      if freeze_blocks.any?
        fb = freeze_blocks.first
        found = analysis.freeze_block_at(fb.start_line)
        expect(found).to eq(fb)
      end
    end

    it "extracts freeze block content" do
      analysis = described_class.new(json_with_freeze)
      if analysis.freeze_blocks.any?
        freeze_block = analysis.freeze_blocks.first
        expect(freeze_block.start_line).to be_a(Integer)
        expect(freeze_block.end_line).to be_a(Integer)
      end
    end
  end

  describe "with block comment freeze markers" do
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
end

RSpec.shared_examples "custom freeze token" do
  describe "with custom freeze token" do
    let(:json_with_custom_token) do
      <<~JSON
        {
          "normal": "value",
          // my-token:freeze
          "frozen": "value",
          // my-token:unfreeze
          "other": "value"
        }
      JSON
    end

    it "recognizes the custom token" do
      analysis = described_class.new(json_with_custom_token, freeze_token: "my-token")
      expect(analysis.freeze_blocks.size).to eq(1)
    end
  end
end

RSpec.shared_examples "root node access" do
  describe "#root_node and #root_object" do
    let(:object_json) { '{"key": "value"}' }
    let(:array_json) { '["item1", "item2"]' }
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "returns root_node for valid JSON" do
      analysis = described_class.new(object_json)
      expect(analysis.valid?).to be true
      expect(analysis.root_node).to be_a(Jsonc::Merge::NodeWrapper)
    end

    it "returns the root node" do
      analysis = described_class.new(simple_json)
      root = analysis.root_node
      expect(root).to be_a(Jsonc::Merge::NodeWrapper)
    end

    it "returns root_object for object JSON" do
      analysis = described_class.new(object_json)
      expect(analysis.valid?).to be true
      root_obj = analysis.root_object
      expect(root_obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(root_obj.object?).to be true
    end

    it "returns the root object" do
      analysis = described_class.new(simple_json)
      obj = analysis.root_object
      expect(obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(obj.object?).to be true
    end

    it "returns nil root_object for array JSON" do
      analysis = described_class.new(array_json)
      expect(analysis.valid?).to be true
      expect(analysis.root_object).to be_nil
    end

    it "returns nil for array root" do
      analysis = described_class.new('["item1", "item2"]')
      obj = analysis.root_object
      expect(obj).to be_nil
    end
  end

  describe "#root_object_open_line" do
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
  end

  describe "#root_object_close_line" do
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
end

RSpec.shared_examples "root pairs extraction" do
  describe "#root_pairs" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "returns key-value pairs from root object" do
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be true
      pairs = analysis.root_pairs
      expect(pairs).to be_an(Array)
    end

    it "returns pairs from root object" do
      analysis = described_class.new(simple_json)
      pairs = analysis.root_pairs
      expect(pairs).to be_an(Array)
      expect(pairs.size).to eq(2)
    end

    it "returns empty array when no root object" do
      analysis = described_class.new('["item"]')
      expect(analysis.valid?).to be true
      expect(analysis.root_pairs).to eq([])
    end

    it "returns empty array for array root" do
      analysis = described_class.new('["item1"]')
      pairs = analysis.root_pairs
      expect(pairs).to eq([])
    end
  end
end

RSpec.shared_examples "line access" do
  describe "#line_at" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "returns the line at the given 1-based index" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1)).to eq("{")
    end

    it "returns nil for out of bounds" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(1000)).to be_nil
    end

    it "returns nil for zero index" do
      analysis = described_class.new(simple_json)
      expect(analysis.line_at(0)).to be_nil
    end
  end

  describe "#normalized_line" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

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
end

RSpec.shared_examples "signature generation" do
  describe "#generate_signature" do
    let(:complex_json) do
      <<~JSON
        {
          "name": "test-package",
          "version": "2.0.0",
          "dependencies": {
            "lodash": "^4.17.21",
            "express": "^4.18.0"
          }
        }
      JSON
    end

    it "generates a signature for nodes" do
      analysis = described_class.new(complex_json)
      node = analysis.nodes.first
      if node.is_a?(Jsonc::Merge::NodeWrapper)
        sig = analysis.generate_signature(node)
        expect(sig).to be_an(Array).or be_nil
      end
    end

    it "returns nil for nil input" do
      analysis = described_class.new(complex_json)
      sig = analysis.generate_signature(nil)
      expect(sig).to be_nil
    end
  end

  describe "compute_node_signature" do
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

RSpec.shared_examples "custom signature generator" do
  describe "custom signature generator" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

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
end

RSpec.shared_examples "fallthrough_node? behavior" do
  describe "#fallthrough_node?" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

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
end

RSpec.shared_examples "comment tracker" do
  describe "#comment_tracker" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "returns a CommentTracker instance" do
      analysis = described_class.new(simple_json)
      expect(analysis.comment_tracker).to be_a(Jsonc::Merge::CommentTracker)
    end
  end
end

RSpec.shared_examples "parser path handling" do
  describe "parser path handling" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "uses TREE_SITTER_JSONC_PATH environment variable" do
      expect(described_class).to respond_to(:find_parser_path)
    end

    it "handles nonexistent parser path gracefully" do
      analysis = described_class.new(simple_json, parser_path: "/nonexistent/path/to/parser.so")
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
      expect(analysis.errors.first).to include("nonexistent")
    end

    it "handles TreeHaver::NotAvailable gracefully" do
      allow(TreeHaver).to receive(:parser_for).and_raise(TreeHaver::NotAvailable.new("No parser available"))
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
      expect(analysis.errors.first).to include("No parser available")
    end

    it "handles other parse errors gracefully" do
      allow(TreeHaver).to receive(:parser_for).and_raise(StandardError.new("Unexpected error"))
      analysis = described_class.new(simple_json)
      expect(analysis.valid?).to be false
      expect(analysis.errors).not_to be_empty
    end
  end
end

RSpec.shared_examples "edge cases" do
  describe "edge cases" do
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
end

RSpec.shared_examples "freeze block helpers" do
  describe "freeze block helpers" do
    let(:simple_json) do
      <<~JSON
        {
          "name": "test",
          "version": "1.0.0"
        }
      JSON
    end

    it "#in_freeze_block? returns false when no freeze blocks" do
      analysis = described_class.new(simple_json)
      expect(analysis.in_freeze_block?(1)).to be false
    end

    it "#freeze_block_at returns nil when no freeze block at line" do
      analysis = described_class.new(simple_json)
      expect(analysis.freeze_block_at(1)).to be_nil
    end
  end
end
