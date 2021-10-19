# citeproc-lua

The `citeproc-lua` is a Lua implementation of the [Citation Style Language](https://citationstyles.org/) (CSL), an XML-based language that defines the formats of citations and bibliography. With a CSL processor (citeproc), references can be generated according to the rules specified in the style. This project aims to provide a replacement for BibTeX, the traditional bibliography processor used for LaTeX.

Some the interfaces and code design are borrowed from [Juris-M/citeproc-js](https://github.com/Juris-M/citeproc-js) and [brechtm/citeproc-py](https://github.com/brechtm/citeproc-py) and thanks to both projects.



## Dependencies

The `citeproc-lua` is written with Lua 5.3 but it has not been tested with other versions.
It is built upon the following packages.

- `slnunicode` (Part of LuaTeX)
- [michal-h21/LuaXML](https://github.com/michal-h21/LuaXML) ([CTAN](https://ctan.org/pkg/luaxml))
- [michal-h21/lua-uca](https://github.com/michal-h21/lua-uca) ([CTAN](https://ctan.org/pkg/lua-uca)) (to be used)

These packages are available in the latest version of TeX Live. To correctly load the modules in a Lua script, you may state `kpse.set_program_name("luatex")` at the beginning of the file and run it with `texlua` program.



## Usage

A simple example is in the [`example/`](https://github.com/zepinglee/citeproc-lua/tree/main/example) directory.

Note that the API is not stable and is likely to change in the future.

### Create an engine instance
```lua
local citeproc = require("citeproc")
local engine = citeproc.new(sys, style)
```

The `sys` is a table which must contain `retrieveLocale()` and `retrieveItem()` methods. Thet are called to feed the engine with inputs.



### `updateItems()`

The `updateItems()` method refreshes the registry of the engine.
```lua
params, result = engine:updateItems(ids)
```
The `ids` is just a list of `id`s.
```lua
ids = {"ITEM-1", "ITEM-2"}
```


### `makeCitationCluster()`

The `makeCitationCluster()` method is called to generate a citation of (possibly) multiple items.

```lua
params, result = engine:makeCitationCluster(cite_items)
```

The `cite_items` is a list of tables which contain the `id` and other options (not implemented).

```lua
cite_items = {
  { id = "ITEM-1" },
  { id = "ITEM-2" }
}
```

Returns:
```lua
"(D’Arcus, 2005; Bennett, 2009)"
```

The more complicated method `processCitationCluster()` is not implemented yet.

### `makeBibliography()`

The `makeBibliography()` method produces the bibliography and parameters required for formatting.
```lua
result = engine:makeBibliography()
```

Returns:
```lua
result = {
  {
    hangingindent = false,
    ["second-field-align"] = false,
  },
  {
    '<div class="csl-entry">B. D’Arcus, <i>Boundaries of Dissent: Protest and State Power in the Media Age</i>, Routledge, 2005.</div>',
    '<div class="csl-entry">F.G. Bennett Jr., “Getting Property Right: ‘Informal’ Mortgages in the Japanese Courts,” <i>Pac. Rim L. &#38; Pol’y J.</i>, vol. 18, Aug. 2009, pp. 463–509.</div>'
  }
}
```



## Running the tests

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
Currently the `citeproc-lua` has passed 594 of 853 tests from test-suite.

Select tests via pattern.

```bash
busted --run=citeproc --filter=sort_CitationNumber
```

Run the test of modules in `citeproc-lua`.

```bash
busted --pattern=formatted_text --filter=quotes
```



# Related material

- CSL
  - [CSL Homepage](https://citationstyles.org/)
  - [CSL 1.0.1 specification](https://docs.citationstyles.org/en/stable/specification.html)
  - [CSL 1.0.2 specification](https://github.com/citation-style-language/documentation/blob/master/specification.rst)
  - [CSL 1.1 specification](https://github.com/citation-style-language/documentation/blob/v1.1/specification.rst)
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
