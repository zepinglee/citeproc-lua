# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.4.0] - 2023-04-02

### Added

- Add hyperlinks to citations when `hyperref` is loaded.
- Add backref.
- Add journal abbreviation.
- The `title`s and `booktitle`s from BibTeX data are converted to sentence case.
- Add [`layout` extension](https://citeproc-js.readthedocs.io/en/latest/csl-m/index.html#cs-layout-extension) of CSL-M.

### Fixed

- Fix missing warning of empty citation ([latex3/latex2e#790](https://github.com/latex3/latex2e/issues/790)).
- Fix url link of PMCID.
- Fix an error of LaTeX commands in cite prefix ([#36](https://github.com/zepinglee/citeproc-lua/issues/36)).
- Fix invalid `bib-item-sep` option.
- Fix the delimiter of `cs:choose` in deeper levels.

## [v0.3.0] - 2022-12-25

### Added

- Add author only command `\citeauthor`.
- Add narrative citation commands `\textcite` and `\citet` ([#17](https://github.com/zepinglee/citeproc-lua/issues/17)).
- Add parenthetical citation commands `\parencite` and `\citep` for compatibility.

### Changed

- The "-locator" suffixes are removed from the `article-locator` and `title-locator` options.
- The LaTeX markups in citation prefix is now correctly precessed ([#33](https://github.com/zepinglee/citeproc-lua/issues/33)).

### Fixed

- Fix an error in checking the plurity of `number-of-pages` ([#27](https://github.com/zepinglee/citeproc-lua/issues/27)).
- Fix an error in converting value `"2nd"` to its ordinal form ([#27](https://github.com/zepinglee/citeproc-lua/issues/27)).
- Fix missing DOI prefix when used with `hyperref` ([#28](https://github.com/zepinglee/citeproc-lua/issues/28)).
- Fix special characters (`#` and `%`) in URL ([#30](https://github.com/zepinglee/citeproc-lua/issues/30)).

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

[Unreleased]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.0...HEAD
[v0.4.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.3.0...0.4.0
[v0.3.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.2...0.3.0
[v0.2.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.1...0.2.2
[v0.2.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.0...0.2.1
[v0.2.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.1...0.2.0
[v0.1.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.0...v0.1.1
[v0.1.0]: https://github.com/zepinglee/citeproc-lua/releases/tag/v0.1.0
