--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local choose = {}

local Element = require("citeproc-element").Element
local SeqIr = require("citeproc-ir-node").SeqIr
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
  local branch
  local branch_ir
  for _, child in ipairs(self.children) do
    if child:evaluate_conditions(engine, state, context) then
      branch = child
      branch_ir = child:build_ir(engine, state, context)
      break
    end
  end

  if not branch_ir then
    branch_ir = SeqIr:new({}, self)
    branch_ir.group_var = "missing"
  end

  local ir = SeqIr:new({branch_ir}, self)
  ir.group_var = branch_ir.group_var
  ir.name_count = branch_ir.name_count
  ir.sort_key = branch_ir.sort_key

  if not context.disambiguate then
    context.disambiguate = true

    for _, child in ipairs(self.children) do
      if child:evaluate_conditions(engine, state, context) then
        if child ~= branch then
          ir.disambiguate_branch_ir = child:build_ir(engine, state, context)
        end
        break
      end
    end

    context.disambiguate = false
  end

  return ir
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
  conditions = nil,
  match = "all"
})

function If:new()
  local o = Element.new(self)
  o.conditions = {}
  o.match = "all"
  return o
end

function If:from_node(node)
  local o = If:new()
  -- TODO: disambiguate
  -- o:set_bool_attribute(node, "disambiguate")

  o:add_conditions(node, "disambiguate")
  o:add_conditions(node, "is-numeric")
  o:add_conditions(node, "is-uncertain-date")
  o:add_conditions(node, "locator")
  o:add_conditions(node, "position")
  o:add_conditions(node, "type")
  o:add_conditions(node, "variable")

  o.match = node:get_attribute("match")

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

function If:build_children_ir(engine, state, context)
  if not self.children then
    return nil
  end
  local irs = {}
  local name_count
  local ir_sort_key
  local group_var = "plain"

  for _, child_element in ipairs(self.children) do
    local child_ir = child_element:build_ir(engine, state, context)

    if child_ir then
      local child_group_var = child_ir.group_var
      if child_group_var == "important" then
        group_var = "important"
      elseif child_group_var == "missing" then
        if group_var == "plain" then
          group_var = "missing"
        end
      end

      if child_ir.name_count then
        if not name_count then
          name_count = 0
        end
        name_count = name_count + child_ir.name_count
      end

      if child_ir.sort_key ~= nil then
        ir_sort_key = child_ir.sort_key
      end

      -- The condition can be simplified
      table.insert(irs, child_ir)
    end
  end

  if #irs == 0 then
    group_var = "missing"
  end

  local ir = SeqIr:new(irs, self)
  ir.name_count = name_count
  ir.sort_key = ir_sort_key
  ir.group_var = group_var
  return ir
end

function If:build_ir(engine, state, context)
  if not self:evaluate_conditions(engine, state, context) then
    return nil
  end

  local ir = self:build_children_ir(engine, state, context)
  if not ir then
    return nil
  end

  ir.should_inherit_delim = true
  return ir
end

function If:evaluate_conditions(engine, state, context)
  local res = false
  -- util.debug(self.conditions)
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
  -- util.debug(context.cite)
  -- util.debug(condition)
  if condition.condition == "disambiguate" then
    return context.disambiguate or (context.in_bibliography and context.reference.disambiguate)

  elseif condition.condition == "is-numeric" then
    local variable = context:get_variable(condition.value)
    return util.is_numeric(variable)

  elseif condition.condition == "is-uncertain-date" then
    local variable = context:get_variable(condition.value)
    -- TODO
    return self:is_uncertain_date(variable)

  elseif condition.condition == "locator" then
    local locator_label = context:get_variable("label")
    if locator_label == "sub verbo" then
      locator_label = "sub-verbo"
    end
    return locator_label == condition.value

  elseif condition.condition == "position" then
    return self:check_position(condition.value, context)

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

function If:is_uncertain_date(variable)
  if variable == nil then
    return false
  end
  local circa = variable["circa"]
  return circa and circa ~= ""
end

function If:check_position(position, context)
  -- util.debug(context.cite)
  if context.in_bibliography then
    return false
  end
  if position == "first" then
    return (context.cite.position == util.position_map["first"])
  elseif position == "near-note" then
    return context.cite["near-note"] or context.cite.near_note
  else
    return (context.cite.position >= util.position_map[position])
  end
end


local ElseIf = If:derive("else-if")


local Else = Element:derive("else")

function Else:from_node(node)
  local o = Else:new()
  o:process_children_nodes(node)
  return o
end

function Else:evaluate_conditions(engine, state, context)
  return true
end

Else.build_children_ir = If.build_children_ir
Else.build_ir = If.build_ir


choose.Choose = Choose
choose.If = If
choose.ElseIf = ElseIf
choose.Else = Else

return choose
