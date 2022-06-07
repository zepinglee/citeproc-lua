--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local output_module = {}

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
    -- punctuation-in-quote?
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


local InlineElement = {
  type = "InlineElement",
  base_class = "InlineElement",
}

function InlineElement:derive(type)
  local o = {
    type  = type,
    base_class = "InlineElement",
  }
  self[type] = o
  setmetatable(o, self)
  self.__index = self
  o.__index = o
  return o
end

function InlineElement:new(inlines)
  local o = {
    inlines = inlines,
    type  = self.type,
    base_class = self.base_class,
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

function Formatted:new(inlines, formatting)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.formatting = formatting
  setmetatable(o, self)
  return o
end


local Quoted = InlineElement:derive("Quoted")

function Quoted:new(inlines, localized_quotes)
  local o = InlineElement.new(self)
  o.inlines = inlines
  if localized_quotes then
    o.quotes = localized_quotes
  else
    o.quotes = LocalizedQuotes:new()
  end

  setmetatable(o, self)
  return o
end


local NoCase = InlineElement:derive("NoCase")

function NoCase:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


local NoDecor = InlineElement:derive("NoDecor")

function NoDecor:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


local Linked = InlineElement:derive("Linked")

function Linked:new(inlines, href)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.href = href
  setmetatable(o, self)
  return o
end


local Div = InlineElement:derive("Div")

function Div:new(inlines, display)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.div = display
  setmetatable(o, self)
  return o
end


function InlineElement:parse(str)
  -- Return a list of inlines
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

  if el.inlines then
    return el.inlines
  else
    return {el}
  end

end

function InlineElement:from_node(node)
  local tag_name = node:get_element_name()
  local inlines = {}

  for _, child in ipairs(node:get_children()) do
    local inline
    if child:is_text() then
      inline = PlainText:new(child:get_text())
    elseif child:is_element() then
      inline = InlineElement:from_node(child)
    end
    table.insert(inlines, inline)
  end

  if tag_name == "i" then
    return Formatted:new(inlines, {["font-style"] = "italic"})
  elseif tag_name == "b" then
    return Formatted:new(inlines, {["font-weight"] = "bold"})
  elseif tag_name == "sup" then
    return Formatted:new(inlines, {["vertical-align"] = "sup"})
  elseif tag_name == "sub" then
    return Formatted:new(inlines, {["vertical-align"] = "sub"})
  elseif tag_name == "span" then
    local style = node:get_attribute("style")
    local class = node:get_attribute("class")
    if style == "font-variant:small-caps;" or style == "font-variant: small-caps;" then
      return Formatted:new(inlines, {["font-variable"] = "small-caps"})
    elseif class == "nocase" then
      return NoCase:new(inlines)
    elseif class == "nodecor" then
      return NoDecor:new(inlines)
    end
  end

  local el = InlineElement:new()
  el.inlines = inlines
  return el
end

function InlineElement:parse_quotes(inline)
  local quote_fragments = InlineElement:get_quote_fragments(inline)
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

function InlineElement:get_quote_fragments(inline)
  local inlines
  if inline.value then
    inlines = {inline.value}
  else
    inlines = inline.inlines
  end
  local fragments = {}
  for _, inline in ipairs(inlines) do
    if inline.type == "PlainText" then
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
        string.gsub(inline.value, "()(" .. quote .. ")()", function (idx, qt, next_idx)
          table.insert(quote_tuples, {idx, qt, next_idx})
        end)
      end
      table.sort(quote_tuples, function (a, b)
        return a[1] < b[1]
      end)
      local start_idx = 1
      for _, quote_tuple in ipairs(quote_tuples) do
        local idx, qt, next_idx = table.unpack(quote_tuple)
        local fragment = string.sub(inline.value, start_idx, idx-1)
        if fragment ~= "" then
          table.insert(fragments, PlainText:new(fragment))
        end
        table.insert(fragments, qt)
        start_idx = next_idx
      end
      -- Insert last fragment
      local fragment = string.sub(inline.value, start_idx, #inline.value)
      if fragment ~= "" then
        table.insert(fragments, PlainText:new(fragment))
      end
    else
      table.insert(fragments, inline)
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
  elseif self.inlines then
    return self.inlines[1]:get_left_most_string()
  end
end

function InlineElement:get_right_most_string()
  if self.value then
    return self.value
  elseif self.inlines then
    return self.inlines[#self.inlines]:get_left_most_string()
  end
end

function InlineElement:capitalize_first_term()
  if self.type == "PlainText" then
    self.value = util.capitalize(self.value)
  elseif self.inlines[1] then
    self.inlines[1]:capitalize_first_term()
  end
end


local MarkupWriter = {}

function MarkupWriter:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function MarkupWriter:derive()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function MarkupWriter:write_inlines(inlines)
  local res = ""
  for _, node in ipairs(inlines) do
    res = res .. self:write_inline(node)
  end
  return res
end

function MarkupWriter:write_inline(inline)
  if type(inline) == "string" then
    return self:write_escaped(inline)

  elseif type(inline) == "table" then
    -- util.debug(inline.type)
    if inline.type == "PlainText" then
      return self:write_escaped(inline.value)

    elseif inline.type == "InlineElement" then
      return self:write_children(inline)

    elseif inline.type == "Formatted" then
      return self:write_formatted(inline)

    elseif inline.type == "Quoted" then
      return self:write_quoted(inline)

    elseif inline.type == "Div" then
      return self:write_formatted(inline)

    elseif inline.type == "Linked" then
      return self:write_link(inline)

      -- local res = ""
      -- for _, node in ipairs(inline.inlines) do
      --   res = res .. self:write_inline(node)
      -- end
      -- return res

    end
  end
  return ""
end

function MarkupWriter:write_children(inline)
  local res = ""
  for _, child_inline in ipairs(inline.inlines) do
    res = res .. self:write_inline(child_inline)
  end
  return res
end

function MarkupWriter:write_quoted(inline)
  local res = self:write_children(inline)
  local quotes = inline.quotes
  if inline.is_inner then
    return quotes.inner_open .. res .. quotes.inner_close
  else
    return quotes.outer_open .. res .. quotes.outer_close
  end
end


local HtmlWriter = MarkupWriter:derive()

HtmlWriter.markups = {
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
  ["@cite/entry"] = "%s",
  ["@bibliography/entry"] = "<div class=\"csl-entry\">%s</div>\n"
}

function HtmlWriter:write_escaped(str)
  str = string.gsub(str, "%&", "&#38;")
  str = string.gsub(str, "<", "&#60;")
  str = string.gsub(str, ">", "&#62;")
  for char, sub in pairs(util.superscripts) do
    str = string.gsub(str, char, "<sup>" .. sub .. "</sup>")
  end
  return str
end

function HtmlWriter:write_formatted(inline)
  local res = self:write_children(inline)
  for key, value in pairs(inline.formatting) do
    key = "@" .. key .. "/" .. value
    local format_str = self.markups[key]
    if format_str then
      res = string.format(format_str, res)
    end
  end
  return res
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

function OutputFormat:group(inlines_list, delimiter, formatting)
  -- Each node is list of InlineElements
  if #inlines_list == 1 then
    return self:format_list(inlines_list[1], formatting)
  else
    local inlines = OutputFormat:join_many(inlines_list, delimiter)
    return self:format_list(inlines, formatting)
  end
end

function OutputFormat:format_list(inlines, formatting)
  if formatting then
    return {Formatted:new(inlines, formatting)}
  else
    return inlines
  end
end

function OutputFormat:join_many(lists, delimiter)
  local res = {}
  for i, list in ipairs(lists) do
    if delimiter and i > 1 then
      table.insert(res, PlainText:new(delimiter))
    end
    for _, el in ipairs(list) do
      table.insert(res, el)
    end
  end
  return res
end

function OutputFormat:with_format(inlines, formatting)
  return self:format_list(inlines, formatting)
end

function OutputFormat:affixed_quoted(inlines, affixes, localized_quotes)
  if localized_quotes then
    inlines = self:quoted(inlines, localized_quotes)
  end
  if affixes and affixes.prefix then
    table.insert(inlines, 1, PlainText:new(affixes.prefix))
  end
  if affixes and affixes.suffix then
    table.insert(inlines, PlainText:new(affixes.suffix))
  end
  return inlines
end

function OutputFormat:quoted(inlines, localized_quotes)
  return {Quoted:new(inlines, localized_quotes)}
end

function OutputFormat:with_display(nodes, display)
  if display then
    return {Div:new(nodes, display)}
  else
    return nodes
  end
end

function OutputFormat:output(inlines, punctuation_in_quote)
  -- TODO: flip-flop
  -- inlines = self:flip_flop_inlines(inlines)

  if punctuation_in_quote then
    self:move_punctuation(inlines)
  end

  local markup_writer = HtmlWriter:new()

  -- TODO:
  -- if self.format == "html" then
  -- elseif self.format == "latex" then
  -- end

  return markup_writer:write_inlines(inlines)
end

function OutputFormat:output_bibliography_entry(inlines, punctuation_in_quote)
  -- TODO: flip-flop
  -- inlines = self:flip_flop_inlines(inlines)
  if punctuation_in_quote then
    self:move_punctuation(inlines)
  end
  local markup_writer = HtmlWriter:new()
  -- TODO:
  -- if self.format == "html" then
  -- elseif self.format == "latex" then
  -- end
  local res = markup_writer:write_inlines(inlines)
  return string.format(markup_writer.markups["@bibliography/entry"], res)
end

function OutputFormat:move_punctuation(inlines)
  -- TODO
end



output_module.LocalizedQuotes = LocalizedQuotes

output_module.HtmlWriter = HtmlWriter

output_module.InlineElement = InlineElement
output_module.PlainText = PlainText
output_module.Formatted = Formatted
output_module.Quoted = Quoted
output_module.Linked = Linked
output_module.Div = Div
output_module.NoCase = NoCase
output_module.NoDecor = NoDecor

output_module.OutputFormat = OutputFormat

return output_module
