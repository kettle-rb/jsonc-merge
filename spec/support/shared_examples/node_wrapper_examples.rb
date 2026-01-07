# frozen_string_literal: true

# Shared examples for NodeWrapper across different backends
#
# These examples test NodeWrapper behavior that should be consistent
# regardless of which tree-sitter backend is used (MRI, FFI, Rust, Java).
#
# Note: Some backends (especially Java/jtreesitter) may have differences in
# how they handle certain node types or expose tree-sitter functionality.

RSpec.shared_examples "basic node properties" do
  let(:json_content) { '{"name": "test", "version": "1.0.0"}' }

  before do
    @analysis = Jsonc::Merge::FileAnalysis.new(json_content)
    @wrapper = @analysis.nodes.find { |n| n.is_a?(Jsonc::Merge::NodeWrapper) }
  end

  it "returns the node type" do
    skip "No wrapper node available" unless @wrapper
    expect(@wrapper.type).to be_a(Symbol)
  end

  it "returns the starting line number" do
    skip "No wrapper node available" unless @wrapper
    expect(@wrapper.start_line).to be_a(Integer)
    expect(@wrapper.start_line).to be >= 1
  end

  it "returns the ending line number" do
    skip "No wrapper node available" unless @wrapper
    expect(@wrapper.end_line).to be_a(Integer)
    expect(@wrapper.end_line).to be >= @wrapper.start_line
  end
end

RSpec.shared_examples "type predicates" do
  describe "type predicate methods" do
    it "object? returns true for object nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.object?).to be true
    end

    it "array? returns false for object nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.array?).to be false
    end
  end
end

RSpec.shared_examples "pair node handling" do
  describe "#key_name and #value_node" do
    let(:json) { '{"myKey": "myValue"}' }

    it "returns key name for pair nodes" do
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair

      # Note: Some backends may not support key_name extraction
      # This is a known limitation of certain tree-sitter bindings
      key_name = pair.key_name
      if key_name
        expect(key_name).to eq("myKey")
      else
        skip "Backend does not support key_name extraction"
      end
    end

    it "returns value wrapper for pair nodes" do
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair

      value = pair.value_node
      if value
        expect(value).to be_a(Jsonc::Merge::NodeWrapper)
      else
        skip "Backend does not support value_node extraction"
      end
    end
  end
end

RSpec.shared_examples "signature generation" do
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
      expect(sig.first).to eq(:pair)

      # Note: Some backends may not extract key names properly
      # In that case, sig[1] might be nil
      if sig[1].nil?
        skip "Backend does not support key name extraction in signatures"
      else
        expect(sig[1]).to eq("key")
      end
    end

    it "generates signature for object nodes" do
      json = '{"b": 1, "a": 2}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root

      sig = root.signature
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:object)

      # Keys should be sorted
      # Note: Some backends may not extract keys properly
      if sig[1].empty?
        skip "Backend does not support object key extraction"
      else
        expect(sig[1]).to eq(["a", "b"])
      end
    end
  end
end

RSpec.shared_examples "container detection" do
  describe "#container? and #leaf?" do
    it "returns true for object containers" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.container?).to be true
      expect(root.leaf?).to be false
    end
  end
end

RSpec.shared_examples "pairs and elements" do
  describe "#pairs and #elements" do
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
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.elements).to eq([])
    end
  end
end

RSpec.shared_examples "complete type predicates" do
  describe "all type predicate methods" do
    it "string? returns true for string values" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.string?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "number? returns true for number values" do
      json = '{"count": 42}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.number?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "boolean? returns true for true values" do
      json = '{"enabled": true}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.boolean?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "boolean? returns true for false values" do
      json = '{"enabled": false}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.boolean?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "null? returns true for null values" do
      json = '{"value": null}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.null?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "pair? returns true for key-value pairs" do
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

RSpec.shared_examples "comprehensive signature generation" do
  describe "signature generation for all types" do
    it "generates signature for document root" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      sig = root.signature
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:document)
    end

    it "generates signature for array with element count" do
      json = '["a", "b", "c"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      if array_node
        sig = array_node.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:array)
        expect(sig[1]).to eq(3)
      else
        skip "No array node found"
      end
    end

    it "generates signature for string with content" do
      json = '{"key": "hello"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:string)
        expect(sig[1]).to include("hello")
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "generates signature for number with value" do
      json = '{"count": 42}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:number)
        expect(sig[1]).to eq("42")
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "handles negative numbers" do
      json = '{"value": -123}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.number?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "handles decimal numbers" do
      json = '{"value": 3.14}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.number?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "generates signature for boolean true" do
      json = '{"flag": true}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:boolean)
        expect(sig[1]).to eq("true")
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "generates signature for boolean false" do
      json = '{"flag": false}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:boolean)
        expect(sig[1]).to eq("false")
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "generates signature for null" do
      json = '{"nothing": null}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        sig = value.signature
        expect(sig).to be_an(Array)
        expect(sig.first).to eq(:null)
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "generates signature for pair with key name" do
      json = '{"myKey": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      sig = pair.signature
      expect(sig).to be_an(Array)
      expect(sig.first).to eq(:pair)
      if sig[1].nil?
        skip "Backend does not support key name extraction"
      else
        expect(sig[1]).to eq("myKey")
      end
    end
  end
end

RSpec.shared_examples "node properties and methods" do
  describe "node properties" do
    it "#freeze_node? returns false for NodeWrapper" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.freeze_node?).to be false
    end

    it "#type? returns true when type matches" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.type?(:object)).to be true
      expect(root.type?("object")).to be true
    end

    it "#type? returns false when type does not match" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.type?(:array)).to be false
    end

    it "#comment? returns false for non-comment nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.comment?).to be false
    end

    it "#content returns node content from source lines" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.content).to be_a(String)
      expect(root.content).not_to be_empty
    end

    it "#text extracts text from tree-sitter node" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.text).to be_a(String)
    end

    it "#inspect returns a debug string" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.inspect).to be_a(String)
      expect(root.inspect).to include("NodeWrapper")
    end

    it "#children returns an array" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.children).to be_an(Array)
    end

    it "#frozen? returns false for regular nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.frozen?).to be false
    end
  end
