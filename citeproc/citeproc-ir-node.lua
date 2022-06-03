--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util = require("citeproc-util")


local IrNode = {
  ir_type = "irnode",
  element_name = nil,
  text = nil,
  formatting = nil,
  affixes = nil,
  children = nil,
  delimiter = nil,
}

function IrNode:new(element_name, text)
  local o = {
    element_name = element_name,
    text = text,
    ir_type = self.ir_type,
    group_var = "plain",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:derive(ir_type)
  local o = {
    ir_type = ir_type,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:flatten(format)
  if self.text then
    return {self.text}
  elseif self.children and #self.children > 0 then
    return self:flatten_seq(format)
  end
  return nil
end

function IrNode:flatten_seq(format)
  local res = {}
  for _, child in ipairs(self.children) do
    if type(child) == "string" then
      table.insert(res, child)
    elseif type(child) == "table" then
      table.insert(res, child:flatten(format))
    end
  end
  if #res == 0 then
    return nil
  end

  res = format:group(res, self.delimiter, self.formatting)
  res = format:affixed_quoted(res, self.prefix, self.suffix, self.quotes);
  res = format:with_display(res, self.display);
  return res

  -- if self.delimiter then
  --   res = util.join(res, self.delimiter)
  -- end


end

function IrNode:capitalize_first_term()
  if self.text then
    self.text = util.capitalize(self.text)
  elseif self.children and self.children[1] then
    local child_1 = self.children[1]
    if type(child_1) == "string" then
      child_1 = util.capitalize(child_1)
    elseif type(child_1) == "table" then
      child_1:capitalize_first_term()
    end
  end
end



local TextIr = IrNode:derive("TextIr")
local NameIr = IrNode:derive("NameIr")
local SeqIr = IrNode:derive("SeqIr")


irnode.IrNode = IrNode
irnode.TextIr = TextIr
irnode.NameIr = NameIr
irnode.SeqIr = SeqIr

function SeqIr:new(element_name)
  local o = {
    element_name = element_name,
    children = {},
    ir_type = self.ir_type,
    group_var = "plain",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

return irnode
