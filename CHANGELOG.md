# Changelog

[![SemVer 2.0.0][📌semver-img]][📌semver] [![Keep-A-Changelog 1.0.0][📗keep-changelog-img]][📗keep-changelog]

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][📗keep-changelog],
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
and [yes][📌major-versions-not-sacred], platform and engine support are part of the [public API][📌semver-breaking].
Please file a bug if you notice a violation of semantic versioning.

[📌semver]: https://semver.org/spec/v2.0.0.html
[📌semver-img]: https://img.shields.io/badge/semver-2.0.0-FFDD67.svg?style=flat
[📌semver-breaking]: https://github.com/semver/semver/issues/716#issuecomment-869336139
[📌major-versions-not-sacred]: https://tom.preston-werner.com/2022/05/23/major-version-numbers-are-not-sacred.html
[📗keep-changelog]: https://keepachangelog.com/en/1.0.0/
[📗keep-changelog-img]: https://img.shields.io/badge/keep--a--changelog-1.0.0-FFDD67.svg?style=flat

## [Unreleased]

### Added

- Added shared comment capability and augmenter exposure with normalized region and attachment access for root object / array files, comment-only documents, and reproducible comment-heavy fixtures

### Changed

- Rebased `Jsonc::Merge::CommentTracker` onto the shared
  `Ast::Merge::Comment::CStyleTrackerBase`, keeping only JSONC-specific owner
  resolution and block-comment policy local
- Adopted the shared `Ast::Merge::Layout` contract for root-level JSONC layout gaps, including shared layout compliance coverage across the supported backend paths
- Preserved destination leading and inline comments through template-preferred matched pair and recursive object / array merges while keeping comment association stable through nested JSONC shapes
- Preserved or promoted comments for removed destination-only pairs and array items when `remove_template_missing_nodes: true` is enabled, while keeping comma placement and stripped JSON validity intact
- Adopted `Ast::Merge::TrailingGroups::DestIterate` for position-aware template-only pair and array-item insertion while preserving JSONC freeze blocks and comment-bearing recursive container merges
- Reused the shared emitter comment-region helpers for document-boundary replay,
  line-comment-only matched-node emission, bounded removed-node promotion, and
  safe trailing-container replay while keeping broader block-comment fallback
  behavior local to JSONC

### Deprecated

### Removed

### Fixed

- Preserved comments on matched object / array container pairs and trailing container comment blocks when equivalent JSONC comments differ only by whitespace, including devcontainer-style recursive merges
- ConflictResolver no longer collapses nodes that share the same signature.
  Multiple nodes with identical signatures are now matched 1:1 in order via
  cursor-based positional matching, instead of being treated as a single node.
  While duplicate keys are invalid in JSONC (same as JSON), the recursive merge
  already scopes each level, and this fix ensures correctness for any edge cases.
- Removal-mode separator blank lines are now preserved only when promoted comment
  content is actually emitted, preventing stray vertical gaps after uncommented
  destination-only removals
- Matched and removed JSONC nodes now preserve single-line and multi-line
  `/* ... */` comment spans more faithfully by replaying tracked raw source
  lines when block-comment fallback is required

### Security

## [1.0.1] - 2026-02-19

- TAG: [v1.0.1][1.0.1t]
- COVERAGE: 93.01% -- 639/687 lines in 11 files
- BRANCH COVERAGE: 68.75% -- 231/336 branches in 11 files
- 96.43% documented

### Added

- AGENTS.md

### Changed

- appraisal2 v3.0.6
- kettle-test v1.0.10
- stone_checksums v1.0.3
- ast-merge v4.0.6
- tree_haver v5.0.5
- tree_stump v0.2.0
  - fork no longer required, updates all applied upstream
- Updated documentation on hostile takeover of RubyGems
  - https://dev.to/galtzo/hostile-takeover-of-rubygems-my-thoughts-5hlo

## [1.0.0] - 2026-02-01

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 93.01% -- 639/687 lines in 11 files
- BRANCH COVERAGE: 68.75% -- 231/336 branches in 11 files
- 96.43% documented

### Added

- Initial release

### Security

[Unreleased]: https://github.com/kettle-rb/jsonc-merge/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/kettle-rb/jsonc-merge/compare/v1.0.0...v1.0.1
[1.0.1t]: https://github.com/kettle-rb/jsonc-merge/releases/tag/v1.0.1
[1.0.0]: https://github.com/kettle-rb/jsonc-merge/compare/f1cc25b1d9b79c598270e3aa203fa56787e6c6fc...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/jsonc-merge/tags/v1.0.0
