--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util = require("citeproc-util")


local IrNode = {
  ir_type = "node",
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
    table.insert(res, child:flatten(format))
  end
  if #res == 0 then
    return nil
  end

  res = format:group(res, self.delimiter, self.formatting)
  res = format:affixed_quoted(res, self.affixes, self.quotes);
  res = format:with_display(res, self.display);
  return res

  -- if self.delimiter then
  --   res = util.join(res, self.delimiter)
  -- end


end


local Quoted


irnode.IrNode = IrNode

return irnode
