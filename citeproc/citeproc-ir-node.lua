--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util = require("citeproc-util")


local IrNode = {
  _element = nil,
  _type = "IrNode",
  _base_class = "IrNode",
  text = nil,
  formatting = nil,
  affixes = nil,
  children = nil,
  delimiter = nil,
}

function IrNode:new(children, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    children = children,
    group_var = "plain",
  }

  o.group_var = "missing"
  for _, child_ir in ipairs(children) do
    if child_ir.group_var == "important" then
      o.group_var = "important"
      break
    elseif child_ir.group_var == "plain" then
      o.group_var = "plain"
    end
  end

  o.person_name_irs = {}
  if children then
    for _, child in ipairs(children) do
      if child.person_name_irs then
        util.extend(o.person_name_irs, child.person_name_irs)
      end
    end
  end

  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:derive(type)
  local o = {
    _type = type,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function IrNode:_debug(level)
  level = level or 0
  local text = string.format("\n%s [%s] %s <%s>", string.rep("    ", level), self.group_var, self._type, self._element)
  if self.children and #self.children > 0 then
    for _, child_ir in ipairs(self.children) do
      text = text .. child_ir:_debug(level + 1)
    end

  elseif self.inlines then
    for _, inline in ipairs(self.inlines) do
      text = text .. " " .. inline:_debug()
    end
  end
  return text
end

function IrNode:flatten(format)
  return format:flatten_ir(self)
end

function IrNode:capitalize_first_term()
  -- util.debug(self)
  if self._type == "Rendered" and self.element and (self.element.term == "ibid" or self.element.term == "and") then
    self.inlines[1]:capitalize_first_term()
  elseif self._type == "SeqIr" and self.children[1] then
    self.children[1]:capitalize_first_term()
  end
end

function IrNode:collect_year_suffix_irs()
  local year_suffix_irs = {}
  if self.children then
    for i, child_ir in ipairs(self.children) do
      if child_ir._type == "YearSuffix" then
        table.insert(year_suffix_irs, child_ir)
      elseif child_ir.children then
        util.extend(year_suffix_irs,
          child_ir:collect_year_suffix_irs())
      end
    end
  end
  return year_suffix_irs
end

function IrNode:find_first_year_ir()
  if self.is_year then
    return self
  end
  if self.children then
    for _, child_ir in ipairs(self.children) do
      local year_ir = child_ir:find_first_year_ir()
      if year_ir then
        return year_ir
      end
    end
  end
  return nil
end


local Rendered = IrNode:derive("Rendered")

function Rendered:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    element = element,  -- required for capitalizing first term
    inlines = inlines,
    group_var = "plain",
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


local YearSuffix = IrNode:derive("YearSuffix")

function YearSuffix:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    element = element,
    inlines = inlines,
    group_var = "plain",
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


local NameIr = IrNode:derive("NameIr")


local PersonNameIr = IrNode:derive("PersonNameIr")

function PersonNameIr:new(inlines, element)
  local o = {
    _element = element.element_name,
    _type = self._type,
    inlines = inlines,
    group_var = "plain",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


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
irnode.YearSuffix = YearSuffix
irnode.NameIr = NameIr
irnode.PersonNameIr = PersonNameIr
irnode.SeqIr = SeqIr

return irnode
