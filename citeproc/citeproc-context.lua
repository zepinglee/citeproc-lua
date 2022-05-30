--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local context = {}

local util = require("citeproc-util")


local Context = {
  -- format: Output,
  -- cite_id: Option<CiteId>,
  style = nil,
  locale = nil,
  -- name_citation: Arc<NameEl>,
  -- names_delimiter: Option<SmartString>,

  -- position: (Position, Option<u32>),

  -- disamb_pass: Option<DisambPass>,

  -- cite = nil,
  item = nil,
  bib_number = nil,

  in_bibliography = false,
  sort_key = nil,
}

function Context:new(style)
  local o = {
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Context:get_variable(name, form)
  local res = nil
  local variable_name = name
  if form then
    variable_name = variable_name .. "-" .. form
  end
  res = self.item[variable_name]
  if res then
    return res
  end

  if form then
    res = self.item[name]
    if res then
      return res
    end
  end

  variable_name = string.gsub(name, "%-short$", "")
  res = self.item[variable_name]
  return res
end

function Context:get_macro(name)
  local res = self.style.macros[name]
  if not res then
    util.error(string.format('Undefined macro "%s"', name))
  end
  return res
end

function Context:get_term(name, form, plural)
end


return context
