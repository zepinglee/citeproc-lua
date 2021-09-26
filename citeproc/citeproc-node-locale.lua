local Element = require("citeproc.citeproc-node-element")


local Locale = Element:new()

function Locale:get_option (key)
  local query = string.format("style-options[%s]", key)
  local option = self:query_selector(query)[1]
  if option then
    local value = option:get_attribute(key)
      if self.option_type[key] == "integer" then
        value = tonumber(value)
      elseif self.option_type[key] == "boolean" then
        value = (value == "true")
      end
    return value
  else
    return nil
  end
end

function Locale:get_term (name, form, number, gender)

  if form == "long" then
    form = nil
  end

  local match_last
  local match_last_two
  local match_whole
  if number then
    assert(type(number) == "number")
    match_last = string.format("%s-%02d", name, number % 10)
    match_last_two = string.format("%s-%02d", name, number % 100)
    match_whole = string.format("%s-%02s", name, number)
  end

  local res = nil
  for _, term in ipairs(self:query_selector("term")) do
    -- Use get_path?
    local match_name = name

    if number then
      local term_match = term:get_attribute("last-two-digits")
      if term_match == "whole-number" then
        match_name = match_whole
      elseif term_match == "last-two-digits" then
        match_name = match_last_two
      elseif number < 10 then
        -- "13" can match only "ordinal-13" not "ordinal-03"
        -- It is sliced to "3" in a later checking pass.
        match_name = match_last_two
      else
        match_name = match_last
      end
    end

    local term_name = term:get_attribute("name")
    local term_form = term:get_attribute("form")
    if term_form == "long" then
      term_form = nil
    end
    local term_gender = term:get_attribute("gender-form")

    if term_name == match_name and term_form == form and term_gender == gender then
      return term
    end

  end

  -- Fallback
  if form == "verb-sort" then
    return self:get_term(name, "verb")
  elseif form == "symbol" then
    return self:get_term(name, "short")
  elseif form == "verb" then
    return self:get_term(name, "long")
  elseif form == "short" then
    return self:get_term(name, "long")
  end

  if number and number > 10 then
    return self:get_term(name, nil, number % 10, gender)
  end

  if gender then
    return self:get_term(name, nil, number, nil)
  end

  if number then
    return self:get_term(name, nil, nil, nil)
  end

  return nil
end


return Locale
