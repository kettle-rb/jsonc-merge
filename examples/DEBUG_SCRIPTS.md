# Debug Scripts for Backend Testing

This directory contains debug scripts for testing jsonc-merge behavior across different tree-sitter backends.

## Available Scripts

### 1. `debug_mri_backend.rb` - MRI/ruby_tree_sitter
Tests the MRI C extension backend (ruby_tree_sitter gem).

**Usage:**
```bash
ruby examples/debug_mri_backend.rb
```

**Requirements:**
- MRI Ruby (not JRuby or TruffleRuby)
- `ruby_tree_sitter` gem installed
- tree-sitter-jsonc grammar installed

### 2. `debug_ffi_backend.rb` - FFI Backend
Tests the FFI bindings to libtree-sitter.

**Usage:**
```bash
ruby examples/debug_ffi_backend.rb
```

**Requirements:**
- Ruby with FFI support (MRI, JRuby, TruffleRuby)
- `ffi` gem installed
- libtree-sitter.so in LD_LIBRARY_PATH
- tree-sitter-jsonc grammar installed

### 3. `debug_rust_backend.rb` - Rust/tree_stump
Tests the Rust extension backend via tree_stump gem.

**Usage:**
```bash
ruby examples/debug_rust_backend.rb
```

**Requirements:**
- MRI Ruby
- `tree_stump` gem installed (Rust extension)
- tree-sitter-jsonc grammar available

### 4. `debug_java_backend.rb` - Java/jtreesitter
Tests the Java backend for JRuby via jtreesitter.

**Usage:**
```bash
jruby examples/debug_java_backend.rb
```

**Requirements:**
- JRuby
- jtreesitter JARs installed (see tree_haver setup)
- tree-sitter-jsonc grammar installed
- Environment variables set:
  - `TREE_SITTER_JAVA_JARS_DIR`
  - `TREE_SITTER_RUNTIME_LIB`
  - `TREE_SITTER_JSONC_PATH`

## What These Scripts Test

All scripts test the same scenarios to ensure consistent behavior:

1. **Valid JSON Parsing**
   - Parse a simple JSON object
   - Access root node and pairs
   - Check `child_by_field_name` availability
   - Verify key_name and value_node methods

2. **Invalid JSON Detection**
   - Parse invalid JSON
   - Check error detection (has_error?)
   - Verify ERROR nodes are found

3. **Template-Only Node Merging**
   - Merge template with extra fields
   - Verify `add_template_only_nodes: true` works
   - Check that container merging is recursive
   - Verify statements contain objects, not pairs

4. **Backend Information**
   - Show backend capabilities
   - Display configuration

## Expected Output

For a working backend, you should see:
- ✓ Grammar loaded successfully
- Valid JSON parses with no errors
- Invalid JSON is detected (valid? = false)
- Merge result contains BOTH "destination" and "newField"
- Result is a single JSON object (not two concatenated objects)
- Statements show `type=object, container?=true`

## Comparing Backends

Run all scripts to compare behavior:

```bash
# MRI backend
ruby examples/debug_mri_backend.rb > /tmp/mri_output.txt

# FFI backend
ruby examples/debug_ffi_backend.rb > /tmp/ffi_output.txt

# Rust backend
ruby examples/debug_rust_backend.rb > /tmp/rust_output.txt

# Java backend (requires JRuby)
jruby examples/debug_java_backend.rb > /tmp/java_output.txt

# Compare outputs
diff /tmp/mri_output.txt /tmp/java_output.txt
```

## Common Issues

### Grammar Not Found
```
✗ Grammar(loading(failed!))
```
**Fix**: Install the grammar:
```bash
ts-grammar-action install jsonc
```

### Backend Not Available
```
MRI backend(available?: false)
```
**Fix**: Install the required gem:
```bash
gem install ruby_tree_sitter  # For MRI
gem install ffi               # For FFI
gem install tree_stump        # For Rust
```

### Wrong Merge Output
If you see two separate JSON objects instead of one merged object:
```json
{"name": "destination"}
{"name": "template", "newField": "value"}
```

This indicates that `statements` is returning pairs instead of the root object. The fix is in `integrate_nodes_and_freeze_blocks` to return the root object, not individual pairs.

## Understanding the Output

### Key Indicators

**Good:**
- `statements: [0] type=object, container?=true` ✓
- `Result contains 'newField': true` ✓
- `Result contains 'destination': true` ✓
- Single JSON object output ✓

**Bad:**
- `statements: [0] type=pair, container?=false` ✗
- Two separate JSON objects in output ✗
- `newField` not in output when `add_template_only_nodes: true` ✗

## Purpose

These scripts help:
1. **Diagnose backend-specific issues** without running full test suite
2. **Understand tree-sitter API differences** across backends
3. **Verify fixes** work on all backends
4. **Document expected behavior** for each backend

## Adding New Tests

To add a new test scenario:
1. Add to one script (e.g., `debug_mri_backend.rb`)
2. Copy the test to all other scripts
3. Document expected behavior in this README
4. Run on all backends to verify consistency

