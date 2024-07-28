--
-- Copyright (c) 2021-2024 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local number_module = {}

local element
local ir_node
local util

if kpse then
  element = require("citeproc-element")
  ir_node = require("citeproc-ir-node")
  util = require("citeproc-util")
else
  element = require("citeproc.element")
  ir_node = require("citeproc.ir-node")
  util = require("citeproc.util")
end

local Element = element.Element
local Rendered = ir_node.Rendered
local GroupVar = ir_node.GroupVar


---@class Number: Element
---@field variable string
---@field form string?
---@field prefix string?
---@field suffix string?
---@field display string?
---@field text_case string?
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
    ---@cast number string | number?
  end
  if not number or number == "" then
    local ir = Rendered:new({}, self)
    ir.group_var = GroupVar.Missing
    return ir
  end

  if type(number) == "number" then
    number = tostring(number)
  end
  number = self:format_number(number, self.variable, self.form, context)

  local inlines = self:render_text_inlines(number, context)
  local ir = Rendered:new(inlines, self)
  ir.group_var = GroupVar.Important

  -- Suppress substituted name variable
  if state.name_override and not context.sort_key then
    state.suppressed[self.variable] = true
  end
  return ir
end


number_module.Number = Number

return number_module
