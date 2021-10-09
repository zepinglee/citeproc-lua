--[[
  Copyright (C) 2021 Zeping Lee
--]]

local util = require("citeproc.citeproc-util")


local formats = {}

formats.html = {
  ["text_escape"] = function (str)
    str = string.gsub(str, "%&", "&#38;")
    str = string.gsub(str, "<", "&#60;")
    str = string.gsub(str, ">", "&#62;")
    for char, sub in pairs(util.superscripts) do
      str = string.gsub(str, char, "<sup>" .. sub .. "</sup>")
    end
    return str
  end,
  ["@font-style/italic"] = "<i>%%STRING%%</i>",
  ["@font-style/oblique"] = "<em>%%STRING%%</em>",
  ["@font-style/normal"] = '<span style="font-style:normal;">%%STRING%%</span>',
  ["@font-variant/small-caps"] = '<span style="font-variant:small-caps;">%%STRING%%</span>',
  ["@font-variant/normal"] = '<span style="font-variant:normal;">%%STRING%%</span>',
  ["@font-weight/bold"] = "<b>%%STRING%%</b>",
  ["@font-weight/normal"] = '<span style="font-weight:normal;">%%STRING%%</span>',
  ["@font-weight/light"] = false,
  ["@text-decoration/none"] = '<span style="text-decoration:none;">%%STRING%%</span>',
  ["@text-decoration/underline"] = '<span style="text-decoration:underline;">%%STRING%%</span>',
  ["@vertical-align/sup"] = "<sup>%%STRING%%</sup>",
  ["@vertical-align/sub"] = "<sub>%%STRING%%</sub>",
  ["@vertical-align/baseline"] = '<span style="baseline">%%STRING%%</span>',
  ["@quotes/true"] = function (str, context)
    local open_quote = context.style:get_term("open-quote"):render(context)
    local close_quote = context.style:get_term("close-quote"):render(context)
    return open_quote .. str .. close_quote
  end,
  ["@quotes/inner"] = function (str, context)
    local open_quote = context.style:get_term("open-inner-quote"):render(context)
    local close_quote = context.style:get_term("close-inner-quote"):render(context)
    return open_quote .. str .. close_quote
  end,
  ["@bibliography/entry"] = function (str, context)
    return '<div class="csl-entry">' .. str .. "</div>"
  end,
  ["@display/block"] = function (str, state)
    return '\n\n    <div class="csl-block">' .. str .. "</div>\n";
  end,
  ["@display/left-margin"] = function (str, state)
    return '\n    <div class="csl-left-margin">' .. str .. "</div>";
  end,
  ["@display/right-inline"] = function (str, state)
    return '<div class="csl-right-inline">' .. str .. "</div>\n  ";
  end,
  ["@display/indent"] = function (str, state)
    return '<div class="csl-indent">' .. str .. "</div>\n  ";
  end,
}

formats.latex = {
  ["text_escape"] = function (str)
    str = str:gsub("\\", "\\textbackslash")
    str = str:gsub("#", "\\#")
    str = str:gsub("$", "\\$")
    str = str:gsub("%%", "\\%")
    str = str:gsub("&", "\\&")
    str = str:gsub("{", "\\{")
    str = str:gsub("}", "\\}")
    str = str:gsub("_", "\\_")
    str = str:gsub(util.unicode["no-break space"], "~")
    for char, sub in pairs(util.superscripts) do
      str = string.gsub(str, char, "\\textsuperscript{" .. sub "}")
    end
    return str
  end,
  ["@font-style/normal"] = "{\\normalshape %%STRING%%}",
  ["@font-style/italic"] = "\\emph{%%STRING%%}",
  ["@font-style/oblique"] = "\\textsl{%%STRING%%}",
  ["@font-variant/normal"] = "{\\normalshape %%STRING%%}",
  ["@font-variant/small-caps"] = "\\textsc{%%STRING%%}",
  ["@font-weight/normal"] = "\\fontseries{m}\\selectfont %%STRING%%",
  ["@font-weight/bold"] = "\\textbf{%%STRING%%}",
  ["@font-weight/light"] = "\\fontseries{l}\\selectfont %%STRING%%",
  ["@text-decoration/none"] = false,
  ["@text-decoration/underline"] = "\\underline{%%STRING%%}",
  ["@vertical-align/sup"] = "\\textsuperscript{%%STRING%%}",
  ["@vertical-align/sub"] = "\\textsubscript{%%STRING%%}",
  ["@vertical-align/baseline"] = false,
  ["@quotes/true"] = function (str, context)
    local open_quote = context.style:get_term("open-quote"):render(context)
    local close_quote = context.style:get_term("close-quote"):render(context)
    return open_quote .. str .. close_quote
  end,
  ["@quotes/inner"] = function (str, context)
    local open_quote = context.style:get_term("open-inner-quote"):render(context)
    local close_quote = context.style:get_term("close-inner-quote"):render(context)
    return open_quote .. str .. close_quote
  end,
  ["@bibliography/entry"] = function (str, context)
    return "\\bibitem[".. context.item.id .. "]{} " .. str
  end
}


return formats
