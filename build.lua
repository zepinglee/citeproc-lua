#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "citation-style-language"

docfiledir = "./doc"
testfiledir = "./test/latex"
testsuppdir = testfiledir .. "/support"

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
  "locales/csl-locales-*.xml",
  "styles/*.csl"
}
tagfiles = {
  "CHANGELOG.md",
  "citeproc/citeproc.lua",
  "doc/citation-style-language-doc.tex",
  "doc/citeproc-lua.1",
  "latex/citation-style-language.sty",
}
textfiles = {"doc/README.md", "CHANGELOG.md", "DEPENDS.txt"}
typesetfiles = {"*.tex"}

includetests = {}

checkconfigs = {
  "build",
  "test/latex/config-luatex-1",
  "test/latex/config-luatex-2",
  "test/latex/config-other-1",
  "test/latex/config-other-2",
}

asciiengines = {}
packtdszip = true

tdslocations = {
  "tex/latex/citation-style-language/styles/*.csl",
  "tex/latex/citation-style-language/locales/csl-locales-*.xml",
}

function update_tag(file, content, tagname, tagdate)
  local version_pattern = "%d[%d.]*"
  local url_prefix = "https://github.com/zepinglee/citeproc-lua/compare/"
  if file == "citation-style-language.sty" then
    return string.gsub(content,
      "\\ProvidesExplPackage %{citation%-style%-language%} %{[^}]+%} %{[^}]+%}",
      "\\ProvidesExplPackage {citation-style-language} {" .. tagdate .. "} {v" .. tagname .. "}")
  elseif file == "citeproc.lua" then
    return string.gsub(content,
      'citeproc%.__VERSION__ = "' .. version_pattern .. '"',
      'citeproc.__VERSION__ = "' .. tagname .. '"')
  elseif file == "citation-style-language-doc.tex" then
    return string.gsub(content,
      "\\date%{([^}]+)%}",
      "\\date{" .. tagdate .. " v" .. tagname .. "}")
  elseif file == "citeproc-lua.1" then
    return string.gsub(content,
      '%.TH citeproc-lua 1 "' .. version_pattern .. '"\n',
      '.TH citeproc-lua 1 "' .. tagname .. '"\n')
  elseif file == "CHANGELOG.md" then
    local previous = string.match(content, "compare/v(" .. version_pattern .. ")%.%.%.HEAD")
    if tagname == previous then return content end
    -- print(tagname)
    -- print(previous)
    content = string.gsub(content,
      "## %[Unreleased%]", "## [Unreleased]\n\n## [v" .. tagname .. "] - " .. tagdate)
    content = string.gsub(content,
      "v" .. version_pattern .. "%.%.%.HEAD",
      "v" .. tagname .. "...HEAD\n[v" .. tagname .. "]: " .. url_prefix .. "v" .. previous
        .. "..." .. tagname)
    return content
  end
  return content
end