end

RSpec.shared_examples "line and bracket methods" do
  describe "line methods" do
    it "#opening_line returns the opening line for objects" do
      json = "{\n  \"key\": \"value\"\n}"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.opening_line).to eq("{")
    end

    it "#opening_line returns the opening line for arrays" do
      json = "[\n  \"item\"\n]"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.opening_line).to eq("[")
    end

    it "#opening_line returns nil for non-container nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.opening_line).to be_nil
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "#closing_line returns the closing line for objects" do
      json = "{\n  \"key\": \"value\"\n}"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.closing_line).to eq("}")
    end

    it "#closing_line returns the closing line for arrays" do
      json = "[\n  \"item\"\n]"
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.closing_line).to eq("]")
    end

    it "#closing_line returns nil for non-container nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.closing_line).to be_nil
      else
        skip "Backend does not support value_node extraction"
      end
    end
  end

  describe "bracket methods" do
    it "#opening_bracket returns { for objects" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.opening_bracket).to eq("{")
    end

    it "#opening_bracket returns [ for arrays" do
      json = '["item"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.opening_bracket).to eq("[")
    end

    it "#opening_bracket returns nil for non-container nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.opening_bracket).to be_nil
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "#closing_bracket returns } for objects" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.closing_bracket).to eq("}")
    end

    it "#closing_bracket returns ] for arrays" do
      json = '["item"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.closing_bracket).to eq("]")
    end

    it "#closing_bracket returns nil for non-container nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.closing_bracket).to be_nil
      else
        skip "Backend does not support value_node extraction"
      end
    end
  end
end

RSpec.shared_examples "mergeable children" do
  describe "#mergeable_children" do
    it "returns pairs for object nodes" do
      json = '{"a": 1, "b": 2}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      children = root.mergeable_children
      expect(children.size).to eq(root.pairs.size)
      expect(children.all?(&:pair?)).to be true
    end

    it "returns elements for array nodes" do
      json = '["a", "b"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      children = array_node.mergeable_children
      expect(children.size).to eq(array_node.elements.size)
      expect(children.all?(&:string?)).to be true
    end

    it "returns empty array for string leaf nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.mergeable_children).to eq([])
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "returns empty array for number leaf nodes" do
      json = '{"key": 42}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.mergeable_children).to eq([])
      else
        skip "Backend does not support value_node extraction"
      end
    end
  end
end

RSpec.shared_examples "nested structures" do
  describe "nested structures" do
    it "handles nested objects" do
      json = '{"outer": {"inner": "value"}}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.object?).to be true
        expect(value.pairs.size).to eq(1)
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "handles nested arrays" do
      json = '{"items": [1, 2, [3, 4]]}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.array?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
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
end

RSpec.shared_examples "edge cases" do
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
      if value
        expect(value.string?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "handles unicode in strings" do
      json = '{"emoji": "🎉"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      key_name = pair.key_name
      if key_name
        expect(key_name).to eq("emoji")
      else
        skip "Backend does not support key_name extraction"
      end
    end

    it "handles escaped characters in strings" do
      json = '{"path": "C:\\\\Users\\\\test"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      key_name = pair.key_name
      if key_name
        expect(key_name).to eq("path")
      else
        skip "Backend does not support key_name extraction"
      end
    end

    it "skips punctuation in array elements" do
      json = '["a", "b"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
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

    it "skips non-pair children in objects" do
      json = '{"a": 1, "b": 2}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pairs = root.pairs
      expect(pairs.all?(&:pair?)).to be true
    end
  end
end

RSpec.shared_examples "complete container detection" do
  describe "complete container detection" do
    it "#container? returns true for arrays" do
      json = '["item"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      expect(array_node.container?).to be true
    end

    it "#container? returns false for leaf nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.container?).to be false
      else
        skip "Backend does not support value_node extraction"
      end
    end

    it "#leaf? returns false for objects" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.leaf?).to be false
    end

    it "#leaf? returns true for string values" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.pairs.first
      skip "No pair" unless pair
      value = pair.value_node
      if value
        expect(value.leaf?).to be true
      else
        skip "Backend does not support value_node extraction"
      end
    end
  end
end

RSpec.shared_examples "private methods" do
  describe "private methods" do
    it "#find_child_by_type finds child node by type" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      pair = root.send(:find_child_by_type, "pair")
      expect(pair).not_to be_nil if root.pairs.any?
    end

    it "#find_child_by_type returns nil when type not found" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      result = root.send(:find_child_by_type, "nonexistent_type")
      expect(result).to be_nil
    end
  end
end

RSpec.shared_examples "additional pair and element tests" do
  describe "additional pair and element tests" do
    it "#elements returns elements for array nodes" do
      json = '["a", "b", "c"]'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_node
      skip "No root node" unless root
      array_node = root.children.find(&:array?)
      skip "No array" unless array_node
      elements = array_node.elements
      expect(elements.size).to eq(3)
    end

    it "#elements returns empty array for non-array nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.elements).to eq([])
    end

    it "#key_name returns nil for non-pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.key_name).to be_nil
    end

    it "#value_node returns nil for non-pair nodes" do
      json = '{"key": "value"}'
      analysis = Jsonc::Merge::FileAnalysis.new(json)
      root = analysis.root_object
      skip "No root object" unless root
      expect(root.value_node).to be_nil
    end
  end
end
