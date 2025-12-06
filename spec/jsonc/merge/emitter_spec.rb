# frozen_string_literal: true

RSpec.describe Jsonc::Merge::Emitter do
  describe "#initialize" do
    it "creates an emitter with default indent size" do
      emitter = described_class.new
      expect(emitter.indent_size).to eq(2)
    end

    it "allows custom indent size" do
      emitter = described_class.new(indent_size: 4)
      expect(emitter.indent_size).to eq(4)
    end

    it "starts with empty lines" do
      emitter = described_class.new
      expect(emitter.lines).to eq([])
    end
  end

  describe "#emit_object_start" do
    it "emits opening brace" do
      emitter = described_class.new
      emitter.emit_object_start
      expect(emitter.lines).to include("{")
    end
  end

  describe "#emit_object_end" do
    it "emits closing brace" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_object_end
      expect(emitter.lines.last).to eq("}")
    end
  end

  describe "#emit_pair" do
    it "emits key-value pair" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("name", '"test"')
      expect(emitter.to_s).to include('"name"')
    end

    it "supports inline comments" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("key", '"value"', inline_comment: "a comment")
      expect(emitter.to_s).to include("// a comment")
    end
  end

  describe "#emit_comment" do
    it "emits a line comment" do
      emitter = described_class.new
      emitter.emit_comment("This is a comment")
      expect(emitter.lines.first).to include("//")
      expect(emitter.lines.first).to include("This is a comment")
    end
  end

  describe "#emit_block_comment" do
    it "emits a block comment" do
      emitter = described_class.new
      emitter.emit_block_comment("Block comment")
      expect(emitter.lines.first).to include("/*")
      expect(emitter.lines.first).to include("*/")
    end
  end

  describe "#emit_array_start" do
    it "emits opening bracket" do
      emitter = described_class.new
      emitter.emit_array_start
      expect(emitter.lines).to include("[")
    end

    it "supports key for object values" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_array_start("items")
      expect(emitter.to_s).to include('"items": [')
    end
  end

  describe "#emit_array_end" do
    it "emits closing bracket" do
      emitter = described_class.new
      emitter.emit_array_start
      emitter.emit_array_end
      expect(emitter.lines.last).to eq("]")
    end
  end

  describe "#emit_array_element" do
    it "emits array element" do
      emitter = described_class.new
      emitter.emit_array_start
      emitter.emit_array_element("123")
      expect(emitter.to_s).to include("123")
    end
  end

  describe "#to_s" do
    it "returns the emitted content as a string" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("key", '"value"')
      emitter.emit_object_end
      result = emitter.to_s
      expect(result).to be_a(String)
      expect(result).to include("{")
      expect(result).to include("}")
    end
  end

  describe "#to_json" do
    it "is aliased to to_s" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_object_end
      expect(emitter.to_json).to eq(emitter.to_s)
    end
  end

  describe "building a complete JSON object" do
    it "produces valid JSON structure" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("name", '"test-package"')
      emitter.emit_pair("version", '"1.0.0"')
      emitter.emit_object_end

      result = emitter.to_s
      expect(result).to include('"name"')
      expect(result).to include('"test-package"')
      expect(result).to include('"version"')
    end
  end

  describe "#clear" do
    it "clears the output" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("key", '"value"')
      emitter.clear
      expect(emitter.lines).to eq([])
    end

    it "resets indent level" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_object_start
      emitter.clear
      expect(emitter.indent_level).to eq(0)
    end
  end

  describe "#emit_comment with inline option" do
    it "appends inline comment to last line when inline: true" do
      emitter = described_class.new
      emitter.emit_raw_lines(['  "key": "value"'])
      emitter.emit_comment("trailing", inline: true)
      expect(emitter.lines.last).to include("// trailing")
    end

    it "does nothing when lines are empty and inline: true" do
      emitter = described_class.new
      emitter.emit_comment("orphan", inline: true)
      expect(emitter.lines).to be_empty
    end
  end

  describe "#emit_leading_comments" do
    it "emits line comments with indent" do
      emitter = described_class.new
      comments = [
        {text: "comment 1", indent: 2, block: false},
        {text: "comment 2", indent: 4, block: false},
      ]
      emitter.emit_leading_comments(comments)

      expect(emitter.lines[0]).to eq("  // comment 1")
      expect(emitter.lines[1]).to eq("    // comment 2")
    end

    it "emits block comments with indent" do
      emitter = described_class.new
      comments = [{text: "block", indent: 2, block: true}]
      emitter.emit_leading_comments(comments)
      expect(emitter.lines.first).to eq("  /* block */")
    end

    it "handles missing indent gracefully" do
      emitter = described_class.new
      comments = [{text: "no indent", block: false}]
      emitter.emit_leading_comments(comments)
      expect(emitter.lines.first).to eq("// no indent")
    end
  end

  describe "#emit_blank_line" do
    it "adds empty string to lines" do
      emitter = described_class.new
      emitter.emit_blank_line
      expect(emitter.lines).to eq([""])
    end
  end

  describe "comma handling (add_comma_if_needed)" do
    it "adds comma after pair when followed by another pair" do
      emitter = described_class.new
      emitter.emit_pair("first", '"1"')
      emitter.emit_pair("second", '"2"')
      expect(emitter.lines[0]).to end_with(",")
    end

    it "does not add comma after line ending with {" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("key", '"value"')
      expect(emitter.lines[0]).to eq("{")
    end

    it "does not add comma after line ending with [" do
      emitter = described_class.new
      emitter.emit_array_start
      emitter.emit_array_element("1")
      expect(emitter.lines[0]).to eq("[")
    end

    it "does not add comma when line already ends with comma" do
      emitter = described_class.new
      emitter.emit_raw_lines(['"key": "value",'])
      emitter.emit_pair("another", '"value"')
      expect(emitter.lines[0]).to eq('"key": "value",')
    end

    it "does not add comma to empty lines" do
      emitter = described_class.new
      emitter.emit_blank_line
      emitter.emit_pair("key", '"value"')
      expect(emitter.lines[0]).to eq("")
    end
  end

  describe "#to_json edge cases" do
    it "adds trailing newline when content exists" do
      emitter = described_class.new
      emitter.emit_raw_lines(["{"])
      expect(emitter.to_json).to end_with("\n")
    end

    it "returns empty string for no lines" do
      emitter = described_class.new
      expect(emitter.to_json).to eq("")
    end
  end

  describe "#emit_raw_lines" do
    it "adds multiple raw lines" do
      emitter = described_class.new
      emitter.emit_raw_lines(["line 1", "line 2", "line 3"])
      expect(emitter.lines.size).to eq(3)
    end

    it "handles empty array" do
      emitter = described_class.new
      emitter.emit_raw_lines([])
      expect(emitter.lines).to be_empty
    end

    it "adds a single raw line when given array with one element" do
      emitter = described_class.new
      emitter.emit_raw_lines(["raw content"])
      expect(emitter.lines).to include("raw content")
    end
  end

  describe "#indent_level" do
    it "tracks current indentation level" do
      emitter = described_class.new
      expect(emitter.indent_level).to eq(0)
    end

    it "increases after object start" do
      emitter = described_class.new
      emitter.emit_object_start
      expect(emitter.indent_level).to eq(1)
    end

    it "decreases after object end" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_object_end
      expect(emitter.indent_level).to eq(0)
    end
  end

  describe "nested structures" do
    it "handles nested objects" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_raw_lines(['  "outer": {'])
      emitter.emit_raw_lines(['    "inner": "value"'])
      emitter.emit_raw_lines(["  }"])
      emitter.emit_object_end

      result = emitter.to_s
      expect(result).to include("outer")
      expect(result).to include("inner")
    end

    it "handles arrays within objects" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_array_start("items")
      emitter.emit_array_element('"a"')
      emitter.emit_array_element('"b"')
      emitter.emit_array_end
      emitter.emit_object_end

      result = emitter.to_s
      expect(result).to include("items")
      expect(result).to include("[")
      expect(result).to include("]")
    end
  end

  describe "with different indent sizes" do
    it "supports custom indent size" do
      emitter = described_class.new(indent_size: 4)
      emitter.emit_object_start
      emitter.emit_pair("key", '"value"')
      emitter.emit_object_end

      result = emitter.to_s
      expect(result).to include("{")
      expect(emitter.indent_size).to eq(4)
    end
  end

  describe "#emit_pair edge cases" do
    it "handles nil value" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("nullable", "null")
      expect(emitter.to_s).to include('"nullable": null')
    end

    it "handles boolean values" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("flag", "true")
      emitter.emit_pair("other", "false")
      expect(emitter.to_s).to include('"flag": true')
      expect(emitter.to_s).to include('"other": false')
    end

    it "handles number values" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("count", "42")
      emitter.emit_pair("decimal", "3.14")
      expect(emitter.to_s).to include('"count": 42')
      expect(emitter.to_s).to include('"decimal": 3.14')
    end
  end

  describe "#emit_array_element edge cases" do
    it "adds inline comment to array element" do
      emitter = described_class.new
      emitter.emit_array_start
      emitter.emit_array_element('"value"', inline_comment: "a comment")
      expect(emitter.to_s).to include("// a comment")
    end
  end

  describe "indentation edge cases" do
    it "does not decrease indent below zero" do
      emitter = described_class.new
      emitter.emit_object_end  # Try to decrease from 0
      expect(emitter.indent_level).to eq(0)
    end

    it "decreases indent on array end" do
      emitter = described_class.new
      emitter.emit_array_start
      expect(emitter.indent_level).to eq(1)
      emitter.emit_array_end
      expect(emitter.indent_level).to eq(0)
    end
  end

  describe "comma handling edge cases" do
    it "adds comma between array elements" do
      emitter = described_class.new
      emitter.emit_array_start
      emitter.emit_array_element("1")
      emitter.emit_array_element("2")
      result = emitter.to_s
      expect(result).to include("1,")
    end

    it "does not add comma after closing brace" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_object_end
      # No comma should be added within the object
      expect(emitter.lines[0]).to eq("{")
    end
  end

  describe "#clear" do
    it "resets needs_comma flag" do
      emitter = described_class.new
      emitter.emit_pair("key", '"value"')
      emitter.clear
      # After clear, needs_comma should be false
      emitter.emit_object_start
      emitter.emit_pair("new", '"value"')
      # First pair should not have comma before it
      expect(emitter.lines[1]).not_to start_with(",")
    end
  end

  describe "complex JSON structures" do
    it "builds valid nested structure" do
      emitter = described_class.new
      emitter.emit_object_start
      emitter.emit_pair("name", '"test"')
      emitter.emit_array_start("items")
      emitter.emit_object_start
      emitter.emit_pair("id", "1")
      emitter.emit_object_end
      emitter.emit_array_end
      emitter.emit_object_end

      result = emitter.to_s
      expect(result).to include('"name": "test"')
      expect(result).to include('"items"')
      expect(result).to include('"id": 1')
    end
  end
end
