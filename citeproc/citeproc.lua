--[[
  Copyright (C) 2021 Zeping Lee
--]]


local citeproc = {}

local engine = require("citeproc.citeproc-engine")
local bib = require("citeproc.citeproc-bib")

citeproc.__VERSION__ = "0.0.1"

citeproc.new = engine.CiteProc.new
citeproc.parse_bib = bib.parse

return citeproc
