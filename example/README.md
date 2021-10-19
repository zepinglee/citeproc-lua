# citeproc-lua examples

Note that the API is not stable.

## LaTeX example

1. Intall the package

```bash
make install
```

This command uses `l3build` to install the `.sty` and `.lua` files to `TEXMFHOME` which is usually `~/texmf` on Linux or `~/Library/texmf` on macOS.

2. Compile the document with LuaLaTeX.

```bash
latexmk -cd -lualatex -bibtex- example/example.tex
```

Currently only LuaLaTeX is acceptable. Other engines will be supported via a standalone run of `citeproc` in the future.

The following commands is used for uninstalling from `TEXMFHOME`.

```bash
rm -rf "$(kpsewhich -var-value=TEXMFHOME)/scripts/csl"
rm -rf "$(kpsewhich -var-value=TEXMFHOME)/tex/latex/csl"
```

# Bib example

The `citeproc` can also run as a stanalone script to convert a `.bib` database to CSL-JSON format.

```bash
texlua bin/citeproc example/example.bib
```
