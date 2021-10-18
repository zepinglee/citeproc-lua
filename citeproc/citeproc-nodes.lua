--[[
  Copyright (C) 2021 Zeping Lee
--]]


local style  = require("citeproc.citeproc-node-style")
local locale = require("citeproc.citeproc-node-locale")
local layout = require("citeproc.citeproc-node-layout")
local text   = require("citeproc.citeproc-node-text")
local date   = require("citeproc.citeproc-node-date")
local number = require("citeproc.citeproc-node-number")
local names  = require("citeproc.citeproc-node-names")
local label  = require("citeproc.citeproc-node-label")
local group  = require("citeproc.citeproc-node-group")
local choose = require("citeproc.citeproc-node-choose")
local sort   = require("citeproc.citeproc-node-sort")

local nodes = {
  ["style"]        = style.Style,
  ["citation"]     = style.Citation,
  ["bibliography"] = style.Bibliography,
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
