--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local locale = {}

local Element = require("citeproc-element").Element
local util = require("citeproc-util")


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

-- Keep in sync with Terms:from_node
function Locale:get_simple_term(name, form, plural)
  form = form or "long"
  for _, fallback_form in ipairs(self.form_fallbacks[form]) do
    local key = name
    if form ~= "long" then
      key = key .. "/form-" .. fallback_form
    end
    local term = self.terms[key]
    if term then
      if plural then
        return term.multiple or term.text
      else
        return term.single or term.text
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

function Locale:get_option(key)
  local query = string.format("style-options[%s]", key)
  local option = self:query_selector(query)[1]
  if option then
    local value = option:get_attribute(key)
      if self._option_type[key] == "integer" then
        value = tonumber(value)
      elseif self._option_type[key] == "boolean" then
        value = (value == "true")
      end
    return value
  else
    return nil
  end
end

-- function Locale:get_term (name, form, number, gender)

--   if form == "long" then
--     form = nil
--   end

--   local match_last
--   local match_last_two
--   local match_whole
--   if number then
--     assert(type(number) == "number")
--     match_last = string.format("%s-%02d", name, number % 10)
--     match_last_two = string.format("%s-%02d", name, number % 100)
--     match_whole = string.format("%s-%02s", name, number)
--   end

--   local res = nil
--   for _, term in ipairs(self:query_selector("term")) do
--     -- Use get_path?
--     local match_name = name

--     if number then
--       local term_match = term:get_attribute("last-two-digits")
--       if term_match == "whole-number" then
--         match_name = match_whole
--       elseif term_match == "last-two-digits" then
--         match_name = match_last_two
--       elseif number < 10 then
--         -- "13" can match only "ordinal-13" not "ordinal-03"
--         -- It is sliced to "3" in a later checking pass.
--         match_name = match_last_two
--       else
--         match_name = match_last
--       end
--     end

--     local term_name = term:get_attribute("name")
--     local term_form = term:get_attribute("form")
--     if term_form == "long" then
--       term_form = nil
--     end
--     local term_gender = term:get_attribute("gender-form")

--     if term_name == match_name and term_form == form and term_gender == gender then
--       return term
--     end

--   end

--   -- Fallback
--   if form == "verb-sort" then
--     return self:get_term(name, "verb")
--   elseif form == "symbol" then
--     return self:get_term(name, "short")
--   elseif form == "verb" then
--     return self:get_term(name, "long")
--   elseif form == "short" then
--     return self:get_term(name, "long")
--   end

--   if number and number > 10 then
--     return self:get_term(name, nil, number % 10, gender)
--   end

--   if gender then
--     return self:get_term(name, nil, number, nil)
--   end

--   if number then
--     return self:get_term(name, nil, nil, nil)
--   end

--   return nil
-- end


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
