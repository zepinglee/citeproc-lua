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
  -- util.debug(condition)
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

  elseif condition.condition == "position" then
    if context.in_bibliography then
      return false
    end
    local res = false
    local position = condition.value
    if context.mode == "citation" then
      if position == "first" then
        res = (context.cite.position == util.position_map["first"])
      elseif position == "near-note" then
        util.debug(context.cite)
        local near_note = context.cite["near-note"]
        if near_note ~= nil then
          return near_note
        end
        local note_distance = context.cite.note_number - context.cite.last_reference_note_number
        return note_distance >= 0 and note_distance <= context.area.near_note_distance
      else
        res = (context.cite.position >= util.position_map[position])
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


choose.Choose = Choose
choose.If = If
choose.ElseIf = ElseIf
choose.Else = Else

return choose
