--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local output_module = {}

local unicode = require("unicode")
local dom = require("luaxml-domobject")

local util = require("citeproc-util")


local LocalizedQuotes = {
  outer_open = util.unicode['left double quotation mark'],
  outer_close = util.unicode['right double quotation mark'],
  inner_open = util.unicode['left single quotation mark'],
  inner_close = util.unicode['right single quotation mark'],
  punctuation_in_quote = false,
}

function LocalizedQuotes:new(outer_open, outer_close, inner_open, inner_close, punctuation_in_quote)
  local o = {
    outer_open = outer_open or util.unicode['left double quotation mark'],
    outer_close = outer_close or util.unicode['right double quotation mark'],
    inner_open = inner_open or util.unicode['left single quotation mark'],
    inner_close = inner_close or util.unicode['right single quotation mark'],
    punctuation_in_quote = punctuation_in_quote,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


local InlineElement = {
  _type = "InlineElement",
  _base_class = "InlineElement",
}

function InlineElement:derive(type)
  local o = {
    _type  = type,
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
    _type  = self._type,
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


local Micro = InlineElement:derive("Micro")

-- This is how we can flip-flop only user-supplied styling.
-- Inside this is parsed micro html
function Micro:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


local Quoted = InlineElement:derive("Quoted")

function Quoted:new(inlines, localized_quotes)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.is_inner = false
  if localized_quotes then
    o.quotes = localized_quotes
  else
    o.quotes = LocalizedQuotes:new()
  end

  setmetatable(o, self)
  return o
end


local Code = InlineElement:derive("Code")

function Code:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


local MathML = InlineElement:derive("MathML")

function MathML:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


local MathTeX = InlineElement:derive("MathTeX")

function MathTeX:new(value)
  local o = InlineElement.new(self)
  o.value = value
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

function Linked:new(value, href)
  local o = InlineElement.new(self)
  o.value = value
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


local CiteInline = InlineElement:derive("CiteInline")

function CiteInline:new(inlines, cite_item)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.cite_item = cite_item
  setmetatable(o, self)
  return o
end


function InlineElement:parse(text, context)
  local text_type = type(text)
  local inlines
  if text_type == "table" then
    -- CSL rich text
    inlines = self:parse_csl_rich_text(text)
  elseif text_type == "string" then
    -- String with HTML-like formatting tags
    inlines = self:parse_html_tags(text, context)
  elseif text_type == "number" then
    inlines = {PlainText:new(tostring(text))}
  else
    util.error("Invalid text type")
  end
  return inlines
end

function InlineElement:parse_csl_rich_text(text)
  -- Example: [
  --   "A title with a",
  --   {
  --     "quote": "quoted string."
  --   }
  -- ]
  local inlines = {}

  local text_type = type(text)
  if text_type == "string" then
    table.insert(inlines, PlainText:new(text))
  elseif text_type == "table" then
    for _, subtext in ipairs(text) do
      local subtext_type = type(subtext)
      local inline
      if subtext_type == "string" then
        inline = PlainText:new(subtext)
      elseif subtext_type == "table" then
        local format
        local content
        for format_, content_ in pairs(subtext) do
          format = format_
          content = content_
        end
        if format == "bold" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["font-weight"] = "bold"})
        elseif format == "code" then
          if type(content) ~= "string" then
            util.error("Invalid rich text content.")
          end
          inline = Code:new(content)
        elseif format == "italic" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["font-style"] = "italic"})
        elseif format == "math-ml" then
          if type(content) ~= "string" then
            util.error("Invalid rich text content.")
          end
          inline = Code:new(content)
        elseif format == "math-tex" then
          if type(content) ~= "string" then
            util.error("Invalid rich text content.")
          end
          inline = Code:new(content)
        elseif format == "preserve" then
          inline = NoCase:new(self:parse_csl_rich_text(content))
        elseif format == "quote" then
          inline = Quoted:new(self:parse_csl_rich_text(content))
        elseif format == "sc" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["font-variant"] = "small-caps"})
        elseif format == "strike" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["strike-through"] = true})
        elseif format == "sub" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["font-variant"] = "small-caps"})
        elseif format == "sup" then
          inline = Formatted:new(self:parse_csl_rich_text(content), {["font-variant"] = "small-caps"})
        end
      end
      table.insert(inlines, inline)
    end
  else
    util.error("Invalid text type")
  end

  return inlines
end

function InlineElement:parse_html_tags(str, context)
  -- Return a list of inlines
  -- if type(str) ~= "string" then
  --   print(debug.traceback())
  -- end
  local html_str = "<div>" .. str .. "</div>"
  local ok, html = pcall(dom.parse, html_str)
  local inlines
  if ok then
    local div = html:get_path("div")[1]
    local el = InlineElement:from_node(div)
    inlines = el.inlines
  else
    local el = PlainText:new(str)
    inlines = {el}
  end

  inlines = InlineElement:parse_quotes(inlines, context)
  return inlines
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
  elseif tag_name == "sc" then
    return Formatted:new(inlines, {["font-variant"] = "small-caps"})
  elseif tag_name == "span" then
    local style = node:get_attribute("style")
    local class = node:get_attribute("class")
    if style == "font-variant:small-caps;" or style == "font-variant: small-caps;" then
      return Formatted:new(inlines, {["font-variant"] = "small-caps"})
    elseif class == "nocase" then
      return NoCase:new(inlines)
    elseif class == "nodecor" then
      return NoDecor:new(inlines)
    end
  end

  return InlineElement:new(inlines)
end

