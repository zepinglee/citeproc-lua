--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local sort = {}

local uca_languages
local uca_ducet
local uca_collator

local element
local output
local util
local node_date

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  uca_languages = require("lua-uca-languages")
  uca_ducet = require("lua-uca-ducet")
  uca_collator = require("lua-uca-collator")
  element = require("citeproc-element")
  output = require("citeproc-output")
  util = require("citeproc-util")
  node_date = require("citeproc-node-date")
else
  uca_languages = require("citeproc.lua-uca.languages")
  uca_ducet = require("citeproc.lua-uca.ducet")
  uca_collator = require("citeproc.lua-uca.collator")
  element = require("citeproc.element")
  output = require("citeproc.output")
  util = require("citeproc.util")
  node_date = require("citeproc.node-date")
end

local Element = element.Element
local Date = node_date.Date
local InlineElement = output.InlineElement


-- [Sorting](https://docs.citationstyles.org/en/stable/specification.html#sorting)
---@class Sort: Element
---@field children Key[]
---@field sort_directions boolean[]
local Sort = Element:derive("sort")

function Sort:from_node(node)
  local o = Sort:new()
  o.children = {}

  o:process_children_nodes(node)
  o.sort_directions = {}
  for i, key in ipairs(o.children) do
    o.sort_directions[i] = (key.sort ~= "descending")
  end
  table.insert(o.sort_directions, true)

  return o
end

function Sort:sort(items, state, context)
  -- key_map = {
  --   id1 = {key1, key2, ...},
  --   id2 = {key1, key2, ...},
  --   ...
  -- }
  local key_map = {}
  local sort_directions = self.sort_directions
  -- true: ascending
  -- false: descending

  if not Sort.collator then
    local lang = context.engine.lang
    local language = string.sub(lang, 1, 2)
    Sort.collator = uca_collator.new(uca_ducet)
    if language ~= "en" then
      if uca_languages[language] then
        Sort.collator = uca_languages[language](Sort.collator)
      else
        util.warning(string.format("Locale '%s' is not provided by lua-uca. The sorting order may be incorrect.", lang))
      end
    end
  end

  -- TODO: optimize: use cached values for fixed keys
  for i, item in ipairs(items) do
    key_map[item.id] = {}

    context.id = item.id
    context.cite = item
    context.reference = context.engine.registry.registry[item.id]

    for j, key in ipairs(self.children) do
      if context.reference then
        context.sort_key = key
        local key_str = key:eval(context.engine, state, context)
        key_map[item.id][j] = key_str
      else
        -- The entry is missing
        key_map[item.id][j] = false
      end
    end
    -- To preserve the original order of items with same sort keys
    -- sort_NameImplicitSortOrderAndForm.txt
    table.insert(key_map[item.id], i)
  end

  -- util.debug(key_map)

  local function compare_entry(item1, item2)
    return self.compare_entry(key_map, sort_directions, item1, item2)
  end
  -- util.debug(items)
  table.sort(items, compare_entry)

  return items
end

function Sort.compare(value1, value2)
  if type(value1) == "string" then
    return Sort.compare_strings(value1, value2)
  else
    return value1 < value2
  end
end

function Sort.compare_strings(str1, str2)
  if Sort.collator then
    return Sort.collator:compare_strings(str1, str2)
  else
    return str1 < str2
  end
end

function Sort.compare_entry(key_map, sort_directions, item1, item2)
  for i, value1 in ipairs(key_map[item1.id]) do
    local ascending = sort_directions[i]
    local value2 = key_map[item2.id][i]
    if value1 and value2 then
      local res
      if ascending then
        res = Sort.compare(value1, value2)
      else
        res = Sort.compare(value2, value1)
      end
      if res or value1 ~= value2 then
        return res
      end
    elseif value1 then
      return true
    elseif value2 then
      return false
    end
  end
end


---@class Key: Element
---@field sort string?
---@field variable string?
---@field macro string?
---@field names_min number?
---@field names_use_first number?
---@field names_use_last number?
local Key = Element:derive("key")

function Key:new()
  local o = Element.new(self)
  Key.sort = "ascending"
  return o
end

function Key:from_node(node)
  local o = Key:new()
  o:set_attribute(node, "sort")
  o:set_attribute(node, "variable")
  o:set_attribute(node, "macro")
  o:set_number_attribute(node, "names-min")
  o:set_number_attribute(node, "names-use-first")
  o:set_bool_attribute(node, "names-use-last")
  return o
end

function Key:eval(engine, state, context)
  local res
  if self.variable then
    local variable_type = util.variable_types[self.variable]
    if variable_type == "name" then
      res = self:eval_name(engine, state, context)
    elseif variable_type == "date" then
      res = self:eval_date(context)
    elseif variable_type == "number" then
      local value = context:get_variable(self.variable)
      if type(value) == "string" and string.match(value, "%s+") then
        value = tonumber(value)
      end
      res = value
    else
      res = context:get_variable(self.variable)
      if type(res) == "string" then
        local inlines = InlineElement:parse(res, context)
        res = context.format:output(inlines)
      end
    end
  elseif self.macro then
    local macro = context:get_macro(self.macro)
    state:push_macro(self.macro)
    local ir = macro:build_ir(engine, state, context)
    state:pop_macro(self.macro)
    if ir.name_count then
      return ir.name_count
    elseif ir.sort_key ~= nil then
      return ir.sort_key
    end
    local output_format = context.format
    local inlines = ir:flatten(output_format)
    -- util.debug(inlines)
    local str = output_format:output(inlines)
    return str
  end
  if res == nil then
    -- make table.insert(_, nil) work
    res = false
  end
  return res
end

function Key:eval_name(engine, state, context)
  if not self.name_inheritance then
    self.name_inheritance = util.clone(context.name_inheritance)
  end
  local name = context:get_variable(self.variable)
  if not name then
    return false
  end
  local ir = self.name_inheritance:build_ir(self.variable, nil, nil, engine, state, context)
  if ir.name_count then
    -- name count
    return ir.name_count
  end
  local output_format = context.format
  local inlines = ir:flatten(output_format)

  local str = output_format:output(inlines)

  return str
end

function Key:eval_date(context)
  if not self.date then
    self.date = Date:new()
    self.date.variable = self.variable
    self.date.form = "numeric"
    self.date.date_parts = "year-month-day"
  end
  return self.date:render_sort_key(context.engine, nil, context)
end


sort.Sort = Sort
sort.Key = Key

return sort
