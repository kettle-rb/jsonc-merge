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

- ConflictResolver now applies per-node-type preferences via `node_typing`.
- Utilizes `Ast::Merge::RSpec::MergeGemRegistry` when running RSpec tests

### Changed

- Documentation cleanup
- Upgrade to [ast-merge v4.0.5](https://github.com/kettle-rb/ast-merge/releases/tag/v4.0.5)
- Upgrade to [tree_haver v5.0.3](https://github.com/kettle-rb/tree_haver/releases/tag/v5.0.3)

### Deprecated

### Removed

### Fixed

- loading of backends for tree_haver in specs

### Security

## [1.0.0] - 2026-01-12

- TAG: [v1.0.0][1.0.0t]
- COVERAGE: 93.00% -- 624/671 lines in 11 files
- BRANCH COVERAGE: 69.25% -- 223/322 branches in 11 files
- 96.43% documented

### Added

- Initial release

### Security

[Unreleased]: https://github.com/kettle-rb/jsonc-merge/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/kettle-rb/jsonc-merge/compare/f1cc25b1d9b79c598270e3aa203fa56787e6c6fc...v1.0.0
[1.0.0t]: https://github.com/kettle-rb/jsonc-merge/tags/v1.0.0
