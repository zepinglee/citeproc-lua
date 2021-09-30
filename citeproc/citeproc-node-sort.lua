local unicode = require("unicode")
local inspect = require("inspect")

local Element = require("citeproc.citeproc-node-element")
local Names = require("citeproc.citeproc-node-names").names
local util = require("citeproc.citeproc-util")


local Sort = Element:new()

function Sort:sort (items, context)
  -- key_map = {
  --   id1 = {key1, key2, ...},
  --   id2 = {key1, key2, ...},
  --   ...
  -- }
  context.variable_attempt = {}

  local key_map = {}

  for _, item in ipairs(items) do
    if not key_map[item.id] then
      key_map[item.id] = {}

      context.item = item
      for _, key in ipairs(self:query_selector("key")) do
        local value = key:render(item, context)
        if value == nil then
          value = false
        elseif type(value) == "table" and value._type == "FormattedText" then
          value = value:render(context.engine.formatter, context)
        end
        if type(value) == "string" then
          value = unicode.utf8.lower(value)
        end
        table.insert(key_map[item.id], value)
      end
    end
  end


  local sort_directions = {}
  -- true: ascending
  -- false: descending
  for i, key in ipairs(self:query_selector("key")) do
    local direction = (key:get_attribute("sort") ~= "descending")
    sort_directions[i] = direction
  end

  local compare_entry = function (item1, item2)
    for i, value1 in ipairs(key_map[item1.id]) do
      local ascending = sort_directions[i]
      local value2 = key_map[item2.id][i]
      if value1 and value2 then
        local res
        if ascending then
          res = value1 < value2
        else
          res = value1 > value2
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
  table.sort(items, compare_entry)

  if context.mode == "bibliography" then
    for i, item in ipairs(items) do
      item["citation-number"] = i
    end
  end

  return items
end


local Key = Element:new()

function Key:render (item, context)
  context = self:process_context(context)
  context.options["name-as-sort-order"] = "all"
  context.name_sorting = true
  local variable = self:get_attribute("variable")
  if variable then
    context.variable = variable
    local variable_type = util.variable_types[variable]
    if variable_type == "name" then
      return self:_render_name(item, context)
    elseif variable_type == "date" then
      return self:_render_date(item, context)
    elseif variable_type == "number" then
      return item[variable]
    else
      return item[variable]
    end
  else
    local macro = self:get_attribute("macro")
    if macro then
      return self:get_macro(macro):render(item, context)
    end
  end
end

function Key:_render_name (item, context)
  if not self.names then
    self.names = self:create_element("names", {}, self)
    Names:set_base_class(self.names)
    self.names:set_attribute("variable", context.options["variable"])
    self.names:set_attribute("form", "long")
  end
  local res = self.names:render(item, context)
  return res
end

function Key:_render_date (item, context)
  local variable = self:get_variable(item, context.options["variable"], context)
  if not variable then
    return nil
  end
  local date_parts = variable["date-parts"][1]
  local date_parts_number = {}
  for i = 1, 3 do
    local number = 0
    if date_parts[i] then
      number = tonumber(date_parts[i])
    end
    table.insert(date_parts_number, number)
  end
  local year, month, day = table.unpack(date_parts_number)
  return string.format("%05d%02d%02d", year + 10000, month, day)
end


return {
  sort = Sort,
  key = Key,
}
