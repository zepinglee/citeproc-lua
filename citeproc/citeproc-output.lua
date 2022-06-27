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


function InlineElement:parse(str, context)
  -- Return a list of inlines
  if type(str) ~= "string" then
    print(debug.traceback())
  end
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

  local quote_stack = {}
  local text_stack = {{}}

  local localized_quotes = context:get_localized_quotes()

  for _, fragment in ipairs(quote_fragments) do
    if type(fragment) == "table" then
      if fragment.inlines then
        fragment.inlines = self:parse_quotes(fragment.inlines, context)
      end
      table.insert(text_stack[#text_stack], fragment)

    elseif type(fragment) == "string" then

      local quote = fragment
      local stack_top_quote = nil
      if #quote_stack > 0 then
        stack_top_quote = quote_stack[#quote_stack]
      end

      if quote == "'" then
        if stack_top_quote == "'" and #text_stack[#text_stack] > 0 then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack], localized_quotes)
          table.remove(text_stack, #text_stack)
          table.insert(text_stack[#text_stack], quoted)
        else
          table.insert(quote_stack, quote)
          table.insert(text_stack, {})
        end

      elseif quote == '"' then
        if stack_top_quote == '"' then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack], localized_quotes)
          table.remove(text_stack, #text_stack)
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
              stack_top_quote == util.unicode["left single quotation mark"]) or
             (quote == util.unicode["right double quotation mark"] and
              stack_top_quote == util.unicode["left double quotation mark"]) or
             (quote == util.unicode["right-pointing double angle quotation mark"] and
              stack_top_quote == util.unicode["left-pointing double angle quotation mark"]) then
          table.remove(quote_stack, #quote_stack)
          local quoted = Quoted:new(text_stack[#text_stack], localized_quotes)
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
      if quote == "'" then
        quote = util.unicode["apostrophe"]
      end
      table.insert(elements, PlainText:new(quote))
      for _, el in ipairs(text_stack[i + 1]) do
        table.insert(elements, el)
      end
    end
  end

  return elements
end

function InlineElement:get_quote_fragments(inlines)
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
      return self:write_display(inline)

    elseif inline.type == "Linked" then
      return self:write_link(inline)

    elseif inline.type == "NoCase" or inline.type == "NoDecor" then
      return self:write_inlines(inline.inlines)

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
  ["@bibliography/entry"] = "<div class=\"csl-entry\">%s</div>\n",
  ["@display/block"] = '\n\n    <div class="csl-block">%s</div>\n',
  ["@display/left-margin"] = '\n    <div class="csl-left-margin">%s</div>',
  ["@display/right-inline"] = '<div class="csl-right-inline">%s</div>\n  ',
  ["@display/indent"] = '<div class="csl-indent">%s</div>\n  ',
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

function HtmlWriter:write_display(inline)
  local res = self:write_children(inline)
  local key = string.format("@display/%s", inline.div)
  local format_str = self.markups[key]
  res = string.format(format_str, res)
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
  if inline.type == "PlainText" then
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
    if inline.type == "PlainText" then
      inline.value = self:transform_case(inline.value, text_case, seen_one, is_last, is_uppercase);
      seen_one = seen_one or string_contains_word(inline.value)
    elseif inline.type == "NoCase" or
           inline.type == "NoDecor" or
           (inline.type == "Formatted" and inline.formatting["font-variant"] == "small-caps") or
           (inline.type == "Formatted" and inline.formatting["vertical-align"] == "sup") or
           (inline.type == "Formatted" and inline.formatting["vertical-align"] == "sub") then
      seen_one = seen_one or inline_contains_word(inline)

    elseif inline.type == "Formatted" or inline.type == "Quoted" then
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
  local segments = util.segment_words(str)

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
  self:flip_flop_inlines(inlines)

  self:move_punctuation(inlines)

  -- util.debug(inlines)

  local markup_writer = HtmlWriter:new()

  -- TODO:
  -- if self.format == "html" then
  -- elseif self.format == "latex" then
  -- end

  return markup_writer:write_inlines(inlines)
end

function OutputFormat:output_bibliography_entry(inlines, punctuation_in_quote)
  self:flip_flop_inlines(inlines)
  self:move_punctuation(inlines)
  local markup_writer = HtmlWriter:new()
  -- TODO:
  -- if self.format == "html" then
  -- elseif self.format == "latex" then
  -- end
  local res = markup_writer:write_inlines(inlines)
  return string.format(markup_writer.markups["@bibliography/entry"], res)
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
    if inline.type == "Formatted" then
      local new_state = util.clone(state)
      local formatting = inline.formatting

      for _, attribute in ipairs({"font-style", "font-variant", "font-weight"}) do
        local value = formatting[attribute]
        if value and value~= "normal" then
          if value == state[attribute] then
            formatting[attribute] = "normal"
          end
          new_state[attribute] = formatting[attribute]
        end
      end
      self:flip_flop(inline.inlines, new_state)

    elseif inline.type == "Quoted" then
      inline.is_inner = state.in_inner_quotes
      local new_state = util.clone(state)
      new_state.in_inner_quotes = not new_state.in_inner_quotes
      self:flip_flop(inline.inlines, new_state)

    elseif inline.type == "NoDecor" then
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
            inline.type = "Formatted"
            inline.formatting = {}
          end
          inline.formatting[attr] = value
        end
      end
    end
  end
end

local function find_left(inline)
  if inline.type == "PlainText" then
    return inline
  elseif inline.inlines then
    return find_left(inline.inlines[1])
  else
    return nil
  end
end

local function find_right(inline)
  if inline.type == "PlainText" then
    return inline
  elseif inline.inlines then
    return find_right(inline.inlines[#inline.inlines])
  else
    return nil
  end
end

local function find_right_quoted(inline)
  if inline.type == "Quoted" then
    if inline.quotes.punctuation_in_quote == false then
      return nil
    end
    return find_right(inline.inlines[#inline.inlines])
  elseif inline.inlines then
    return find_right_quoted(inline.inlines[#inline.inlines])
  else
    return nil
  end
end

local function normalise_text_elements(inlines)
  local idx = 1
  local len = #inlines
  while idx < len do
    local first = find_right(inlines[idx])
    if not first then
      return nil
    end

    local second = find_left(inlines[idx+1])
    if not second then
      return nil
    end

    local first_char = string.sub(first.value, -1)
    local second_char = string.sub(second.value, 1, 1)
    if first_char == second_char and (first_char == "," or first_char == ".") then
      second.value = string.sub(second.value, 2)
    end

    idx = idx + 1
  end

end

local function move_around_quote(slice, idx, piq)
  -- util.debug(slice)
  local first = find_right_quoted(slice[idx])
  if not first then
    return nil
  end

  local second = find_left(slice[idx+1])
  if not second then
    return nil
  end

  local first_char = string.sub(first.value, -1)
  local second_char = string.sub(second.value, 1, 1)

  -- util.debug(first_char)
  -- util.debug(second_char)

  if output_module.in_quote_puncts[second_char] then
    if output_module.quote_punctuation_map[first_char] then
      local combined = output_module.quote_punctuation_map[first_char][second_char]
      first.value = string.sub(first.value, 1, -2) .. combined
      second.value = string.sub(second.value, 2)
    else
      first.value = first.value .. second_char
      second.value = string.sub(second.value, 2)
    end
  end

  -- local outside = find_left_text(inlines[idx+1])
  -- local outside_char = string.sub(outside.value, 1, 1)
  -- if util.is_punct(outside_char) then
  -- end

end

function OutputFormat:move_punctuation(inlines, piq)
  normalise_text_elements(inlines)

  local idx = 1
  local len = #inlines
  while idx < len do
    local new_idx = idx + 1
    move_around_quote(inlines, idx, piq)

    idx = new_idx
  end

  for _, inline in ipairs(inlines) do
    if inline.type == "Quoted" or inline.type == "Formatted" or
        inline.type == "Div" then
      self:move_punctuation(inline.inlines)
    end
  end
end

output_module.in_quote_puncts = {
  ["."] = true,
  ["?"] = true,
  -- [":"] = true,
  [","] = true,
  [";"] = true,
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
