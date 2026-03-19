# Blank Line Normalization Plan for `jsonc-merge`

_Date: 2026-03-19_

## Role in the family refactor

`jsonc-merge` is an important adopter because comments and surrounding spacing are both semantically meaningful to human-maintained JSONC files.

## Current evidence files

Implementation files:

- `lib/jsonc/merge/smart_merger.rb`
- `lib/jsonc/merge/conflict_resolver.rb`
- `lib/jsonc/merge/file_analysis.rb`

Relevant specs:

- `spec/support/shared_examples/smart_merger_examples.rb`
- `spec/integration/merge_output_validation_spec.rb`
- `spec/integration/reproducible_merge_spec.rb`
- `spec/jsonc/merge/removal_mode_compliance_spec.rb`

## Current pressure points

Known family-level pressure points include:

- promoted removed-node comments needing stable separator blank lines
- idempotence after repeated merges
- object/array/key removal cases where blank lines can drift or collapse incorrectly

## Migration targets

### 1. Adopt shared gap preservation for comment-aware JSONC structures

Spacing around preserved comments and adjacent keys/items should move onto shared `ast-merge` layout behavior.

### 2. Normalize removal-mode separator handling

The current JSONC-specific spacing/idempotence fixes should become shared behavior where practical.

### 3. Keep conservative exactness where config files benefit from it

JSONC often needs human-readable but stable formatting; the shared model should preserve exact gap intent when that is the chosen policy.

## Workstreams

- audit existing JSONC spacing regressions
- migrate removal-mode separator logic first
- migrate general top-level and nested gap handling second
- confirm repeated merges remain byte-stable where intended

## Exit criteria

- JSONC no longer needs bespoke fixes for the shared separator-blank-line cases
- repeated merges remain stable
- comments, keys, and array items preserve intended gap behavior under the shared layout contract
