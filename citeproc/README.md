# `citeproc-lua`

## Create an engine instance
```lua
local citeproc = require("citeproc")
local engine = citeproc.new(sys, style)
```

The `sys` is a table which must contain `retrieveLocale()` and `retrieveItem()` functions. Thet are called to feed the engine with inputs.



## `updateItems()`

The `updateItems()` method refreshes the registry of the engine.
```lua
params, result = engine:updateItems(ids)
```
The `ids` is just a list of `id`s.
```lua
ids = {"ITEM-1", "ITEM-2"}
```


## `makeCitationCluster()`

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

## `makeBibliography()`

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
