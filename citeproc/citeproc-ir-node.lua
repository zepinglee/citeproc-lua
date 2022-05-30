--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}


local IrNode = {
  ir_type = "node",
  element_name = nil,
  text = nil,
  formatting = nil,
  children = nil,
  delimiter = nil,
}

function IrNode:new(element_name, text)
  local o = {
    element_name = element_name,
    text = text,
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

function IrNode:flatten()
  return self
end


local Quoted


irnode.IrNode = IrNode

return irnode
