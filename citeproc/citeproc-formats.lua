--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local formats = {}

local dom = require("luaxml-domobject")

local util = require("citeproc-util")


local LocalizedQuotes = {
  outer_open = util.unicode['left double quotation mark'],
  outer_close = util.unicode['right double quotation mark'],
  inner_open = util.unicode['left single quotation mark'],
  inner_close = util.unicode['right single quotation mark'],
}

function LocalizedQuotes:new(outer_open, outer_close, inner_open, inner_close)
  local o = {
    outer_open = outer_open or util.unicode['left double quotation mark'],
    outer_close = outer_close or util.unicode['right double quotation mark'],
    inner_open = inner_open or util.unicode['left single quotation mark'],
    inner_close = inner_close or util.unicode['right single quotation mark'],
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


local InlineElement = {
  type = "InlineElement",
}

function InlineElement:derive(type)
  local o = {
    type  = type,
    class = "InlineElement",
  }
  self[type] = o
  setmetatable(o, self)
  self.__index = self
  o.__index = o
  return o
end

function InlineElement:new(children)
  local o = {
    children = children,
    type  = self.type,
    class = "InlineElement",
  }
  setmetatable(o, self)
  return o
end


local PlainText = InlineElement:derive("PlainText")

function PlainText:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


local Formatted = InlineElement:derive("Formatted")

function Formatted:new(nodes, formmatting)
  local o = InlineElement.new(self)
  o.children = nodes
  o.formatting = formmatting
  setmetatable(o, self)
  return o
end


local Quoted = InlineElement:derive("Quoted")

function Quoted:new(nodes, localized_quotes)
  local o = InlineElement.new(self)
  o.children = nodes
  if localized_quotes then
    o.quotes = localized_quotes
  else
    o.quotes = LocalizedQuotes:new()
  end

  setmetatable(o, self)
  return o
end


local NoCase = InlineElement:derive("NoCase")

function NoCase:new(nodes)
  local o = InlineElement.new(self)
  o.children = nodes
  setmetatable(o, self)
  return o
end


local NoDecor = InlineElement:derive("NoDecor")

function NoDecor:new(nodes)
  local o = InlineElement.new(self)
  o.children = nodes
  setmetatable(o, self)
  return o
end


local Linked = InlineElement:derive("Linked")

function Linked:new(nodes, href)
  local o = InlineElement.new(self)
  o.children = nodes
  o.href = href
  setmetatable(o, self)
  return o
end


local Div = InlineElement:derive("Div")

function Div:new(nodes, display)
  local o = InlineElement.new(self)
  o.children = nodes
  o.div = display
  setmetatable(o, self)
  return o
end


function InlineElement:parse(str)
  local html_str = "<div>" .. str .. "</div>"
  local ok, html = pcall(dom.parse, html_str)
  local el
  if ok then
    local div = html:get_path("div")[1]
    el = InlineElement:from_node(div)
  else
    el = PlainText:new(str)
  end

  el = InlineElement:parse_quotes(el)

  if el.children and #el.children == 1 then
    el = el.children[1]
  end

  return el
end

function InlineElement:from_node(node)
  local tag_name = node:get_element_name()
  local child_elements = {}

  for _, child in ipairs(node:get_children()) do
    local el
    if child:is_text() then
      el = PlainText:new(child:get_text())
    elseif child:is_element() then
      el = InlineElement:from_node(child)
    end
    table.insert(child_elements, el)
  end

  if tag_name == "i" then
    return Formatted:new(child_elements, {["font-style"] = "italic"})
  elseif tag_name == "b" then
    return Formatted:new(child_elements, {["font-weight"] = "bold"})
  elseif tag_name == "sup" then
    return Formatted:new(child_elements, {["vertical-align"] = "sup"})
  elseif tag_name == "sub" then
    return Formatted:new(child_elements, {["vertical-align"] = "sub"})
  elseif tag_name == "span" then
    local style = node:get_attribute("style")
    local class = node:get_attribute("class")
    if style == "font-variant:small-caps;" or style == "font-variant: small-caps;" then
      return Formatted:new(child_elements, {["font-variable"] = "small-caps"})
    elseif class == "nocase" then
      return NoCase:new(child_elements)
    elseif class == "nodecor" then
      return NoDecor:new(child_elements)
    end
  end

  local el = InlineElement:new()
  el.children = child_elements
  return el
end

function InlineElement:parse_quotes(element)
  local quote_fragments = InlineElement:get_quote_fragments(element)
  -- util.debug(quote_fragments)

  local quote_stack = {}
  local text_stack = {{}}

  for _, fragment in ipairs(quote_fragments) do
    if type(fragment) == "table" then
      table.insert(text_stack[#text_stack], fragment)
    elseif type(fragment) == "string" then

      local quote = fragment
      local stack_top_quote = nil
      if #quote_stack > 0 then
        stack_top_quote = quote_stack[#quote_stack]
      end

      if quote == "'" then
        if stack_top_quote == "'" then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack])
          table.remove(text_stack, #text_stack)
          table.insert(text_stack[#text_stack], quoted)
        else
          table.insert(quote_stack, quote)
          table.insert(text_stack, {})
        end

      elseif quote == '"' then
        if stack_top_quote == '"' then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack])
          table.remove(text_stack, #text_stack)
          table.insert(text_stack[#text_stack], quoted)
        else
          table.insert(quote_stack, quote)
          table.insert(text_stack, {})
        end

      elseif (quote == util.unicode["right single quotation mark"] and
              stack_top_quote == util.unicode["left single quotation mark"]) or
             (quote == util.unicode["right double quotation mark"] and
              stack_top_quote == util.unicode["left double quotation mark"]) or
             (quote == util.unicode["right-pointing double angle quotation mark"] and
              stack_top_quote == util.unicode["left-pointing double angle quotation mark"]) then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack])
          table.remove(text_stack, #text_stack)
          table.insert(text_stack[#text_stack], quoted)

      else
        table.insert(text_stack[#text_stack], PlainText:new(quote))

      end

    end
  end

  local elements = text_stack[1]
  if #text_stack > 1 then
    assert(#text_stack == #quote_stack + 1)
    for i, quote in ipairs(quote_stack) do
      table.insert(elements, PlainText:new(quote))
      for _, el in ipairs(text_stack[i + 1]) do
        table.insert(elements, el)
      end
    end
  end

  if #elements == 1 then
    return elements[1]
  else
    return InlineElement:new(elements)
  end

end

function InlineElement:get_quote_fragments(element)
  local child_elements
  if element.value then
    child_elements = {element.value}
  else
    child_elements = element.children
  end
  local fragments = {}
  for _, child in ipairs(child_elements) do
    if child.type == "PlainText" then
      local quote_tuples = {}
      for _, quote in ipairs({
        "'",
        '"',
        util.unicode["left single quotation mark"],
        util.unicode["right single quotation mark"],
        util.unicode["left double quotation mark"],
        util.unicode["right double quotation mark"],
        util.unicode["left-pointing double angle quotation mark"],
        util.unicode["right-pointing double angle quotation mark"],
      }) do
        string.gsub(child.value, "()(" .. quote .. ")()", function (idx, qt, next_idx)
          table.insert(quote_tuples, {idx, qt, next_idx})
        end)
      end
      table.sort(quote_tuples, function (a, b)
        return a[1] < b[1]
      end)
      local start_idx = 1
      for _, quote_tuple in ipairs(quote_tuples) do
        local idx, qt, next_idx = table.unpack(quote_tuple)
        local fragment = string.sub(child.value, start_idx, idx-1)
        if fragment ~= "" then
          table.insert(fragments, PlainText:new(fragment))
        end
        table.insert(fragments, qt)
        start_idx = next_idx
      end
      -- Insert last fragment
      local fragment = string.sub(child.value, start_idx, #child.value)
      if fragment ~= "" then
        table.insert(fragments, PlainText:new(fragment))
      end
    else
      table.insert(fragments, child)
    end

    for i = #fragments, 1, -1 do
      local fragment = fragments[i]
      if fragment == "'" or fragment == '"' then
        local left, right
        if i > 1 then
          left = fragments[i - 1]
          if type(left) == "table" then
            left = left:get_right_most_string()
          end
        end
        if i < #fragments then
          right = fragments[i + 1]
          if type(right) == "table" then
            right = right:get_left_most_string()
          end
        end
        -- TODO: consider utf-8
        if not left or string.match(left, "%s$") or string.match(left, "%p$") then
          fragments[i] = "'"
        elseif not right or string.match(right, "%s$") or string.match(right, "^%p") then
          fragments[i] = "'"
        else
          fragments[i] = PlainText:new(util.unicode['apostrophe'])
        end
      end
    end
  end
  return fragments
end

function InlineElement:get_left_most_string()
  if self.value then
    return self.value
  elseif self.children then
    return self.children[1]:get_left_most_string()
  end
end

function InlineElement:get_right_most_string()
  if self.value then
    return self.value
  elseif self.children then
    return self.children[#self.children]:get_left_most_string()
  end
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

function OutputFormat:affixed_quoted(nodes, prefix, suffix, quotes)
  if quotes then
    nodes = self:quoted(nodes, quotes)
  end
  if prefix then
    table.insert(nodes, 1, prefix)
  end
  if suffix then
    table.insert(nodes, suffix)
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

function OutputFormat:write_inline(element)
  if type(element) == "string" then
    return self:write_escaped(element)

  elseif type(element) == "table" then
    -- util.debug(element.type)
    if element.type == "PlainText" then
      return self:write_escaped(element.value)

    elseif element.type == "InlineElement" then
      return self:write_children(element)

    elseif element.type == "Formatted" then
      return self:write_formatted(element)

    elseif element.type == "Quoted" then
      return self:write_quoted(element)

    elseif element.type == "Div" then
      return self:write_formatted(element)

    elseif element.type == "Linked" then
      return self:write_link(element)

      -- local res = ""
      -- for _, node in ipairs(element.children) do
      --   res = res .. self:write_inline(node)
      -- end
      -- return res

    end
  end
  return ""
end

function OutputFormat:write_children(element)
  if element.value then
    return element.value
  elseif element.children then
    local res = ""
    for _, child in ipairs(element.children) do
      res = res .. self:write_inline(child)
    end
    return res
  end
end

function OutputFormat:write_escaped(str)
  str = string.gsub(str, "%&", "&#38;")
  str = string.gsub(str, "<", "&#60;")
  str = string.gsub(str, ">", "&#62;")
  for char, sub in pairs(util.superscripts) do
    str = string.gsub(str, char, "<sup>" .. sub .. "</sup>")
  end
  return str
end

function OutputFormat:write_quoted(element)
  local res = self:write_children(element)
  local quotes = element.quotes
  if element.is_inner then
    return quotes.inner_open .. res .. quotes.inner_close
  else
    return quotes.outer_open .. res .. quotes.outer_close
  end
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


formats.InlineElement = InlineElement
formats.PlainText = PlainText
formats.Formatted = Formatted
formats.Quoted = Quoted
formats.Linked = Linked
formats.Div = Div
formats.NoCase = NoCase
formats.NoDecor = NoDecor

formats.OutputFormat = OutputFormat

return formats