function InlineElement:parse_quotes(inlines, context)
  local quote_fragments = InlineElement:get_quote_fragments(inlines)
  -- util.debug(quote_fragments)

  local quote_stack = {}
  local text_stack = {{}}

  local localized_quotes
  if context then
    localized_quotes = context:get_localized_quotes()
  else
    localized_quotes = LocalizedQuotes:new()
  end

  for _, fragment in ipairs(quote_fragments) do
    local top_text_list = text_stack[#text_stack]

    if type(fragment) == "table" then
      if fragment.inlines then
        fragment.inlines = self:parse_quotes(fragment.inlines, context)
      end
      table.insert(top_text_list, fragment)

    elseif type(fragment) == "string" then
      local quote = fragment
      local top_quote = quote_stack[#quote_stack]

      if quote == "'" then
        if top_quote == "'" and #top_text_list > 0 then
          table.remove(quote_stack)
          local quoted = Quoted:new(top_text_list, localized_quotes)
          table.remove(text_stack)
          table.insert(text_stack[#text_stack], quoted)
        else
          table.insert(quote_stack, quote)
          table.insert(text_stack, {})
        end

      elseif quote == '"' then
        if top_quote == '"' then
          table.remove(quote_stack)
          local quoted = Quoted:new(top_text_list, localized_quotes)
          table.remove(text_stack)
          table.insert(text_stack[#text_stack], quoted)
        else
          table.insert(quote_stack, quote)
          table.insert(text_stack, {})
        end

      elseif quote == util.unicode["left single quotation mark"] or
             quote == util.unicode["left double quotation mark"] or
             quote == util.unicode["left-pointing double angle quotation mark"] then
        table.insert(quote_stack, quote)
        table.insert(text_stack, {})

      elseif (quote == util.unicode["right single quotation mark"] and
              top_quote == util.unicode["left single quotation mark"]) or
             (quote == util.unicode["right double quotation mark"] and
              top_quote == util.unicode["left double quotation mark"]) or
             (quote == util.unicode["right-pointing double angle quotation mark"] and
              top_quote == util.unicode["left-pointing double angle quotation mark"]) then
          table.remove(quote_stack)
          local quoted = Quoted:new(top_text_list, localized_quotes)
          table.remove(text_stack)
          table.insert(text_stack[#text_stack], quoted)

      else
        local last_inline = top_text_list[#top_text_list]
        if last_inline and last_inline._type == "PlainText" then
          last_inline.value = last_inline.value .. fragment
        else
          table.insert(top_text_list, PlainText:new(fragment))
        end
      end

    end
  end

  local elements = text_stack[1]
  if #text_stack > 1 then
    -- assert(#text_stack == #quote_stack + 1)
    for i, quote in ipairs(quote_stack) do
      if quote == "'" then
        quote = util.unicode["apostrophe"]
      end
      local last_inline = elements[#elements]
      if last_inline and last_inline._type == "PlainText" then
        last_inline.value = last_inline.value .. quote
      else
        table.insert(elements, PlainText:new(quote))
      end

      for _, inline in ipairs(text_stack[i + 1]) do
        if inline._type == "PlainText" then
          local last_inline = elements[#elements]
          if last_inline and last_inline._type == "PlainText" then
            last_inline.value = last_inline.value .. inline.value
          else
            table.insert(elements, inline)
          end
        else
          table.insert(elements, inline)
        end
      end
    end
  end

  return elements
end

local function merge_fragments_at(fragments, i)
  if type(fragments[i+1]) == "string" then
    fragments[i] = fragments[i] .. fragments[i+1]
    table.remove(fragments, i+1)
  end
  if type(fragments[i-1]) == "string" then
    fragments[i-1] = fragments[i-1] .. fragments[i]
    table.remove(fragments, i)
  end
end

-- Return a list of strings and InlineElement
function InlineElement:get_quote_fragments(inlines)
  local fragments = {}
  for _, inline in ipairs(inlines) do
    if inline._type == "PlainText" then
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
          table.insert(fragments, fragment)
        end
        table.insert(fragments, qt)
        start_idx = next_idx
      end
      -- Insert last fragment
      local fragment = string.sub(inline.value, start_idx, #inline.value)
      if fragment ~= "" then
        table.insert(fragments, fragment)
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
        if left and right then
          if string.match(left, "%s$") and string.match(right, "^%s") then
            -- Orphan quote: bugreports_SingleQuote.txt
            if fragment == "'" then
              fragments[i] = util.unicode['apostrophe']
            end
            merge_fragments_at(fragments, i)
          end
          if not string.match(left, "[%s%p]$") and not string.match(right, "^[%s%p]") then
            if fragment == "'" then
              fragments[i] = util.unicode['apostrophe']
            end
            merge_fragments_at(fragments, i)
          end
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
  -- util.debug(self)
  if self._type == "PlainText" then
    self.value = util.capitalize(self.value)
  elseif self._type ~= "Code" and self._type ~= "MathML" and self._type ~= "MathTeX" then
    if self.inlines[1] then
    self.inlines[1]:capitalize_first_term()
    end
  end
end

--[[
Class inheritance hierarchical

OutputFormat
├── SortStringFormat
├── DisamStringFormat
└── Markup
    ├── LatexWriter
    ├── HtmlWriter
    └── PlainTextWriter
--]]

local OutputFormat = {}

function OutputFormat:new(format_name)
  local o = {
    name = format_name,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function OutputFormat:flatten_ir(ir)
  if self.group_var == "missing" or self.collapse_suppressed then
    return {}
  end
  local inlines = {}
  if ir._type == "SeqIr" or ir._type == "NameIr" then
    inlines = self:flatten_seq_ir(ir)
  else
    inlines = self:with_format(ir.inlines, ir.formatting)
    inlines = self:affixed_quoted(inlines, ir.affixes, ir.quotes);
    inlines = self:with_display(inlines, ir.display);
  end
  return inlines
end

function OutputFormat:flatten_seq_ir(ir)
  -- if not ir.children then
  --   print(debug.traceback())
  -- end
  if #ir.children == 0 then
    return {}
  end
  local inlines_list = {}
  for _, child in ipairs(ir.children) do
    if child.group_var ~= "missing" and not child.collapse_suppressed then
      local child_inlines = self:flatten_ir(child)
      if #child_inlines > 0 then
        table.insert(inlines_list, child_inlines)
      end
    end
  end

  if #inlines_list == 0 then
    return {}
  end

  local inlines = self:group(inlines_list, ir.delimiter, ir.formatting)
  -- assert ir.quotes == localized quotes
  inlines = self:affixed_quoted(inlines, ir.affixes, ir.quotes);
  inlines = self:with_display(inlines, ir.display);
  return inlines
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

function OutputFormat:apply_text_case(inlines, text_case, is_english)
  if not inlines or #inlines == 0 or not text_case then
    return
  end
  -- Title case conversion only affects English-language items.
  if text_case == "title" and not is_english then
    return
  end
  local is_uppercase = false  -- TODO
  self:apply_text_case_inner(inlines, text_case, false, is_uppercase)
end

local function string_contains_word(str)
  return string.match(str, "%w") ~= nil
end

local function inline_contains_word(inline)
  if inline._type == "PlainText" then
    return string_contains_word(inline.value)
  elseif inline.inlines then
    for _, el in ipairs(inline.inlines) do
      if inline_contains_word(el) then
        return true
      end
    end
  end
  return false
end

function OutputFormat:apply_text_case_inner(inlines, text_case, seen_one, is_uppercase)
  for i, inline in ipairs(inlines) do
    if seen_one and text_case == "capitalize-first" then
      break
    end
    local is_last = (i == #inlines)
    if inline._type == "PlainText" then
      inline.value = self:transform_case(inline.value, text_case, seen_one, is_last, is_uppercase);
      seen_one = seen_one or string_contains_word(inline.value)
    elseif inline._type == "NoCase" or
           inline._type == "NoDecor" or
           inline._type == "Code" or
           inline._type == "MathML" or
           inline._type == "MathTeX" or
           (inline._type == "Formatted" and inline.formatting["font-variant"] == "small-caps") or
           (inline._type == "Formatted" and inline.formatting["vertical-align"] == "sup") or
           (inline._type == "Formatted" and inline.formatting["vertical-align"] == "sub") then
      seen_one = seen_one or inline_contains_word(inline)

    elseif inline._type == "Formatted" or inline._type == "Quoted" or inline._type == "CiteInline" then
      seen_one = self:apply_text_case_inner(inline.inlines, text_case, seen_one, is_uppercase) or seen_one
    end
  end
  return seen_one
end

local function transform_lowercase(str)
  return string.gsub(str, utf8.charpattern, unicode.utf8.lower)
end

local function transform_uppercase(str)
  -- TODO: locale specific uppercase: textcase_LocaleUnicode.txt
  return string.gsub(str, utf8.charpattern, unicode.utf8.upper)
end

local function transform_first_word(str, transform)
  -- TODO: [Unicode word boundaries](https://www.unicode.org/reports/tr29/#Word_Boundaries)
  local segments = util.segment_words(str)
  for _, segment in ipairs(segments) do
    if segment[1] ~= "" then
      segment[1] = transform(segment[1])
      break
    end
  end
  local res = ""
  for _, segment in ipairs(segments) do
    res = res .. segment[1] .. segment[2]
  end
  return res
end

local function transform_each_word(str, seen_one, is_last, transform)
  -- util.debug(str)
  local segments = util.segment_words(str)
  -- util.debug(segments)
  -- print(debug.traceback())

  local first_idx
  local last_idx
  for i, segment in ipairs(segments) do
    if segment[1] ~= "" then
      if not first_idx then
        first_idx = i
      end
      last_idx = i
    end
  end

  local immediate_before = ""
  local last_punct = ""
  for i, segment in ipairs(segments) do
    local is_first_word = not seen_one and i == first_idx
    local is_last_word = is_last and i == last_idx
    local follows_colon = (
      last_punct == ":" or
      last_punct == "!" or
      last_punct == "?" or
      last_punct == "?")
    local no_stop_word = is_first_word or is_last_word or follows_colon or (segment[2] == "-" and immediate_before ~= "-")

    if (immediate_before == "." or immediate_before == "-") and #segment[1] == 1 then
    else
      segment[1] = transform(segment[1], no_stop_word)
    end

    if segment[1] ~= "" then
      immediate_before = segment[1]
      last_punct = string.match(segment[1], "(%S)%s*$") or last_punct
    end
    if segment[2] ~= "" then
      immediate_before = segment[2]
      last_punct = string.match(segment[2], "(%S)%s*$") or last_punct
    end
  end
  local res = ""
  for _, segment in ipairs(segments) do
    res = res .. segment[1] .. segment[2]
  end
  return res
end

local function transform_capitalize_word_if_lower(word)
  if util.is_lower(word) then
    return string.gsub(word, utf8.charpattern, unicode.utf8.upper, 1)
  else
    return word
  end
end

local function title_case_word(word, no_stop_word)
  -- Entirely non-English
  -- e.g. "β" in "β-Carotine"
  if string.match(word, "%a") and (not util.stop_words[word] or no_stop_word) and util.is_lower(word) then
    return string.gsub(word, utf8.charpattern, unicode.utf8.upper, 1)
  else
    return word
  end
end

function OutputFormat:transform_case(str, text_case, seen_one, is_last, is_uppercase)
  local res = str
  if text_case == "lowercase" then
    res = transform_lowercase(str)
  elseif text_case == "uppercase" then
    res = transform_uppercase(str)
  elseif text_case == "capitalize-first" then
    res = transform_first_word(str, transform_capitalize_word_if_lower)
  elseif text_case == "capitalize-all" then
    res = transform_each_word(str, false, false, transform_capitalize_word_if_lower)
  elseif text_case == "sentence" then
    -- TODO: if uppercase convert all to lowercase
    res = transform_first_word(str, transform_capitalize_word_if_lower)
  elseif text_case == "title" then
    -- TODO: if uppercase convert all to lowercase
    res = transform_each_word(str, seen_one, is_last, title_case_word)
  end
  return res
end

function OutputFormat:affixed(inlines, affixes)
  if affixes and affixes.prefix then
    table.insert(inlines, 1, PlainText:new(affixes.prefix))
  end
  if affixes and affixes.suffix then
    table.insert(inlines, PlainText:new(affixes.suffix))
  end
  return inlines
end

function OutputFormat:affixed_quoted(inlines, affixes, localized_quotes)
  inlines = util.clone(inlines)
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

function OutputFormat:output(inlines, context)
  self:flip_flop_inlines(inlines)

  self:move_punctuation(inlines)

  -- util.debug(inlines)

  return self:write_inlines(inlines, context)
end

function OutputFormat:output_bibliography_entry(inlines, context)
  self:flip_flop_inlines(inlines)
  -- util.debug(inlines)
  self:move_punctuation(inlines)
  -- TODO:
  -- if self.format == "html" then
  -- elseif self.format == "latex" then
  -- end
  local res = self:write_inlines(inlines, context)
  local markup = self.markups["@bibliography/entry"]
  if type(markup) == "string" then
    res = string.format(markup, res)
  elseif type(markup) == "function" then
    res = markup(res, context)
  end
  return res
end

function OutputFormat:flip_flop_inlines(inlines)
  local flip_flop_state = {
    ["font-style"] = "normal",
    ["font-variant"] = "normal",
    ["font-weight"] = "normal",
    ["text-decoration"] = "none",
    ["vertical-alignment"] = "baseline",
    in_inner_quotes = false,
  }
  self:flip_flop(inlines, flip_flop_state)
end

function OutputFormat:flip_flop(inlines, state)
  for i, inline in ipairs(inlines) do
    if inline._type == "Micro" then
      self:flip_flop_micro_inlines(inline.inlines, state)

    elseif inline._type == "Formatted" then
      local new_state = util.clone(state)
      local formatting = inline.formatting

      for _, attribute in ipairs({"font-style", "font-variant", "font-weight"}) do
        local value = formatting[attribute]
        if value then
          if value == state[attribute] then
            if value == "normal" then
              formatting[attribute] = nil
            -- Formatting outside Micro is not reset to "normal".
            -- else
            --   formatting[attribute] = "normal"
            end
          end
          new_state[attribute] = value
        end
      end
      self:flip_flop(inline.inlines, new_state)

    elseif inline._type == "Quoted" then
      inline.is_inner = state.in_inner_quotes
      local new_state = util.clone(state)
      new_state.in_inner_quotes = not new_state.in_inner_quotes
      self:flip_flop(inline.inlines, new_state)

    elseif inline._type == "NoDecor" then
      local new_state = {
        ["font-style"] = "normal",
        ["font-variant"] = "normal",
        ["font-weight"] = "normal",
        ["text-decoration"] = "none",
      }
      self:flip_flop(inline.inlines, new_state)
      for attr, value in pairs(new_state) do
        if value and state[attr] ~= value then
          if not inline.formatting then
            inline._type = "Formatted"
            inline.formatting = {}
          end
          inline.formatting[attr] = value
        end
      end

    elseif inline._type == "Code" or
        inline._type == "MathML" or
        inline._type == "MathTeX" then
      return

    elseif inline.inlines then  -- Div, ...
      self:flip_flop(inline.inlines, state)
    end
  end
end

function OutputFormat:flip_flop_micro_inlines(inlines, state)
  for i, inline in ipairs(inlines) do
    if inline._type == "Micro" then
      self:flip_flop_micro_inlines(inline.inlines, state)

    elseif inline._type == "Formatted" then
      local new_state = util.clone(state)
      local formatting = inline.formatting

      for _, attribute in ipairs({"font-style", "font-variant", "font-weight"}) do
        local value = formatting[attribute]
        if value then
          if value == state[attribute] then
            if value == "normal" then
              formatting[attribute] = nil
            else
              -- Formatting inside Micro is reset to "normal".
              formatting[attribute] = "normal"
              value = "normal"
            end
          end
          new_state[attribute] = value
        end
      end
      self:flip_flop_micro_inlines(inline.inlines, new_state)

    elseif inline._type == "Quoted" then
      inline.is_inner = state.in_inner_quotes
      local new_state = util.clone(state)
      new_state.in_inner_quotes = not new_state.in_inner_quotes
      self:flip_flop_micro_inlines(inline.inlines, new_state)

    elseif inline._type == "NoDecor" then
      local new_state = {
        ["font-style"] = "normal",
        ["font-variant"] = "normal",
        ["font-weight"] = "normal",
        ["text-decoration"] = "none",
      }
      self:flip_flop_micro_inlines(inline.inlines, new_state)
      for attr, value in pairs(new_state) do
        if value and state[attr] ~= value then
          if not inline.formatting then
            inline._type = "Formatted"
            inline.formatting = {}
          end
          inline.formatting[attr] = value
        end
      end

    elseif inline._type == "Code" or
        inline._type == "MathML" or
        inline._type == "MathTeX" then
      return

    elseif inline.inlines then  -- Div, ...
      self:flip_flop_micro_inlines(inline.inlines, state)
    end
  end
end

local function find_left(inline)
  if inline._type == "PlainText" then
    return inline
  -- elseif inline._type == "Micro" then
  --   return nil
  elseif inline.inlines and #inline.inlines > 0 and inline._type~="Quoted" then
    return find_left(inline.inlines[1])
  else
    return nil
  end
end

local function find_right(inline)
  if inline._type == "PlainText" then
    return inline
  -- elseif inline._type == "Micro" then
  --   return nil
  elseif inline.inlines and #inline.inlines > 0 and inline._type ~= "Quoted" then
    return find_right(inline.inlines[#inline.inlines])
  else
    return nil
  end
end

local function find_right_in_quoted(inline)
  if inline._type == "PlainText" then
    return inline
  -- elseif inline._type == "Micro" then
  --   return nil
  elseif inline.inlines and #inline.inlines > 0 then
    return find_right_in_quoted(inline.inlines[#inline.inlines])
  else
    return nil
  end
end

-- "'Foo,' bar" => ,
local function find_right_quoted(inline)
  if inline._type == "Quoted" and #inline.inlines > 0 then
    return find_right_in_quoted(inline.inlines[#inline.inlines]), inline.quotes.punctuation_in_quote
  -- elseif inline._type == "Micro" then
  --   return nil
  elseif inline.inlines and #inline.inlines > 0 then
    return find_right_quoted(inline.inlines[#inline.inlines])
  else
    return nil, false
  end
end

local function smash_string_push(first, second)
  local first_char = string.sub(first.value, -1)
  local second_char = string.sub(second.value, 1, 1)
  -- util.debug(first_char)
  -- util.debug(second_char)

  local punct_map = output_module.quote_punctuation_map
  if second_char == " " and (first_char == " " or
      util.endswith(first.value, util.unicode["no-break space"])) then
    second.value = string.sub(second.value, 2)
  elseif punct_map[first_char] then
    if first_char == second_char then
      second.value = string.sub(second.value, 2)
    else
      local combined = punct_map[first_char][second_char]
      if combined and #combined == 1 then
        second.value = string.sub(second.value, 2)
        first.value = string.sub(first.value, 1, -2) .. combined
      end
    end
  end
end

local function smash_just_punc(first, second)
  first = find_right(first)  -- PlainText
  second = find_left(second)  -- PlainText
  if first and second then
    local first_char = string.sub(first.value, -1)
    local second_char = string.sub(second.value, 1, 1)
    -- util.debug(first_char)
    -- util.debug(second_char)

    local punct_map = output_module.quote_punctuation_map
    if second_char == " " and (first_char == " " or
        util.endswith(first.value, util.unicode["no-break space"])) then
      second.value = string.sub(second.value, 2)
      return true
    elseif punct_map[first_char] then
      if first_char == second_char then
        second.value = string.sub(second.value, 2)
        return true
      else
        local combined = punct_map[first_char][second_char]
        if combined and #combined == 1 then
          second.value = string.sub(second.value, 2)
          first.value = string.sub(first.value, 1, -2) .. combined
          return true
        end
      end
    end
  else
    return false
  end
end

local function normalise_text_elements(inlines)
  -- 1. Merge punctuations: "?." => "?"
  -- 2. Merge spaces: "  " => " "
  local idx = 1
  while idx < #inlines do
    local first = inlines[idx]
    local second = inlines[idx+1]

    if first._type == "PlainText" and second._type == "PlainText" then
      smash_string_push(first, second)
      first.value = first.value .. second.value
      table.remove(inlines, idx + 1)

    elseif first._type == "Micro" and second._type == "PlainText" then
      local success = smash_just_punc(first, second)
      if success then
        if second.value == "" then
          table.remove(inlines, idx + 1)
        end
      else
        idx = idx + 1
      end

    elseif (first._type == "Formatted" or first._type == "CiteInline")
        and second._type == "PlainText" then
      local success = smash_just_punc(first, second)
      if success then
        if second.value == "" then
          table.remove(inlines, idx + 1)
        end
      else
        idx = idx + 1
      end

    else
      idx = idx + 1
    end
  end

end

local function move_in_quotes(first, second)
  local first_char = string.sub(first.value, -1)
  local second_char = string.sub(second.value, 1, 1)
  local success = false
  if output_module.move_in_puncts[second_char] then
    if first_char == second_char then
      second.value = string.sub(second.value, 2)
      success = true
    elseif output_module.quote_punctuation_map[first_char] then
      local combined = output_module.quote_punctuation_map[first_char][second_char]
      first.value = string.sub(first.value, 1, -2) .. combined
      second.value = string.sub(second.value, 2)
      success = true
    else
      first.value = first.value .. second_char
      second.value = string.sub(second.value, 2)
      success = true
    end
  end
  return success
end

local function move_out_quotes(first, second)
  local first_char = string.sub(first.value, -1)
  local second_char = string.sub(second.value, 1, 1)
  local success = false
  if output_module.move_out_puncts[first_char] then
    if first_char == second_char then
      first.value = string.sub(first.value, 1, -2)
      success = true
    elseif output_module.quote_punctuation_map[second_char] then
      local combined = output_module.quote_punctuation_map[first_char][second_char]
      first.value = string.sub(first.value, 1, -2)
      second.value = combined .. string.sub(second.value, 2)
      success = true
    else
      first.value = string.sub(first.value, 1, -2)
      second.value = first_char .. second.value
      success = true
    end
  end
  return success
end

local function move_around_quote(inlines)
  local idx = 1

  while idx < #inlines do
    -- Move punctuation into quotes as needed
    local first, punctuation_in_quote = find_right_quoted(inlines[idx])

    local second = find_left(inlines[idx+1])
    local success = false
    if first and second then
      if punctuation_in_quote then
        success = move_in_quotes(first, second)
      else
        success = move_out_quotes(first, second)
      end
      if not success then
        idx = idx + 1
      end
    else
      idx = idx + 1
    end
  end
end

function OutputFormat:move_punctuation(inlines, piq)
  -- Merge punctuations
  normalise_text_elements(inlines)

  move_around_quote(inlines)

  for _, inline in ipairs(inlines) do
    if inline._type == "Quoted" or inline._type == "Formatted" or
        inline._type == "Div" or inline._type == "CiteInline" then
      self:move_punctuation(inline.inlines)
    end
  end
end

function OutputFormat:write_inlines(inlines, context)
  local res = ""
  for _, inline in ipairs(inlines) do
    res = res .. self:write_inline(inline, context)
  end
  return res
end

function OutputFormat:write_inline(inline, context)
  if inline.value then
    return self:write_escaped(inline.value, context)
  elseif inline.inlines then
    return self:write_inlines(inline.inlines, context)
  end
  return ""
end

function OutputFormat:write_escaped(str, context)
  return str
end


local Markup = OutputFormat:new()

function Markup:write_inline(inline, context)
  -- if not context then
  --   print(debug.traceback())
  --   error('stop')
  -- end
  if type(inline) == "string" then
    -- Should not happen
    return self:write_escaped(inline, context)

  elseif type(inline) == "table" then
    -- util.debug(inline._type)
    if inline._type == "PlainText" then
      return self:write_escaped(inline.value, context)

    elseif inline._type == "InlineElement" then
      return self:write_inlines(inline.inlines, context)

    elseif inline._type == "Formatted" then
      return self:write_formatted(inline, context)

    elseif inline._type == "Quoted" then
      return self:write_quoted(inline, context)

    elseif inline._type == "Div" then
      return self:write_display(inline, context)

    elseif inline._type == "Linked" then
      return self:write_link(inline, context)

    elseif inline._type == "CiteInline" then
      return self:write_cite(inline, context)

    elseif inline._type == "Code" then
      return self:write_code(inline.inlines, context)

    elseif inline._type == "MathML" then
      return self:write_mathml(inline.inlines, context)

    elseif inline._type == "MathTeX" then
      return self:write_math_tex(inline.inlines, context)

    elseif inline._type == "NoCase" or inline._type == "NoDecor" then
      return self:write_inlines(inline.inlines, context)

    else
      return self:write_inlines(inline.inlines, context)
    end
  end
  return ""
end

function Markup:write_formatted(inline, context)
  return self:write_inlines(inline.inlines, context)
end

function Markup:write_quoted(inline, context)
  local res = self:write_inlines(inline.inlines, context)
  local quotes = inline.quotes
  if inline.is_inner then
    return quotes.inner_open .. res .. quotes.inner_close
  else
    return quotes.outer_open .. res .. quotes.outer_close
  end
end

function Markup:write_display(inline, context)
  return self:write_inlines(inline.inlines, context)
end

function Markup:write_link(inline, context)
  return self:write_escaped(inline.value, context)
end

function Markup:write_cite(inline, context)
  return self:write_inlines(inline.inlines, context)
end


local LatexWriter = Markup:new()

LatexWriter.markups = {
  ["bibstart"] = function (engine)
    return string.format("\\begin{thebibliography}{%s}\n", engine.registry.longest_label)
  end,
  ["bibend"] = "\\end{thebibliography}",
  ["@font-style/normal"] = "{\\normalshape %s}",
  ["@font-style/italic"] = "\\textit{%s}",
  ["@font-style/oblique"] = "\\textsl{%s}",
  ["@font-variant/normal"] = "{\\normalshape %s}",
  ["@font-variant/small-caps"] = "\\textsc{%s}",
  ["@font-weight/normal"] = "{\\fontseries{m}\\selectfont %s}",
  ["@font-weight/bold"] = "\\textbf{%s}",
  ["@font-weight/light"] = "{\\fontseries{l}\\selectfont %s}",
  ["@text-decoration/none"] = false,
  ["@text-decoration/underline"] = "\\underline{%s}",
  ["@vertical-align/sup"] = "\\textsuperscript{%s}",
  ["@vertical-align/sub"] = "\\textsubscript{%s}",
  ["@vertical-align/baseline"] = false,
  ["@cite/entry"] = false,
  ["@bibliography/entry"] = function (str, context)
    if string.match(str, "\\bibitem") then
      str =  str .. "\n"
    else
      str =  "\\bibitem{".. context.id .. "}\n" .. str .. "\n"
    end
    return str
  end,
  -- ["@display/block"] = false,
  -- ["@display/left-margin"] = '\n    <div class="csl-left-margin">%s</div>',
  -- ["@display/right-inline"] = '<div class="csl-right-inline">%s</div>',
  -- ["@display/indent"] = '<div class="csl-indent">%s</div>\n  ',
}

function LatexWriter:write_escaped(str, context)
  -- TeXbook, p. 38
  str = str:gsub("\\", "\\textbackslash{}")
  str = str:gsub("{", "\\{")
  str = str:gsub("}", "\\}")
  str = str:gsub("%$", "\\$")
  str = str:gsub("&", "\\&")
  str = str:gsub("#", "\\#")
  str = str:gsub("%^", "\\^")
  str = str:gsub("_", "\\_")
  str = str:gsub("%%", "\\%%")
  str = str:gsub("~", "\\~")
  str = str:gsub(util.unicode["em space"], "\\quad ")
  str = str:gsub(util.unicode["no-break space"], "~")
  for char, sub in pairs(util.superscripts) do
    str = string.gsub(str, char, "\\textsuperscript{" .. sub .. "}")
  end
  return str
end

function LatexWriter:write_formatted(inline, context)
  local res = self:write_inlines(inline.inlines, context)
  for _, key in ipairs({"font-style", "font-variant", "font-weight", "text-decoration", "vertical-align"}) do
    local value = inline.formatting[key]
    if value then
      key = "@" .. key .. "/" .. value
      local format_str = self.markups[key]
      if format_str then
        res = string.format(format_str, res)
      end
    end
  end
  return res
end

function LatexWriter:write_display(inline, context)
  if inline.div == "left-margin" then
    local plainter_text_writer = output_module.PlainTextWriter:new()
    local str = plainter_text_writer:write_inline(inline, context)
    local len = utf8.len(str)
    if len > context.engine.registry.maxoffset then
      context.engine.registry.maxoffset = len
      context.engine.registry.longest_label = str
    end
  end

  local res = self:write_inlines(inline.inlines, context)
  if inline.div == "left-margin" then
    if string.match(res, "%]") then
      res = "{" .. res .. "}"
    end
    res = string.format("\\bibitem[%s]{%s}\n", res, context.id)

  elseif inline.div == "right-inline" then
    return res

  elseif inline.div == "block" then
    return ""
  end
  return res
end

function LatexWriter:write_link(inline, context)
  if inline.href == inline.value then
    -- URL
    return string.format("\\url{%s}", inline.value)
  elseif context.engine.opt.wrap_url_and_doi then
    return string.format("\\href{%s}{%s}", inline.href, self:write_escaped(inline.value, context))
  else
    return self:write_escaped(inline.value, context)
  end
end

function LatexWriter:write_cite(inline, context)
  local str = self:write_inlines(inline.inlines, context)
  if context.engine.opt.citation_link then
    str = string.format("\\cslcite{%s}{%s}", inline.cite_item.id, str)
  end
  return str
end

function LatexWriter:write_code(inline, context)
  return inline.value
end

function LatexWriter:write_mathml(inline, context)
  util.error("MathML is not supported in LaTeX output.")
  return ""
end

function LatexWriter:write_math_tex(inline, context)
  return string.format("$%s$", inline.value)
end


local HtmlWriter = Markup:new()

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
  ["@cite/entry"] = nil,
  ["@bibliography/entry"] = "<div class=\"csl-entry\">%s</div>\n",
  ["@display/block"] = '\n\n    <div class="csl-block">%s</div>\n',
  ["@display/left-margin"] = '\n    <div class="csl-left-margin">%s</div>',
  ["@display/right-inline"] = '<div class="csl-right-inline">%s</div>\n  ',
  ["@display/indent"] = '<div class="csl-indent">%s</div>\n  ',
}

function HtmlWriter:write_escaped(str, context)
  str = string.gsub(str, "%&", "&#38;")
  str = string.gsub(str, "<", "&#60;")
  str = string.gsub(str, ">", "&#62;")
  for char, sub in pairs(util.superscripts) do
    str = string.gsub(str, char, "<sup>" .. sub .. "</sup>")
  end
  return str
end

function HtmlWriter:write_formatted(inline, context)
  local res = self:write_inlines(inline.inlines, context)
  for _, key in ipairs({"font-style", "font-variant", "font-weight", "text-decoration", "vertical-align"}) do
    local value = inline.formatting[key]
    if value then
      key = "@" .. key .. "/" .. value
      local format_str = self.markups[key]
      if format_str then
        res = string.format(format_str, res)
      end
    end
  end
  return res
end

function HtmlWriter:write_display(inline, context)
  if inline.div == "left-margin" then
    local plainter_text_writer = output_module.PlainTextWriter:new()
    local str = plainter_text_writer:write_inline(inline, context)
    local len = utf8.len(str)
    if len > context.engine.registry.maxoffset then
      context.engine.registry.maxoffset = len
      context.engine.registry.longest_label = str
    end
  end

  if #inline.inlines == 0 then
    return ""
  end
  local res = self:write_inlines(inline.inlines, context)
  local key = string.format("@display/%s", inline.div)
  if inline.div == "right-inline" then
    -- Strip trailing spaces
    -- variables_ContainerTitleShort.txt
    res = string.gsub(res, "%s+$", "")
  end
  local format_str = self.markups[key]
  res = string.format(format_str, res)
  return res
end

function HtmlWriter:write_link(inline, context)
  -- if not context then
  --   print(debug.traceback())
  -- end
  local content = self:write_escaped(inline.value, context)
  if context.engine.opt.wrap_url_and_doi then
    local href = self:write_escaped(inline.href, context)
    return string.format('<a href="%s">%s</a>', href, content)
  else
    return content
  end
end

function HtmlWriter:write_code(inline, context)
  return string.format("<code>%s</code>", inline.value)
end

function HtmlWriter:write_mathml(inline, context)
  return string.format('<math xmlns="http://www.w3.org/1998/Math/MathML">%s</math>', inline.value)
end

function HtmlWriter:write_math_tex(inline, context)
  return string.format("<code>$%s$</code>", self:write_escaped(inline.value, context))
end


local PlainTextWriter = Markup:new()

PlainTextWriter.markups = {}

function PlainTextWriter:write_escaped(str, context)
  return str
end

function PlainTextWriter:write_formatted(inline, context)
  return self:write_inlines(inline.inlines, context)
end

function PlainTextWriter:write_display(inline, context)
  return self:write_inlines(inline.inlines, context)
end


-- Omit formatting and quotes
local SortStringFormat = OutputFormat:new()

function SortStringFormat:output(inlines, context)
  -- self:flip_flop_inlines(inlines)
  -- self:move_punctuation(inlines)
  return self:write_inlines(inlines, context)
end

function SortStringFormat:write_escaped(str, context)
  -- sort_Quotes.txt
  str = string.gsub(str, ",", "")
  return str
end


-- Omit formatting and quotes
local DisamStringFormat = OutputFormat:new()

function DisamStringFormat:output(inlines, context)
  -- self:flip_flop_inlines(inlines)
  -- self:move_punctuation(inlines)
  return self:write_inlines(inlines, context)
end

function DisamStringFormat:flatten_ir(ir)
  if self.group_var == "missing" then
    return {}
  end
  local inlines
  if ir._type == "SeqIr" or ir._type == "NameIr" then
    inlines = self:flatten_seq_ir(ir)
  elseif ir._type == "YearSuffix" then
    -- Don't include year-suffix in disambiguation
    inlines = {}
  else
    inlines = self:affixed_quoted(ir.inlines, ir.affixes, ir.quotes);
    inlines = self:with_display(inlines, ir.display);
  end
  return inlines
end

function DisamStringFormat:flatten_seq_ir(ir)
  -- if not ir.children then
  --   print(debug.traceback())
  -- end
  if #ir.children == 0 then
    return {}
  end
  local inlines_list = {}
  for _, child in ipairs(ir.children) do
    if child.group_var ~= "missing" then
      -- and not child.collapse_suppressed
      -- Suppressed irs are stil kept in the DisamStringFormat
      table.insert(inlines_list, self:flatten_ir(child))
    end
  end

  local inlines = self:group(inlines_list, ir.delimiter, ir.formatting)
  -- assert ir.quotes == localized quotes
  inlines = self:affixed_quoted(inlines, ir.affixes, ir.quotes);
  inlines = self:with_display(inlines, ir.display);

  -- -- A citation layout
  -- if ir._element == "layout" and ir.cite_item then
  --   inlines = {CiteInline:new(inlines, ir.cite_item)}
  -- end

  return inlines
end


function InlineElement.has_space(inlines)
  local str = DisamStringFormat:output(inlines)
  if not str then
    return false
  end
  if string.match(util.strip(str), "%s") then
    return true
  else
    return false
  end
end

output_module.move_in_puncts = {
  ["."] = true,
  ["!"] = true,
  ["?"] = true,
  [","] = true,
}

output_module.move_out_puncts = {
  [","] = true,
  [";"] = true,
  [":"] = true,
}

-- https://github.com/Juris-M/citeproc-js/blob/aa2683f48fe23be459f4ed3be3960e2bb56203f0/src/queue.js#L724
-- Also merge duplicate punctuations.
output_module.quote_punctuation_map = {
  ["!"] = {
    ["."] = "!",
    ["?"] = "!?",
    [":"] = "!",
    [","] = "!,",
    [";"] = "!;",
  },
  ["?"] = {
    ["!"] = "?!",
    ["."] = "?",
    [":"] = "?",
    [","] = "?,",
    [";"] = "?;",
  },
  ["."] = {
    ["!"] = ".!",
    ["?"] = ".?",
    [":"] = ".:",
    [","] = ".,",
    [";"] = ".;",
  },
  [":"] = {
    ["!"] = "!",
    ["?"] = "?",
    ["."] = ":",
    [","] = ":,",
    [";"] = ":;",
  },
  [","] = {
    ["!"] = ",!",
    ["?"] = ",?",
    [":"] = ",:",
    ["."] = ",.",
    [";"] = ",;",
  },
  [";"] = {
    ["!"] = "!",
    ["?"] = "?",
    [":"] = ";",
    [","] = ";,",
    ["."] = ";",
  }
}


output_module.LocalizedQuotes = LocalizedQuotes

output_module.InlineElement = InlineElement
output_module.PlainText = PlainText
output_module.Formatted = Formatted
output_module.Micro = Micro
output_module.Quoted = Quoted
output_module.Linked = Linked
output_module.Div = Div
output_module.CiteInline = CiteInline
output_module.NoCase = NoCase
output_module.NoDecor = NoDecor

output_module.OutputFormat = OutputFormat

output_module.Markup = Markup
output_module.LatexWriter = LatexWriter
output_module.HtmlWriter = HtmlWriter
output_module.PlainTextWriter = PlainTextWriter
output_module.DisamStringFormat = DisamStringFormat
output_module.SortStringFormat = SortStringFormat

return output_module
