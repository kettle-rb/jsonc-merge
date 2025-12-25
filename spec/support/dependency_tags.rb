# frozen_string_literal: true

# Dependency detection helpers for conditional test execution in jsonc-merge
#
# This module detects whether the tree-sitter jsonc grammar is available
# and configures RSpec to skip tests that require unavailable dependencies.
#
# Usage in specs:
#   it "requires tree-sitter-jsonc", :tree_sitter_jsonc do
#     # This test only runs when tree-sitter-jsonc is available
#   end

module JsoncMergeDependencies
  class << self
    # Check if tree-sitter-jsonc grammar is available AND working via TreeHaver
    # This checks that parsing actually works, not just that a grammar file exists
    def tree_sitter_jsonc_available?
      return @tree_sitter_jsonc_available if defined?(@tree_sitter_jsonc_available)
      @tree_sitter_jsonc_available = begin
        # TreeHaver handles grammar discovery and raises NotAvailable if not found
        parser = TreeHaver.parser_for(:jsonc)
        result = parser.parse('{"key": "value" /* comment */}')
        !result.nil? && result.root_node && !result.root_node.has_error?
      rescue TreeHaver::NotAvailable
        false
      end
    end

    # Check if running on JRuby
    def jruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "jruby"
    end

    # Check if running on MRI (CRuby)
    def mri?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby"
    end

    # Get a summary of available dependencies (for debugging)
    def summary
      {
        tree_sitter_jsonc: tree_sitter_jsonc_available?,
        ruby_engine: RUBY_ENGINE,
        jruby: jruby?,
        mri: mri?,
      }
    end
  end
end

RSpec.configure do |config|
  # Define exclusion filters for optional dependencies
  # Tests tagged with these will be skipped when the dependency is not available

  config.before(:suite) do
    # Print dependency summary if JSONC_MERGE_DEBUG is set
    if ENV["JSONC_MERGE_DEBUG"]
      puts "\n=== Jsonc::Merge Test Dependencies ==="
      JsoncMergeDependencies.summary.each do |dep, available|
        status = case available
        when true then "✓ available"
        when false then "✗ not available"
        else available.to_s
        end
        puts "  #{dep}: #{status}"
      end
      puts "======================================\n"
    end
  end

  # ============================================================
  # Positive tags: run when dependency IS available
  # ============================================================

  # Skip tests tagged :tree_sitter_jsonc when tree-sitter-jsonc grammar is not available
  config.filter_run_excluding tree_sitter_jsonc: true unless JsoncMergeDependencies.tree_sitter_jsonc_available?

  # Skip tests tagged :jruby when not running on JRuby
  config.filter_run_excluding jruby: true unless JsoncMergeDependencies.jruby?

  # ============================================================
  # Negated tags: run when dependency is NOT available
  # ============================================================

  # Skip tests tagged :not_tree_sitter_jsonc when tree-sitter-jsonc IS available
  config.filter_run_excluding not_tree_sitter_jsonc: true if JsoncMergeDependencies.tree_sitter_jsonc_available?

  # Skip tests tagged :not_jruby when running on JRuby
  config.filter_run_excluding not_jruby: true if JsoncMergeDependencies.jruby?
end

