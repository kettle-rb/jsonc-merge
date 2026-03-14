# PLAN.md

## Goal
Bring the shared Comment AST & Merge capability from `psych-merge` into `jsonc-merge` so JSONC merges preserve both structure and comments with stable output.

`psych-merge` is the reference implementation for shared comment regions, attachments, prelude/postlude handling, matched-node comment fallback, and removed-node comment promotion.

## Current Status
- `jsonc-merge` is one of the highest-value follow-on targets because comments are legal and common in JSONC.
- The gem already has the expected merge-gem structure (`lib/`, `spec/`, `README.md`, `AGENTS.md`) and should remain the comment-aware counterpart to strict `json-merge`.
- This gem is a strong candidate for a source-augmented approach similar to `psych-merge`: use the structural parser for merge decisions, but derive comment ownership from source-aware tracking.
- The main design goal is to preserve comment placement without making output invalid JSONC.

## Integration Strategy
- Add a shared comment capability surface to analysis and merge layers:
  - `comment_capability`
  - `comment_augmenter`
  - normalized comment regions / attachments
- Prefer source-tracked comment ownership over parser-only ownership for leading, inline, and comment-only sections.
- Reuse the `psych-merge` playbook for:
  - document prelude/postlude comments
  - matched-node destination comment fallback when template content wins
  - removed-node comment preservation and inline promotion
  - blank-line-separated comment blocks

## First Slices
1. Add shared comment capability plumbing to file analysis and node wrapping.
2. Preserve document-level prelude and postlude comments around root object/array merges.
3. Preserve leading and inline destination comments when a matched template key/value pair wins.
4. Preserve comments for removed destination-only pairs and removed array items when removal is enabled.
5. Expand recursive array/object scenarios with blank-line-separated comment sections.

## First Files To Inspect
- `lib/jsonc/merge/file_analysis.rb`
- `lib/jsonc/merge/node_wrapper.rb`
- `lib/jsonc/merge/smart_merger.rb`
- `lib/jsonc/merge/conflict_resolver.rb`
- `lib/jsonc/merge/emitter.rb`
- any existing comment tracking implementation under `lib/jsonc/merge/`

## Tests To Add First
- analysis specs for comment region inference
- emitter specs for leading / inline / promoted comment emission
- smart merger specs for matched and removed pairs
- recursive array/object specs with comment-only sections
- reproducible fixtures for comment-heavy merges once behavior stabilizes

## Risks
- `//` and `/* ... */` comments must not be confused with comment-like text inside strings.
- Removing or reordering pairs can easily break comma placement.
- Block comment ownership can be ambiguous near arrays and trailing values.
- Output must remain valid JSONC even when comments are preserved aggressively.

## Success Criteria
- Shared comment capability is exposed through the analysis layer.
- Leading, inline, and document-boundary comments are preserved in common merges.
- Removed destination-only nodes can preserve or promote comments without invalid output.
- Recursive merges keep comment association stable.
- Reproducible fixtures cover the highest-risk comment-heavy JSONC scenarios.

## Rollout Phase
- Phase 1 target.
- Recommended as the first active implementation after `psych-merge` because it combines high value with a clear source-augmented comment model.

## Latest `ast-merge` Comment Logic Checklist (2026-03-13)
- [x] Shared capability plumbing: `comment_capability`, `comment_augmenter`, normalized region/attachment access
- [x] Document boundary ownership: prelude/postlude and comment-only file handling
- [x] Matched-node fallback: destination leading/inline preservation under template preference
- [x] Removed-node preservation: destination-only pair/array-item comment preservation and inline promotion
- [x] Recursive/fixture parity: nested object/array scenarios and reproducible comment-heavy fixtures

Current parity status: complete for the latest shared `ast-merge` comment rollout shape, and the local workspace-path gem wiring has now been revalidated under `KETTLE_RB_DEV`.

