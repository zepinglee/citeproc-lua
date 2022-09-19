--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style  = require("citeproc-node-style")
local citation  = require("citeproc-node-citation")
local bibliography  = require("citeproc-node-bibliography")
local locale = require("citeproc-node-locale")
local layout = require("citeproc-node-layout")
local text   = require("citeproc-node-text")
local date   = require("citeproc-node-date")
local number = require("citeproc-node-number")
local names  = require("citeproc-node-names")
local label  = require("citeproc-node-label")
local group  = require("citeproc-node-group")
local choose = require("citeproc-node-choose")
local sort   = require("citeproc-node-sort")

local nodes = {
  ["style"]        = style.Style,
  ["citation"]     = citation.Citation,
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
