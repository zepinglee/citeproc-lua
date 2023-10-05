# citeproc-lua

[![CTAN](https://img.shields.io/ctan/v/citation-style-language)](https://www.ctan.org/pkg/citation-style-language)
[![LuaRocks](https://img.shields.io/luarocks/v/zepinglee/citeproc-lua)](https://luarocks.org/modules/zepinglee/citeproc-lua)
[![GitHub release](https://img.shields.io/github/v/release/zepinglee/citeproc-lua)](https://github.com/zepinglee/citeproc-lua/releases/latest)
[![GitHub commits](https://img.shields.io/github/commits-since/zepinglee/citeproc-lua/latest)](https://github.com/zepinglee/citeproc-lua/commits/main)
[![Automated testing](https://github.com/zepinglee/citeproc-lua/actions/workflows/test.yml/badge.svg)](https://github.com/zepinglee/citeproc-lua/actions/workflows/test.yml)

- Homepage: https://github.com/zepinglee/citeproc-lua
- Author: Zeping Lee
- Email: zepinglee AT gmail DOT com
- License: MIT

The [Citation Style Language](https://citationstyles.org/) (CSL) is an
XML-based language that defines the formats of citations and bibliography.
There are currently thousands of styles in CSL including the most widely used
APA, Chicago, Vancouver, etc.
The `citeproc-lua` project is a Lua implementation of CSL v1.0.2 processor
that is aimed for use with LaTeX.
The engine reads bibliographic metadata and performs sorting and formatting on
both citations and bibliography according to the selected CSL style.
A LaTeX package (`citation-style-language.sty`) is provided to communicate with
the processor.

This project is in early development stage and some features of CSL are not implemented yet.
Comments, suggestions and bug reports are welcome.


## LaTeX example

A full LaTeX example is in the [`examples/`](examples) directory.

- LaTeX document example.tex

```latex
\documentclass{article}

\usepackage{citation-style-language}
\cslsetup{style = apa}
\addbibresource{example.json}  % or example.bib or example.yaml

\begin{document}

\cite{ITEM-1}
\printbibliography

\end{document}
```

- For LuaTeX

```bash
lualatex example.tex
lualatex example.tex
```

- For other TeX engines

```bash
pdflatex example.tex
citeproc-lua example.aux
pdflatex example.tex
```



## Installation

The above example should work out-of-the-box with TeX Live 2022 or later version.
If you want to install the GitHub develop version of this package,
you may follow the steps below.

The `citation-style-language` requires the following packages:
`filehook`, `l3kernel`, `l3packages`, `lua-uca`, `lualibs`,
`luatex`, `luaxml`, and `url`.
`l3build` is also required for actually performing the installation.
Make sure they are already installed in the TeX distribution.

```bash
git clone https://github.com/zepinglee/citeproc-lua  # Clone the repository
cd citeproc-lua
git submodule update --init --remote                 # Fetch submodules
l3build install
```

These commands install the package files to `TEXMFHOME` which is usually
`~/texmf` on Linux or `~/Library/texmf` on macOS.
Besides, the `citeproc-lua` executable needs to be copied to some directory
in the `PATH` environmental variable so that it can be called directly in the shell.
For example provided `~/bin` is in `PATH`:

```bash
cp citeproc/citeproc-lua.lua "~/bin/citeproc-lua"
```

To uninstall the package from `TEXMFHOME`:

```bash
l3build uninstall
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
