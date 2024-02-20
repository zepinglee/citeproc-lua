#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

local package_repository = "https://github.com/zepinglee/citeproc-lua"

module = "citation-style-language"

local ok, mydata = pcall(require, "zepingleedata.lua")
if not ok then
  mydata = {}
end

docfiledir = "./docs"
-- testfiledir = "./tests/latex"
testsuppdir = "./tests/latex/support"

exefiles = {"citeproc-lua.lua", "**/citeproc-lua.lua"}
installfiles = {
  "**/*.lua",
  "**/*.sty",
  "**/csl-locales-*.xml",
  "**/*.csl",
}
scriptfiles = {"**/*.lua"}
scriptmanfiles = {"citeproc-lua.1"}
sourcefiles = {
  "citeproc/*.lua",
  "latex/*.sty",
  "submodules/locales/csl-locales-*.xml",
  "submodules/styles/*.csl"
}
tagfiles = {
  "CHANGELOG.md",
  "citeproc/*.lua",
  "docs/citation-style-language-doc.tex",
  "docs/citeproc-lua.1",
  "latex/*.sty",
}
textfiles = {"docs/README.md", "CHANGELOG.md", "DEPENDS.txt"}
typesetfiles = {"*.tex"}

checkconfigs = {
  "build",
  "tests/latex/config-luatex-1",
  "tests/latex/config-luatex-2",
  "tests/latex/config-pdftex-1",
  "tests/latex/config-pdftex-2",
}

asciiengines = {}
packtdszip = true

tdslocations = {
  "tex/latex/citation-style-language/styles/*.csl",
  "tex/latex/citation-style-language/locales/csl-locales-*.xml",
}

local package_version = nil
-- local announcement = nil
local version_pattern = "%d[%d.]*"
-- local f = io.open("CHANGELOG.md")
-- if f then
--   local content = f:read("*a")
--   package_version = string.match(content, "## %[(" .. version_pattern .. ")%]")
--   announcement = string.match(content, "(## %[" .. version_pattern .. "%].-\n)%s+## %[")
--   f:close()
-- end

local ctan_uploader = mydata.name or "Zeping Lee"
local ctan_email = mydata.email

uploadconfig = {
  pkg               = "citation-style-language",
  version           = package_version,
  author            = "Zeping Lee",
  license           = {"mit", "cc-by-sa-3"},
  uploader          = ctan_uploader,
  email             = ctan_email,
  summary           = "Bibliography formatting with Citation Style Language",
  description       = [[The Citation Style Language (CSL) is an XML-based language that defines the formats of citations and bibliography. There are currently thousands of styles in CSL including the most widely used APA, Chicago, Vancouver, etc. The citation-style-language package is aimed to provide another reference formatting method for LaTeX that utilizes the CSL styles. It contains a citation processor implemented in pure Lua (citeproc-lua) which reads bibliographic metadata and performs sorting and formatting on both citations and bibliography according to the selected CSL style. A LaTeX package (citation-style-language.sty) is provided to communicate with the processor.]],
  ctanPath          = "/biblio/citation-style-language",
  repository        = package_repository,
  bugtracker        = "https://github.com/zepinglee/citeproc-lua/issues",
  topic             = {"biblio", "use-lua"},
  -- announcement      = announcement,
  update            = true,
}

function update_tag(file, content, tagname, tagdate)
  version = string.gsub(tagname, "^v", "")

  content = string.gsub(content,
    "Copyright %(c%) (%d%d%d%d)%-%d%d%d%d",
    "Copyright (c) %1-" .. os.date("%Y"))

  if file == "CHANGELOG.md" then
    local previous = string.match(content, "compare/v(" .. version_pattern .. ")%.%.%.HEAD")
    if version ~= previous then
      content = string.gsub(content,
        "## %[Unreleased%]",
        "## [Unreleased]\n\n## [" .. version .. "] - " .. tagdate)
      content = string.gsub(content,
        "v" .. version_pattern .. "%.%.%.HEAD",
        "v" .. version .. "...HEAD\n[" .. version .. "]: " .. package_repository .. "/compare/v" .. previous
          .. "...v" .. tagname)
    end

  elseif file == "citeproc.lua" then
    content =  string.gsub(content,
      'citeproc%.__VERSION__ = "' .. version_pattern .. '"',
      'citeproc.__VERSION__ = "' .. version .. '"')

  elseif string.match(file, "%.sty$")then
    content =  string.gsub(content,
      "\\ProvidesExplPackage {(.-)} {.-} {.-}",
      "\\ProvidesExplPackage {%1} {" .. tagdate .. "} {" .. version .. "}")

  elseif string.match(file, "%-doc%.tex$") then
    content =  string.gsub(content,
      "\\date%{([^}]+)%}",
      "\\date{" .. tagdate .. " v" .. version .. "}")

  elseif file == "citeproc-lua.1" then
    content =  string.gsub(content,
      '%.TH citeproc%-lua 1 "' .. version_pattern .. '"\n',
      '.TH citeproc-lua 1 "' .. version .. '"\n')

  end
  return content
end
