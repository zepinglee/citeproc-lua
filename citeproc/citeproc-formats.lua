--[[
  Copyright (C) 2021 Zeping Lee
--]]

local util = require("citeproc-util")


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
  ["bibstart"] = "<div class=\"csl-bib-body\">\n",
  ["bibend"] = "</div>",
  ["@font-style/italic"] = "<i>%s</i>",
  ["@font-style/oblique"] = "<em>%s</em>",
  ["@font-style/normal"] = '<span style="font-style:normal;">%s</span>',
  ["@font-variant/small-caps"] = '<span style="font-variant:small-caps;">%s</span>',
  ["@font-variant/normal"] = '<span style="font-variant:normal;">%s</span>',
  ["@font-weight/bold"] = "<b>%s</b>",
  ["@font-weight/normal"] = '<span style="font-weight:normal;">%s</span>',
  ["@font-weight/light"] = false,
  ["@text-decoration/none"] = '<span style="text-decoration:none;">%s</span>',
  ["@text-decoration/underline"] = '<span style="text-decoration:underline;">%s</span>',
  ["@vertical-align/sup"] = "<sup>%s</sup>",
  ["@vertical-align/sub"] = "<sub>%s</sub>",
  ["@vertical-align/baseline"] = '<span style="baseline">%s</span>',
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
    return '<div class="csl-entry">' .. str .. "</div>\n"
  end,
  ["@display/block"] = function (str, state)
    return '\n\n    <div class="csl-block">' .. str .. "</div>\n"
  end,
  ["@display/left-margin"] = function (str, state)
    return '\n    <div class="csl-left-margin">' .. str .. "</div>"
  end,
  ["@display/right-inline"] = function (str, state)
    str = util.rstrip(str)
    return '<div class="csl-right-inline">' .. str .. "</div>\n  "
  end,
  ["@display/indent"] = function (str, state)
    return '<div class="csl-indent">' .. str .. "</div>\n  "
  end,
}

formats.latex = {
  ["text_escape"] = function (str)
    if util.startswith(str, "http://") or util.startswith(str, "https://") then
      str = "\\url{" .. str .. "}"
    else
      str = str:gsub("\\", "\\textbackslash")
      str = str:gsub("#", "\\#")
      str = str:gsub("%$", "\\$")
      str = str:gsub("%%", "\\%%")
      str = str:gsub("&", "\\&")
      str = str:gsub("{", "\\{")
      str = str:gsub("}", "\\}")
      str = str:gsub("_", "\\_")
      str = str:gsub(util.unicode["no-break space"], "~")
      for char, sub in pairs(util.superscripts) do
        str = string.gsub(str, char, "\\textsuperscript{" .. sub .. "}")
      end
    end
    return str
  end,
  ["bibstart"] = function (context)
    return string.format("\\begin{thebibliography}{%s}\n", context.build.longest_label)
  end,
  ["bibend"] = "\\end{thebibliography}",
  ["@font-style/normal"] = "{\\normalshape %s}",
  ["@font-style/italic"] = "\\emph{%s}",
  ["@font-style/oblique"] = "\\textsl{%s}",
  ["@font-variant/normal"] = "{\\normalshape %s}",
  ["@font-variant/small-caps"] = "\\textsc{%s}",
  ["@font-weight/normal"] = "\\fontseries{m}\\selectfont %s",
  ["@font-weight/bold"] = "\\textbf{%s}",
  ["@font-weight/light"] = "\\fontseries{l}\\selectfont %s",
  ["@text-decoration/none"] = false,
  ["@text-decoration/underline"] = "\\underline{%s}",
  ["@vertical-align/sup"] = "\\textsuperscript{%s}",
  ["@vertical-align/sub"] = "\\textsubscript{%s}",
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
    if not string.match(str, "\\bibitem") then
      str =  "\\bibitem{".. context.item.id .. "}\n" .. str
    end
    return str .. "\n"
  end,
  ["@display/block"] = function (str, state)
    return str
  end,
  ["@display/left-margin"] = function (str, state)
    if #str > #state.build.longest_label then
      state.build.longest_label = str
    end
    if string.match(str, "%]") then
      str = "{" .. str .. "}"
    end
    return string.format("\\bibitem[%s]{%s}\n", str, state.item.id)
  end,
  ["@display/right-inline"] = function (str, state)
    return str
  end,
  ["@display/indent"] = function (str, state)
    return str
  end,
}


return formats
