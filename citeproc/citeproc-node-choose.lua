local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Choose = Element:new()

function Choose:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local result, status = child:render(item, context)
      if status then
        return result
      end
    end
  end
  return nil
end


local If = Element:new()

If.render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local results = {}

  local variable_names = context["is-numeric"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      table.insert(results, util.is_numeric(variable))
    end
  end

  variable_names = context["is-uncertain-date"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      table.insert(results, util.is_uncertain_date(variable))
    end
  end

  local position = context["position"]
  if position then
    -- TODO:
    table.insert(results, position == "first")
  end

  local type_names = context["type"]
  if type_names then
    for _, type_name in ipairs(util.split(type_names)) do
      table.insert(results, item["type"] == type_name)
    end
  end

  variable_names = context["variable"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      local res = (variable ~= nil and variable ~= "")
      table.insert(results, res)
    end
  end

  local match = context["match"] or "all"
  local status = false
  if match == "any" then
    status = util.any(results)
  elseif match == "none" then
    status = not util.any(results)
  else
    status = util.all(results)
  end
  if status then
    return self:render_children(item, context), status
  else
    return nil, false
  end
end


local ElseIf = If:new()


local Else = Element:new()

Else.render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  return self:render_children(item, context), true
end


return {
  choose = Choose,
  ["if"] = If,
  ["else-if"] = ElseIf,
  ["else"] = Else,
}
