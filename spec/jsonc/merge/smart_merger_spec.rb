# frozen_string_literal: true

# SmartMerger specs with explicit backend testing
#
# This spec file tests SmartMerger behavior across all available tree-sitter backends:
# - :mri (via ruby_tree_sitter gem, tagged :mri_backend)
# - :ffi (via FFI bindings, tagged :ffi_backend)
# - :rust (via tree_stump gem, tagged :rust_backend)
# - :java (via jtreesitter, tagged :java_backend)
#
# We define shared examples that are parameterized, then include them in
# backend-specific contexts.

RSpec.describe Jsonc::Merge::SmartMerger do
  # ============================================================
  # :auto backend tests (uses whatever is available)
  # ============================================================

  context "with :auto backend", :jsonc_grammar do
    it_behaves_like "basic initialization"
    it_behaves_like "basic merge operation"
    it_behaves_like "template preference"
    it_behaves_like "add template-only nodes"
    it_behaves_like "destination-only nodes preservation"
    it_behaves_like "invalid template detection"
    it_behaves_like "invalid destination detection"
    it_behaves_like "JSONC support"
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

    it_behaves_like "basic initialization"
    it_behaves_like "basic merge operation"
    it_behaves_like "template preference"
    it_behaves_like "add template-only nodes"
    it_behaves_like "destination-only nodes preservation"
    it_behaves_like "invalid template detection"
    it_behaves_like "invalid destination detection"
    it_behaves_like "JSONC support"
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

    it_behaves_like "basic initialization"
    it_behaves_like "basic merge operation"
    it_behaves_like "template preference"
    it_behaves_like "add template-only nodes"
    it_behaves_like "destination-only nodes preservation"
    it_behaves_like "invalid template detection"
    it_behaves_like "invalid destination detection"
    it_behaves_like "JSONC support"
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

    it_behaves_like "basic initialization"
    it_behaves_like "basic merge operation"
    it_behaves_like "template preference"
    it_behaves_like "add template-only nodes"
    it_behaves_like "destination-only nodes preservation"
    it_behaves_like "invalid template detection"
    it_behaves_like "invalid destination detection"
    it_behaves_like "JSONC support"
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

    it_behaves_like "basic initialization"
    it_behaves_like "basic merge operation"
    it_behaves_like "template preference"
    it_behaves_like "add template-only nodes"
    it_behaves_like "destination-only nodes preservation"
    it_behaves_like "invalid template detection"
    it_behaves_like "invalid destination detection"
    it_behaves_like "JSONC support"
  end
end
