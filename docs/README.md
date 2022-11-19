# citation-style-language

The [Citation Style Language](https://citationstyles.org/) (CSL) is an
XML-based language that defines the formats of citations and bibliography.
There are currently thousands of styles in CSL including the most widely used
APA, Chicago, Vancouver, etc.
The `citation-style-language` package is aimed to provide another reference
formatting method for LaTeX that utilizes the CSL styles.
It contains a citation processor implemented in pure Lua (`citeproc-lua`)
which reads bibliographic metadata and performs sorting and formatting on both
citations and bibliography according to the selected CSL style.
A LaTeX package (`citation-style-language.sty`) is provided to communicate
with the processor.

This project is in early development stage and some features of CSL (especially
collapsing and disambiguation) are not implemented yet. Comments, suggestions
and bug reports are welcome.

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

- Compiling with LuaTeX

```bash
lualatex example.tex
lualatex example.tex
```

- Compiling with other TeX engines

```bash
pdflatex example.tex
citeproc-lua example.aux
pdflatex example.tex
```


## License

The LaTeX package and Lua library are released under MIT license.
The CSL locale files and styles are redistributed under the [Creative Commons Attribution-ShareAlike 3.0 Unported license](https://creativecommons.org/licenses/by-sa/3.0/).
