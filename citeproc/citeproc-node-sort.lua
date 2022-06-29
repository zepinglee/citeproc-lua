--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local sort = {}

local unicode = require("unicode")

local Element = require("citeproc-element").Element
local names = require("citeproc-node-names")
local InlineElement = require("citeproc-output").InlineElement
local util = require("citeproc-util")


-- [Sorting](https://docs.citationstyles.org/en/stable/specification.html#sorting)
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
  context.variable_attempt = {}

  local key_map = {}
  local sort_directions = self.sort_directions
  -- true: ascending
  -- false: descending

  if not Sort.collator then
    local lang = context.engine.lang
    local language = string.sub(lang, 1, 2)
    -- It's 6 seconds slower to run the whole test-suite if these package
    -- loading statements are put in the header.
    local uca_ducet = require("lua-uca.lua-uca-ducet")
    local uca_collator = require("lua-uca.lua-uca-collator")
    Sort.collator = uca_collator.new(uca_ducet)
    if language ~= "en" then
      local uca_languages = require("lua-uca.lua-uca-languages")
      if uca_languages[language] then
        Sort.collator = uca_languages[language](Sort.collator)
      else
        util.warning(string.format('Locale "%s" is not provided by lua-uca. The sorting order may be incorrect.', lang))
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
      context.sort_key = key

      local key_str = key:render(context.engine, state, context)
      key_map[item.id][j] = key_str
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
  o:set_attribute(node, "names-min")
  o:set_attribute(node, "names-use-first")
  o:set_attribute(node, "names-use-last")
  return o
end

function Key:render(engine, state, context)
  local res
  if self.variable then
    local variable_type = util.variable_types[self.variable]
    if variable_type == "name" then
      res = self:_render_name(engine, state, context)
    elseif variable_type == "date" then
      res = self:_render_date(context)
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
    local output_format = context.format
    local inlines = ir:flatten(output_format)
    local str = output_format:output(inlines)
    return str
  end
  if res == nil then
    -- make table.insert(_, nil) work
    res = false
  end
  return res
end

function Key:_render_name(engine, state, context)
  if not self.name_inheritance then
    self.name_inheritance = util.clone(context.name_inheritance)
    self.name_inheritance.name_as_sort_order = "all"
    self.name_inheritance.delimiter = "   "
    if self.names_min then
      self.name_inheritance.et_al_min = self.names_min
    end
    if self.names_use_first then
      self.name_inheritance.et_al_use_first = self.names_use_first
    end
    if self.names_use_last then
      self.name_inheritance.et_al_use_last = self.names_use_last
    end
  end
  local name = context:get_variable(self.variable)
  if not name then
    return false
  end
  local ir = self.name_inheritance:build_ir(self.variable, nil, nil, engine, state, context)
  if type(ir) == "number" then
    -- name count
    return ir
  end
  local output_format = context.format
  local inlines = ir:flatten(output_format)

  local str = output_format:output(inlines)

  return str
end

function Key:_render_date(context)
  local date = context:get_variable(self.variable)
  if not date then
    return false
  end
  if not date["date-parts"] then
    return date.literal or date.raw
  end
  local res = ""
  for _, date_parts in ipairs(date["date-parts"]) do
    for i, date_part in ipairs(date_parts) do
      local value = date_parts[i]
      if type(value) == "string" then
        value = tonumber(value)
      end
      if i == 1 then -- year
        res = res .. string.format("%05d", value + 10000)
      elseif i == 2 then  -- month
        if value < 1 or value > 12 then
          value = 0
        end
        res = res .. string.format("%02d", value)
      else  -- month
        res = res .. string.format("%02d", value)
      end
    end
  end
  return res
end

-- function Key._normalize_string(str)
--   str = unicode.utf8.lower(str)
--   str = string.gsub(str, "[%[%]]", "")
--   local words = {}
--   for _, word in ipairs(util.split(str, " ")) do
--     -- TODO: strip leading prepositions
--     -- remove leading apostrophe on name particle
--     word = string.gsub(word, "^" .. util.unicode["apostrophe"], "")
--     table.insert(words, word)
--   end
--   str = table.concat(words, " ")
--   str = string.gsub(str, util.unicode["apostrophe"], "'")
--   return str
-- end


sort.Sort = Sort
sort.Key = Key

return sort
