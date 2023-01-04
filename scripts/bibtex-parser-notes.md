# BibTeX Parser Notes

## BibTeX parser requirements for CSL engine:

- Full BibTeX syntax support: `@string`, `@preamble`, `month = "10~" # jan`...
- Convert to Unicode: `\'{E}` => `É`.
  - TeX ligatures: `--` => en dash, ` `` ` => `“`, `''` => `”`.
- TeX unescape: `10\% & 99\$`.
- Name parsing.
- Rich text: `\textbf{...}`, `{\em ...}`.
- Case protection: `The {Feynman} Lectures on Physics`.
- TeX command (non-unicode) protection: `\mbox{G-Animal's}`.
- Math protection: `A $L^2$-function`.
- Convert title to sentence case.
<!-- - Bib(La)TeX to CSL Mapping. -->


## BibTeX Parser implementations

### Original BibTeX

- WEB source code: <https://tug.org/svn/texlive/trunk/Build/source/texk/web2c/bibtex.web>
- GitHub mirror: <https://github.com/TeX-Live/texlive-source/blob/trunk/texk/web2c/bibtex.web>
- CTAN page: <https://ctan.org/pkg/bibtex>
- Documentation:
  - [btxdoc.pdf](http://mirrors.ctan.org/biblio/bibtex/base/btxdoc.pdf)
  - [btxhak.pdf](http://mirrors.ctan.org/biblio/bibtex/base/btxhak.pdf)
- Tame the BeaST: <http://mirrors.ctan.org/info/bibtex/tamethebeast/ttb_en.pdf>
A summary of BibTeX: http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html


### Lua implementations

- ConTeXt BibTeX parser
  - <https://source.contextgarden.net/tex/context/base/mkiv/bibl-bib.lua>
  - Based on `lpeg`
- LPEG BibTeX
  - <https://github.com/oncomouse/lpeg-bibtex>
  - Based on `lpeg`
- `sile` package `bibtex`
  - <https://github.com/sile-typesetter/sile/blob/master/packages/bibtex/init.lua>
  - Based on `lpeg`
- bibparser-lua
  - <https://github.com/infogrind/bibparser-lua>
- luabibtex
  - URL: <https://github.com/echiesse/luabibtex>
  - Parser: <https://github.com/echiesse/luabibtex/blob/master/src/bibParser.lua>
  - Simple implementation.


### JavaScript implementations

Citation.js Blog post by Lars Willighagen: <https://citation.js.org/blog/?post=2671087865137010007>

BibTeX Parser Experiments: <https://github.com/citation-js/bibtex-parser-experiments/>

- @citation-js/plugin-bibtex: <https://github.com/citation-js/citation-js/tree/main/packages/plugin-bibtex>
- @retorquere/bibtex-parser (BBT) (used by Better BibTeX for Zotero): <https://github.com/retorquere/bibtex-parser>
- Zotero BibTeX translator: <https://github.com/zotero/translators/blob/master/BibTeX.js>


### Python implementations

- python-bibtexparser: https://github.com/sciunto-org/python-bibtexparser
  - Documentation: https://bibtexparser.readthedocs.io/
  - Based on pyparsing
- <https://github.com/aclements/biblib>
  - Faithfully following the grammar in the WEB source code of BibTeX
- PybTeX <https://pybtex.org/>
  - https://bitbucket.org/pybtex-devs/pybtex/src/master/



## LaTeX PEG grammar

- https://github.com/michael-brade/LaTeX.js
  - JavaScript LaTeX to HTML5 translator
