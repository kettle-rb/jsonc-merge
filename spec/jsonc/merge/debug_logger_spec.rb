# frozen_string_literal: true

require "spec_helper"

RSpec.describe Jsonc::Merge::DebugLogger do
  # Use the shared examples to validate base DebugLogger integration
  it_behaves_like "Ast::Merge::DebugLogger" do
    let(:described_logger) { described_class }
    let(:env_var_name) { "JSONC_MERGE_DEBUG" }
    let(:log_prefix) { "[Jsonc::Merge]" }
  end

  describe "JSON-specific functionality" do
    describe ".time" do
      it "returns the block result" do
        result = described_class.time("test") { 42 }
        expect(result).to eq(42)
      end

      context "when enabled" do
        it "outputs timing information" do
          stub_env("JSONC_MERGE_DEBUG" => "1")
          expect { described_class.time("test operation") { sleep(0.001) } }.to output(/Completed: test operation.*real_ms/).to_stderr
        end
      end
    end

    describe ".log_node" do
      context "when enabled" do
        it "logs FreezeNode info" do
          stub_env("JSONC_MERGE_DEBUG" => "1")
          lines = [
            "// json-merge:freeze",
            '"secret": "value"',
            "// json-merge:unfreeze",
          ]
          freeze_node = Jsonc::Merge::FreezeNode.new(
            start_line: 1,
            end_line: 3,
            lines: lines,
            start_marker: "// json-merge:freeze",
            end_marker: "// json-merge:unfreeze",
          )

          expect {
            described_class.log_node(freeze_node, label: "TestFreeze")
          }.to output(/FreezeNode/).to_stderr
        end

        it "logs NodeWrapper info" do
          stub_env("JSONC_MERGE_DEBUG" => "1")
          json = '{"key": "value"}'
          analysis = Jsonc::Merge::FileAnalysis.new(json)
          node = analysis.nodes.first

          if node.is_a?(Jsonc::Merge::NodeWrapper)
            expect {
              described_class.log_node(node, label: "TestWrapper")
            }.to output(/TestWrapper/).to_stderr
          end
        end

        it "logs unknown node type info using extract_node_info" do
          stub_env("JSONC_MERGE_DEBUG" => "1")
          unknown_node = Object.new

          expect {
            described_class.log_node(unknown_node, label: "TestUnknown")
          }.to output(/TestUnknown/).to_stderr
        end
      end

      context "when disabled" do
        it "does not output anything" do
          # Don't stub JSONC_MERGE_DEBUG - it defaults to disabled
          unknown_node = Object.new

          expect {
            described_class.log_node(unknown_node, label: "Test")
          }.not_to output.to_stderr
        end
      end
    end
  end
end
