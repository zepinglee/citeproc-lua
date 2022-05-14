# citeproc-lua examples

Note that the API is not stable.

## LaTeX example

1. Intall the package

```bash
make install
```

This command uses `l3build` to install the `.sty` and `.lua` files to `TEXMFHOME` which is usually `~/texmf` on Linux or `~/Library/texmf` on macOS.

2. Compile the document.

For LuaLaTeX, the citations and bibliography can be generated without triggering BibTeX. It takes at most two passes to get the correct labels.

```bash
cd example
lualatex example.tex
lualatex example.tex
```

The `latexmk` can also be used.
```bash
latexmk -cd -lualatex -bibtex- example/example.tex
```

For engines other than LuaLaTeX, the `citeproc` executable is required to run as BibTeX.

```bash
cd example
pdflatex example.tex
citeproc-lua example.aux
pdflatex example.tex
```


The following commands are used for uninstalling from `TEXMFHOME`.

```bash
make uninstall
```

# Bib example

The `citeproc` can also run as a stanalone script to convert a `.bib` database to CSL-JSON format.

```bash
citeproc-lua example/example.bib
```