## Progress
- 2026-03-13: Local workspace-path validation rechecked after modular gemfile wiring normalization.
- Replaced direct local `path:` overrides in modular tree-sitter / templating gemfiles with the shared `nomono` local-override pattern and reran the full `jsonc-merge` suite in workspace mode; the suite is green with the existing backend-availability pending examples only.
- 2026-03-11: Plan sync completed.
- Confirmed `jsonc-merge` remains aligned to the latest shared `ast-merge` comment checklist with all rollout slices complete.
- This plan now serves as a completed Phase 1 reference alongside `dotenv-merge`.
- 2026-03-09: Phase 1 / Slice 1 completed.
- Landed the minimal shared comment capability surface in `CommentTracker` and `FileAnalysis`.
- Preserved document-boundary destination comments for top-level object and top-level array merges.
- Fixed root-array integration so top-level arrays participate as mergeable statements.
- Added focused specs for shared capability exposure, header/footer preservation, comment-only destinations, and root-array ownership.
- Validated with focused specs and the full `jsonc-merge` suite.
- 2026-03-09: Phase 1 / Slice 2 completed.
- Added matched template-preferred pair comment fallback so destination leading and inline comments survive when template content wins.
- Added local `remove_template_missing_nodes` plumbing in `jsonc-merge` and preserved comments for removed destination-only pairs.
- Made JSONC comma insertion comment-aware so commas stay attached to structural lines rather than promoted comment lines.
- Added focused and integration regressions for matched/removed pair comments and revalidated the full `jsonc-merge` suite.
- 2026-03-09: Phase 1 / Slice 3 started and partially completed.
- Probed recursive/nested JSONC comment scenarios through the real merger before broadening changes.
- Fixed nested-object inline-comment comma placement so commas land before inline comments and stripped JSON remains valid.
- Fixed blank-line preservation between nested leading comment blocks and their owning content.
- Added nested-object comment regressions and revalidated the full `jsonc-merge` suite.
- Extended recursive merging to keyed arrays so mixed object/array structures now preserve destination comments, avoid duplicated array keys, and keep stripped JSON valid.
- Preserved comments for removed destination-only array items when removal is enabled, including promoted inline comments.
- Added focused and integration regressions for mixed object/array recursive comment scenarios.
- Promoted the strongest recursive comment-heavy scenarios into reproducible fixtures:
  - nested object comment blocks with inline comment comma placement
  - keyed array/object recursive comment preservation
  - removed destination-only array item comment promotion
- Added `spec/integration/reproducible_merge_spec.rb` plus `spec/fixtures/reproducible/*` coverage for those scenarios.
- Revalidated the new reproducible spec, the focused recursive/comment specs, and the full `jsonc-merge` suite.

## Execution Backlog

### Slice 1 — Shared capability + document boundaries
- Add `comment_capability`, `comment_augmenter`, and normalized region access to file analysis.
- Infer and preserve document prelude/postlude comments for root object and root array files.
- Add focused specs for comment-only files, header comments, and footer comments.

Status: complete on 2026-03-09.

### Slice 2 — Matched and removed node comment preservation
- Preserve destination leading and inline comments when matched template-preferred pairs win.
- Preserve comments for removed destination-only pairs when removal is enabled.
- Promote removed inline comments to standalone comment lines where necessary.
- Add focused resolver/emitter/smart-merger specs for object members first.

Status: complete on 2026-03-09.

### Slice 3 — Recursive structures + fixtures
- Extend the same ownership rules to arrays, nested objects, and mixed object/array structures.
- Add blank-line-separated comment-block regressions.
- Promote the best cases to reproducible fixtures once behavior is stable.

Status: complete on 2026-03-09.
Completed: nested-object inline-comment comma placement, nested blank-line comment-block preservation, keyed-array recursive comment preservation, removed-array-item comment preservation, and reproducible fixture promotion for the strongest recursive comment-heavy scenarios.
Next recommended resume point: keep `jsonc-merge` in regression-only mode and continue the remaining Phase 1 rollout in `toml-merge`.

## Dependencies / Resume Notes
- Reference sibling `psych-merge` sources `../psych-merge/lib/psych/merge/comment_tracker.rb` and `../psych-merge/lib/psych/merge/conflict_resolver.rb` for source-augmented ownership rules.
- Start in `lib/jsonc/merge/file_analysis.rb` and `lib/jsonc/merge/conflict_resolver.rb` before touching emitter details.
- Keep strict JSON behavior boundaries aligned with `json-merge`.

## Exit Gate For This Plan
- Comment-heavy JSONC merges preserve comments without breaking commas or structural validity.
- High-value object and array scenarios are covered by focused specs and reproducible fixtures.
