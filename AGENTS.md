# AGENTS.md - Development Guide

## 🎯 Project Overview

### Running Commands

Always make commands self-contained. Use `mise exec -C /home/pboling/src/kettle-rb/prism-merge -- ...` so the command gets the project environment in the same invocation.
If the command is complicated write a script in local tmp/ and then run the script.

This project is a **RubyGem** managed with the [kettle-rb](https://github.com/kettle-rb) toolchain.

**Minimum Supported Ruby**: See the gemspec `required_ruby_version` constraint.
**Local Development Ruby**: See `.tool-versions` for the version used in local development (typically the latest stable Ruby).

## ⚠️ AI Agent Terminal Limitations

### Terminal Output Is Available, but Each Command Is Isolated

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

✅ **CORRECT** — If you need shell syntax first, load the environment in the same command:

### Use `mise` for Project Environment

**CRITICAL**: The canonical project environment lives in `mise.toml`, with local overrides in `.env.local` loaded via `dotenvy`.

⚠️ **Watch for trust prompts**: After editing `mise.toml` or `.env.local`, `mise` may require trust to be refreshed before commands can load the project environment. Until that trust step is handled, commands can appear hung or produce no output, which can look like terminal access is broken.

**Recovery rule**: If a `mise exec` command goes silent or appears hung, assume `mise trust` is the first thing to check. Recover by running:

```bash
mise trust -C /home/pboling/src/kettle-rb/jsonc-merge
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec
```

```bash
mise trust -C /path/to/project
mise exec -C /path/to/project -- bundle exec rspec
```

Do this before spending time on unrelated debugging; in this workspace pattern, silent `mise` commands are usually a trust problem first.

```bash
mise trust -C /home/pboling/src/kettle-rb/jsonc-merge
```

✅ **CORRECT** — Run self-contained commands with `mise exec`:

```bash
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec
```

✅ **CORRECT**:
```bash
eval "$(mise env -C /home/pboling/src/kettle-rb/jsonc-merge -s bash)" && bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/jsonc-merge
bundle exec rspec
```

❌ **WRONG**:
```bash
cd /home/pboling/src/kettle-rb/jsonc-merge && bundle exec rspec
```

```bash
eval "$(mise env -C /path/to/project -s bash)" && bundle exec rspec
```

❌ **WRONG** — Do not rely on a previous command changing directories:

```bash
cd /path/to/project
bundle exec rspec
```

❌ **WRONG** — A chained `cd` does not give directory-change hooks time to update the environment:

```bash
cd /path/to/project && bundle exec rspec
```

### Prefer Internal Tools Over Terminal

### Environment Variable Helpers

```ruby
before do
  stub_env("MY_ENV_VAR" => "value")
end

before do
  hide_env("HOME", "USER")
end
```

### Dependency Tags

Use dependency tags to conditionally skip tests when optional dependencies are not available:

### Workspace layout

## 🏗️ Architecture

### Toolchain Dependencies

This gem is part of the **kettle-rb** ecosystem. Key development tools:

### NEVER Pipe Test Commands Through head/tail

When you do run tests, keep the full output visible so you can inspect failures completely.

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

| Tool | Purpose |
|------|---------|
| `kettle-dev` | Development dependency: Rake tasks, release tooling, CI helpers |
| `kettle-test` | Test infrastructure: RSpec helpers, stubbed_env, timecop |
| `kettle-jem` | Template management and gem scaffolding |

### Executables (from kettle-dev)

| Executable | Purpose |
|-----------|---------|
| `kettle-release` | Full gem release workflow |
| `kettle-pre-release` | Pre-release validation |
| `kettle-changelog` | Changelog generation |
| `kettle-dvcs` | DVCS (git) workflow automation |
| `kettle-commit-msg` | Commit message validation |
| `kettle-check-eof` | EOF newline validation |

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

```
lib/
├── <gem_namespace>/           # Main library code
│   └── version.rb             # Version constant (managed by kettle-release)
spec/
├── fixtures/                  # Test fixture files (NOT auto-loaded)
├── support/
│   ├── classes/               # Helper classes for specs
│   └── shared_contexts/       # Shared RSpec contexts
├── spec_helper.rb             # RSpec configuration (loaded by .rspec)
gemfiles/
├── modular/                   # Modular Gemfile components
│   ├── coverage.gemfile       # SimpleCov dependencies
│   ├── debug.gemfile          # Debugging tools
│   ├── documentation.gemfile  # YARD/documentation
│   ├── optional.gemfile       # Optional dependencies
│   ├── rspec.gemfile          # RSpec testing
│   ├── style.gemfile          # RuboCop/linting
│   └── x_std_libs.gemfile     # Extracted stdlib gems
├── ruby_*.gemfile             # Per-Ruby-version Appraisal Gemfiles
└── Appraisal.root.gemfile     # Root Gemfile for Appraisal builds
.git-hooks/
├── commit-msg                 # Commit message validation hook
├── prepare-commit-msg         # Commit message preparation
├── commit-subjects-goalie.txt # Commit subject prefix filters
└── footer-template.erb.txt    # Commit footer ERB template
```

## 🔧 Development Workflows

### Running Tests

```bash
# Full suite
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec

# Single file (disable coverage threshold check)
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/jsonc/merge/smart_merger_spec.rb

# Specific backend tests
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec --tag mri_backend
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec --tag rust_backend
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bundle exec rspec --tag ffi_backend
```

Full suite spec runs:

```bash
mise exec -C /path/to/project -- bundle exec rspec
```

For single file, targeted, or partial spec runs the coverage threshold **must** be disabled.
Use the `K_SOUP_COV_MIN_HARD=false` environment variable to disable hard failure:

```bash
mise exec -C /path/to/project -- env K_SOUP_COV_MIN_HARD=false bundle exec rspec spec/path/to/spec.rb
```

### Coverage Reports

```bash
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bin/rake coverage
mise exec -C /home/pboling/src/kettle-rb/jsonc-merge -- bin/kettle-soup-cover -d
```

```bash
mise exec -C /path/to/project -- bin/rake coverage
mise exec -C /path/to/project -- bin/kettle-soup-cover -d
```

**Key ENV variables** (set in `mise.toml`, with local overrides in `.env.local`):
- `K_SOUP_COV_DO=true` – Enable coverage
- `K_SOUP_COV_MIN_LINE` – Line coverage threshold
- `K_SOUP_COV_MIN_BRANCH` – Branch coverage threshold
- `K_SOUP_COV_MIN_HARD=true` – Fail if thresholds not met

### Code Quality

```bash
mise exec -C /path/to/project -- bundle exec rake reek
mise exec -C /path/to/project -- bundle exec rubocop-gradual
```

### Releasing

```bash
bin/kettle-pre-release    # Validate everything before release
bin/kettle-release        # Full release workflow
```

## 📝 Project Conventions

### API Conventions

#### SmartMerger API

### Test Infrastructure

- Uses `kettle-test` for RSpec helpers (stubbed_env, block_is_expected, silent_stream, timecop)
- Uses `Dir.mktmpdir` for isolated filesystem tests
- Spec helper is loaded by `.rspec` — never add `require "spec_helper"` to spec files

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

### Freeze Block Preservation

Template updates preserve custom code wrapped in freeze blocks:

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

```ruby
# kettle-jem:freeze
# ... custom code preserved across template runs ...
# kettle-jem:unfreeze
```

### Modular Gemfile Architecture

Gemfiles are split into modular components under `gemfiles/modular/`. Each component handles a specific concern (coverage, style, debug, etc.). The main `Gemfile` loads these modular components via `eval_gemfile`.

### Forward Compatibility with `**options`

**CRITICAL**: All constructors and public API methods that accept keyword arguments MUST include `**options` as the final parameter for forward compatibility.

## 🧪 Testing Patterns

### TreeHaver Dependency Tags

**Available tags**:
✅ **PREFERRED** — Use internal tools:

- `grep_search` instead of `grep` command
- `file_search` instead of `find` command
- `read_file` instead of `cat` command
- `list_dir` instead of `ls` command
- `replace_string_in_file` or `create_file` instead of `sed` / manual editing

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

```ruby
RSpec.describe SomeClass, :prism_merge do
  # Skipped if prism-merge is not available
end
```

## 🚫 Common Pitfalls

1. **NEVER mix FFI and MRI backends** – Use `TreeHaver.with_backend` for isolation
2. **NEVER use manual skip checks** – Use dependency tags (`:jsonc_grammar`, `:mri_backend`)
3. **Do NOT load vendor gems** – They are not part of this project; they do not exist in CI
4. **Use `tmp/` for temporary files** – Never use `/tmp` or other system directories
5. **Do NOT expect `cd` to persist** – Every terminal command is isolated; use a self-contained `mise exec -C ... -- ...` invocation.
6. **Do NOT rely on prior shell state** – Previous `cd`, `export`, aliases, and functions are not available to the next command.

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

❌ **AVOID** when possible:

- `run_in_terminal` for information gathering

Only use terminal for:

- Running tests (`bundle exec rspec`)
- Installing dependencies (`bundle install`)
- Simple commands that do not require much shell escaping
- Running scripts (prefer writing a script over a complicated command with shell escaping)

1. **NEVER pipe test output through `head`/`tail`** — Run tests without truncation so you can inspect the full output.
