# frozen_string_literal: true

require "spec_helper"

# NodeWrapper specs with explicit backend testing
#
# This spec file tests NodeWrapper behavior across all available tree-sitter backends.
# Different backends may have varying levels of support for certain operations,
# especially around key/value node extraction in the Java backend.

RSpec.describe Jsonc::Merge::NodeWrapper do
  # ============================================================
  # :auto backend tests (uses whatever is available)
  # ============================================================

  context "with :auto backend", :jsonc_grammar do
    it_behaves_like "basic node properties"
    it_behaves_like "type predicates"
    it_behaves_like "complete type predicates"
    it_behaves_like "pair node handling"
    it_behaves_like "signature generation"
    it_behaves_like "comprehensive signature generation"
    it_behaves_like "node properties and methods"
    it_behaves_like "line and bracket methods"
    it_behaves_like "container detection"
    it_behaves_like "complete container detection"
    it_behaves_like "pairs and elements"
    it_behaves_like "additional pair and element tests"
    it_behaves_like "mergeable children"
    it_behaves_like "nested structures"
    it_behaves_like "edge cases"
    it_behaves_like "private methods"
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

    it_behaves_like "basic node properties"
    it_behaves_like "type predicates"
    it_behaves_like "complete type predicates"
    it_behaves_like "pair node handling"
    it_behaves_like "signature generation"
    it_behaves_like "comprehensive signature generation"
    it_behaves_like "node properties and methods"
    it_behaves_like "line and bracket methods"
    it_behaves_like "container detection"
    it_behaves_like "complete container detection"
    it_behaves_like "pairs and elements"
    it_behaves_like "additional pair and element tests"
    it_behaves_like "mergeable children"
    it_behaves_like "nested structures"
    it_behaves_like "edge cases"
    it_behaves_like "private methods"
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

    it_behaves_like "basic node properties"
    it_behaves_like "type predicates"
    it_behaves_like "complete type predicates"
    it_behaves_like "pair node handling"
    it_behaves_like "signature generation"
    it_behaves_like "comprehensive signature generation"
    it_behaves_like "node properties and methods"
    it_behaves_like "line and bracket methods"
    it_behaves_like "container detection"
    it_behaves_like "complete container detection"
    it_behaves_like "pairs and elements"
    it_behaves_like "additional pair and element tests"
    it_behaves_like "mergeable children"
    it_behaves_like "nested structures"
    it_behaves_like "edge cases"
    it_behaves_like "private methods"
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

    it_behaves_like "basic node properties"
    it_behaves_like "type predicates"
    it_behaves_like "complete type predicates"
    it_behaves_like "pair node handling"
    it_behaves_like "signature generation"
    it_behaves_like "comprehensive signature generation"
    it_behaves_like "node properties and methods"
    it_behaves_like "line and bracket methods"
    it_behaves_like "container detection"
    it_behaves_like "complete container detection"
    it_behaves_like "pairs and elements"
    it_behaves_like "additional pair and element tests"
    it_behaves_like "mergeable children"
    it_behaves_like "nested structures"
    it_behaves_like "edge cases"
    it_behaves_like "private methods"
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

    it_behaves_like "basic node properties"
    it_behaves_like "type predicates"
    it_behaves_like "complete type predicates"
    it_behaves_like "pair node handling"
    it_behaves_like "signature generation"
    it_behaves_like "comprehensive signature generation"
    it_behaves_like "node properties and methods"
    it_behaves_like "line and bracket methods"
    it_behaves_like "container detection"
    it_behaves_like "complete container detection"
    it_behaves_like "pairs and elements"
    it_behaves_like "additional pair and element tests"
    it_behaves_like "mergeable children"
    it_behaves_like "nested structures"
    it_behaves_like "edge cases"
    it_behaves_like "private methods"
  end
end
