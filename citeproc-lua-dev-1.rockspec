---@diagnostic disable: codestyle-check, lowercase-global
rockspec_format = "3.0"
package = "citeproc-lua"
version = "dev-1"
source = {
   url = "git+https://github.com/zepinglee/citeproc-lua.git",
}
description = {
   summary = "A Lua implementation of the Citation Style Language (CSL)",
   detailed = "A Lua implementation of the Citation Style Language (CSL).",
   homepage = "https://github.com/zepinglee/citeproc-lua",
   license = "MIT"
}
dependencies = {
   "lua >= 5.3",
   "api7-lua-tinyyaml>=0.4.3",
   "datafile >= 0.8",
   "lpeg >= 1.0.2",
   -- "lua-uca >= 0.1",
   "luautf8 >= 0.1"
   -- "mhluaxml >= 0.1"
}
build = {
   type = "builtin",
   modules = {
      ["citeproc.bibtex-data"] = "citeproc/citeproc-bibtex-data.lua",
      ["citeproc.bibtex-parser"] = "citeproc/citeproc-bibtex-parser.lua",
      ["citeproc.bibtex2csl"] = "citeproc/citeproc-bibtex2csl.lua",
      ["citeproc.context"] = "citeproc/citeproc-context.lua",
      ["citeproc.element"] = "citeproc/citeproc-element.lua",
      ["citeproc.engine"] = "citeproc/citeproc-engine.lua",
      ["citeproc.init"] = "citeproc/citeproc.lua",
      ["citeproc.ir-node"] = "citeproc/citeproc-ir-node.lua",
      ["citeproc.journal-data"] = "citeproc/citeproc-journal-data.lua",
      ["citeproc.latex-data"] = "citeproc/citeproc-latex-data.lua",
      ["citeproc.latex-parser"] = "citeproc/citeproc-latex-parser.lua",
      ["citeproc.lua-uca.collator"] = "submodules/lua-uca/src/lua-uca/lua-uca-collator.lua",
      ["citeproc.lua-uca.ducet"] = "submodules/lua-uca/src/lua-uca/lua-uca-ducet.lua",
      ["citeproc.lua-uca.languages"] = "submodules/lua-uca/src/lua-uca/lua-uca-languages.lua",
      ["citeproc.lua-uca.reordering-table"] = "submodules/lua-uca/src/lua-uca/lua-uca-reordering-table.lua",
      ["citeproc.lua-uca.tailoring"] = "submodules/lua-uca/src/lua-uca/lua-uca-tailoring.lua",
      ["citeproc.lua-uni-algos.case"] = "submodules/lua-uni-algos/lua-uni-case.lua",
      ["citeproc.lua-uni-algos.graphemes"] = "submodules/lua-uni-algos/lua-uni-graphemes.lua",
      ["citeproc.lua-uni-algos.init"] = "submodules/lua-uni-algos/lua-uni-algos.lua",
      -- ["citeproc.lua-uni-algos.normalize"] = "submodules/lua-uni-algos/lua-uni-normalize.lua",
      ["citeproc.lua-uni-algos.parse"] = "submodules/lua-uni-algos/lua-uni-parse.lua",
      ["citeproc.lua-uni-algos.words"] = "submodules/lua-uni-algos/lua-uni-words.lua",
      ["citeproc.luaxml.cssquery"] = "submodules/luaxml/luaxml-cssquery.lua",
      ["citeproc.luaxml.domobject"] = "submodules/luaxml/luaxml-domobject.lua",
      ["citeproc.luaxml.entities"] = "submodules/luaxml/luaxml-entities.lua",
      ["citeproc.luaxml.mod-handler"] = "submodules/luaxml/luaxml-mod-handler.lua",
      ["citeproc.luaxml.mod-xml"] = "submodules/luaxml/luaxml-mod-xml.lua",
      ["citeproc.luaxml.namedentities"] = "submodules/luaxml/luaxml-namedentities.lua",
      ["citeproc.luaxml.parse-query"] = "submodules/luaxml/luaxml-parse-query.lua",
      ["citeproc.luaxml.pretty"] = "submodules/luaxml/luaxml-pretty.lua",
      ["citeproc.luaxml.stack"] = "submodules/luaxml/luaxml-stack.lua",
      ["citeproc.luaxml.testxml"] = "submodules/luaxml/luaxml-testxml.lua",
      ["citeproc.luaxml.transform"] = "submodules/luaxml/luaxml-transform.lua",
      ["citeproc.manager"] = "citeproc/citeproc-manager.lua",
      ["citeproc.node-bibliography"] = "citeproc/citeproc-node-bibliography.lua",
      ["citeproc.node-choose"] = "citeproc/citeproc-node-choose.lua",
      ["citeproc.node-citation"] = "citeproc/citeproc-node-citation.lua",
      ["citeproc.node-date"] = "citeproc/citeproc-node-date.lua",
      ["citeproc.node-group"] = "citeproc/citeproc-node-group.lua",
      ["citeproc.node-label"] = "citeproc/citeproc-node-label.lua",
      ["citeproc.node-layout"] = "citeproc/citeproc-node-layout.lua",
      ["citeproc.node-locale"] = "citeproc/citeproc-node-locale.lua",
      ["citeproc.node-names"] = "citeproc/citeproc-node-names.lua",
      ["citeproc.node-number"] = "citeproc/citeproc-node-number.lua",
      ["citeproc.node-sort"] = "citeproc/citeproc-node-sort.lua",
      ["citeproc.node-style"] = "citeproc/citeproc-node-style.lua",
      ["citeproc.node-text"] = "citeproc/citeproc-node-text.lua",
      ["citeproc.nodes"] = "citeproc/citeproc-nodes.lua",
      ["citeproc.output"] = "citeproc/citeproc-output.lua",
      ["citeproc.unicode"] = "citeproc/citeproc-unicode.lua",
      ["citeproc.util"] = "citeproc/citeproc-util.lua",
      ["citeproc.yaml"] = "citeproc/citeproc-yaml.lua"
   },
   copy_directories = {
      "submodules/unicode-data"
   }
}
test_dependencies = {
   "dkjson >= 2.1.0",
   "luafilesystem >= 1.5.0"
}
test = {
   type = "busted",
   flags = {
      "--lpath=''",
      "--run=citeproc"
   }
}
