--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local context = {}

local LocalizedQuotes = require("citeproc-output").LocalizedQuotes

local util = require("citeproc-util")


local Context = {
  reference = nil,
  format = nil,
  cite_id = nil,
  style = nil,
  locale = nil,
  name_citation = nil,
  names_delimiter = nil,

  position = nil,

  disamb_pass = nil,

  cite = nil,
  bib_number = nil,

  in_bibliography = false,
  sort_key = nil,

  year_suffix = nil,
}

function Context:new()
  local o = {
    in_bibliography = false
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Context:get_variable(name, form)
  local variable_type = util.variable_types[name]
  if variable_type == "number" then
    return self:get_number(name)
  -- elseif variable_type == "name" then
  --   return self:get_name(name)
  -- elseif variable_type == "date" then
  --   return self:get_date(name)
  else
    return self:get_ordinary(name, form)
  end
end

function Context:get_ordinary(name, form)
  local res = nil
  local variable_name = name
  if form and form ~= "long" then
    variable_name = variable_name .. "-" .. form
  end

  if variable_name == "locator" or variable_name == "label" then
    res = self.cite[variable_name]
  else
    res = self.reference[variable_name]
  end
  if res then
    return res
  end

  if variable_name == "container-title-short" then
    res = self.reference["journalAbbreviation"]
    if res then
      return res
    end
  end

  if form then
    res = self.reference[name]
    if res then
      return res
    end
  end

  -- if name == "title-short" or name == "container-title-short" then
  --   variable_name = string.gsub(name, "%-short$", "")
  --   res = self.reference[variable_name]
  -- end

  return res
end

function Context:get_number(name)
  if name == "locator" then
    return self.cite.locator
  elseif name == "citation-number" then
    return self.bib_number
  elseif name == "first-reference-note-number" then
    return self.cite["first-reference-note-number"]
  elseif name == "page-first" then
    return self.page_first(self.reference.page)
  else
    return self.reference[name]
  end
end

function Context:get_localized_date(form)
  return self.locale.dates[form]
end

function Context:get_macro(name)
  local res = self.style.macros[name]
  if not res then
    util.error(string.format('Undefined macro "%s"', name))
  end
  return res
end

function Context:get_simple_term(name, form, plural)
  assert(self.locale)
  return self.locale:get_simple_term(name, form, plural)
end

function Context:get_localized_quotes()
  return LocalizedQuotes:new(
    self:get_simple_term("open-quote"),
    self:get_simple_term("close-quote"),
    self:get_simple_term("open-inner-quote"),
    self:get_simple_term("close-inner-quote"),
    self.locale.style_options.punctuation_in_quote
  )
end

function Context.page_first(page)
  local page_first = util.split(page, "%s*[&,-]%s*")[1]
  return util.split(page_first, util.unicode["en dash"])[1]
end

-- https://docs.citationstyles.org/en/stable/specification.html#non-english-items
function Context:is_english()
  local language = self:get_variable("language")
  if util.startswith(self.engine.lang, "en") then
    if not language or util.startswith(language, "en") then
      return true
    else
      return false
    end
  else
    if language and util.startswith(language, "en") then
      return true
    else
      return false
    end
  end
end


local IrState = {}

function IrState:new(style, cite_id, cite, reference)
  local o = {
    macro_stack = {},
    suppressed = {},
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrState:push_macro(macro_name)
  for _, name in ipairs(macro_name) do
    if name == macro_name then
      util.error(string.format('Recursive macro "%s".', macro_name))
    end
    table.insert(self.macro_stack, macro_name)
  end
end

function IrState:pop_macro(macro_name)
  table.remove(self.macro_stack)
end


context.Context = Context
context.IrState = IrState

return context
