--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local choose = {}

local element
local ir_node
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  element = require("citeproc-element")
  ir_node = require("citeproc-ir-node")
  util = require("citeproc-util")
else
  element = require("citeproc.element")
  ir_node = require("citeproc.ir-node")
  util = require("citeproc.util")
end

local Element = element.Element
local SeqIr = ir_node.SeqIr
local GroupVar = ir_node.GroupVar

local Position = util.Position


-- [Choose](https://docs.citationstyles.org/en/stable/specification.html#choose)
---@class Choose: Element
---@field children (If | ElseIf | Else)[]
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
  local active_branch
  local branch_ir

  local ir = SeqIr:new({}, self)
  ---@case ir SeqIr
  ir.should_inherit_delim = true
  ir.group_var = GroupVar.Missing

  for _, child in ipairs(self.children) do
    if child:evaluate_conditions(engine, state, context) then
      active_branch = child
      ---@cast child If
      branch_ir = child:build_ir(engine, state, context)
      if branch_ir and branch_ir.group_var ~= GroupVar.Missing then
        ir = SeqIr:new({branch_ir}, self)
        ir.should_inherit_delim = true
        ir.group_var = branch_ir.group_var
        ir.name_count = branch_ir.name_count
        ir.sort_key = branch_ir.sort_key
      else
        ir.group_var = GroupVar.Missing
      end
      break
    end
  end

  -- util.debug(ir)

  if not context.disambiguate then
    context.disambiguate = true

    for _, child in ipairs(self.children) do
      if child:evaluate_conditions(engine, state, context) then
        if child ~= active_branch then
          ---@cast child If
          ir.disambiguate_branch_ir = child:build_ir(engine, state, context)
        end
        break
      end
    end

    context.disambiguate = false
  end

  return ir
end


---@class Condition
---@field condition string
---@field value string
---@field match_type string
local Condition = {
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


---@class If: Element
---@field match string?
---@field conditions Condition[]
local If = Element:derive("if", {
  conditions = nil,
  match = "all"
})

---@return If
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

---@param node Node
---@param attribute string
function If:add_conditions(node, attribute)
  local values = node:get_attribute(attribute)
  if not values then
    return
  end
  if attribute == "type" then
    local type_dict = {}
    for _, value in ipairs(util.split(values)) do
      type_dict[value] = true
    end
    local condition = Condition:new(attribute, type_dict, self.match)
    table.insert(self.conditions, condition)
  else
    for _, value in ipairs(util.split(values)) do
      local condition = Condition:new(attribute, value, self.match)
      table.insert(self.conditions, condition)
    end
  end
end

function If:build_children_ir(engine, state, context)
  if not self.children then
    return nil
  end
  local irs = {}
  local name_count
  local ir_sort_key
  local group_var = GroupVar.Plain

  for _, child_element in ipairs(self.children) do
    local child_ir = child_element:build_ir(engine, state, context)

    if child_ir then
      local child_group_var = child_ir.group_var
      if child_group_var == GroupVar.Important then
        group_var = GroupVar.Important
      elseif child_group_var == GroupVar.Missing and child_ir._type ~= "YearSuffix" then
        if group_var == GroupVar.Plain then
          group_var = GroupVar.Missing
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
    group_var = GroupVar.Missing
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
    local variable = condition.value
    local variable_type = util.variable_types[variable] or "standard"

    if variable_type ~= "standard" and variable_type ~= "number" then
      util.warning(string.format("Expecting number variable for condition 'is-numeric', got %s '%s'", variable_type, variable))
      return false
    end

    local value = context:get_variable(variable)
    if not value then
      return false
    end
    if type(value) ~= "string" and type(value) ~= "number" then
      util.error(string.format("Expecting a string or number for variable '%s', got '%s'", variable, type(value)))
    end
    return util.is_numeric(value)

  elseif condition.condition == "is-uncertain-date" then
    local variable = condition.value

    local variable_type = util.variable_types[variable] or "standard"

    if variable_type ~= "date" then
      util.warning(string.format("Expecting date variable for condition 'is-uncertain-date', got '%s'", variable_type, variable))
      return false
    end
    local value = context:get_variable(variable)
    if not value then
      return false
    end
    return self:is_uncertain_date(value)

  elseif condition.condition == "locator" then
    local locator = context:get_variable("locator")
    if not locator or locator == "" then
      return false
    end
    local locator_label = context:get_variable("label")
    if locator_label == "sub verbo" then
      locator_label = "sub-verbo"
    end
    return locator_label == condition.value

  elseif condition.condition == "position" then
    return self:check_position(condition.value, context)

  elseif condition.condition == "type" then
    local item_type = context:get_variable("type")
    return condition.value[item_type] ~= nil

  elseif condition.condition == "variable" then
    local var = condition.value
    if var == "locator" or var == "label" then
      if context.in_bibliography then
        return false
      else
        return context.cite[var] ~= nil
      end
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

  local position_level = context.cite.position or context.cite.position_level or 0
  -- context.cite.position is for hacking in debugging
  -- bugreports_DemoPageFullCiteCruftOnSubsequent.txt
  if position == "first" then
    return (position_level == Position.First)
  elseif position == "near-note" then
    return context.cite["near-note"] or context.cite.near_note
  else
    return (position_level >= util.position_map[position])
  end
end


---@class ElseIf: If
local ElseIf = If:derive("else-if")


---@class Else: Element
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
