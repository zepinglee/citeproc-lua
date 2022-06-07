--
-- Copyright (c) 2021-2022 Zeping Lee
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

  if not self.children then
    -- local ir = SeqIr:new()
    return nil
  end

  local irs = {}
  local group_var = "plain"
  for _, child_element in ipairs(self.children) do
    local child_ir = child_element:build_ir(engine, state, context)

    if child_ir then  -- TODO: should be removed
      -- cs:group and its child elements are suppressed if
      --   a) at least one rendering element in cs:group calls a variable (either
      --      directly or via a macro), and
      --   b) all variables that are called are empty. This accommodates
      --      descriptive cs:text and `cs:label` elements.
      local child_group_var = child_ir.group_var
      if child_group_var == "important" then
        group_var = "important"
      elseif child_group_var == "missing" then
        if group_var == "plain" then
          group_var = "missing"
        end
      end

      -- The condition can be simplified
      if child_ir and child_ir.group_var ~= "missing" then
        table.insert(irs, child_ir)
      end
    end
  end

  if #irs == 0 or group_var == "missing" then
    return nil
  end

  -- A non-empty nested cs:group is treated as a non-empty variable for the
  -- puropses of determining suppression of the outer cs:group.
  local ir = SeqIr:new(irs, self)
  ir.group_var = "important"

  -- ir = self:apply_delimiter(ir)
  -- ir = self:apply_formatting(ir)
  -- ir = self:apply_affixes(ir)
  -- ir = self:apply_display(ir)
  ir.delimiter = self.delimiter
  ir.formatting = self.formatting
  ir.affixes = self.affixes
  ir.display = self.display

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

  res = self:_apply_format(res, context)
  res = self:_apply_affixes(res, context)
  res = self:_apply_display(res, context)
  return res
end


group.Group = Group

return group
