--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local group = {}

local Element = require("citeproc-element").Element
local util = require("citeproc-util")


local Group = Element:derive("group")

function Group:from_node(node)
  local o = Group:new()
  o:get_delimiter_attribute(node)
  o:get_affixes_attributes(node)
  o:get_display_attribute(node)
  o:get_formatting_attributes(node)

  o:process_children_nodes(node)

  return o
end

function Group:build_ir(engine, state, context)
  local ir = self:build_children_ir(engine, state, context)
  ir = self:_apply_delimiter(ir)
  ir = self:_apply_formatting(ir)
  ir = self:_apply_affixes(ir)
  ir = self:_apply_display(ir)
  return ir
end

function Group:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local num_variable_attempt = #context.variable_attempt

  local res = self:render_children(item, context)

  if #context.variable_attempt > num_variable_attempt then
    if not util.any(util.slice(context.variable_attempt, num_variable_attempt + 1)) then
      res = nil
    end
  end

  res = self:format(res, context)
  res = self:wrap(res, context)
  res = self:display(res, context)
  return res
end


group.Group = Group

return group
