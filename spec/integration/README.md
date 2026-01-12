# Integration Tests for JSONC-Merge

## Purpose

These integration tests validate that **actual merge output is correct**, not just internal state. They would have caught all the bugs we discovered during JRuby CI investigation.

## Test Files

### 1. `merge_output_validation_spec.rb`

**Tests actual merge output correctness**

Coverage:
- ✅ Output is valid, parseable JSON
- ✅ No duplicate keys or objects
- ✅ Preference options work correctly
- ✅ add_template_only_nodes actually adds fields
- ✅ Nested objects merge recursively
- ✅ Multi-line JSON formats correctly
- ✅ Array handling (replacement, not merge)
- ✅ Comments are preserved
- ✅ Error handling (parse errors)

**Key Value:** Tests what users actually care about - is the output correct?

### 2. `backend_consistency_spec.rb`

**Ensures all backends produce identical output**

Coverage:
- ✅ MRI backend produces valid output
- ✅ FFI backend produces valid output
- ✅ Rust backend produces valid output
- ✅ Java backend produces valid output
- ✅ All backends produce semantically equivalent JSON
- ✅ Complex nested merges work on all backends
- ✅ Edge cases handled consistently

**Key Value:** Catches backend-specific bugs before they reach users.

### 3. `bug_regression_spec.rb`

**Prevents regression of discovered bugs**

Each bug has dedicated tests:

1. **Statements returning pairs** - Validates statements contain root object
2. **Root objects not matching** - Validates root signatures match
3. **Single-line duplication** - Validates no content duplication
4. **Pair duplication** - Validates pairs emit correctly
5. **FFI field access** - Validates FFI backend can extract keys
6. **Missing commas** - Validates JSON has proper separators
7. **Template-only nodes** - Validates fields actually get added
8. **Invalid JSON errors** - Validates errors raised before merge

**Key Value:** Documents what broke and ensures it stays fixed.

## Why These Tests Matter

### Before (No Integration Tests)

**What we tested:**
- Internal node types
- Signature generation
- Method return values

**What we missed:**
- Merge produced two concatenated objects
- Output had no commas (invalid JSON)
- Template-only nodes weren't added
- FFI backend couldn't extract keys

### After (With Integration Tests)

**What we test:**
```ruby
# Simple but effective
result = merger.merge
parsed = JSON.parse(result)  # Would fail on invalid JSON
expect(parsed["newField"]).to eq("added")  # Actually checks field is there
```

This would have caught ALL the bugs immediately.

## Running the Tests

```bash
# Run all integration tests
bundle exec rspec spec/integration

# Run specific test file
bundle exec rspec spec/integration/merge_output_validation_spec.rb

# Run on specific backend
bundle exec rspec spec/integration/backend_consistency_spec.rb --tag mri_backend

# Run bug regression tests
bundle exec rspec spec/integration/bug_regression_spec.rb
```

## Test Organization

```
spec/
├── integration/           # NEW - Tests actual output
│   ├── merge_output_validation_spec.rb
│   ├── backend_consistency_spec.rb
│   └── bug_regression_spec.rb
│
├── jsonc/merge/          # Unit tests for classes
│   ├── file_analysis_spec.rb
│   ├── smart_merger_spec.rb
│   ├── conflict_resolver_spec.rb
│   └── ...
│
└── support/
    └── shared_examples/  # Shared tests run on all backends
```

## What Makes These Tests Good

### 1. They Test Reality
```ruby
# Bad: Testing internal state
expect(result.lines.size).to eq(3)

# Good: Testing actual output
expect(JSON.parse(result)).to eq({"key" => "value"})
```

### 2. They're Comprehensive
- Valid JSON parsing
- All expected keys present
- Correct values
- Works on all backends

### 3. They're Clear
Each test documents:
- What bug it prevents
- What should happen
- What would break if the bug returns

### 4. They're Fast
Integration tests, but still fast because:
- No I/O (in-memory strings)
- No external dependencies
- Simple JSON structures

## Future Additions

As we add features, add integration tests for:
- [ ] Freeze blocks actually preserved
- [ ] Match refiners work correctly
- [ ] Region merging produces correct output
- [ ] Streaming output (when implemented)

## Pattern for Other Gems

This pattern should be applied to:
- json-merge
- bash-merge
- psych-merge
- toml-merge
- rbs-merge

Each should have:
1. Output validation tests
2. Backend consistency tests
3. Bug regression tests

## Success Criteria

A good integration test:
1. ✅ Tests actual user-facing output
2. ✅ Would have caught the bug
3. ✅ Clearly documents what should happen
4. ✅ Fails if bug is reintroduced
5. ✅ Is fast and reliable

## Maintenance

When adding features:
1. Add integration test FIRST
2. Implement feature
3. Test passes
4. Add unit tests for details

When fixing bugs:
1. Add failing integration test
2. Fix bug
3. Test passes
4. Add to bug_regression_spec.rb

