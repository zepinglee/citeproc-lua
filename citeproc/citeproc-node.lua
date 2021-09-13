--[[
  Copyright (C) 2021 Zeping Lee
--]]

local Node = {
  Element = require("citeproc.citeproc-node-ELement"),

  style = require("citeproc.citeproc-node-style").style,
  citation = require("citeproc.citeproc-node-style").citation,
  bibliography = require("citeproc.citeproc-node-style").bibliography,

  locale = require("citeproc.citeproc-node-locale"),
  term = require("citeproc.citeproc-node-term"),

  layout = require("citeproc.citeproc-node-layout"),
  text = require("citeproc.citeproc-node-text"),

  date = require("citeproc.citeproc-node-date").date,
  ["date-part"] = require("citeproc.citeproc-node-date")["date-part"],

  number = require("citeproc.citeproc-node-number"),

  names = require("citeproc.citeproc-node-names").names,
  name = require("citeproc.citeproc-node-names").name,
  ["name-part"] = require("citeproc.citeproc-node-names")["name-part"],
  ["et-al"] = require("citeproc.citeproc-node-names")["et-al"],
  ["substitute"] = require("citeproc.citeproc-node-names")["substitute"],

  label = require("citeproc.citeproc-node-label"),
  group = require("citeproc.citeproc-node-group"),

  choose = require("citeproc.citeproc-node-choose").choose,
  ["if"] = require("citeproc.citeproc-node-choose")["if"],
  ["else"] = require("citeproc.citeproc-node-choose")["else"],
  ["else-if"] = require("citeproc.citeproc-node-choose")["else-if"],

  sort = require("citeproc.citeproc-node-sort").sort,
  key = require("citeproc.citeproc-node-sort").key,
}

return Node
