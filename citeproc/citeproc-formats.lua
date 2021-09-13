--[[
  Copyright (C) 2021 Zeping Lee
--]]

-- Fomatting

local formats = {}

formats.html = {
  ["text_escape"] = function (text)
    text = string.gsub(text, "%&", "&#38;")
    text = string.gsub(text, "<", "&#60;")
    text = string.gsub(text, ">", "&#62;")
    text = string.gsub(text, "%s%s", "\u{00A0}")
    return text
  end,
  ["@font-style/italic"] = "<i>%%STRING%%</i>",
  ["@font-style/oblique"] = "<em>%%STRING%%</em>",
  ["@font-style/normal"] = "<span style=\"font-style:normal;\">%%STRING%%</span>",
  ["@font-variant/small-caps"] = "<span style=\"font-variant:small-caps;\">%%STRING%%</span>",
  ["@font-variant/normal"] = "<span style=\"font-variant:normal;\">%%STRING%%</span>",
  ["@font-weight/bold"] = "<b>%%STRING%%</b>",
  ["@font-weight/normal"] = "<span style=\"font-weight:normal;\">%%STRING%%</span>",
  ["@font-weight/light"] = false,
  ["@text-decoration/none"] = "<span style=\"text-decoration:none;\">%%STRING%%</span>",
  ["@text-decoration/underline"] = "<span style=\"text-decoration:underline;\">%%STRING%%</span>",
  ["@vertical-align/sup"] = "<sup>%%STRING%%</sup>",
  ["@vertical-align/sub"] = "<sub>%%STRING%%</sub>",
  ["@vertical-align/baseline"] = "<span style=\"baseline\">%%STRING%%</span>",
  ["@bibliography/entry"] = function (res, item)
    return "<div class=\"csl-entry\">" .. res .. "</div>"
  end
}

formats.latex = {
  ["text_escape"] = function (text)
    text = text:gsub("\\", "\\textbackslash")
    text = text:gsub("#", "\\#")
    text = text:gsub("$", "\\$")
    text = text:gsub("%%", "\\%")
    text = text:gsub("&", "\\&")
    text = text:gsub("{", "\\{")
    text = text:gsub("}", "\\}")
    text = text:gsub("_", "\\_")
    text = text:gsub("%s%s", "~")
    return text
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
  ["@bibliography/entry"] = function (res, item)
    return "\\bibitem[".. item.id .. "]{} " .. res
  end
}


return formats
