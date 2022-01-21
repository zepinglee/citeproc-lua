#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "citation-style-language"

docfiledir = "./doc"
testfiledir = "./test/latex"
testsuppdir = testfiledir .. "/support"

exefiles = {"citeproc", "**/citeproc"}
installfiles = {
  "**/*.sty",
  "**/*.lua",
  "**/citeproc",
  "**/*.json",
  "**/csl-locales-*.xml",
  "**/*.csl",
}
scriptfiles = {"**/*.lua", "**/citeproc"}
scriptmanfiles = {"citeproc.1"}
sourcefiles = {
  "citeproc/*",
  "latex/*",
  "locales/csl-locales-*.xml",
  "styles/*.csl"
}
tagfiles = {
  "latex/citation-style-language.sty",
  "citeproc/citeproc.lua",
  "doc/citation-style-language-doc.tex",
  "doc/citeproc.1",
  "CHANGELOG.md",
}
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
  "tex/latex/citation-style-language/styles/*.csl",
  "tex/latex/citation-style-language/locales/csl-locales-*.xml",
}

function update_tag(file, content, tagname, tagdate)
  local version_pattern = "%d[%d.]*"
  local url_prefix = "https://github.com/zepinglee/citeproc-lua/compare/"
  if file == "citation-style-language.sty" then
    return string.gsub(content,
      "\\ProvidesExplPackage %{citation-style-language%} %{[^}]+%} %{[^}]+%}",
      "\\ProvidesExplPackage {citation-style-language} {" .. tagdate .. "} {" .. tagname .. "}")
  elseif file == "citeproc.lua" then
    return string.gsub(content,
      'citeproc%.__VERSION__ = "' .. version_pattern .. '"',
      'citeproc.__VERSION__ = "' .. string.sub(tagname, 2) .. '"')
  elseif file == "citation-style-language-doc.tex" then
    return string.gsub(content,
      "\\date%{([^}]+)%}",
      "\\date{" .. tagdate .. " " .. tagname .. "}")
  elseif file == "citeproc.1" then
    return string.gsub(content,
      '%.TH citeproc 1 "' .. version_pattern .. '"\n',
      '.TH citeproc 1 "' .. string.sub(tagname, 2) .. '"\n')
  elseif file == "CHANGELOG.md" then
    local previous = string.match(content, "compare/(v" .. version_pattern .. ")%.%.%.HEAD")
    if tagname == previous then return content end
    content = string.gsub(content,
      "## %[Unreleased%]",
      "## [Unreleased]\n\n## [" .. tagname .."]")
    return string.gsub(content,
      "v" .. version_pattern .. "%.%.%.HEAD",
      tagname .. "...HEAD\n[" .. tagname .. "]: " .. url_prefix .. previous
        .. "..." .. tagname)
  end
  return content
end
