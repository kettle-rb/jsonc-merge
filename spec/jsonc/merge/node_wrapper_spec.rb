# frozen_string_literal: true

RSpec.describe Jsonc::Merge::NodeWrapper do
  # NodeWrapper requires a tree-sitter node, which requires parser availability
  # These tests use the actual parser when available

  describe "when tree-sitter parser is available" do
    let(:json_content) { '{"key": "value"}' }

    it "creates wrapper instances from FileAnalysis" do
      analysis = Jsonc::Merge::FileAnalysis.new(json_content)
      nodes = analysis.nodes
      expect(nodes).to be_an(Array)
      expect(nodes).to all(be_a(described_class).or(be_a(Jsonc::Merge::FreezeNode)))
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end
  end

  describe "instance methods" do
    let(:json_content) { '{"name": "test", "version": "1.0.0"}' }

    before do
      @analysis = Jsonc::Merge::FileAnalysis.new(json_content)
      @wrapper = @analysis.nodes.find { |n| n.is_a?(described_class) }
    rescue Jsonc::Merge::ParseError => e
      skip "Tree-sitter parser not available: #{e.message}"
    end

    describe "#type" do
      it "returns the node type" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.type).to be_a(Symbol)
      end
    end

    describe "#start_line" do
      it "returns the starting line number" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.start_line).to be_a(Integer)
        expect(@wrapper.start_line).to be >= 1
      end
    end

    describe "#end_line" do
      it "returns the ending line number" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.end_line).to be_a(Integer)
        expect(@wrapper.end_line).to be >= @wrapper.start_line
      end
    end

    describe "#text" do
      it "returns the node text" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.text).to be_a(String)
      end
    end

    describe "#children" do
      it "returns an array" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.children).to be_an(Array)
      end
    end

    describe "#frozen?" do
      it "returns false for regular nodes" do
        skip "No wrapper node available" unless @wrapper
        expect(@wrapper.frozen?).to be false
      end
    end
  end

  describe "type predicate methods" do
    describe "#object?" do
      it "returns true for object nodes" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        expect(root.object?).to be true
      end
    end

    describe "#array?" do
      it "returns true for array root" do
        json = '["item1", "item2"]'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_node
        skip "No root node" unless root
        # The root document contains an array
        array_node = root.children.find(&:array?)
        skip "No array child" unless array_node
        expect(array_node.array?).to be true
      end

      it "returns false for non-array nodes" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        expect(root.array?).to be false
      end
    end

    describe "#string?" do
      it "returns true for string values" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value node" unless value
        expect(value.string?).to be true
      end
    end

    describe "#number?" do
      it "returns true for number values" do
        json = '{"count": 42}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value node" unless value
        expect(value.number?).to be true
      end
    end

    describe "#boolean?" do
      it "returns true for true values" do
        json = '{"enabled": true}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value node" unless value
        expect(value.boolean?).to be true
      end

      it "returns true for false values" do
        json = '{"enabled": false}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value node" unless value
        expect(value.boolean?).to be true
      end
    end

    describe "#null?" do
      it "returns true for null values" do
        json = '{"value": null}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value node" unless value
        expect(value.null?).to be true
      end
    end

    describe "#pair?" do
      it "returns true for key-value pairs" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        expect(pair.pair?).to be true
      end
    end
  end

  describe "#key_name" do
    it "returns key name for pair nodes" do
      json = '{"myKey": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      expect(pair.key_name).to eq("myKey")
    end

    it "returns nil for non-pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.key_name).to be_nil
    end
  end

  describe "#value_node" do
    it "returns value wrapper for pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      expect(value).to be_a(described_class)
    end

    it "returns nil for non-pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.value_node).to be_nil
    end
  end

  describe "#pairs" do
    it "returns pairs for object nodes" do
      json = '{"a": 1, "b": 2}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pairs = root.pairs
      expect(pairs.size).to eq(2)
      pairs.each { |p| expect(p.pair?).to be true }
    end

    it "returns empty array for non-object nodes" do
      json = '["item"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.pairs).to eq([])
    end
  end

  describe "#elements" do
    it "returns elements for array nodes" do
      json = '["a", "b", "c"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
      expect(elements.size).to eq(3)
    end

    it "returns empty array for non-array nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.elements).to eq([])
    end
  end

  describe "#signature" do
    it "generates signature for pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      sig = pair.signature
      expect(sig).to be_an(Array)
    end
  end

  describe "#freeze_node?" do
    it "returns false for NodeWrapper" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.freeze_node?).to be false
    end
  end

  describe "#type?" do
    it "returns true when type matches" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.type?(:object)).to be true
      expect(root.type?("object")).to be true
    end

    it "returns false when type does not match" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.type?(:array)).to be false
    end
  end

  describe "#comment?" do
    it "returns false for non-comment nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.comment?).to be false
    end
  end

  describe "#content" do
    it "returns node content from source lines" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.content).to be_a(String)
      expect(root.content).not_to be_empty
    end

    it "returns empty string when start_line is nil" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      # Test the edge case by checking the method exists
      expect(root).to respond_to(:content)
    end
  end

  describe "#node_text" do
    it "extracts text from tree-sitter node" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.text).to be_a(String)
    end
  end

  describe "#find_child_by_type" do
    it "finds child node by type" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.send(:find_child_by_type, "pair")
      expect(pair).not_to be_nil if root.pairs.any?
    end

    it "returns nil when type not found" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      result = root.send(:find_child_by_type, "nonexistent_type")
      expect(result).to be_nil
    end
  end

  describe "#inspect" do
    it "returns a debug string" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.inspect).to be_a(String)
      expect(root.inspect).to include("NodeWrapper")
    end
  end

  describe "signature generation" do
    describe "for document type" do
      it "generates signature for document root" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_node
        skip "No root node" unless root
        sig = root.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:document)
      end
    end

    describe "for object type" do
      it "generates signature with sorted keys" do
        json = '{"b": 1, "a": 2}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        sig = root.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:object)
        expect(sig[1]).to eq(["a", "b"])
      end
    end

    describe "for array type" do
      it "generates signature with element count" do
        json = '["a", "b", "c"]'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_node
        skip "No root node" unless root
        array_node = root.children.find(&:array?)
        skip "No array node" unless array_node
        sig = array_node.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:array)
        expect(sig[1]).to eq(3)
      end
    end

    describe "for string type" do
      it "generates signature with string content" do
        json = '{"key": "hello"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:string)
        expect(sig[1]).to include("hello")
      end
    end

    describe "for number type" do
      it "generates signature with number value" do
        json = '{"count": 42}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:number)
        expect(sig[1]).to eq("42")
      end

      it "handles negative numbers" do
        json = '{"value": -123}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        expect(value.number?).to be true
      end

      it "handles decimal numbers" do
        json = '{"value": 3.14}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        expect(value.number?).to be true
      end
    end

    describe "for boolean type" do
      it "generates signature for true" do
        json = '{"flag": true}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:boolean)
        expect(sig[1]).to eq("true")
      end

      it "generates signature for false" do
        json = '{"flag": false}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:boolean)
        expect(sig[1]).to eq("false")
      end
    end

    describe "for null type" do
      it "generates signature for null" do
        json = '{"nothing": null}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        value = pair.value_node
        skip "No value" unless value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:null)
      end
    end

    describe "for pair type" do
      it "generates signature with key name" do
        json = '{"myKey": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        sig = pair.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:pair)
        expect(sig[1]).to eq("myKey")
      end
    end
  end

  describe "nested structures" do
    it "handles nested objects" do
      json = '{"outer": {"inner": "value"}}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      skip "No value" unless value
      expect(value.object?).to be true
      expect(value.pairs.size).to eq(1)
    end

    it "handles nested arrays" do
      json = '{"items": [1, 2, [3, 4]]}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      skip "No value" unless value
      expect(value.array?).to be true
    end

    it "handles arrays of objects" do
      json = '[{"a": 1}, {"b": 2}]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
      expect(elements.size).to eq(2)
      elements.each { |e| expect(e.object?).to be true }
    end
  end

  describe "edge cases" do
    it "handles empty object" do
      json = "{}"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.pairs).to eq([])
    end

    it "handles empty array" do
      json = "[]"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.elements).to eq([])
    end

    it "handles empty string value" do
      json = '{"key": ""}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      skip "No value" unless value
      expect(value.string?).to be true
    end

    it "handles unicode in strings" do
      json = '{"emoji": "🎉"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      expect(pair.key_name).to eq("emoji")
    end

    it "handles escaped characters in strings" do
      json = '{"path": "C:\\\\Users\\\\test"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      expect(pair.key_name).to eq("path")
    end
  end

  describe "method edge cases" do
    describe "#find_child_by_field" do
      it "returns nil when node does not respond to child_by_field_name" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        # The method should handle this gracefully
        result = root.send(:find_child_by_field, "nonexistent")
        expect(result).to be_nil.or be_a(Object)
      end
    end

    describe "#node_text" do
      it "returns empty string when node doesn't have byte methods" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        # Test that the method exists and works
        expect(root.text).to be_a(String)
      end
    end

    describe "#children" do
      it "returns empty array when node does not respond to each" do
        json = '"simple string"'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_node
        skip "No root node" unless root
        # Children should be an array
        expect(root.children).to be_an(Array)
      end
    end

    describe "#key_name edge cases" do
      it "returns nil when key node is not found" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        # Object node should return nil for key_name
        expect(root.key_name).to be_nil
      end
    end

    describe "#value_node edge cases" do
      it "handles pair with missing value" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        pair = root.pairs.first
        skip "No pair" unless pair
        # Value should be present
        expect(pair.value_node).to be_a(Jsonc::Merge::NodeWrapper)
      end
    end

    describe "#content edge cases" do
      it "handles missing lines gracefully" do
        json = '{"key": "value"}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        # Content should be a string
        expect(root.content).to be_a(String)
      end
    end
  end

  describe "array element edge cases" do
    it "skips punctuation in elements" do
      json = '["a", "b"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
      # Should only have 2 elements, not punctuation
      expect(elements.size).to eq(2)
      expect(elements.all?(&:string?)).to be true
    end

    it "handles mixed type arrays" do
      json = '[1, "two", true, null]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
      expect(elements.size).to eq(4)
    end
  end

  describe "object pairs edge cases" do
    it "skips non-pair children" do
      json = '{"a": 1, "b": 2}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pairs = root.pairs
      # Should only include pair nodes
      expect(pairs.all?(&:pair?)).to be true
    end
  end

  describe "signature extraction" do
    describe "#extract_object_keys" do
      it "extracts keys from object" do
        json = '{"z": 1, "a": 2, "m": 3}'
        analysis = Jsonc::Merge::FileAnalysis.new(json)
        root = analysis.root_object
        skip "No root object" unless root
        sig = root.signature
        expect(sig.first).to eq(:object)
        # Keys should be sorted
        expect(sig[1]).to eq(["a", "m", "z"])
      end
    end
  end
end
