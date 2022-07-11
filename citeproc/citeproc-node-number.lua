--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local number_module = {}

local Element = require("citeproc-element").Element

local Rendered = require("citeproc-ir-node").Rendered

local util = require("citeproc-util")


local Number = Element:derive("number")

function Number:new(node)
  local o = {
    element_name = "number",
    form = "numeric",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Number:from_node(node)
  local o = Number:new()
  o:set_attribute(node, "variable")
  o:set_attribute(node, "form")
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  return o
end

function Number:build_ir(engine, state, context)
  local number
  if not state.suppressed[self.variable] then
    number = context:get_variable(self.variable, self.form)
  end
  if not number then
    local ir = Rendered:new({}, self)
    ir.group_var = "missing"
    return ir
  end

  if type(number) == "number" then
    number = tostring(number)
    number = self:format_number(number, self.variable, self.form, context)
  elseif util.is_numeric(number) then
    number = self:format_number(number, self.variable, self.form, context)
  end

  local inlines = self:render_text_inlines(number, context)
  local ir = Rendered:new(inlines, self)
  ir.group_var = "important"

  -- Suppress substituted name variable
  if state.name_override and not context.sort_key then
    state.suppressed[self.variable] = true
  end
  return ir
end


number_module.Number = Number

return number_module
