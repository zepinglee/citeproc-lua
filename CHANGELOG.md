# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Changed

- The `require("citeproc")` now return a module table instead of a class table. And the intialization method of the engine is changed from `CtieProc:new` to `citeproc.new`.
- `CiteProc:makebibliography()` now returns a list of two tables: `params` and `bib_items`, not two tables.

## [v0.0.1] - 2021-09-11

### Added

- Initial release

[Unreleased]: https://github.com/zepinglee/citeproc-lua/compare/v0.0.1...HEAD
[v0.0.1]: https://github.com/zepinglee/citeproc-lua/releases/tag/v0.0.1
