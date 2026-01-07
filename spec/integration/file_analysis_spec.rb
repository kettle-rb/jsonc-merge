# frozen_string_literal: true

# Integration tests for FileAnalysis with real JSON parsing scenarios

RSpec.describe "Jsonc::Merge::FileAnalysis Integration", :jsonc_grammar do
  describe "with JSONC comments" do
    let(:jsonc_content) do
      <<~JSON
        {
          // This is a line comment
          "name": "test",
          /* This is a block comment */
          "version": "1.0.0"
        }
      JSON
    end

    it "parses JSONC content (may have errors due to comments)" do
      analysis = Jsonc::Merge::FileAnalysis.new(jsonc_content)
      # tree-sitter JSON parser may report errors for comments
      # but the content is still processed for freeze blocks
      expect(analysis).to be_a(Jsonc::Merge::FileAnalysis)
      expect(analysis.comment_tracker).to be_a(Jsonc::Merge::CommentTracker)
    end
  end

  describe "with freeze blocks" do
    let(:json_with_freeze) do
      <<~JSON
        {
          "name": "test",
          // json-merge:freeze Secret config
          "secrets": {
            "key": "value"
          },
          // json-merge:unfreeze
          "public": "data"
        }
      JSON
    end

    it "extracts freeze blocks" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_with_freeze)
      # Freeze blocks are extracted even without a valid AST
      expect(analysis.freeze_blocks.size).to eq(1)
      expect(analysis.freeze_blocks.first.reason).to eq("Secret config")
    end

    it "identifies lines within freeze blocks" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_with_freeze)
      freeze_block = analysis.freeze_blocks.first

      expect(analysis.in_freeze_block?(freeze_block.start_line)).to be true
      expect(analysis.in_freeze_block?(freeze_block.end_line)).to be true
      expect(analysis.in_freeze_block?(1)).to be false
    end

    it "retrieves freeze block at line" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_with_freeze)
      freeze_block = analysis.freeze_blocks.first

      found = analysis.freeze_block_at(freeze_block.start_line + 1)
      expect(found).to eq(freeze_block)
      expect(analysis.freeze_block_at(1)).to be_nil
    end
  end

  describe "with custom freeze token" do
    let(:json_with_custom_token) do
      <<~JSON
        {
          "name": "test",
          // my-token:freeze
          "frozen": "content",
          // my-token:unfreeze
          "normal": "content"
        }
      JSON
    end

    it "recognizes custom freeze token" do
      analysis = Jsonc::Merge::FileAnalysis.new(
        json_with_custom_token,
        freeze_token: "my-token",
      )
      expect(analysis.freeze_blocks.size).to eq(1)
    end
  end

  describe "with custom signature generator" do
    let(:json_content) { '{"name": "test", "version": "1.0.0"}' }

    it "uses custom signature generator" do
      custom_sig_called = false
      custom_generator = ->(node) {
        custom_sig_called = true
        [:custom, node.class.name]
      }

      analysis = Jsonc::Merge::FileAnalysis.new(
        json_content,
        signature_generator: custom_generator,
      )

      expect(analysis.valid?).to be(true)
      expect(analysis.nodes).not_to be_empty

      # Generate signature for first node to trigger custom generator
      analysis.nodes.each do |node|
        analysis.generate_signature(node)
      end

      expect(custom_sig_called).to be true
    end

    it "falls through when custom generator returns a node" do
      # Generator returns a node, which triggers fallthrough to compute_node_signature
      fallthrough_generator = ->(node) { node }

      analysis = Jsonc::Merge::FileAnalysis.new(
        json_content,
        signature_generator: fallthrough_generator,
      )

      expect(analysis.valid?).to be(true)

      analysis.nodes.each do |node|
        sig = analysis.generate_signature(node)
        # Should compute signature via fallthrough
        expect(sig).not_to be_nil if node.is_a?(Jsonc::Merge::NodeWrapper)
      end
    end
  end

  describe "#normalized_line" do
    let(:json_content) { "{\n  \"key\": \"value\"\n}" }

    it "returns stripped line content" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_content)
      expect(analysis.normalized_line(2)).to eq('"key": "value"')
    end

    it "returns nil for invalid line numbers" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_content)
      expect(analysis.normalized_line(0)).to be_nil
      expect(analysis.normalized_line(100)).to be_nil
    end
  end

  describe "#root_node and #root_object" do
    let(:object_json) { '{"key": "value"}' }
    let(:array_json) { '["item1", "item2"]' }

    it "returns root_node for valid JSON" do
      analysis = Jsonc::Merge::FileAnalysis.new(object_json)
      expect(analysis.valid?).to be(true)
      expect(analysis.root_node).to be_a(Jsonc::Merge::NodeWrapper)
    end

    it "returns root_object for object JSON" do
      analysis = Jsonc::Merge::FileAnalysis.new(object_json)
      expect(analysis.valid?).to be(true)
      root_obj = analysis.root_object
      expect(root_obj).to be_a(Jsonc::Merge::NodeWrapper)
      expect(root_obj.object?).to be true
    end

    it "returns nil root_object for array JSON" do
      analysis = Jsonc::Merge::FileAnalysis.new(array_json)
      expect(analysis.valid?).to be(true)
      # root_object looks for an object node, array JSON doesn't have one at root
      expect(analysis.root_object).to be_nil
    end
  end

  describe "#root_pairs" do
    let(:json_content) { '{"a": 1, "b": 2}' }

    it "returns key-value pairs from root object" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_content)
      expect(analysis.valid?).to be(true)
      pairs = analysis.root_pairs
      expect(pairs).to be_an(Array)
    end

    it "returns empty array when no root object" do
      analysis = Jsonc::Merge::FileAnalysis.new('["item"]')
      expect(analysis.valid?).to be(true)
      expect(analysis.root_pairs).to eq([])
    end
  end
end
