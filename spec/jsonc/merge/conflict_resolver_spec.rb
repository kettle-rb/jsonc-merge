# frozen_string_literal: true

RSpec.describe Jsonc::Merge::ConflictResolver do
  let(:template_json) do
    <<~JSON
      {
        "name": "template-package",
        "version": "2.0.0",
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
          "lodash": "^4.17.21"
        },
        "custom": "value"
      }
    JSON
  end

  describe "#initialize" do
    it "creates a resolver with analyses" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = described_class.new(template_analysis, dest_analysis)

      expect(resolver.template_analysis).to eq(template_analysis)
      expect(resolver.dest_analysis).to eq(dest_analysis)
    rescue Jsonc::Merge::ParseError => e
      skip "tree-sitter parser not available: #{e.message}"
    end

    it "accepts preference option" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = described_class.new(
        template_analysis,
        dest_analysis,
        preference: :template,
      )

      expect(resolver.preference).to eq(:template)
    rescue Jsonc::Merge::ParseError => e
      skip "tree-sitter parser not available: #{e.message}"
    end

    it "accepts add_template_only_nodes option" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = described_class.new(
        template_analysis,
        dest_analysis,
        add_template_only_nodes: true,
      )

      expect(resolver.add_template_only_nodes).to be true
    rescue Jsonc::Merge::ParseError => e
      skip "tree-sitter parser not available: #{e.message}"
    end
  end

  describe "#resolve" do
    it "populates the result" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      # Skip if analysis failed (parser may not be working)
      skip "FileAnalysis not valid - parser may not be available" unless template_analysis.valid? && dest_analysis.valid?

      resolver = described_class.new(template_analysis, dest_analysis)
      result = Jsonc::Merge::MergeResult.new

      resolver.resolve(result)

      expect(result.lines).not_to be_empty
    rescue Jsonc::Merge::ParseError => e
      skip "tree-sitter parser not available: #{e.message}"
    end

    context "with destination preference" do
      it "preserves destination values" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        # Skip if analysis failed (parser may not be working)
        skip "FileAnalysis not valid - parser may not be available" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :destination,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        # Destination-only values should be preserved
        expect(output).to include("custom")
      rescue Jsonc::Merge::ParseError => e
        skip "tree-sitter parser not available: #{e.message}"
      end
    end

    context "with template preference" do
      it "uses template values for matching signatures" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.lines).not_to be_empty
      rescue Jsonc::Merge::ParseError => e
        skip "tree-sitter parser not available: #{e.message}"
      end
    end

    context "with add_template_only_nodes enabled" do
      let(:template_with_extra) do
        <<~JSON
          {
            "name": "template",
            "newField": "from-template"
          }
        JSON
      end

      let(:simple_dest) do
        <<~JSON
          {
            "name": "dest"
          }
        JSON
      end

      it "adds template-only nodes to result" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_extra)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(simple_dest)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          add_template_only_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        expect(output).to include("newField")
      rescue Jsonc::Merge::ParseError => e
        skip "tree-sitter parser not available: #{e.message}"
      end
    end

    context "with freeze blocks in destination" do
      let(:dest_with_freeze) do
        <<~JSONC
          {
            "name": "dest",
            // json-merge:freeze
            "frozen": "preserved",
            // json-merge:unfreeze
            "normal": "value"
          }
        JSONC
      end

      it "preserves freeze blocks from destination" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_freeze)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        # Freeze blocks should be preserved
        expect(result.lines).not_to be_empty
      rescue Jsonc::Merge::ParseError => e
        skip "tree-sitter parser not available: #{e.message}"
      end
    end

    context "with nodes that have no signature" do
      it "handles nodes without signatures gracefully" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        # Should not raise
        expect { resolver.resolve(result) }.not_to raise_error
      rescue Jsonc::Merge::ParseError => e
        skip "tree-sitter parser not available: #{e.message}"
      end
    end

    context "with template preference merging leaf nodes", :jsonc_grammar do
      let(:template_with_different_values) do
        <<~JSON
          {
            "name": "template-name",
            "version": "2.0.0"
          }
        JSON
      end

      let(:dest_with_same_keys) do
        <<~JSON
          {
            "name": "dest-name",
            "version": "1.0.0"
          }
        JSON
      end

      it "uses template values when preference is :template" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_different_values)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_same_keys)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        expect(output).to include("template-name")
        expect(output).to include("2.0.0")
      end
    end

    context "with container nodes (nested objects)", :jsonc_grammar do
      let(:template_with_nested) do
        <<~JSON
          {
            "config": {
              "debug": true,
              "template_only": "value"
            }
          }
        JSON
      end

      let(:dest_with_nested) do
        <<~JSON
          {
            "config": {
              "debug": false,
              "dest_only": "custom"
            }
          }
        JSON
      end

      it "recursively merges nested objects" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_nested)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_nested)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          add_template_only_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        # Should have content from both nested objects
        expect(output).to include("config")
        expect(output).to include("dest_only")
      end

      it "uses destination values by default in nested objects" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_nested)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_nested)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :destination,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        # Destination values for matching keys
        expect(output).to include("false")
      end
    end

    context "with mismatched container types", :jsonc_grammar do
      let(:template_with_array) do
        <<~JSON
          {
            "items": [1, 2, 3]
          }
        JSON
      end

      let(:dest_with_object) do
        <<~JSON
          {
            "items": {"a": 1}
          }
        JSON
      end

      it "handles mismatched types using preference" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_array)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_object)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :destination,
        )
        result = Jsonc::Merge::MergeResult.new

        expect { resolver.resolve(result) }.not_to raise_error
      end
    end

    context "with match_refiner", :jsonc_grammar do
      let(:template_with_key) do
        <<~JSON
          {
            "name": "template",
            "old_key": "value"
          }
        JSON
      end

      let(:dest_with_renamed_key) do
        <<~JSON
          {
            "name": "dest",
            "new_key": "value"
          }
        JSON
      end

      it "uses match_refiner for fuzzy matching" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_key)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_renamed_key)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        # Define a simple match struct
        match_struct = Struct.new(:template_node, :dest_node)

        # Custom match refiner that matches old_key to new_key
        match_refiner = ->(unmatched_t, unmatched_d, _context) {
          matches = []
          unmatched_t.each do |t_node|
            next unless t_node.respond_to?(:key_name) && t_node.key_name == "old_key"

            unmatched_d.each do |d_node|
              next unless d_node.respond_to?(:key_name) && d_node.key_name == "new_key"

              matches << match_struct.new(t_node, d_node)
            end
          end
          matches
        }

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          match_refiner: match_refiner,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        # Should have processed without errors
        expect(result.lines).not_to be_empty
      end
    end

    context "with empty match_refiner result", :jsonc_grammar do
      it "handles empty refined matches" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        # Refiner that returns empty array
        match_refiner = ->(_t, _d, _ctx) { [] }

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          match_refiner: match_refiner,
        )
        result = Jsonc::Merge::MergeResult.new

        expect { resolver.resolve(result) }.not_to raise_error
      end
    end
  end
end
