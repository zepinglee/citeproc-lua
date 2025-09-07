# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fix extra spaces caused by `tex.print` ([#102](https://github.com/zepinglee/citeproc-lua/issues/102)).

## [0.8.2] - 2025-08-14

### Fixed

- Fix missing citations in `\include`d documents ([#101](https://github.com/zepinglee/citeproc-lua/issues/101)).

## [0.8.1] - 2025-08-06

### Added

- Add support for grouping bibliography by authors ([#94](https://github.com/zepinglee/citeproc-lua/issues/94)).
- Add `bib-name-sep` and `bib-after-name-sep` options to control the vertical space of author groups ([#94](https://github.com/zepinglee/citeproc-lua/issues/94)).

### Changed

- Suppress \newrefsection in bib heading ([#93](https://github.com/zepinglee/citeproc-lua/issues/93)).

### Fixed

- Fix missing `keyword` field when converted from BibTeX ([#97](https://github.com/zepinglee/citeproc-lua/issues/97)).
- Fix capitalization of the first term in an in-text citation ([#98](https://github.com/zepinglee/citeproc-lua/issues/98)).
- Fix missing BibTeX string definitions in standard styles.

## [0.8.0] - 2025-04-29

### Added

- Convert BibTeX entry keys to NFC
- The entry keys are case-folded for comparing.
- Add citation option `unsorted`.

### Fixed

- Fix an infinite loop bug of unrecognized `babel` language name ([#65](https://github.com/zepinglee/citeproc-lua/issues/65)).
- Bib2csl: The hyphens in `number` fields are correctly escaped when converted to CSL-JSON.
- Bib2csl: Map `shorthand` field to CSL `citation-label` variable.
- BibTeX parser: Fix hyphen in family name.
- Fix a bug in EDTF parsing.
- Bib2csl: Fix a sentence case conversion bug that words after colons are not capitalized.
- Fix an error when `hyperref` is loaded before CSL ([#91](https://github.com/zepinglee/citeproc-lua/issues/91)).

## [0.7.0] - 2025-02-23

### Added

- Add `journal-abbreviation` option to `\addbibresource` command to disable searching abbreviations of journal titles ([#85](https://github.com/zepinglee/citeproc-lua/issues/85)).

### Fixed

- Match journal title with multiple words when converting `.bib` to CSL-JSON ([#85](https://github.com/zepinglee/citeproc-lua/issues/85)).

## [0.6.8] - 2025-01-25

### Fixed

- Fix links to excluded entries in bibliography ([#82](https://github.com/zepinglee/citeproc-lua/issues/82)).

## [0.6.7] - 2025-01-10

### Added

- Add `citation-range-delimiter` term as an extension to CSL.

## [0.6.6] - 2024-11-18

### Added

- Add `\citeyear` command.

## [0.6.5] - 2024-10-05

### Fixed

- The locator in citation is converted to HTML-like tagged string ([#78](https://github.com/zepinglee/citeproc-lua/issues/78)).

## [0.6.4] - 2024-09-15

### Fixed

- Refactor `processCitationCluster()` to fix unexpected nil ([#77](https://github.com/zepinglee/citeproc-lua/issues/77)).

## [0.6.3] - 2024-08-28

### Added

- Add support for citation affixes.

### Fixed

- Fix `\ref` with underscore in citation affixes ([#74](https://github.com/zepinglee/citeproc-lua/issues/74)).

## [0.6.2] - 2024-08-21

### Added

- Add support for `perpage` package.

### Fixed

- Fix note position in multiple chapters ([#72](https://github.com/zepinglee/citeproc-lua/issues/72)).
- Fix incorrect locale map of UKenglish.

## [0.6.1] - 2024-08-15

### Fixed

- Fix parsing quotation marks ([#71](https://github.com/zepinglee/citeproc-lua/issues/71)).

## [0.6.0] - 2024-07-31

### Added

- Add support for multiple bibliographies (`refsection` environment).
- Add global `ref-section` option.
- Add support for `biber`'s `%`-style inline comment in `.bib` files.

### Fixed

- Fix an error of empty locator in citation ([#70](https://github.com/zepinglee/citeproc-lua/discussions/70)).

## [0.5.1] - 2024-07-10

### Fixed

- Fix a bug in font style flip-flopping with raw code ([#67](https://github.com/zepinglee/citeproc-lua/issues/67)).

## [0.5.0] - 2024-06-09

### Added

- Add `\fullcite` command ([#64](https://github.com/zepinglee/citeproc-lua/issues/64)).
- Add support for annotated bibliography ([#64](https://github.com/zepinglee/citeproc-lua/issues/64)).

### Changed

- Check if the `\cite` command is in a footnote.

## [0.4.9] - 2024-04-21

### Added

- Add normal paragraph style for list of references ([#60](https://github.com/zepinglee/citeproc-lua/discussions/60)).

- Add `bib-par-indent` option for the amount of paragraph indentation.

## [0.4.8] - 2024-03-12

### Fixed

- Fix unexpected "nil" with empty page ([#58](https://github.com/zepinglee/citeproc-lua/issues/58)).

## [0.4.7] - 2024-03-10

### Added

- Add support of biblatex's extended name format ([#48](https://github.com/zepinglee/citeproc-lua/issues/48)).

- Add `\citeyearpar` and `\parencite*`  commands ([#52](https://github.com/zepinglee/citeproc-lua/issues/52)).

### Fixed

- Fix an error in parsing TeX math contents ([#49](https://github.com/zepinglee/citeproc-lua/issues/49)).

## [0.4.6] - 2024-02-20

### Fixed

- Define an internal variable

## [0.4.5] - 2023-10-05

### Fixed

- Fix tilde (nonbreakable space) incorrectly displayed in LuaTeX ([#42](https://github.com/zepinglee/citeproc-lua/issues/42)).
- If no style is defined, a warning is given and the default APA style will be used ([#43](https://github.com/zepinglee/citeproc-lua/issues/43)).
- The JSON decoding error is now correctly issued.

## [0.4.4] - 2023-09-16

### Fixed

- Fix a disambiguation bug with names from conditional branches.
- Fix a typo related to `beamer` compatibility ([#41](https://github.com/zepinglee/citeproc-lua/issues/41#issuecomment-1715538773)).

## [0.4.3] - 2023-09-07

### Added

- Add support for CSL-YAML input.
- Add support for dependent styles.
- Resolve `crossref`s in BibTeX data.
- Add support for `backref` package (part of `hyperref`).

### Fixed

- Fix compatibility with `beamer` ([#41](https://github.com/zepinglee/citeproc-lua/issues/41)).

## [0.4.2] - 2023-07-04

### Changed

- BibTeX parser: The `eid` from `biblatex` field is mapped to CSL's `number` ([retorquere/zotero-better-bibtex#2551](https://github.com/retorquere/zotero-better-bibtex/issues/2551#issuecomment-1615593134)).

### Fixed

- Fix a bug with `<text variable="locator">` in `<bibliography>` ([#39](https://github.com/zepinglee/citeproc-lua/issues/39)).
- Fix missing `$` errors caused by underscores in citations keys.
- Fix a conflict of already defined `\@currentHref` due to changes in LaTeX2e kernel 2023-06-01 ([latex3/latex2e#pr956](https://github.com/latex3/latex2e/pull/956)).

## [0.4.1] - 2023-04-12

### Added

- Add support for `crossref` feature in BibTeX database.
- Add `\printbibheading` command.
- Add options `heading`, `label`, and `title` in `\printbibliography` ([#31](https://github.com/zepinglee/citeproc-lua/issues/31)).
- Add `prenote` and `postnote` options in `\printbibliography`.

### Fixed

- Remove UTF-8 BOM from loaded files (fix [#34](https://github.com/zepinglee/citeproc-lua/issues/34)).

## [0.4.0] - 2023-04-02

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

## [0.3.0] - 2022-12-25

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

## [0.2.2] - 2022-09-23

### Fixed

- `latexmk` can automatically call citeproc-lua when compiling with `pdflatex` or `xelatex` (thanks to [John Collins](http://personal.psu.edu/~jcc8/)).
- Fix incorrect labels in numeric reference list ([#25](https://github.com/zepinglee/citeproc-lua/issues/25)).

## [0.2.1] - 2022-09-18

### Changed

- Rewrite BibTeX parser with `lpeg`. The accent letters are now converted to unicode.

### Fixed

- Fix redundant warning `entry "*" not found`.

## [0.2.0] - 2022-08-18

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

## [0.1.1] - 2022-03-21

### Added

- Add support for [CSL v1.0.2](https://github.com/citation-style-language/schema/releases/tag/v1.0.2).
- Add CSL-JSON format in `\addbibresource` ([#11](https://github.com/zepinglee/citeproc-lua/issues/11)).
- Add multicite command `\cites` ([#10](https://github.com/zepinglee/citeproc-lua/issues/10)).
- Add URL format setup.

### Fixed

- Fix the incompatibility with `babel` ([#9](https://github.com/zepinglee/citeproc-lua/issues/9)).
- Fix missing `\url` commands in bibliography ([#12](https://github.com/zepinglee/citeproc-lua/issues/12)).

## [0.1.0] - 2022-01-22

### Added

- Initial CTAN release.

[Unreleased]: https://github.com/zepinglee/citeproc-lua/compare/v0.8.2...HEAD
[0.8.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.8...v0.7.0
[0.6.8]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.7...v0.6.8
[0.6.7]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.6...v0.6.7
[0.6.6]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.5...v0.6.6
[0.6.5]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.4...v0.6.5
[0.6.4]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.3...v0.6.4
[0.6.3]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.5.1...v0.6.0
[0.5.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.9...v0.5.0
[0.4.9]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.8...v0.4.9
[0.4.8]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.7...v0.4.8
[0.4.7]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.6...v0.4.7
[0.4.6]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.5...v0.4.6
[0.4.5]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.4...v0.4.5
[0.4.4]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.3...v0.4.4
[0.4.3]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.2...v0.4.3
[0.4.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.1...v0.4.2
[0.4.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.2...v0.3.0
[0.2.2]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/zepinglee/citeproc-lua/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/zepinglee/citeproc-lua/releases/tag/v0.1.0
