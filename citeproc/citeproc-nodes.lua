--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style
local citation
local bibliography
local locale
local layout
local text
local date
local number
local names
local label
local group
local choose
local sort

if kpse then
  style  = require("citeproc-node-style")
  citation  = require("citeproc-node-citation")
  bibliography  = require("citeproc-node-bibliography")
  locale = require("citeproc-node-locale")
  layout = require("citeproc-node-layout")
  text   = require("citeproc-node-text")
  date   = require("citeproc-node-date")
  number = require("citeproc-node-number")
  names  = require("citeproc-node-names")
  label  = require("citeproc-node-label")
  group  = require("citeproc-node-group")
  choose = require("citeproc-node-choose")
  sort   = require("citeproc-node-sort")
else
  style  = require("citeproc.node-style")
  citation  = require("citeproc.node-citation")
  bibliography  = require("citeproc.node-bibliography")
  locale = require("citeproc.node-locale")
  layout = require("citeproc.node-layout")
  text   = require("citeproc.node-text")
  date   = require("citeproc.node-date")
  number = require("citeproc.node-number")
  names  = require("citeproc.node-names")
  label  = require("citeproc.node-label")
  group  = require("citeproc.node-group")
  choose = require("citeproc.node-choose")
  sort   = require("citeproc.node-sort")
end

local nodes = {
  ["style"]        = style.Style,
  ["citation"]     = citation.Citation,
  ["intext"]       = citation.Intext,
  ["bibliography"] = bibliography.Bibliography,
  ["locale"]       = locale.Locale,
  ["term"]         = locale.Term,
  ["layout"]       = layout.Layout,
  ["text"]         = text.Text,
  ["date"]         = date.Date,
  ["date-part"]    = date.DatePart,
  ["number"]       = number.Number,
  ["names"]        = names.Names,
  ["name"]         = names.Name,
  ["name-part"]    = names.NamePart,
  ["et-al"]        = names.EtAl,
  ["substitute"]   = names.Substitute,
  ["label"]        = label.Label,
  ["group"]        = group.Group,
  ["choose"]       = choose.Choose,
  ["if"]           = choose.If,
  ["else"]         = choose.Else,
  ["else-if"]      = choose.ElseIf,
  ["sort"]         = sort.Sort,
  ["key"]          = sort.Key,
}

return nodes
