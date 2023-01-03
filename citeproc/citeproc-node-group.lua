--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local group = {}

local SeqIr = require("citeproc-ir-node").SeqIr
local Element = require("citeproc-element").Element
local util = require("citeproc-util")


local Group = Element:derive("group")

function Group:from_node(node)
  local o = Group:new()
  o:get_delimiter_attribute(node)
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_formatting_attributes(node)

  o:process_children_nodes(node)

  return o
end

function Group:build_ir(engine, state, context)
  local ir = self:build_group_ir(engine, state, context)
  if ir then
    ir.delimiter = self.delimiter
    ir.formatting = util.clone(self.formatting)
    ir.affixes = util.clone(self.affixes)
    ir.display = self.display
  end
  return ir
end

group.Group = Group

return group
