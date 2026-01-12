# frozen_string_literal: true

# Load shared dependency tags from tree_haver and ast-merge
#
# This file follows the standard spec/support/ convention. The actual
# implementation is in tree_haver so it can be shared across all gems
# in the TreeHaver/ast-merge family.
#
# For debugging, use TREE_HAVER_DEBUG=true which prints dependency
# availability in a way that respects backend isolation (FFI vs MRI).
#
# @see TreeHaver::RSpec::DependencyTags
# @see Ast::Merge::RSpec (shared examples for DebugLogger, FreezeNodeBase, MergeResultBase)

require "tree_haver/rspec"
require "ast/merge/rspec"

# Alias for convenience in existing specs
JsoncMergeDependencies = TreeHaver::RSpec::DependencyTags
