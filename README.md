# citeproc-lua

[![CTAN](https://img.shields.io/ctan/v/citation-style-language)](https://www.ctan.org/pkg/citation-style-language)
[![GitHub release](https://img.shields.io/github/v/release/zepinglee/citeproc-lua)](https://github.com/zepinglee/citeproc-lua/releases/latest)
[![GitHub commits](https://img.shields.io/github/commits-since/zepinglee/citeproc-lua/latest)](https://github.com/zepinglee/citeproc-lua/commits/main)
<!-- [![Actions Status](https://github.com/zepinglee/citeproc-lua/workflows/Test/badge.svg)](https://github.com/zepinglee/citeproc-lua/actions) -->

The [Citation Style Language](https://citationstyles.org/) (CSL) is an
XML-based language that defines the formats of citations and bibliography.
There are currently thousands of styles in CSL including the most widely used
APA, Chicago, Vancouver, etc.
The `citeproc-lua` project is a Lua implementation of CSL v1.0.1 processor
that is aimed for use with LaTeX.
The engine reads bibliographic metadata and performs sorting and formatting on
both citations and bibliography according to the selected CSL style.
A LaTeX package (`citation-style-language.sty`) is provided to communicate with
the processor.

This project is in early development stage and some features of CSL (especially
collapsing and disambiguation) are not implemented yet. Comments, suggestions
and bug reports are welcome.

## LaTeX example

A full LaTeX example is in the [`example/`](example) directory.

- LaTeX document example.tex

```latex
\documentclass{article}

\usepackage{citation-style-language}
\cslsetup{style = apa}
\addbibresource{example.bib}

\begin{document}

\cite{ITEM-1}
\printbibliography

\end{document}
```

- Compiling with LuaTeX

```bash
lualatex example.tex
lualatex example.tex
```

- Compiling with other TeX engines

```bash
pdflatex example.tex
citeproc example.aux
pdflatex example.tex
```


## License

The LaTeX package and Lua library are released under MIT license.
The CSL locale files and styles are redistributed under the [Creative Commons Attribution-ShareAlike 3.0 Unported license](https://creativecommons.org/licenses/by-sa/3.0/).


## Related material

- CSL
  - [CSL Homepage](https://citationstyles.org/)
  - [CSL specification](https://docs.citationstyles.org/en/stable/specification.html)
  - [CSL schema](https://github.com/citation-style-language/schema)
  - [CSL processors in other languages](https://citationstyles.org/developers/#csl-processors)
    - [Juris-M/citeproc-js](https://github.com/Juris-M/citeproc-js)
      - [documentation](https://citeproc-js.readthedocs.io/en/latest/)
    - [brechtm/citeproc-py](https://github.com/brechtm/citeproc-py)
    - [jgm/citeproc](https://github.com/jgm/citeproc)
    - [andras-simonyi/citeproc-el](https://github.com/andras-simonyi/citeproc-el)
    - [inukshuk/citeproc-ruby](https://github.com/inukshuk/citeproc-ruby)
    - [zotero/citeproc-rs](https://github.com/zotero/citeproc-rs)
  - [CSL locales](https://github.com/citation-style-language/locales)
  - [CSL styles](https://github.com/citation-style-language/styles)
  - [CSL test-suite](https://github.com/citation-style-language/test-suite)
- Articles
  - [A Citation Style Language (CSL) workshop](https://tug.org/TUGboat/tb35-3/tb111stender.pdf) (TUGboat article)
- Discussions
  - [Citation Style Language vs. biblatex](https://tex.stackexchange.com/questions/434946/citation-style-language-vs-biblatex-vs-possibly-other-citing-systems)
