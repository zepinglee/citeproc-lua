# Tests

## `citeproc-lua` tests

The [`busted`](https://olivinelabs.com/busted/#output-handlers) library is required to run the tests. Make sure it is installed with the same Lua version as LuaTeX so that it can be loaded correctly.

```bash
luarocks --lua-dir /usr/local/opt/lua@5.3 --lua-version 5.3 install busted
```

Clone the two submodules [`test-suite`](https://github.com/citation-style-language/test-suite) and [`locales`](https://github.com/citation-style-language/locales) into the [`test/`](https://github.com/zepinglee/citeproc-lua/tree/main/test) directory.

```bash
git submodule update --init
```

Run all the tests from `test-suite`.

```bash
busted --run=citeproc
```

The log is printed to [`test/citeproc-test.log`](https://github.com/zepinglee/citeproc-lua/tree/main/test/citeproc-test.log).
Currently the `citeproc-lua` has passed 600 of 853 tests from test-suite.

Select tests via pattern.

```bash
busted --run=citeproc --filter=sort_CitationNumber
```

Run the test of modules in `citeproc-lua`.

```bash
busted --pattern=formatted_text --filter=quotes
```

# LaTeX tests

```bash
l3build check
l3build check --config test/latex/config-luatex-2 luatex-2-csl
l3build save --config test/latex/config-other-3 other-3-csl
```
