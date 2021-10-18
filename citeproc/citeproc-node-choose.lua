local choose = {}

local element = require("citeproc.citeproc-element")
local util = require("citeproc.citeproc-util")


local Choose = element.Element:new()

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


local If = element.Element:new()

If.render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local results = {}

  local variable_names = context.options["is-numeric"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = self:get_variable(item, variable_name, context)
      table.insert(results, util.is_numeric(variable))
    end
  end

  variable_names = context.options["is-uncertain-date"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = self:get_variable(item, variable_name, context)
      table.insert(results, util.is_uncertain_date(variable))
    end
  end

  local positions = context.options["position"]
  if positions then
    for _, position in ipairs(util.split(positions)) do
      local res = false
      if context.mode == "citation" then
        if position == "first" then
          res = (item.position == util.position_map["first"])
        elseif position == "near-note" then
          res = item["near-note"] ~= nil and item["near-note"] ~= false
        else
          res = (item.position >= util.position_map[position])
        end
      end
      table.insert(results, res)
    end
  end

  local type_names = context.options["type"]
  if type_names then
    for _, type_name in ipairs(util.split(type_names)) do
      table.insert(results, item["type"] == type_name)
    end
  end

  variable_names = context.options["variable"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = self:get_variable(item, variable_name, context)
      local res = (variable ~= nil and variable ~= "")
      table.insert(results, res)
    end
  end

  local match = context.options["match"] or "all"
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


local Else = element.Element:new()

Else.render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  return self:render_children(item, context), true
end


choose.Choose = Choose
choose.If = If
choose.ElseIf = ElseIf
choose.Else = Else

return choose
