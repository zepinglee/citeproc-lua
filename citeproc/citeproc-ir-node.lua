--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util = require("citeproc-util")


local IrNode = {
  type = "IrNode",
  base_class = "IrNode",
  element_name = nil,
  text = nil,
  formatting = nil,
  affixes = nil,
  children = nil,
  delimiter = nil,
}

function IrNode:new(children)
  local o = {
    type = self.type,
    children = children,
    base_class = self.base_class,
    group_var = "plain",
    -- element = element,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:derive(type)
  local o = {
    type = type,
    base_class = self.base_class,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:flatten(format)
  if self.type == "SeqIr" or self.type == "NameIr" then
    return self:flatten_seq(format)
  else
    local inlines = format:affixed_quoted(self.inlines, self.affixes, self.quotes);
    return format:with_display(inlines, self.display);
  end

end

function IrNode:flatten_seq(format)
  local inlines_list = {}
  for _, child in ipairs(self.children) do
    table.insert(inlines_list, child:flatten(format))
  end

  local inlines = format:group(inlines_list, self.delimiter, self.formatting)
  -- assert self.quotes == localized quotes
  inlines = format:affixed_quoted(inlines, self.affixes, self.quotes);
  inlines = format:with_display(inlines, self.display);
  return inlines
end

function IrNode:capitalize_first_term()
  -- util.debug(self)
  if self.type == "Rendered" and self.element and self.element.term then
    self.inlines[1]:capitalize_first_term()
  elseif self.type == "SeqIr" and self.children[1] then
    self.children[1]:capitalize_first_term()
  end
end



local Rendered = IrNode:derive("Rendered")

function Rendered:new(inlines, element)
  local o = {
    inlines = inlines,
    element = element,
    type = self.type,
    base_class = self.base_class,
    group_var = "plain",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

local NameIr = IrNode:derive("NameIr")
local SeqIr = IrNode:derive("SeqIr")

-- function SeqIr:new(children)
--   o = IrNode.new(self, children)
--   local o = {
--     children = children,
--     group_var = "plain",
--   }
--   setmetatable(o, self)
--   self.__index = self
--   return o
-- end



irnode.IrNode = IrNode
irnode.Rendered = Rendered
irnode.NameIr = NameIr
irnode.SeqIr = SeqIr

return irnode
