# citeproc-lua example

Note that the API is not stable.

## Lua example

The script `simple.lua` loads `citeproc` as a library. Then it reads data from simple.json and process it according to the CSL style `simple.csl` and output to stdout.

```bash
texlua example/simple.lua
```


# Bib example

The `citeproc` can also run as a stanalone script to convert a `.bib` database to CSL-JSON format.

```bash
texlua bin/citeproc example/example.bib
```
