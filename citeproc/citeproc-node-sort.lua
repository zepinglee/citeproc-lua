local sort = {}

local unicode = require("unicode")

local element = require("citeproc.citeproc-element")
local names = require("citeproc.citeproc-node-names")
local date = require("citeproc.citeproc-node-date")
local util = require("citeproc.citeproc-util")


local Sort = element.Element:new()

function Sort:sort (items, context)
  -- key_map = {
  --   id1 = {key1, key2, ...},
  --   id2 = {key1, key2, ...},
  --   ...
  -- }
  context.variable_attempt = {}

  local key_map = {}
  local sort_directions = {}
  -- true: ascending
  -- false: descending

  for _, item in ipairs(items) do
    if not key_map[item.id] then
      key_map[item.id] = {}

      context.item = item
      for i, key in ipairs(self:query_selector("key")) do
        if sort_directions[i] == nil then
          local direction = (key:get_attribute("sort") ~= "descending")
          sort_directions[i] = direction
        end
        local value = key:render(item, context)
        table.insert(key_map[item.id], value)
      end
    end
  end

  -- util.debug(key_map)

  local function compare_entry(item1, item2)
    return self.compare_entry(key_map, sort_directions, item1, item2)
  end
  table.sort(items, compare_entry)

  return items
end

function Sort.compare_entry(key_map, sort_directions, item1, item2)
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

local Key = element.Element:new()

function Key:render (item, context)
  context = self:process_context(context)
  context.options["name-as-sort-order"] = "all"
  context.sorting = true
  local variable = self:get_attribute("variable")
  local res = nil
  if variable then
    context.variable = variable
    local variable_type = util.variable_types[variable]
    if variable_type == "name" then
      res = self:_render_name(item, context)
    elseif variable_type == "date" then
      res = self:_render_date(item, context)
    elseif variable_type == "number" then
      res = item[variable]
    else
      res = item[variable]
    end
  else
    local macro = self:get_attribute("macro")
    if macro then
      res = self:get_macro(macro):render(item, context)
    end
  end
  if res == nil then
    res = false
  elseif type(res) == "table" and res._type == "RichText" then
    res = res:render(nil, context)
  end
  if type(res) == "string" then
    res = self._normalize_string(res)
  end
  return res
end

function Key:_render_name (item, context)
  if not self.names then
    self.names = self:create_element("names", {}, self)
    names.Names:set_base_class(self.names)
    self.names:set_attribute("variable", context.options["variable"])
    self.names:set_attribute("form", "long")
  end
  local res = self.names:render(item, context)
  return res
end

function Key:_render_date (item, context)
  if not self.date then
    self.date = self:create_element("date", {}, self)
    date.Date:set_base_class(self.date)
    self.date:set_attribute("variable", context.options["variable"])
    self.date:set_attribute("form", "numeric")
  end
  local res = self.date:render(item, context)
  return res
end
function Key._normalize_string(str)
  str = unicode.utf8.lower(str)
  str = string.gsub(str, "[%[%]]", "")
  local words = {}
  for _, word in ipairs(util.split(str, " ")) do
    -- TODO: strip leading prepositions
    -- remove leading apostrophe on name particle
    word = string.gsub(word, "^" .. util.unicode["apostrophe"], "")
    table.insert(words, word)
  end
  str = table.concat(words, " ")
  str = string.gsub(str, util.unicode["apostrophe"], "'")
  return str
end


sort.Sort = Sort
sort.Key = Key

return sort
