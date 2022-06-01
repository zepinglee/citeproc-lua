--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local choose = {}

local Element = require("citeproc-element").Element
local util = require("citeproc-util")

-- [Choose](https://docs.citationstyles.org/en/stable/specification.html#choose)
local Choose = Element:derive("choose")

function Choose:from_node(node)
  local o = Choose:new()
  o.children = {}
  o:process_children_nodes(node)
  if #o.children == 0 then
    return nil
  end
  return o
end

function Choose:build_ir(engine, state, context)
  for _, child in ipairs(self.children) do
    local ir = child:build_ir(engine, state, context)
    if ir then
      return ir
    end
  end
  return nil
end


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


local Condition = {
  condition = nil,
  value = nil,
  match_type = "all",
}

function Condition:new(condition, value, match_type)
  local o = {
    condition = condition,
    value = value,
    match_type = match_type or "all"
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


local If = Element:derive("if", {
  conditions = {},
  match = "all"
})

function If:from_node(node)
  local o = If:new()
  -- TODO: disambiguate
  o:set_bool_attribute(node, "disambiguate")

  -- o.is_numeric = util.to_list(node:get_attribute("is-numeric"))
  -- o.is_uncertain_date = util.to_list(node:get_attribute("is-uncertain-date"))
  -- o:set_attribute(node, "locator")
  -- o:set_attribute(node, "postition")
  -- o.type = util.to_list(node:get_attribute("type"))
  -- o.variable = util.to_list(node:get_attribute("variable"))

  o:add_conditions(node, "is-numeric")
  o:add_conditions(node, "is-uncertain-date")
  o:add_conditions(node, "locator")
  o:add_conditions(node, "postition")
  o:add_conditions(node, "type")
  o:add_conditions(node, "variable")

  o.match = util.to_list(node:get_attribute("match"))

  o:process_children_nodes(node)

  return o
end

function If:add_conditions(node, attribute)
  local values = node:get_attribute(attribute)
  if not values then
    return
  end
  for _, value in ipairs(util.split(values)) do
    local condition = Condition:new(attribute, value, self.match)
    table.insert(self.conditions, condition)
  end
end

function If:build_ir(engine, state, context)
  if self:evaluate_conditions(engine, state, context) then
    local ir = self:build_children_ir(engine, state, context)
    ir.should_inherit_delim = true
    return ir
  else
    return nil
  end
end

function If:evaluate_conditions(engine, state, context)
  local res = false
  for _, condition in ipairs(self.conditions) do
    if self:evaluate_condition(condition, state, context) then
      if self.match == "any" then
        return true
      elseif self.match == "none" then
        return false
      end
    else
      if self.match == "all" then
        return false
      end
    end
  end
  if self.match == "any" then
    return false
  else
    return true
  end
end

function If:evaluate_condition(condition, state, context)
  if condition.condition == "is-numeric" then
    local variable = context:get_variable(condition.value)
    return util.is_numeric(variable)

  elseif condition.condition == "is-uncertain-date" then
    local variable = context:get_variable(condition.value)
    return util.is_numeric(variable)

  elseif condition.condition == "locator" then
    local locator_label = context:get_variable("label")
    if locator_label == "sub verbo" then
      locator_label = "sub-verbo"
    end
    return locator_label == condition.value

  elseif condition.condition == "locator" then
    if context.in_bibliography then
      return false
    end
    local res = false
    local position = condition.value
    if context.mode == "citation" then
      if position == "first" then
        res = (context.item.position == util.position_map["first"])
      elseif position == "near-note" then
        res = context.item["near-note"] ~= nil and context.item["near-note"] ~= false
      else
        res = (context.item.position >= util.position_map[position])
      end
    end
    return res

  elseif condition.condition == "type" then
    local item_type = context:get_variable("type")
    return item_type == condition.value

  elseif condition.condition == "variable" then
    local var = condition.value
    if var == "locator" or var == "label" then
      return context.cite[var] ~= nil
    else
      local res = context.reference[var] ~= nil
      return res
    end
  end
end

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

  local locator_types = context.options["locator"]
  if locator_types then
    for _, locator_type in ipairs(util.split(locator_types)) do
      local locator_label = item.label or "page"
      local res = locator_label == locator_type
      if locator_type == "sub-verbo" then
        res = locator_label == "sub-verbo" or locator_label == "sub verbo"
      end
      table.insert(results, res)
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


local ElseIf = If:derive("else-if")


local Else = Element:derive("else")

function Else:from_node(node)
  local o = Else:new()
  o:process_children_nodes(node)
  return o
end

function Else:build_ir(engine, state, context)
  return self:build_children_ir(engine, state, context)
end

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
