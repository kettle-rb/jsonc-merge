# frozen_string_literal: true

require "spec_helper"
require "ast/merge/rspec/shared_examples"

RSpec.describe Jsonc::Merge::ConflictResolver do
  before do
    stub_const("AnalysisDouble", Struct.new(:lines, :comment_tracker) do
      def line_at(line_num)
        lines[line_num - 1]
      end

      def comment_region_for_range(range, kind:, full_line_only: false)
        comment_tracker.comment_region_for_range(range, kind: kind, full_line_only: full_line_only)
      end
    end)
  end

  it_behaves_like "Ast::Merge::ConflictResolverBase" do
    let(:conflict_resolver_class) { described_class }
    let(:strategy) { :batch }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          template_analysis,
          dest_analysis,
          preference: preference,
          add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
        )
      }
    end
    let(:build_mock_analysis) do
      -> { double("MockAnalysis") }
    end
  end

  it_behaves_like "Ast::Merge::ConflictResolverBase batch strategy" do
    let(:conflict_resolver_class) { described_class }
    let(:build_conflict_resolver) do
      ->(preference:, template_analysis:, dest_analysis:, **opts) {
        described_class.new(
          template_analysis,
          dest_analysis,
          preference: preference,
          add_template_only_nodes: opts.fetch(:add_template_only_nodes, false),
        )
      }
    end
    let(:build_mock_analysis) do
      -> { double("MockAnalysis") }
    end
  end

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

  describe "#initialize", :jsonc_grammar do
    it "creates a resolver with analyses" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = described_class.new(template_analysis, dest_analysis)

      expect(resolver.template_analysis).to eq(template_analysis)
      expect(resolver.dest_analysis).to eq(dest_analysis)
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
    end
  end

  describe "#resolve", :jsonc_grammar do
    it "populates the result" do
      template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
      dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

      resolver = described_class.new(template_analysis, dest_analysis)
      result = Jsonc::Merge::MergeResult.new

      resolver.resolve(result)

      expect(result.lines).not_to be_empty
    end

    context "with destination preference" do
      it "preserves destination values" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

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
      end
    end

    context "with template preference" do
      it "uses template values for matching signatures" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.lines).not_to be_empty
      end
    end

    context "with per-node-type preference" do
      it "uses template values for typed nodes and destination for others" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        node_typing = {
          "NodeWrapper" => lambda { |node|
            if node.pair? && node.key_name == "version"
              Ast::Merge::NodeTyping.with_merge_type(node, :version_key)
            else
              node
            end
          },
        }

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: {default: :destination, version_key: :template},
          node_typing: node_typing,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        expect(output).to include('"version": "2.0.0"')
        expect(output).to include('"name": "my-package"')
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

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          add_template_only_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        output = result.to_json
        expect(output).to include("newField")
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

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        # Freeze blocks should be preserved
        expect(result.lines).not_to be_empty
      end
    end

    context "with document boundary comments", :jsonc_grammar do
      it "replays destination prelude and postlude comments around a root object merge" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "name": "template"
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          // Destination header

          {
            "name": "destination"
          }

          // Destination footer
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          // Destination header

          {
            "name": "destination"
          }

          // Destination footer
        JSONC
      end

      it "preserves a comment-only destination when no structural nodes exist" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "name": "template"
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          // Destination docs

          // More destination docs
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          // Destination docs

          // More destination docs
        JSONC
      end

      it "preserves destination line comments on matched container opening lines" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "config": {
              "keep": 1
            }
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            // Config docs
            "config": { // destination inline
              "keep": 9
            }
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            // Config docs
            "config": { // destination inline
              "keep": 1
            }
          }
        JSONC
      end

      it "falls back to manual replay when matched leading comments include block comments" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "shared": "template"
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            /* Shared docs */
            "shared": "destination" // destination inline
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            /* Shared docs */
            "shared": "template" // destination inline
          }
        JSONC
      end

      it "replays multi-line leading block comments without collapsing them when a matched template-preferred pair wins" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "shared": "template"
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            /* Shared docs
             * spanning lines
             */
            "shared": "destination" // destination inline
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            /* Shared docs
             * spanning lines
             */
            "shared": "template" // destination inline
          }
        JSONC
      end
    end

    context "with nodes that have no signature" do
      it "handles nodes without signatures gracefully" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(template_json)
        dest_analysis = Jsonc::Merge::FileAnalysis.new(dest_json)

        resolver = described_class.new(template_analysis, dest_analysis)
        result = Jsonc::Merge::MergeResult.new

        # Should not raise
        expect { resolver.resolve(result) }.not_to raise_error
      end
    end

    context "with removed destination node comments", :jsonc_grammar do
      it "does not preserve separator blank lines for removed nodes without promoted comments" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "keep": 1,
            "remove": 2,

            "tail": 3
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          remove_template_missing_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "keep": 1,
            "tail": 3
          }
        JSONC
      end

      it "falls back to manual replay when removed leading comments include block comments" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "keep": 1,
            /* Remove docs */
            "remove": 2, // remove inline
            "tail": 3
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          remove_template_missing_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "keep": 1,
            /* Remove docs */
            // remove inline
            "tail": 3
          }
        JSONC
      end

      it "replays multi-line leading block comments for removed destination nodes without collapsing them" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "keep": 1,
            /* Remove docs
             * spanning lines
             */
            "remove": 2, // remove inline
            "tail": 3
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          remove_template_missing_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "keep": 1,
            /* Remove docs
             * spanning lines
             */
            // remove inline
            "tail": 3
          }
        JSONC
      end

      it "promotes inline comments from removed containers using the opening line" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "keep": 1,
            "remove": { // remove inline
              "nested": true
            },
            "tail": 3
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          remove_template_missing_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "keep": 1,
            // remove inline
            "tail": 3
          }
        JSONC
      end

      it "promotes inline block comments from removed containers using the opening line" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "keep": 1,
            "tail": 3
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "keep": 1,
            "remove": { /* remove inline */
              "nested": true
            },
            "tail": 3
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          remove_template_missing_nodes: true,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "keep": 1,
            /* remove inline */
            "tail": 3
          }
        JSONC
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

      it "compacts matched empty nested objects while keeping comment indentation aligned" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "features": {
              // comment from template
              "./apt-install": {}
            }
          }
        JSONC
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "features": {
              // comment from destination
              "./apt-install": {
              }
            }
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "features": {
              // comment from destination
              "./apt-install": {}
            }
          }
        JSONC
      end

      it "preserves trailing line comments inside matched nested objects with surrounding blank lines" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "config": {
              "keep": 1
            }
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "config": {
              "keep": 9,

              // trailing destination note
            }
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "config": {
              "keep": 1,

              // trailing destination note
            }
          }
        JSONC
      end

      it "falls back to raw trailing replay when matched nested objects end with block comments" do
        template_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSON)
          {
            "config": {
              "keep": 1
            }
          }
        JSON
        dest_analysis = Jsonc::Merge::FileAnalysis.new(<<~JSONC)
          {
            "config": {
              "keep": 9,
              /* trailing destination note */
            }
          }
        JSONC

        skip "FileAnalysis not valid" unless template_analysis.valid? && dest_analysis.valid?

        resolver = described_class.new(
          template_analysis,
          dest_analysis,
          preference: :template,
        )
        result = Jsonc::Merge::MergeResult.new

        resolver.resolve(result)

        expect(result.to_json).to eq(<<~JSONC)
          {
            "config": {
              "keep": 1,
              /* trailing destination note */
            }
          }
        JSONC
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

  describe "trailing container replay helpers" do
    let(:resolver) { described_class.new(double("TemplateAnalysis"), double("DestAnalysis")) }

    it "replays blank lines and full-line // comments in trailing container ranges through a shared region" do
      source = <<~JSONC
        {
          "config": {
            "keep": 9,

            // trailing destination note

          }
        }
      JSONC
      tracker = Jsonc::Merge::CommentTracker.new(source)
      analysis = AnalysisDouble.new(source.lines.map(&:chomp), tracker)
      child = Struct.new(:start_line, :end_line).new(3, 3)
      container_node = double(
        "ContainerNode",
        container?: true,
        start_line: 2,
        end_line: 7,
        mergeable_children: [child],
      )

      expect(analysis).to receive(:comment_region_for_range)
        .with(4..6, kind: :trailing, full_line_only: true)
        .and_call_original

      resolver.send(:emit_container_trailing_lines, container_node, analysis)

      expect(resolver.instance_variable_get(:@emitter).lines).to eq([
        "",
        "    // trailing destination note",
        "",
      ])
    end

    it "falls back to raw replay when trailing container ranges include block comments" do
      source = <<~JSONC
        {
          "config": {
            "keep": 9,
            /* trailing destination note */
          }
        }
      JSONC
      tracker = Jsonc::Merge::CommentTracker.new(source)
      analysis = AnalysisDouble.new(source.lines.map(&:chomp), tracker)
      child = Struct.new(:start_line, :end_line).new(3, 3)
      container_node = double(
        "ContainerNode",
        container?: true,
        start_line: 2,
        end_line: 5,
        mergeable_children: [child],
      )

      expect(analysis).not_to receive(:comment_region_for_range)

      resolver.send(:emit_container_trailing_lines, container_node, analysis)

      expect(resolver.instance_variable_get(:@emitter).lines).to eq([
        "    /* trailing destination note */",
      ])
    end
  end
end
