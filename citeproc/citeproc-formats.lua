--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local formats = {}

local util = require("citeproc-util")


local InlineElement = {
  type = "InlineElement",
}

function InlineElement:derive(type)
  local o = {
    type = type,
  }
  self[type] = o
  setmetatable(o, self)
  self.__index = self
  return o
end

function InlineElement:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

local Micro = InlineElement:derive("Micro")
local Formatted = InlineElement:derive("Formatted")

local Quoted = InlineElement:derive("Quoted")

function Quoted:new(nodes, quotes)
  local o = {
    children = nodes,
    quotes = quotes,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

local Text = InlineElement:derive("Text")
local Linked = InlineElement:derive("Linked")

local Div = InlineElement:derive("Div")

function Div:new(nodes, display)
  local o = {
    children = nodes,
    div = display,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end




local OutputFormat = {}

function OutputFormat:new(format_name)
  local o = {
    name = format_name,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function OutputFormat:group(nodes, delimiter, formatting)
  -- Each node is list of InlineElements
  if #nodes == 1 then
    return self:format_list(nodes[1])
  else
    nodes = OutputFormat:join_many(nodes, delimiter)
    return self:format_list(nodes)
  end
end

function OutputFormat:format_list(nodes, delimiter, formatting)
  if formatting then
    return {Formatted:new(nodes, formatting)}
  else
    return nodes
  end
end

function OutputFormat:join_many(nodes, delimiter)
  local res = {}
  for i, node in ipairs(nodes) do
    if i > 1 then
      table.insert(res, delimiter)
    end
    for _, el in ipairs(node) do
      table.insert(res, el)
    end
  end
  return res
end

function OutputFormat:affixed_quoted(nodes, affixes, quotes)
  if quotes then
    nodes = self:quoted(nodes, quotes)
  end
  if affixes then
    if affixes.prefix then
      table.insert(nodes, 1, affixes.prefix)
    end
    if affixes.suffix then
      table.insert(nodes, affixes.suffix)
    end
  end
  return nodes
end

function OutputFormat:quoted(nodes, quotes)
  return {Quoted:new(nodes, quotes)}
end

function OutputFormat:with_display(nodes, display)
  if display then
    return {Div:new(nodes, display)}
  else
    return nodes
  end
end

function OutputFormat:output(ir)
  -- TODO: flip-flop
  -- ir = self:flip_flop_inlines(ir)

  -- TODO: move punctuation
  -- ir = self:move_punctuation(ir)

  return self:write_inlines(ir)
end

function OutputFormat:write_inlines(ir)
  local res = ""
  for _, node in ipairs(ir) do
    res = res .. self:write_inline(node)
  end
  return res
end

function OutputFormat:write_inline(inline_element)
  if type(inline_element) == "string" then
    return inline_element
  elseif type(inline_element) == "table" then
    if inline_element.type and inline_element.children then
      local res = ""
      for _, node in ipairs(inline_element.children) do
        res = res .. self:write_inline(node)
      end
      return res
    end
  end
  return ""
end

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
  ["@URL/true"] = function (str, state)
    if state.engine.linking_enabled then
      return string.format('<a href="%s">%s</a>', str, str)
    else
      return str
    end
  end,
  ["@DOI/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://doi.org/" .. str;
      end
      return string.format('<a href="%s">%s</a>', href, str)
    else
      return str
    end
  end,
  ["@PMID/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://www.ncbi.nlm.nih.gov/pubmed/" .. str;
      end
      return string.format('<a href="%s">%s</a>', href, str)
    else
      return str
    end
  end,
  ["@PMCID/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://www.ncbi.nlm.nih.gov/pmc/articles/" .. str;
      end
      return string.format('<a href="%s">%s</a>', href, str)
    else
      return str
    end
  end,
}

formats.latex = {
  ["text_escape"] = function (str)
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
  ["@URL/true"] = function (str, state)
    return "\\url{" .. str .. "}"
  end,
  ["@DOI/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://doi.org/" .. str;
      end
      return string.format("\\href{%s}{%s}", href, str)
    else
      return str
    end
  end,
  ["@PMID/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://www.ncbi.nlm.nih.gov/pubmed/" .. str;
      end
      return string.format("\\href{%s}{%s}", href, str)
    else
      return str
    end
  end,
  ["@PMCID/true"] = function (str, state)
    if state.engine.linking_enabled then
      local href = str
      if not string.match(href, "^https?://") then
        href = "https://www.ncbi.nlm.nih.gov/pmc/articles/" .. str;
      end
      return string.format("\\href{%s}{%s}", href, str)
    else
      return str
    end
  end,
}


formats.OutputFormat = OutputFormat

return formats
