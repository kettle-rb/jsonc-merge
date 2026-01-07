# frozen_string_literal: true

# Load shared dependency tags from tree_haver
#
# This file follows the standard spec/support/ convention. The actual
# implementation is in tree_haver so it can be shared across all gems
# in the TreeHaver/ast-merge family.
#
# @see TreeHaver::RSpec::DependencyTags

require "tree_haver/rspec"

# Alias for convenience in existing specs
JsoncMergeDependencies = TreeHaver::RSpec::DependencyTags

# Additional jsonc-merge specific configuration
RSpec.configure do |config|
  # Print dependency summary if JSONC_MERGE_DEBUG is set
  config.before(:suite) do
    if ENV["JSONC_MERGE_DEBUG"]
      puts "\n=== Jsonc::Merge Test Dependencies ==="
      TreeHaver::RSpec::DependencyTags.summary.each do |dep, available|
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
end
