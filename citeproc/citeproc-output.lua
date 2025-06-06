--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local output_module = {}

local lpeg = require("lpeg")
local uni_utf8
local unicode
local ir_node
local util

local using_luatex, _ = pcall(require, "kpse")
if using_luatex then
  uni_utf8 = require("unicode").utf8
  unicode = require("citeproc-unicode")
  ir_node = require("citeproc-ir-node")
  util = require("citeproc-util")
else
  uni_utf8 = require("lua-utf8")
  unicode = require("citeproc.unicode")
  ir_node = require("citeproc.ir-node")
  util = require("citeproc.util")
end

local GroupVar = ir_node.GroupVar


---@class LocalizedQuotes
local LocalizedQuotes = {
  outer_open = util.unicode["left double quotation mark"],
  outer_close = util.unicode["right double quotation mark"],
  inner_open = util.unicode["left single quotation mark"],
  inner_close = util.unicode["right single quotation mark"],
  punctuation_in_quote = false,
}

function LocalizedQuotes:new(outer_open, outer_close, inner_open, inner_close, punctuation_in_quote)
  local o = {
    outer_open = outer_open or util.unicode["left double quotation mark"],
    outer_close = outer_close or util.unicode["right double quotation mark"],
    inner_open = inner_open or util.unicode["left single quotation mark"],
    inner_close = inner_close or util.unicode["right single quotation mark"],
    punctuation_in_quote = punctuation_in_quote,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

-- Inspired by:
-- https://github.com/zotero/citeproc-rs/blob/master/crates/io/src/output/markup.rs#L67
-- https://hackage.haskell.org/package/pandoc-types-1.22.2.1/docs/Text-Pandoc-Definition.html
---@class InlineElement
---@field _type string
---@field _base_class string
---@field value string?
---@field inlines InlineElement[]?
local InlineElement = {
  _type = "InlineElement",
  _base_class = "InlineElement",
  value = nil,
  inlines = nil,
}


---@param class_name string
---@return table
function InlineElement:derive(class_name)
  local o = {
    _type = class_name,
  }
  -- self[class_name] = o
  setmetatable(o, self)
  self.__index = self
  o.__index = o
  return o
end

function InlineElement:new(inlines)
  local o = {
    inlines = inlines,
    _type = self._type,
  }
  setmetatable(o, self)
  return o
end


function InlineElement:_debug(level)
  level = level or 0
  local text = ""
  if level == 0 then
    text = "\n"
  end
  text = text .. self._type
  if self.formatting then
    text = text .. " ["
    for attr, value in pairs(self.formatting) do
      text = text .. attr .. '="' .. value .. '"'
    end
    text = text .. "] "
  end
  if self.is_inner then
    text = text .. " [inner quotes]"
  end
  text = text .. "("
  if self.value then
    text = text .. '"' .. self.value .. '"'
  elseif self.inlines then
    for _, inline in ipairs(self.inlines) do
      text = text .. "\n" .. string.rep("  ", level + 1) .. inline:_debug(level + 1) .. ", "
    end
    text = text .. "\n" .. string.rep("  ", level)
  end
  text = text .. ")"
  return text
end


---@class PlainText: InlineElement
local PlainText = InlineElement:derive("PlainText")

---@param value string
---@return PlainText
function PlainText:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


---@class Formatted: InlineElement
---@field formatting table?
local Formatted = InlineElement:derive("Formatted")

---@param inlines InlineElement[]
---@param formatting table?
---@return Formatted
function Formatted:new(inlines, formatting)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.formatting = formatting
  setmetatable(o, self)
  return o
end


---@class Micro: InlineElement
local Micro = InlineElement:derive("Micro")

-- This is how we can flip-flop only user-supplied styling.
-- Inside this is parsed micro html
---@param inlines InlineElement[]
---@return Micro
function Micro:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


---@class Quoted: InlineElement
---@field is_inner boolean
---@field quotes LocalizedQuotes
local Quoted = InlineElement:derive("Quoted")

---@param inlines InlineElement[]
---@param localized_quotes LocalizedQuotes?
---@param is_inner boolean?
---@return Quoted
function Quoted:new(inlines, localized_quotes, is_inner)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.is_inner = is_inner or false
  if localized_quotes then
    o.quotes = localized_quotes
  else
    o.quotes = LocalizedQuotes:new()
  end

  setmetatable(o, self)
  return o
end


---@class Code: InlineElement
local Code = InlineElement:derive("Code")

---@param value string
---@return Code
function Code:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


---@class MathML: InlineElement
local MathML = InlineElement:derive("MathML")

---@param value string
---@return MathML
function MathML:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


---@class MathTeX: InlineElement
local MathTeX = InlineElement:derive("MathTeX")

---@param value string
---@return MathTeX
function MathTeX:new(value)
  local o = InlineElement.new(self)
  o.value = value
  setmetatable(o, self)
  return o
end


---@class NoCase: InlineElement
local NoCase = InlineElement:derive("NoCase")

---@param inlines InlineElement[]
---@return NoCase
function NoCase:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


---@class NoDecor: InlineElement
local NoDecor = InlineElement:derive("NoDecor")

---@param inlines InlineElement[]
---@return NoDecor
function NoDecor:new(inlines)
  local o = InlineElement.new(self)
  o.inlines = inlines
  setmetatable(o, self)
  return o
end


---@class Linked: InlineElement
---@field href string
local Linked = InlineElement:derive("Linked")

---@param value string
---@param href string
---@return Linked
function Linked:new(value, href)
  local o = InlineElement.new(self)
  o.value = value
  o.href = href
  setmetatable(o, self)
  return o
end


---@class Div: InlineElement
---@field div table?
local Div = InlineElement:derive("Div")

---@param inlines InlineElement[]
---@param display table?
---@return Div
function Div:new(inlines, display)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.div = display
  setmetatable(o, self)
  return o
end


---@class CiteInline: InlineElement
---@field cite_item CitationItem
local CiteInline = InlineElement:derive("CiteInline")

---@param inlines InlineElement[]
---@param cite_item CitationItem
---@return CiteInline
function CiteInline:new(inlines, cite_item)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.cite_item = cite_item
  setmetatable(o, self)
  return o
end


---@class UndefinedCite: InlineElement
---@field cite_item CitationItem
local UndefinedCite = InlineElement:derive("UndefinedCite")

---@param inlines InlineElement[]
---@param cite_item CitationItem
---@return UndefinedCite
function UndefinedCite:new(inlines, cite_item)
  local o = InlineElement.new(self)
  o.inlines = inlines
  o.cite_item = cite_item
  setmetatable(o, self)
  return o
end


---@param text string
---@param context Context?
---@param is_external boolean?
---@return InlineElement[]
function InlineElement:parse(text, context, is_external)
  local text_type = type(text)
  local inlines
  if text_type == "table" then
    -- CSL rich text
    inlines = self:parse_csl_rich_text(text)
  elseif text_type == "string" then
    -- String with HTML-like formatting tags
    inlines = self:parse_html_tags(text, context, is_external)
  elseif text_type == "number" then
    inlines = {PlainText:new(tostring(text))}
  else
    util.error("Invalid text type")
  end
  return inlines
end

---@param text string | (string | table)[]
---@return InlineElement[]
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


local P = lpeg.P
local Ct = lpeg.Ct
local Cp = lpeg.Cp

-- Lua's regex doesn't support groups and thus we have to implement the same
-- logic with `lpeg`.
local code_pattern =
    Ct(Cp() * P("<code>") * Cp()) * ((1 - P("</code>")) ^ 0) *
    Ct(Cp() * P("</code>") * Cp())
    + Ct(Cp() * P("<script>") * Cp()) * ((1 - P("</script>")) ^ 0) *
    Ct(Cp() * P("</script>") * Cp())
    + Ct(Cp() * P("<pre>") * Cp()) * ((1 - P("</pre>")) ^ 0) *
    Ct(Cp() * P("</pre>") * Cp())
    + Ct(Cp() * P("<math>") * Cp()) * ((1 - P("</math>")) ^ 0) * Ct(Cp() * P("</math>") * Cp())
    + Ct(Cp() * P("<math-tex>") * Cp()) * ((1 - P("</math-tex>")) ^ 0) * Ct(Cp() * P("</math-tex>") * Cp())
local basic_tag_pattern = P '<span class="nocase">'
    + P '<span class="nodecor">'
    + P '<span style="font-variant:small-caps;">'
    + P "<sc>"
    + P "<i>"
    + P "<b>"
    + P "<sup>"
    + P "<sub>"
    + P ' "'
    + P " '"
    + P '("'
    + P "('"
    + P "“"
    + P "‘"
    + P "</span>"
    + P "</sc>"
    + P "</i>"
    + P "</b>"
    + P "</sup>"
    + P "</sub>"
    + P '"'
    + P "'"
    + P "”"
    + P "’"

local default_tag_pattern = Ct((code_pattern + Ct(Cp() * basic_tag_pattern * Cp()) + P(1)) ^ 0)

local default_openers_info = {
  ['<span class="nocase">'] = {
    closer = "</span>",
    quotes = false,
  },
  ['<span class="nodecor">'] = {
    closer = "</span>",
    quotes = false,
  },
  ['<span style="font-variant:small-caps;">'] = {
    closer = "</span>",
    quotes = false,
  },
  ["<sc>"] = {
    closer = "</sc>",
    quotes = false,
  },
  ["<i>"] = {
    closer = "</i>",
    quotes = false,
  },
  ["<b>"] = {
    closer = "</b>",
    quotes = false,
  },
  ["<sup>"] = {
    closer = "</sup>",
    quotes = false,
  },
  ["<sub>"] = {
    closer = "</sub>",
    quotes = false,
  },
  [' "'] = {
    closer = '"',
    quotes = true,
  },
  [" '"] = {
    closer = "'",
    quotes = true,
  },
  ["“"] = {
    closer = "”",
    quotes = true,
  },
  ["‘"] = {
    closer = "’",
    quotes = true,
  },
  ["<code>"] = {
    closer = "</code>",
    quotes = false,
  },
  ["<script>"] = {
    closer = "</script>",
    quotes = false,
  },
  ["<pre>"] = {
    closer = "</pre>",
    quotes = false,
  },
  ["<math>"] = {
    closer = "</math>",
    quotes = false,
  },
  ["<math-tex>"] = {
    closer = "</math-tex>",
    quotes = false,
  },
}

local function _quoted(str)
  str = string.gsub(str, "'", "\'")
  return string.format("'%s'", str)
end

---@param locale string
---@param context Context
local function make_locale_tag_info(locale, context)
  if context.engine.locale_tags_info_dict[locale] then
    return
  end
  local localed_quotes = context:get_localized_quotes()

  local tag_pattern = basic_tag_pattern
  local openers_info = util.deep_copy(default_openers_info)

  if localed_quotes.outer_open and localed_quotes.outer_close then
    tag_pattern = tag_pattern + P(_quoted(localed_quotes.outer_open))
    tag_pattern = tag_pattern + P(_quoted(localed_quotes.outer_close))

    openers_info[localed_quotes.outer_open] = {
      closer = localed_quotes.outer_close,
      quotes = true,
      inner = false,
    }
  end

  if localed_quotes.inner_open and localed_quotes.inner_close then
    tag_pattern = tag_pattern + P(_quoted(localed_quotes.inner_open))
    tag_pattern = tag_pattern + P(_quoted(localed_quotes.inner_close))

    openers_info[localed_quotes.inner_open] = {
      closer = localed_quotes.inner_close,
      quotes = true,
      inner = true,
    }
  end

  context.engine.locale_tags_info_dict[locale] = {
    tag_pattern = Ct((code_pattern + Ct(Cp() * tag_pattern * Cp()) + P(1)) ^ 0),
    openers_info = openers_info,
  }
end


local straight_quotes_flip = {
  [" '"] = ' "',
  [' "'] = " '",
};

---@param str any
---@param context Context?
---@return string[]
---@return string[]
local function split_tags_and_strings(str, context)
  local tags = {}
  local strings = {}

  str = string.gsub(str, '(<span)%s+(style="font%-variant:)%s*(small%-caps);?"[^>]*(>)', '%1 %2%3;"%4');

  str = string.gsub(str, '(<span)%s+(class="nocase")[^>]*(>)', "%1 %2%3");
  str = string.gsub(str, '(<span)%s+(class="nodecor")[^>]*(>)', "%1 %2%3");

  local tag_pattern = default_tag_pattern
  local openers_info = default_openers_info
  if context and context.lang then
    tag_pattern = context.engine.locale_tags_info_dict[context.lang].tag_pattern
  end

  local tag_positions_list = lpeg.match(tag_pattern, str)
  if not tag_positions_list then
    error("Pattern not match")
  end
  local start = 1
  local stop = 1
  local new_stop = 1
  for _, postion_tuple in ipairs(tag_positions_list) do
    start, new_stop = table.unpack(postion_tuple)
    table.insert(strings, string.sub(str, stop, start - 1))
    table.insert(tags, string.sub(str, start, new_stop - 1))
    stop = new_stop
  end
  table.insert(strings, string.sub(str, stop, -1))

  for i, tag in ipairs(tags) do
    if string.match(tag, "^.['\"]$") then
      strings[i] = strings[i] .. string.sub(tag, 1, 1)
      tags[i] = " " .. string.sub(tag, 2)
    elseif (tag == "'" or tag == '"') and strings[i] == "" and (i == 1 or openers_info[tags[i - 1]]) then
      -- See `bugreports_NoCaseEscape.txt`.
      -- '"PIAAC-Longitudinal (PIAAC-L) 2015"'
      -- <span class=\"nocase\">\"PIAAC-Longitudinal (PIAAC-Lx) 2015\"</span>
      tags[i] = " " .. tag
    end
  end

  return tags, strings
end


---@param tag string
---@param str string
---@return string?
local function _apostrophe_force(tag, str)
  if tag == "'" or tag == "’" then
    if str ~= "" and string.match(str, "^[^,.?:; ]") then
      return util.unicode["right single quotation mark"]
    end
  elseif (tag == " '" or tag == "’") and str ~= "" and string.match(str, "^%s") then
    return util.unicode["right single quotation mark"]
  end
  return nil
end


---@param quote string
---@param openers_info table
local function set_outer_quote_form(quote, openers_info)
  openers_info[quote].inner = false;
  openers_info[straight_quotes_flip[quote]].inner = true;
end


---@param tag string
---@param inlines InlineElement[]
---@param openers_info table
---@param context Context
---@return InlineElement
local function make_inline_from_tag(tag, inlines, openers_info, context)
  if tag == '<span class="nocase">' then
    return NoCase:new(inlines)
  elseif tag == '<span class="nodecor">' then
    return NoDecor:new(inlines)
  elseif tag == '<span style="font-variant:small-caps;">' then
    return Formatted:new(inlines, {["font-variant"] = "small-caps"})
  elseif tag == "<sc>" then
    return Formatted:new(inlines, {["font-variant"] = "small-caps"})
  elseif tag == "<i>" then
    return Formatted:new(inlines, {["font-style"] = "italic"})
  elseif tag == "<b>" then
    return Formatted:new(inlines, {["font-weight"] = "bold"})
  elseif tag == "<sup>" then
    return Formatted:new(inlines, {["vertical-align"] = "sup"})
  elseif tag == "<sub>" then
    return Formatted:new(inlines, {["vertical-align"] = "sub"})
  elseif openers_info[tag] and openers_info[tag].quotes then
    local localized_quotes = context:get_localized_quotes()
    return Quoted:new(inlines, localized_quotes, openers_info[tag].inner)
  elseif tag == "<code>" or tag == "<script>" or tag == "<pre>" then
    return Code:new(inlines[1].value)
  elseif tag == "<math>" or tag == "<math-tex>" then
    return MathTeX:new(inlines[1].value)
  else
    error(string.format("Invalid tag '%s'", tag))
    return PlainText:new("")
  end
end


--- processTags() in
--- <https://github.com/Juris-M/citeproc-js/blob/master/src/util_flipflop.js#L474>
---@param str string
---@param context Context?
---@param is_external boolean?
---@return InlineElement[]
function InlineElement:parse_html_tags(str, context, is_external)
  if str == "" then
    return {}
  end

  str = string.gsub(str, "(\u{00ab}) ", "\u{00ab}\u{202f}")
  str = string.gsub(str, " (\u{00bb})", "\u{202f}%1")
  str = string.gsub(str, " ([:;?!])", "\u{202f}%1")
  -- str = " " .. string.gsub(str, util.unicode["right single quotation mark"], "'")

  local openers_info = default_openers_info
  if context and context.lang then
    if not context.engine.locale_tags_info_dict[context.lang] then
      make_locale_tag_info(context.lang, context)
    end
    openers_info = context.engine.locale_tags_info_dict[context.lang].openers_info
  end

  local tags, strings = split_tags_and_strings(str, context)

  -- if #tags == 0 then
  --   return {PlainText:new(str)}
  -- end

  ---@type {tag: string, closer: string, pos: number}[]
  local opener_stack = {}

  for i, tag in ipairs(tags) do
    local apostrophe = _apostrophe_force(tag, strings[i + 1])
    if apostrophe then
      strings[i + 1] = apostrophe .. strings[i + 1]
      tags[i] = "";
    else
      local opener_info = openers_info[tag]
      local last_opener_info = opener_stack[#opener_stack]
      if opener_info then
        if opener_info.quotes and last_opener_info and tag == last_opener_info.tag then
          local pos = last_opener_info.pos
          strings[pos + 1] = string.gsub(tag, "^%s", "") .. strings[pos + 1]
          tags[pos] = "";
          table.remove(opener_stack)
        end
        table.insert(opener_stack, {
          tag = tag,
          closer = openers_info[tag].closer,
          pos = i,
        })
      else
        -- Closer tag
        if last_opener_info then
          if last_opener_info.closer == tag then
            table.remove(opener_stack)
          else
            if tag == "'" or tag == "’" then
              strings[i + 1] = "’" .. strings[i + 1]
              tags[i] = ""
            else
              while #opener_stack > 0 and opener_stack[#opener_stack].closer ~= tag do
                local pos = opener_stack[#opener_stack].pos
                strings[pos + 1] = tags[pos] .. strings[pos + 1]
                tags[pos] = ""
                table.remove(opener_stack)
              end
              if #opener_stack > 0 then
                table.remove(opener_stack)
              else
                strings[i + 1] = tags[i] .. strings[i + 1]
                tags[i] = ""
              end
            end
          end
        else
          if tag == "'" or tag == "’" then
            strings[i + 1] = "’" .. strings[i + 1]
            tags[i] = ""
          else
            strings[i + 1] = tags[i] .. strings[i + 1]
            tags[i] = ""
          end
        end
      end
    end
  end

  -- Process remainders in the stack
  if #opener_stack > 0 then
    for _, opener_info in ipairs(opener_stack) do
      local pos = opener_info.pos
      local orphan = string.gsub(tags[pos], "^%s", "")
      orphan = string.gsub(orphan, "'", "’")
      strings[pos + 1] = orphan .. strings[pos + 1]
      tags[pos] = ""
    end
  end

  -- Remove empty tag
  for i = #tags, 1, -1 do
    local tag = tags[i]
    if tag == "" then
      strings[i + 1] = strings[i] .. strings[i + 1]
      table.remove(strings, i)
      table.remove(tags, i)
    end
  end

  -- The first appearance of straight quote is treated as outer quote.
  for _, tag in ipairs(tags) do
    if straight_quotes_flip[tag] then
      set_outer_quote_form(tag, openers_info)
      break
    end
  end

  ---@type InlineElement[]
  local output = {}

  if strings[1] ~= "" then
    table.insert(output, PlainText:new(strings[1]))
  end

  ---@type {tag: string, closer: string, pos: number, output_pos: number}[]
  opener_stack = {}

  for i, tag in ipairs(tags) do
    if openers_info[tag] then
      table.insert(opener_stack, {
        tag = tag,
        closer = openers_info[tag].closer,
        pos = i,
        output_pos = #output + 1,
      })
    else
      assert(#opener_stack > 0)
      local opener_info = opener_stack[#opener_stack]
      assert(opener_info.closer == tag)
      local output_pos = opener_info.output_pos
      local inlines = util.slice(output, output_pos)
      for j = #output, output_pos, -1 do
        table.remove(output, j)
      end
      table.remove(opener_stack)
      local inline = make_inline_from_tag(opener_info.tag, inlines, openers_info, context)
      if inline._type == "Quoted" then
        ---@cast inline Quoted
        local quotes = context:get_localized_quotes()
        inline.punctuation_in_quote = quotes.punctuation_in_quote
      end
      table.insert(output, inline)
    end

    if strings[i + 1] ~= "" then
      table.insert(output, PlainText:new(strings[i + 1]))
    end

  end

  return output
end

local function merge_fragments_at(fragments, i)
  if type(fragments[i + 1]) == "string" then
    fragments[i] = fragments[i] .. fragments[i + 1]
    table.remove(fragments, i + 1)
  end
  if type(fragments[i - 1]) == "string" then
    fragments[i - 1] = fragments[i - 1] .. fragments[i]
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
        local fragment = string.sub(inline.value, start_idx, idx - 1)
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
              fragments[i] = util.unicode["apostrophe"]
            end
            merge_fragments_at(fragments, i)
          end
          if not string.match(left, "[%s%p]$") and not string.match(right, "^[%s%p]") then
            if fragment == "'" then
              fragments[i] = util.unicode["apostrophe"]
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
  if self._type == "PlainText" then
    self.value = unicode.capitalize(self.value)
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

---@class OutputFormat
---@field name string
---@field markups table<string, string>
local OutputFormat = {

}

function OutputFormat:new(format_name)
  local o = {
    name = format_name,
    -- markups = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function OutputFormat:flatten_ir(ir, override_delim)
  if self.group_var == GroupVar.Missing or self.collapse_suppressed then
    return {}
  end
  local inlines = {}
  if ir._type == "SeqIr" or ir._type == "NameIr" then
    inlines = self:flatten_seq_ir(ir, override_delim)
  else
    inlines = self:with_format(ir.inlines, ir.formatting)
    inlines = self:affixed_quoted(inlines, ir.affixes, ir.quotes);
    inlines = self:with_display(inlines, ir.display);
  end
  return inlines
end

---@param ir IrNode
---@param override_delim boolean
---@return InlineElement[]
function OutputFormat:flatten_seq_ir(ir, override_delim)
  -- if not ir.children then
  --   print(debug.traceback())
  -- end
  if #ir.children == 0 then
    return {}
  end
  local inlines_list = {}
  local delimiter = ir.delimiter
  if not delimiter and ir.should_inherit_delim then
    delimiter = override_delim
  end

  for _, child in ipairs(ir.children) do
    if child.group_var ~= GroupVar.Missing and not child.collapse_suppressed then
      local child_inlines = self:flatten_ir(child, delimiter)
      if #child_inlines > 0 then
        table.insert(inlines_list, child_inlines)
      end
    end
  end

  if #inlines_list == 0 then
    return {}
  end

  local inlines = self:group(inlines_list, delimiter, ir.formatting)
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


---Check if there is a lowercase word not in CSL's stop words
---@param str string
---@return boolean
local function is_str_sentence_case(str)
  local words = unicode.words(str)
  for _, word in ipairs(words) do
    if unicode.islower(word) and not util.stop_words[word] then
      return true
    end
  end
  return false
end

---Returns true if the inlines contain a lowercase word which is not CSL's stop words.
---@param inlines table[]
---@return boolean
function OutputFormat:is_sentence_case(inlines)
  for _, inline in ipairs(inlines) do
    if util.is_instance(inline, PlainText) then
      if is_str_sentence_case(inline.value) then
        return true
      end

    elseif util.is_instance(inline, Quoted)
        or util.is_instance(inline, NoCase)
        or util.is_instance(inline, NoDecor)
        or util.is_instance(inline, CiteInline)
        or util.is_instance(inline, UndefinedCite)
        or (util.is_instance(inline, Formatted)
          and inline.formatting["font-variant"] ~= "small-caps"
          and inline.formatting["vertical-align"] ~= "sup"
          and inline.formatting["vertical-align"] ~= "sub") then
      if self:is_sentence_case(inline.inlines) then
        return true
      end
    end
  end
  return false
end

---1. For uppercase strings, the first character of the string remains capitalized.
---   All other letters are lowercased.
---2. For lower or mixed case strings, the first character of the first word is
---   capitalized if the word is lowercase.
---3. All other words are lowercased if capitalized.
---@param inlines table[]
---@param check_sentence_case boolean
function OutputFormat:convert_sentence_case(inlines, check_sentence_case)
  if not inlines or #inlines == 0 then
    return
  end
  local is_uppercase = false  -- TODO
  if check_sentence_case then
    if self:is_sentence_case(inlines) then
      self:apply_text_case_inner(inlines, "capitalize-first", false, is_uppercase)
    else
      self:apply_text_case_inner(inlines, "sentence-strong", false, is_uppercase)
    end
  else
    self:apply_text_case_inner(inlines, "sentence-strong", false, is_uppercase)
  end
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

    elseif inline._type == "Formatted" or inline._type == "Quoted"
        or inline._type == "CiteInline" or inline._type == "UndefinedCite" then
      seen_one = self:apply_text_case_inner(inline.inlines, text_case, seen_one, is_uppercase) or seen_one

    end
  end
  return seen_one
end

local function transform_lowercase(str)
  return unicode.lower(str)
end

local function transform_uppercase(str)
  -- TODO: locale specific uppercase: textcase_LocaleUnicode.txt
  return unicode.upper(str)
end

---@param str string
---@param is_first boolean
---@param transform function
---@return string
local function transform_first_word(str, is_first, transform)
  if is_first then
    local segments = unicode.split_word_bounds(str)
    for i, segment in ipairs(segments) do
      -- bugreports_ThesisUniversityAppearsTwice.txt: "Ph.D"
      if uni_utf8.match(segment, "%a") then
        segments[i] = transform(segment)
        break
      end
    end
    str = table.concat(segments)
  end
  return str
end


local SegmentType = {
  Word = 1,
  Puctuation = 2,
  EndingPunctuation = 3,  -- "?" and "!" excluding "." Do we need a sentence break?
  Colon = 4,  -- Including em-dash
  Other = 0,
}

---@param str string
---@param seen_one boolean
---@param is_last_inline boolean
---@param transform function
---@return string
local function transform_each_word(str, seen_one, is_last_inline, transform)
  local segments = unicode.split_word_bounds(str)

  local segment_type_list = {}
  local last_word_idx
  for i, segment in ipairs(segments) do
    segment_type_list[i] = SegmentType.Other

    -- Do not use isalnum(): "can't"
    if uni_utf8.match(segment, "%w") then
      segment_type_list[i] = SegmentType.Word
      last_word_idx = i

    elseif uni_utf8.match(segment, "%p") then
      segment_type_list[i] = SegmentType.Puctuation
      -- In the case of `Form ({MMPI-2-RF}): Technical Manual`, use `endswith()`.
      if util.endswith(segment, "!") or util.endswith(segment, "?") then
        segment_type_list[i] = SegmentType.EndingPunctuation
        -- elseif segment == ":" or segment == "—" then
      elseif util.endswith(segment, ":") then
        -- Em dash is not taken into consideration, see "Stability—with Job" in `textcase_TitleWithEmDash.txt`
        segment_type_list[i] = SegmentType.Colon
      end
    end
  end

  local sentence_begin = not seen_one
  local after_colon = false

  for i, segment in ipairs(segments) do
    if segment_type_list[i] == SegmentType.Word then
      local is_first_word = sentence_begin
      local is_last_word = segment_type_list[i + 1] == SegmentType.EndingPunctuation
          or (is_last_inline and i == last_word_idx)
      -- See "Pro-Environmental" in `textcase_StopWordBeforeHyphen.txt`
      -- but not "Out-of-Fashion" in `textcase_TitleCaseWithHyphens.txt`.
      local ignore_stop_word = segments[i + 1] == "-" and segments[i - 1] ~= "-"

      -- See "07-x" in `textcase_LastChar.txt`
      if not (segments[i - 1] == "-" and unicode.len(segment) == 1) then
        segments[i] = transform(segment, is_first_word, after_colon, is_last_word, ignore_stop_word)

      end

      sentence_begin = false
      after_colon = false

    elseif segment_type_list[i] == SegmentType.EndingPunctuation then
      sentence_begin = true

    elseif segment_type_list[i] == SegmentType.Colon then
      after_colon = true

    end
  end
  return table.concat(segments)
end

---@param word string
---@return string
local function transform_capitalize_word_if_lower(word)
  if unicode.islower(word) then
    local res = unicode.capitalize(word)
    return res
  else
    return word
  end
end

local function title_case_word(word, is_first, after_end_punct, is_last, ignore_stop_word)
  -- Entirely non-English
  -- e.g. "β" in "β-Carotine"
  -- TODO: two-word cases like "due to"
  local res
  if (is_first or is_last or after_end_punct or ignore_stop_word or not util.stop_words[word])
      and string.match(word, "%a") and unicode.islower(word) then
    res = unicode.capitalize(word)
  else
    res = word
  end
  return res
end

local function transform_lowercase_if_capitalize(word, is_first, after_end_punct, is_last, is_stop_word)
  if not (is_first or after_end_punct) then
    local is_capitalize_word = false
    local lower_first = string.gsub(word, utf8.charpattern, unicode.lower, 1)
    if unicode.islower(lower_first) then
      return lower_first
    else
      return word
    end
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
    res = transform_first_word(str, not seen_one, transform_capitalize_word_if_lower)
  elseif text_case == "capitalize-all" then
    res = transform_each_word(str, false, true, transform_capitalize_word_if_lower)
  elseif text_case == "sentence" then
    -- TODO: if uppercase convert all to lowercase
    res = transform_first_word(str, not seen_one, transform_capitalize_word_if_lower)
  elseif text_case == "title" then
    -- TODO: if uppercase convert all to lowercase
    res = transform_each_word(str, seen_one, is_last, title_case_word)
  elseif text_case == "sentence-strong" then
    -- Conversion for BibTeX title fields to sentence case
    -- TODO: if uppercase convert all to lowercase
    res = transform_each_word(str, seen_one, is_last, transform_lowercase_if_capitalize)
    res = transform_first_word(res, not seen_one, transform_capitalize_word_if_lower)
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

---@param inlines InlineElement[]
---@param affixes table
---@param localized_quotes LocalizedQuotes
---@return InlineElement[]
function OutputFormat:affixed_quoted(inlines, affixes, localized_quotes)
  inlines = util.clone(inlines)
  if localized_quotes then
    inlines = {Quoted:new(inlines, localized_quotes)}
  end
  if affixes and affixes.prefix and affixes.prefix ~= "" then
    table.insert(inlines, 1, PlainText:new(affixes.prefix))
  end
  if affixes and affixes.suffix and affixes.suffix ~= "" then
    table.insert(inlines, PlainText:new(affixes.suffix))
  end
  return inlines
end

function OutputFormat:with_display(nodes, display)
  if display then
    return {Div:new(nodes, display)}
  else
    return nodes
  end
end

---@param inlines InlineElement[]
---@param context Context
function OutputFormat:output(inlines, context)
  self:flip_flop_inlines(inlines)

  self:move_punctuation(inlines)

  return self:write_inlines(inlines, context)
end

---@param inlines InlineElement[]
---@param context Context
---@return string?
function OutputFormat:output_bibliography_entry(inlines, context)
  self:flip_flop_inlines(inlines)
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

---@param inlines InlineElement[]
function OutputFormat:flip_flop_inlines(inlines)
  ---@class FlipFlopState
  local flip_flop_state = {
    ["font-style"] = "normal",
    ["font-variant"] = "normal",
    ["font-weight"] = "normal",
    ["text-decoration"] = "none",
    ["vertical-alignment"] = "baseline",
    in_quotes = false,
    inner_quotes = false,
  }
  self:flip_flop(inlines, flip_flop_state)
end

---@param inlines InlineElement[]
---@param state FlipFlopState
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
      ---@cast inline Quoted
      if state.in_quotes then
        inline.is_inner = not state.inner_quotes
      end
      local new_state = util.clone(state)
      new_state.in_quotes = true
      new_state.inner_quotes = inline.is_inner
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

    elseif inline.inlines then  -- Div, ...
      self:flip_flop(inline.inlines, state)
    end
  end
end

---@param inlines InlineElement[]
---@param state FlipFlopState
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
      ---@cast inline Quoted
      if state.in_quotes then
        inline.is_inner = not state.inner_quotes
      end
      local new_state = util.clone(state)
      new_state.in_quotes = true
      new_state.inner_quotes = inline.is_inner
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

    elseif inline.inlines then  -- Div, ...
      self:flip_flop_micro_inlines(inline.inlines, state)
    end
  end
end

---@param inline InlineElement
---@return InlineElement?
local function find_left(inline)
  if inline._type == "PlainText" then
    return inline
    -- elseif inline._type == "Micro" then
    --   return nil
  elseif inline.inlines and #inline.inlines > 0 and inline._type ~= "Quoted" then
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

--- "'Foo,' bar" => ,
---@param inline InlineElement
---@return boolean
local function find_right_quoted(inline)
  if inline._type == "Quoted" and #inline.inlines > 0 then
    ---@cast inline Quoted
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
    local second = inlines[idx + 1]

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

    elseif (first._type == "Formatted" or first._type == "CiteInline"
          or first._type == "UndefinedCite") and second._type == "PlainText" then
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

---@param inlines InlineElement[]
local function move_around_quote(inlines)
  local idx = 1

  while idx < #inlines do
    -- Move punctuation into quotes as needed
    local first, punctuation_in_quote = find_right_quoted(inlines[idx])

    local second = find_left(inlines[idx + 1])
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

---@param inlines InlineElement[]
---@param punctuation_in_quote boolean?
function OutputFormat:move_punctuation(inlines, punctuation_in_quote)
  -- Merge punctuations
  normalise_text_elements(inlines)

  move_around_quote(inlines)

  for _, inline in ipairs(inlines) do
    if inline._type == "Quoted" or inline._type == "Formatted" or
        inline._type == "Div" or inline._type == "CiteInline"
        or inline._type == "UndefinedCite" then
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


---@class Markup: OutputFormat
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

    elseif inline._type == "UndefinedCite" then
      return self:write_undefined_cite(inline, context)

    elseif inline._type == "Code" then
      return self:write_code(inline, context)

    elseif inline._type == "MathML" then
      return self:write_math_ml(inline, context)

    elseif inline._type == "MathTeX" then
      return self:write_math_tex(inline, context)

    elseif inline._type == "NoCase" then
      return self:write_nocase(inline, context)

    elseif inline._type == "NoDecor" then
      return self:write_nodecor(inline, context)

    else
      return self:write_inlines(inline.inlines, context)
    end
  end
  return ""
end

function Markup:write_formatted(inline, context)
  return self:write_inlines(inline.inlines, context)
end

---@param inline Quoted
---@param context Context
---@return string
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

function Markup:write_undefined_cite(inline, context)
  local bold_inline = Formatted:new({PlainText:new(inline.cite_item.id)}, {["font-weight"] = "bold"})
  return self:write_formatted(bold_inline, context)
end

function Markup:write_code(inline, context)
  return inline.value
end

function Markup:write_math_ml(inline, context)
  return inline.value
end

function Markup:write_math_tex(inline, context)
  return inline.value
end

function Markup:write_nocase(inline, context)
  return self:write_inlines(inline.inlines, context)
end

function Markup:write_nodecor(inline, context)
  return self:write_inlines(inline.inlines, context)
end


local LatexWriter = Markup:new()

LatexWriter.markups = {
  ["bibstart"] = function (engine)
    return string.format("\\begin{thebibliography}{%s}\n", engine.registry.widest_label)
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
      str = str .. "\n"
    else
      str = "\\bibitem{" .. context.id .. "}\n" .. str .. "\n"
    end
    return str
  end,
  -- ["@display/block"] = false,
  -- ["@display/left-margin"] = '\n    <div class="csl-left-margin">%s</div>',
  -- ["@display/right-inline"] = '<div class="csl-right-inline">%s</div>',
  -- ["@display/indent"] = '<div class="csl-indent">%s</div>\n  ',
}

local latex_escape_table = {
  ["\\"] = "\\textbackslash ",
  ["{"] = "\\{",
  ["}"] = "\\}",
  ["$"] = "\\$",
  ["&"] = "\\&",
  ["#"] = "\\#",
  ["^"] = "\\^",
  ["_"] = "\\_",
  ["%"] = "\\%",
  ["~"] = "\\~",
}

---@param str string
---@param context Context
---@return string
function LatexWriter:write_escaped(str, context)
  -- TeXbook, p. 38
  str = str:gsub("[\\{}$&#^_%%~]", latex_escape_table)
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
      context.engine.registry.widest_label = str
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
    res = "\n\n" .. res
    return res
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

function LatexWriter:write_undefined_cite(inline, context)
  return string.format("\\cslundefinedcite{%s}", inline.cite_item.id)
end

function LatexWriter:write_code(inline, context)
  return inline.value
end

function LatexWriter:write_math_ml(inline, context)
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
    --TODO: width of CJK characters
    local len = utf8.len(str)
    if len > context.engine.registry.maxoffset then
      context.engine.registry.maxoffset = len
      context.engine.registry.widest_label = str
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
  if format_str then
    res = string.format(format_str, res)
  end
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

function HtmlWriter:write_math_ml(inline, context)
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

---@class DisamStringFormat: OutputFormat
local DisamStringFormat = OutputFormat:new()

function DisamStringFormat:output(inlines, context)
  -- self:flip_flop_inlines(inlines)
  -- self:move_punctuation(inlines)
  return self:write_inlines(inlines, context)
end

function DisamStringFormat:flatten_ir(ir)
  if self.group_var == GroupVar.Missing then
    return {}
  end
  local inlines
  if ir._type == "SeqIr" or ir._type == "NameIr" then
    if ir._element and ir._element.variable == "accessed" then
      -- Accessed isn't really part of a reference -- it doesn't help disambiguating one from
      -- another. So we will ignore it. Works for, e.g., date_YearSuffixImplicitWithNoDate.txt
      inlines = {}
    else
      inlines = self:flatten_seq_ir(ir)
    end
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
    if child.group_var == GroupVar.Important or child.group_var == GroupVar.Plain then
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
  -- if ir._element_name == "layout" and ir.cite_item then
  --   inlines = {CiteInline:new(inlines, ir.cite_item)}
  -- end

  return inlines
end


local PseudoHtml = HtmlWriter:new()

function PseudoHtml:write_escaped(str, context)
  -- str = string.gsub(str, "%&", "&#38;")
  -- str = string.gsub(str, "<", "&#60;")
  -- str = string.gsub(str, ">", "&#62;")
  -- for char, sub in pairs(util.superscripts) do
  --   str = string.gsub(str, char, "<sup>" .. sub .. "</sup>")
  -- end
  return str
end

function PseudoHtml:write_math_ml(inline, context)
  return string.format("<math>%s</math>", inline.value)
end

function PseudoHtml:write_math_tex(inline, context)
  return string.format("<math-tex>%s</math-tex>", inline.value)
end

function PseudoHtml:write_nocase(inline, context)
  local str = self:write_inlines(inline.inlines, context)
  return string.format('<span class="nocase">%s</span>', str)
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
  },
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
output_module.UndefinedCite = UndefinedCite
output_module.Code = Code
output_module.MathTeX = MathTeX
output_module.MathTML = MathML
output_module.NoCase = NoCase
output_module.NoDecor = NoDecor

output_module.OutputFormat = OutputFormat

output_module.Markup = Markup
output_module.LatexWriter = LatexWriter
output_module.HtmlWriter = HtmlWriter
output_module.PlainTextWriter = PlainTextWriter
output_module.DisamStringFormat = DisamStringFormat
output_module.SortStringFormat = SortStringFormat
output_module.PseudoHtml = PseudoHtml

return output_module
