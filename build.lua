#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "csl"

docfiledir = "./doc"
testfiledir = "./test/latex"
testsuppdir = testfiledir .. "/support"

exefiles = {"**/citeproc"}
installfiles = {"**/*.sty", "**/*.lua", "**/citeproc", "**/*.json", "**/csl-locales-*.xml", "**/*.csl"}
scriptfiles = {"**/*.lua", "**/citeproc"}
-- scriptmanfiles = {"citeproc.1"}
sourcefiles = {"citeproc/*", "latex/*", "locales/csl-locales-*.xml", "styles/*.csl"}
-- tagfiles = {}
typesetfiles = {"*.tex"}

includetests = {}

checkconfigs = {
  "build",
  "test/latex/config-luatex-1",
  "test/latex/config-luatex-2",
  "test/latex/config-other-1",
  "test/latex/config-other-3",
}

asciiengines = {}
packtdszip = true

tdslocations = {
  "tex/latex/csl/styles/*.csl",
  "tex/latex/csl/locales/csl-locales-*.xml",
}
