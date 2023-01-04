#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "citation-style-language"

docfiledir = "./doc"
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
  "citeproc/citeproc.lua",
  "docs/citation-style-language-doc.tex",
  "docs/citeproc-lua.1",
  "latex/citation-style-language.sty",
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
  "tex/latex/citation-style-language/submodules/locales/csl-locales-*.xml",
}

uploadconfig = {
  pkg               = "citation-style-language",
  version           = "0.3.0",
  author            = "Zeping Lee",
  license           = {"mit", "cc-by-sa-3"},
  uploader          = "Zeping Lee",
  email             = "zepinglee@gmail.com",
  summary           = "Bibliography formatting with Citation Style Language",
  description       = [[The Citation Style Language (CSL) is an XML-based language that defines the formats of citations and bibliography. There are currently thousands of styles in CSL including the most widely used APA, Chicago, Vancouver, etc. The citation-style-language package is aimed to provide another reference formatting method for LaTeX that utilizes the CSL styles. It contains a citation processor implemented in pure Lua (citeproc-lua) which reads bibliographic metadata and performs sorting and formatting on both citations and bibliography according to the selected CSL style. A LaTeX package (citation-style-language.sty) is provided to communicate with the processor.]],
  note              = [[Uploaded automatically by l3build...]],
  ctanPath          = "/biblio/citation-style-language",
  repository        = "https://github.com/zepinglee/citeproc-lua",
  bugtracker        = "https://github.com/zepinglee/citeproc-lua/issues",
  topic             = {"biblio", "use-lua"},
  announcement_file = "ctan.ann",
  update            = true,
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
