# frozen_string_literal: true

require "spec_helper"

# FileAnalysis specs with explicit backend testing
#
# This spec file tests FileAnalysis behavior across all available tree-sitter backends:
# - :mri (via ruby_tree_sitter gem, tagged :mri_backend)
# - :ffi (via FFI bindings, tagged :ffi_backend)
# - :rust (via tree_stump gem, tagged :rust_backend)
# - :java (via jtreesitter, tagged :java_backend)
#
# We define shared examples that are parameterized, then include them in
# backend-specific contexts that use TreeHaver.with_backend to explicitly
# select the backend under test.

RSpec.describe Jsonc::Merge::FileAnalysis do
  describe "FileAnalyzable contract", :jsonc_grammar do
    it_behaves_like "Ast::Merge::FileAnalyzable" do
      let(:file_analysis_class) { described_class }
      let(:freeze_node_class) { Json::Merge::FreezeNode }
      let(:sample_source) { "{\n  \"name\": \"value\" // comment\n}\n" }
      let(:sample_source_with_freeze) do
        <<~JSON
          {
            // json-merge:freeze
            "locked": true,
            // json-merge:unfreeze
            "open": false
          }
        JSON
      end
      let(:build_file_analysis) do
        ->(source, **opts) { described_class.new(source, **opts) }
      end

      let(:analysis_expected_feature_profile) do
        {
          owner_selector: :line_bound_statements,
          match_key: :signature,
          read_strategy: :source_augmented_portable_write,
          attachment_strategy: :augmenter_preferred_tracker_layout,
          comment_style: :c_style_line,
          render_family: :json_object_pairs,
          capabilities: {layout_aware: true, logical_owner: false},
          logical_owners: {},
          repair_policies: [],
          surfaces: [],
          delegation_policies: [],
        }
      end
    end
  end

  # ============================================================
  # :auto backend tests (uses whatever is available)
  # This tests the default behavior most users will experience
  # ============================================================

  context "with :auto backend", :jsonc_grammar do
    it_behaves_like "valid JSON parsing", expected_backend: :auto
    it_behaves_like "invalid JSON detection"
    it_behaves_like "freeze block detection"
    it_behaves_like "custom freeze token"
    it_behaves_like "root node access"
    it_behaves_like "root pairs extraction"
    it_behaves_like "line access"
    it_behaves_like "signature generation"
    it_behaves_like "custom signature generator"
    it_behaves_like "fallthrough_node? behavior"
    it_behaves_like "comment tracker"
    it_behaves_like "shared comment capability"
    it_behaves_like "shared layout compliance"
    it_behaves_like "parser path handling"
    it_behaves_like "edge cases"
    it_behaves_like "freeze block helpers"
  end

  # ============================================================
  # Backend-aware tests - MRI/ruby_tree_sitter
  # ============================================================

  context "with MRI backend", :jsonc_grammar, :mri_backend do
    around do |example|
      TreeHaver.with_backend(:mri) do
        example.run
      end
    end

    it_behaves_like "valid JSON parsing", expected_backend: :mri
    it_behaves_like "invalid JSON detection"
    it_behaves_like "freeze block detection"
    it_behaves_like "custom freeze token"
    it_behaves_like "root node access"
    it_behaves_like "root pairs extraction"
    it_behaves_like "line access"
    it_behaves_like "signature generation"
    it_behaves_like "custom signature generator"
    it_behaves_like "fallthrough_node? behavior"
    it_behaves_like "comment tracker"
    it_behaves_like "shared comment capability"
    it_behaves_like "shared layout compliance"
    it_behaves_like "parser path handling"
    it_behaves_like "edge cases"
    it_behaves_like "freeze block helpers"
  end

  # ============================================================
  # Backend-aware tests - FFI
  # ============================================================

  context "with FFI backend", :ffi_backend, :jsonc_grammar do
    around do |example|
      TreeHaver.with_backend(:ffi) do
        example.run
      end
    end

    it_behaves_like "valid JSON parsing", expected_backend: :ffi
    it_behaves_like "invalid JSON detection"
    it_behaves_like "freeze block detection"
    it_behaves_like "custom freeze token"
    it_behaves_like "root node access"
    it_behaves_like "root pairs extraction"
    it_behaves_like "line access"
    it_behaves_like "signature generation"
    it_behaves_like "custom signature generator"
    it_behaves_like "fallthrough_node? behavior"
    it_behaves_like "comment tracker"
    it_behaves_like "shared comment capability"
    it_behaves_like "shared layout compliance"
    it_behaves_like "parser path handling"
    it_behaves_like "edge cases"
    it_behaves_like "freeze block helpers"
  end

  # ============================================================
  # Backend-aware tests - Rust/tree_stump
  # ============================================================

  context "with Rust backend", :jsonc_grammar, :rust_backend do
    around do |example|
      TreeHaver.with_backend(:rust) do
        example.run
      end
    end

    it_behaves_like "valid JSON parsing", expected_backend: :rust
    it_behaves_like "invalid JSON detection"
    it_behaves_like "freeze block detection"
    it_behaves_like "custom freeze token"
    it_behaves_like "root node access"
    it_behaves_like "root pairs extraction"
    it_behaves_like "line access"
    it_behaves_like "signature generation"
    it_behaves_like "custom signature generator"
    it_behaves_like "fallthrough_node? behavior"
    it_behaves_like "comment tracker"
    it_behaves_like "shared comment capability"
    it_behaves_like "shared layout compliance"
    it_behaves_like "parser path handling"
    it_behaves_like "edge cases"
    it_behaves_like "freeze block helpers"
  end

  # ============================================================
  # Backend-aware tests - Java/jtreesitter
  # ============================================================

  context "with Java backend", :java_backend, :jsonc_grammar do
    around do |example|
      TreeHaver.with_backend(:java) do
        example.run
      end
    end

    it_behaves_like "valid JSON parsing", expected_backend: :java
    it_behaves_like "invalid JSON detection"
    it_behaves_like "freeze block detection"
    it_behaves_like "custom freeze token"
    it_behaves_like "root node access"
    it_behaves_like "root pairs extraction"
    it_behaves_like "line access"
    it_behaves_like "signature generation"
    it_behaves_like "custom signature generator"
    it_behaves_like "fallthrough_node? behavior"
    it_behaves_like "comment tracker"
    it_behaves_like "shared layout compliance"
    it_behaves_like "parser path handling"
    it_behaves_like "edge cases"
    it_behaves_like "freeze block helpers"
  end
end
