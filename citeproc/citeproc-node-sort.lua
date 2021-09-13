local Element = require("citeproc.citeproc-node-element")
local Names = require("citeproc.citeproc-node-names").names
local util = require("citeproc.citeproc-util")


local Sort = Element:new()

function Sort:sort (items, context)
  self:debug_info(context)
  local key_dict = {}
  for _, item in ipairs(items) do
    key_dict[item.id] = {}
  end
  local descendings = {}
  for i, key in ipairs(self:query_selector("key")) do
    local descending = key:get_attribute("sort") == "descending"

    table.insert(descendings, descending)
    for _, item in ipairs(items) do
      context.item = item
      local value = key:render(item, context)
      -- util.debug(value)
      if value == nil then
        value = false
      end
      table.insert(key_dict[item.id], value)
    end
  end
  local compare_entry = function (item1, item2)
    for i, value1 in ipairs(key_dict[item1.id]) do
      local descending = descendings[i]
      local value2 = key_dict[item2.id][i]
      if value1 and value2 then
        if value1 < value2 then
          if descending then
            return false
          else
            return true
          end
        elseif value1 > value2 then
          if descending then
            return true
          else
            return false
          end
        end
      elseif value1 then
        return true
      elseif value2 then
        return false
      end
    end
  end
  table.sort(items, compare_entry)
  return items
end


local Key = Element:new()

function Key:render (item, context)
  context = self:process_context(context)
  local variable = self:get_attribute("variable")
  if variable then
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
  end
  context["form"] = "long"
  context["name-as-sort-order"] = "all"
  return self.names:render(item, context)
end

function Key:_render_date (item, context)
  local variable = item[context["variable"]]
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
