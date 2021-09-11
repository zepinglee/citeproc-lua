# citeproc-lua

The `citeproc-lua` is a Lua implementation of the [Citation Style Language](https://citationstyles.org/) (CSL), an XML-based language that defines the formats of citations and bibliography. With a CSL processor (citeproc), references can be generated according to the rules specified in the style. This project aims to provide a replacement for BibTeX, the traditional bibliography processor used for LaTeX.

Some the interfaces and code design are borrowed from [Juris-M/citeproc-js](https://github.com/Juris-M/citeproc-js) and [brechtm/citeproc-py](https://github.com/brechtm/citeproc-py) and thanks to both projects.



## Dependencies

The `citeproc-lua` is written with Lua 5.3 but it has not been tested with other versions.
It is built upon the following packages.

- [michal-h21/LuaXML](https://github.com/michal-h21/LuaXML) ([CTAN](https://ctan.org/pkg/luaxml))
- [michal-h21/lua-uca](https://github.com/michal-h21/lua-uca) ([CTAN](https://ctan.org/pkg/lua-uca)) (to be used)

These packages are available in the latest version of TeX Live. To correctly load the modules in a Lua script, you may state `kpse.set_program_name("luatex")` at the beginning of the file and run it with `texlua` program.



## Usage

A simple example is in the [`example/`](https://github.com/zepinglee/citeproc-lua/tree/main/example) directory.

### Create an engine instance
```lua
local CiteProc = require("citeproc")
local citeproc = CiteProc:new(sys, style)
```

The sys is a table which must contain `retrieveLocale()` and `retrieveItem()` methods. Thet are called to feed the engine with inputs.



### `updateItems()`

The `updateItems()` method refreshes the registry of the engine.
```lua
params, result = citeproc:updateItems(ids)
```
The `ids` is just a list of `id`s.
```lua
ids = {"ITEM-1", "ITEM-2"}
```


### `makeCitationCluster()`

The `makeCitationCluster()` method is called to generate a citation of (possibly) multiple items.

```lua
params, result = citeproc:makeCitationCluster(cite_items)
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
params, result = citeproc:makeBibliography()
```

Returns:
```lua
result = {
  '<div class="csl-entry">B. D’Arcus, <i>Boundaries of Dissent: Protest and State Power in the Media Age</i>, Routledge, 2005.</div>',
  '<div class="csl-entry">F.G. Bennett Jr., “Getting Property Right: ‘Informal’ Mortgages in the Japanese Courts,” <i>Pac. Rim L. &#38; Pol’y J.</i>, vol. 18, Aug. 2009, pp. 463–509.</div>'
}
```



## Running the tests

First clone the two submodules [`test-suite`](https://github.com/citation-style-language/test-suite) and [`locales`](https://github.com/citation-style-language/locales) into the [`test/`](https://github.com/zepinglee/citeproc-lua/tree/main/test) directory.

```bash
git submodule update --init
```

Then you can run the test script [`test/citeproc-test.lua`](https://github.com/zepinglee/citeproc-lua/tree/main/test/citeproc-test.lua).

```bash
texlua test/citepric-test.lua
```

The names of failing tests are printed to [`test/failing_tests.txt`](https://github.com/zepinglee/citeproc-lua/tree/main/test/failing_tests.txt).


You may also run a single test or a subset of tests with common prefix.

```bash
texlua test/citepric-test.lua name_AfterInvertedName
texlua test/citepric-test.lua name_
```

Currently the `citeproc-lua` has passed 315 of 853 tests of test-suite.



# Related material

- CSL
  - [CSL Homepage](https://citationstyles.org/)
  - [CSL 1.0.1 specification](https://docs.citationstyles.org/en/stable/specification.html)
  - [CSL schema](https://github.com/citation-style-language/schema)
  - [CSL processors in other languages](https://citationstyles.org/developers/#csl-processors)
    - [Juris-M/citeproc-js](https://github.com/Juris-M/citeproc-js)
      - [documentation](https://citeproc-js.readthedocs.io/en/latest/)
    - [brechtm/citeproc-py](https://github.com/brechtm/citeproc-py)
    - [zotero/citeproc-rs](https://github.com/zotero/citeproc-rs)
  - [CSL locales](https://github.com/citation-style-language/locales)
  - [CSL styles](https://github.com/citation-style-language/styles)
  - [CSL test-suite](https://github.com/citation-style-language/test-suite)
- Articles
  - [A Citation Style Language (CSL) workshop](https://tug.org/TUGboat/tb35-3/tb111stender.pdf) (TUGboat article)
- Discussions
  - [Citation Style Language vs. biblatex](https://tex.stackexchange.com/questions/434946/citation-style-language-vs-biblatex-vs-possibly-other-citing-systems)
