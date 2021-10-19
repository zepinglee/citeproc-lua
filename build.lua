#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "csl"

docfiledir = "./doc"
sourcefiledir = "./citeproc"
testfiledir = "./test"

installfiles = {"*.sty", "*.lua", "*.json"}
scriptfiles = {"citeproc*.lua"}
-- scriptmanfiles = {"citeproc.1"}
sourcefiles = {"*.sty", "*.lua", "*.json"}
-- tagfiles = {}
-- typesetdemofiles = {}

tdslocations = {
  "scripts/csl/citeproc/citeproc*.lua",
  "scripts/csl/*.lua",
  "tex/latex/csl/citeproc/*.json",
}
