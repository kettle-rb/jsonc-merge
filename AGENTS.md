# AGENTS.md - jsonc-merge Development Guide

## 🎯 Project Overview

`jsonc-merge` is a **format-specific implementation of the `*-merge` gem family** for JSONC (JSON with Comments) files. It provides intelligent JSONC file merging using AST analysis with tree-sitter JSONC parser.

**Core Philosophy**: Intelligent JSONC merging that preserves structure, comments, and formatting while applying updates from templates.

**Repository**: https://github.com/kettle-rb/jsonc-merge
**Current Version**: 1.0.1
**Required Ruby**: >= 3.2.0 (currently developed against Ruby 4.0.1)

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Not Visible

**CRITICAL**: AI agents using `run_in_terminal` almost never see the command output. The terminal tool sends commands to a persistent Copilot terminal, but output is frequently lost or invisible to the agent.

**Workaround**: Always redirect output to a file in the project's local `tmp/` directory, then read it back with `read_file`:

```bash
bundle exec rspec spec/some_spec.rb > tmp/test_output.txt 2>&1
```

**NEVER** use `/tmp` or other system directories — always use the project's own `tmp/` directory.

### direnv Requires Separate `cd` Command

**CRITICAL**: Never chain `cd` with other commands via `&&`. The `direnv` environment won't initialize until after all chained commands finish. Run `cd` alone first:

✅ **CORRECT**:
```bash
cd /home/pboling/src/kettle-rb/ast-merge/vendor/jsonc-merge
```
```bash
bundle exec rspec > tmp/test_output.txt 2>&1
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/ast-merge/vendor/jsonc-merge && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

Use `read_file`, `list_dir`, `grep_search`, `file_search` instead of terminal commands for gathering information. Only use terminal for running tests, installing dependencies, and git operations.

### grep_search Cannot Search Nested Git Projects

This project is a nested git project inside the `ast-merge` workspace. The `grep_search` tool **cannot** search inside it. Use `read_file` and `list_dir` instead.

### NEVER Pipe Test Commands Through head/tail

Always redirect to a file in `tmp/` instead of truncating output.

## 🏗️ Architecture: Format-Specific Implementation

### What jsonc-merge Provides

- **`Jsonc::Merge::SmartMerger`** – JSONC-specific SmartMerger implementation
- **`Jsonc::Merge::FileAnalysis`** – JSONC file analysis with object/array extraction
- **`Jsonc::Merge::NodeWrapper`** – Wrapper for JSONC AST nodes
- **`Jsonc::Merge::MergeResult`** – JSONC-specific merge result
- **`Jsonc::Merge::ConflictResolver`** – JSONC conflict resolution
- **`Jsonc::Merge::FreezeNode`** – JSONC freeze block support
- **`Jsonc::Merge::DebugLogger`** – JSONC-specific debug logging

### Key Dependencies

| Gem | Role |
|-----|------|
| `ast-merge` (~> 4.0) | Base classes and shared infrastructure |
| `tree_haver` (~> 5.0) | Unified parser adapter (tree-sitter) |
| `version_gem` (~> 1.1) | Version management |

### Parser Backend Support

jsonc-merge works with tree-sitter JSONC parser via TreeHaver:

| Backend | Parser | Platform | Notes |
|---------|--------|----------|-------|
| `:mri` | tree-sitter-jsonc | MRI only | Best performance, requires native library |
| `:rust` | tree-sitter-jsonc | MRI only | Rust implementation via tree_stump |
| `:ffi` | tree-sitter-jsonc | All platforms | FFI binding, works on JRuby/TruffleRuby |

## 📁 Project Structure

```
lib/jsonc/merge/
├── smart_merger.rb          # Main SmartMerger implementation
├── file_analysis.rb         # JSONC file analysis
├── node_wrapper.rb          # AST node wrapper
├── merge_result.rb          # Merge result object
├── conflict_resolver.rb     # Conflict resolution
├── freeze_node.rb           # Freeze block support
├── debug_logger.rb          # Debug logging
└── version.rb

spec/jsonc/merge/
├── smart_merger_spec.rb
├── file_analysis_spec.rb
├── node_wrapper_spec.rb
└── integration/
```

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
bundle exec rspec

# Single file (disable coverage threshold check)
K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/jsonc/merge/smart_merger_spec.rb

# Specific backend tests
bundle exec rspec --tag mri_backend
bundle exec rspec --tag rust_backend
bundle exec rspec --tag ffi_backend
```

### Coverage Reports

```bash
cd /home/pboling/src/kettle-rb/ast-merge/vendor/jsonc-merge
bin/rake coverage && bin/kettle-soup-cover -d
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API
- `merge` – Returns a **String** (the merged JSONC content)
- `merge_result` – Returns a **MergeResult** object
- `to_s` on MergeResult returns the merged content as a string

#### JSONC-Specific Features

**Comment Support**:
```jsonc
{
  // Line comment
  "key": "value",
  /* Block comment */
  "another": "value"
}
```

**Freeze Blocks**:
```jsonc
{
  "config": {
    // jsonc-merge:freeze
    "customValue": "don't override",
    "preserveThis": 42
    // jsonc-merge:unfreeze
  }
}
```

## 🧪 Testing Patterns

### TreeHaver Dependency Tags

**Available tags**:
- `:jsonc_grammar` – Requires JSONC grammar (any backend)
- `:mri_backend` – Requires tree-sitter MRI backend
- `:rust_backend` – Requires tree-sitter Rust backend
- `:ffi_backend` – Requires tree-sitter FFI backend
- `:jsonc_parsing` – Requires any JSONC parser

✅ **CORRECT**:
```ruby
RSpec.describe Jsonc::Merge::SmartMerger, :jsonc_grammar do
  # Skipped if no JSONC parser available
end
```

❌ **WRONG**:
```ruby
before do
  skip "Requires tree-sitter" unless tree_sitter_available?  # DO NOT DO THIS
end
```

## 💡 Key Insights

1. **JSONC = JSON + Comments**: Full comment support unlike plain JSON
2. **Comment preservation**: Comments are associated with nodes and preserved during merge
3. **Freeze blocks use `// jsonc-merge:freeze`**: Standard comment syntax
4. **Multi-backend support**: Works with MRI, Rust, and FFI backends
5. **Backend isolation is critical**: Always use `TreeHaver.with_backend`

## 🚫 Common Pitfalls

1. **NEVER mix FFI and MRI backends** – Use `TreeHaver.with_backend` for isolation
2. **NEVER use manual skip checks** – Use dependency tags (`:jsonc_grammar`, `:mri_backend`)
3. **Do NOT load vendor gems** – They are not part of this project; they do not exist in CI
4. **Use `tmp/` for temporary files** – Never use `/tmp` or other system directories

## 🔧 JSONC-Specific Notes

### Comment Types
```jsonc
// Single-line comment
/* Multi-line
   comment */
{
  "key": "value" // Trailing comment
}
```

### Merge Behavior
- **Objects**: Matched by key name; deep merging of nested objects
- **Arrays**: Can be merged or replaced based on preference
- **Comments**: Preserved and associated with their nodes
- **Freeze blocks**: Protect customizations from template updates
