--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local locale = {}

local element
local util

if kpse then
  element = require("citeproc-element")
  util = require("citeproc-util")
else
  element = require("citeproc.element")
  util = require("citeproc.util")
end

local Element = element.Element


---@class Locale: Element
---@field xml_lang string?
---@field terms Terms
---@field dates table<string, Date>
---@field style_options { limit_day_ordinals_to_day_1: boolean?, punctuation_in_quote: boolean }
local Locale = Element:derive("locale")

function Locale:new()
  local o = {
    xml_lang = nil,
    terms = {},
    ordinal_terms = nil,
    dates = {},
    style_options = {
      -- limit_day_ordinals_to_day_1 = false,
      -- punctuation_in_quote = false,
    },
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Locale:from_node(node)
  local o = Locale:new()
  o.xml_lang = node:get_attribute("xml:lang")
  o:process_children_nodes(node)

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "terms" then
      o.terms = child.terms_map
      o.ordinal_terms = child.ordinal_terms
    elseif element_name == "date" then
      o.dates[child.form] = child
    end
  end

  for _, child in ipairs(node:get_children()) do
    if child:is_element() and child:get_element_name() == "style-options" then
      local style_options = child
      o.style_options.limit_day_ordinals_to_day_1 = util.to_boolean(
        style_options:get_attribute("limit-day-ordinals-to-day-1")
      )
      o.style_options.punctuation_in_quote = util.to_boolean(
        style_options:get_attribute("punctuation-in-quote")
      )
    end
  end

  return o
end

function Locale:merge(other)
  for key, value in pairs(other.terms) do
    self.terms[key] = value
  end
  -- https://docs.citationstyles.org/en/stable/specification.html#ordinal-suffixes
  -- The “ordinal” term, and “ordinal-00” through “ordinal-99” terms, behave
  -- differently from other terms when it comes to Locale Fallback.
  -- Whereas other terms can be (re)defined individually, (re)defining any of
  -- the ordinal terms through cs:locale replaces all previously defined
  -- ordinal terms.
  if other.ordinal_terms then
    self.ordinal_terms = other.ordinal_terms
  end
  for key, value in pairs(other.dates) do
    self.dates[key] = value
  end
  for key, value in pairs(other.style_options) do
    if value ~= nil then
      self.style_options[key] = value
    end
  end
  return self
end

Locale.form_fallbacks = {
  ["verb-short"] = {"verb-short", "verb", "long"},
  ["verb"]       = {"verb", "long"},
  ["symbol"]     = {"symbol", "short", "long"},
  ["short"]      = {"short", "long"},
  ["long"]       = {"long"},
}


---Remove leading and trailing spaces
---See label_EditorTranslator1.txt, the `<term name="and others">\n   </term>`
---gives nothing.
---@param str string?
---@return string?
local function strip_term_content(str)
  if not str then
    return nil
  end
  str = string.gsub(str, "^[\r\n]*", "")
  str = string.gsub(str, "[\r\n]*$", "")
  if string.match(str, "^%s*$") then
    str = ""
  end
  return str
end


-- Keep in sync with Terms:from_node
function Locale:get_simple_term(name, form, plural)
  form = form or "long"
  for _, fallback_form in ipairs(self.form_fallbacks[form]) do
    local key = name
    if form ~= "long" then
      -- if not key then
      --   print(debug.traceback())
      -- end
      key = key .. "/form-" .. fallback_form
    end
    local term = self.terms[key]
    if term then
      if plural then
        return strip_term_content(term.multiple) or strip_term_content(term.text)
      else
        return strip_term_content(term.single) or strip_term_content(term.text)
      end
    end
  end
  return nil
end

function Locale:get_ordinal_term(number, gender)
  -- TODO: match and gender

  local keys = {}

  if gender then
    if number < 100 then
      table.insert(keys, string.format("ordinal-%02d/gender-form-%s/match-whole-number", number, gender))
    end
    table.insert(keys, string.format("ordinal-%02d/gender-form-%s/match-last-two-digits", number % 100, gender))
    table.insert(keys, string.format("ordinal-%02d/gender-form-%s/match-last-digit", number % 10, gender))
  end

  if number < 100 then
    table.insert(keys, string.format("ordinal-%02d/match-whole-number", number))
  end
  table.insert(keys, string.format("ordinal-%02d/match-last-two-digits", number % 100))
  table.insert(keys, string.format("ordinal-%02d/match-last-digit", number % 10))
  table.insert(keys, "ordinal")

  for _, key in ipairs(keys) do
    local term = self.ordinal_terms[key]
    if term then
      return term.text
    end
  end
  return nil
end

function Locale:get_number_gender(name)
  local term = self.terms[name]
  if term and term.gender then
    return term.gender
  else
    return nil
  end
end


---@class Terms: Element
local Terms = Element:derive("terms")

function Terms:new()
  local o = Element.new(self)
  o.element_name = "terms"
  o.children = {}
  o.terms_map = {}
  o.ordinal_terms = nil
  return o
end


function Terms:from_node(node)
  local o = Terms:new()
  o:process_children_nodes(node)
  for _, term in ipairs(o.children) do
    local form = term.form
    local gender = term.gender
    local gender_form = term.gender_form
    local match
    if util.startswith(term.name, "ordinal-0") then
      match = term.match or "last-digit"
    elseif util.startswith(term.name, "ordinal-") then
      match = term.match or "last-two-digits"
    end

    local key = term.name
    if form then
      key = key .. '/form-' .. form
    end
    -- if gender then
    --   key = key .. '/gender-' .. gender
    -- end
    if gender_form then
      key = key .. '/gender-form-' .. gender_form
    end
    if match then
      key = key .. '/match-' .. match
    end

    if term.name == "ordinal" or util.startswith(term.name, "ordinal-") then
      if not o.ordinal_terms then
        o.ordinal_terms = {}
      end
      o.ordinal_terms[key] = term
    else
      o.terms_map[key] = term
    end
  end
  return o
end


---@class Term: Element
local Term = Element:derive("term")

function Term:from_node(node)
  local o = Term:new()

  o.name = node:get_attribute("name")
  o.form = node:get_attribute("form")
  o.match = node:get_attribute("match")
  o.gender = node:get_attribute("gender")
  o.gender_form = node:get_attribute("gender-form")
  o.text = node:get_text()
  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "single" then
        o.single = child:get_text()
        o.text = o.single
      elseif element_name == "multiple" then
        o.multiple = child:get_text()
      end
    end
  end

  return o
end


locale.Locale = Locale
locale.Term = Term

return locale
