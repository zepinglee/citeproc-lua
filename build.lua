#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "csl"

docfiledir = "./doc"
sourcefiledir = "./citeproc"
supportdir = "./bin"
testfiledir = "./test/latex"
testsuppdir = "./test/latex/support"

installfiles = {"*.sty", "*.lua", "*.json", "citeproc"}
scriptfiles = {"*.lua", "citeproc"}
-- scriptmanfiles = {"citeproc.1"}
sourcefiles = {"*.sty", "*.lua", "*.json", "citeproc"}
-- tagfiles = {}
-- typesetdemofiles = {}

includetests = {"luatex-1-*"}

checkengines = {"luatex"}
stdengine = "luatex"

checkconfigs = {
  "build",
  "test/latex/config-luatex-2",
  "test/latex/config-other-1",
  "test/latex/config-other-3",
}

checkopts = "-interaction=nonstopmode -shell-escape"

checkruns = 1
-- flatten = false
-- flattentds = false
packtdszip = true

-- tdslocations = {
--   "scripts/csl/*.lua",
--   "tex/latex/csl/citeproc/*.json",
-- }
