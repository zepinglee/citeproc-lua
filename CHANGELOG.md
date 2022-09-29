# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Add author only command `\citeauthor`.
- Add narrative citation commands `\textcite` and `\citet` ([#17](https://github.com/zepinglee/citeproc-lua/issues/17)).
- Add parenthetical citation commands `\parencite` and `\citep` for compatibility.

## [v0.2.2] - 2022-09-23

### Fixed

- `latexmk` can automatically call citeproc-lua when compiling with `pdflatex` or `xelatex` (thanks to [John Collins](http://personal.psu.edu/~jcc8/)).
- Fix incorrect labels in numeric reference list ([#25](https://github.com/zepinglee/citeproc-lua/issues/25)).

## [v0.2.1] - 2022-09-18

### Changed

- Rewrite BibTeX parser with `lpeg`. The accent letters are now converted to unicode.

### Fixed

- Fix redundant warning `entry "*" not found`.

## [v0.2.0] - 2022-08-18

### Added

- The cite grouping, collapsing, and disambiguation features are now implemented.

### Changed

- The `citeproc` executable is renamed to `citeproc-lua` to avoid conflicts with other processor implementations.
- Package configuration can also be given in the package loading options.
- A warning is raised instead of and error in case of duplicate entry keys ([#14](https://github.com/zepinglee/citeproc-lua/issues/14)).

### Fixed

- Fix an infinite loop error when bib entry keys contain hyphens or underscores ([#18](https://github.com/zepinglee/citeproc-lua/issues/18)).
- Fix incorrect item position in note style ([#20](https://github.com/zepinglee/citeproc-lua/issues/20)).
- Fix compatibility with `\blockquote` of `csquotes` ([#21](https://github.com/zepinglee/citeproc-lua/issues/21)).
- Fix non-lowercase field names ([#22](https://github.com/zepinglee/citeproc-lua/issues/22)).

## [v0.1.1] - 2022-03-21

### Added

- Add support for [CSL v1.0.2](https://github.com/citation-style-language/schema/releases/tag/v1.0.2).
- Add CSL-JSON format in `\addbibresource` ([#11](https://github.com/zepinglee/citeproc-lua/issues/11)).
- Add multicite command `\cites` ([#10](https://github.com/zepinglee/citeproc-lua/issues/10)).
- Add URL format setup.

### Fixed

- Fix the incompatibility with `babel` ([#9](https://github.com/zepinglee/citeproc-lua/issues/9)).
- Fix missing `\url` commands in bibliography ([#12](https://github.com/zepinglee/citeproc-lua/issues/12)).

## [v0.1.0] - 2022-01-22

### Added

- Initial CTAN release.

[Unreleased]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.2...HEAD
[v0.2.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.1...0.2.2
[v0.2.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.0...0.2.1
[v0.2.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.1...0.2.0
[v0.1.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.0...v0.1.1
[v0.1.0]: https://github.com/zepinglee/citeproc-lua/releases/tag/v0.1.0
