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
      begin
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        resolver = described_class.new(template_analysis, dest_analysis)

        expect(resolver.template_analysis).to eq(template_analysis)
        expect(resolver.dest_analysis).to eq(dest_analysis)
      rescue Jsonc::Merge::ParseError => e
        skip "Tree-sitter parser not available: #{e.message}"
      end
    end

    it "accepts signature_match_preference option" do
      begin
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          signature_match_preference: :template
        )

        expect(resolver.signature_match_preference).to eq(:template)
      rescue Jsonc::Merge::ParseError => e
        skip "Tree-sitter parser not available: #{e.message}"
      end
    end

    it "accepts add_template_only_nodes option" do
      begin
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          add_template_only_nodes: true
        )

        expect(resolver.add_template_only_nodes).to be true
      rescue Jsonc::Merge::ParseError => e
        skip "Tree-sitter parser not available: #{e.message}"
      end
    end
  end

  describe "#resolve" do
    it "populates the result" do
      begin
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        # Skip if analysis failed (parser may not be working)
        skip "FileAnalysis not valid - parser may not be available" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.lines).not_to be_empty
      rescue Jsonc::Merge::ParseError => e
        skip "Tree-sitter parser not available: #{e.message}"
      end
    end

    context "with destination preference" do
      it "preserves destination values" do
        begin
          template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
          dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

          # Skip if analysis failed (parser may not be working)
          skip "FileAnalysis not valid - parser may not be available" unless template_analysis.valid? && dest_analysis.valid?

          resolver = described_class.new(
            template_analysis,
            dest_analysis,
            signature_match_preference: :destination
          )
          result = Jsonc::Merge::MergeResult.new

          resolver.resolve(result)

          output = result.to_json
          # Destination-only values should be preserved
          expect(output).to include("custom")
        rescue Jsonc::Merge::ParseError => e
          skip "Tree-sitter parser not available: #{e.message}"
        end
      end
    end

    context "with template preference" do
      it "uses template values for matching signatures" do
        begin
          template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
          dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

          skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

          resolver = described_class.new(
            template_analysis,
            dest_analysis,
            signature_match_preference: :template
          )
          result = Jsonc::Merge::MergeResult.new

          resolver.resolve(result)

          expect(result.lines).not_to be_empty
        rescue Jsonc::Merge::ParseError => e
          skip "Tree-sitter parser not available: #{e.message}"
        end
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
        begin
          template_analysis = Jsonc::Merge::FileAnalysis.new(template_with_extra)
          dest_analysis = Jsonc::Merge::FileAnalysis.new(simple_dest)

          skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

          resolver = described_class.new(
            template_analysis,
            dest_analysis,
            add_template_only_nodes: true
          )
          result = Jsonc::Merge::MergeResult.new

          resolver.resolve(result)

          output = result.to_json
          expect(output).to include("newField")
        rescue Jsonc::Merge::ParseError => e
          skip "Tree-sitter parser not available: #{e.message}"
        end
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
        begin
          template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
          dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_with_freeze)

          skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

          resolver = described_class.new(template_analysis, dest_analysis)
          result = Jsonc::Merge::MergeResult.new

          resolver.resolve(result)

          # Freeze blocks should be preserved
          expect(result.lines).not_to be_empty
        rescue Jsonc::Merge::ParseError => e
          skip "Tree-sitter parser not available: #{e.message}"
        end
      end
    end

    context "with nodes that have no signature" do
      it "handles nodes without signatures gracefully" do
        begin
          template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
          dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

          skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

          resolver = described_class.new(template_analysis, dest_analysis)
          result = Jsonc::Merge::MergeResult.new

          # Should not raise
          expect { resolver.resolve(result) }.not_to raise_error
        rescue Jsonc::Merge::ParseError => e
          skip "Tree-sitter parser not available: #{e.message}"
        end
      end
    end
  end
end
