--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local irnode = {}

local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  util = require("citeproc-util")
else
  util = require("citeproc.util")
end


---@enum GroupVar
local GroupVar = {
  Plain = 0,
  Important = 1,
  Missing = 2,
  UnresolvedPlain = 3,
}


---@class IrNode
---@field _element Element?
---@field _element_name string?
---@field _type string
---@field _base_class string
---@field text string?
---@field formatting any
---@field affixes any
---@field display any
---@field quotes LocalizedQuotes
---@field inlines InlineElement[]?
---@field children IrNode[]?
---@field delimiter string?
---@field should_inherit_delim boolean?
---@field group_var GroupVar
---@field sort_key string | boolean?
---@field person_name_irs IrNode[]
---@field name_count integer?
---@field is_year boolean?
local IrNode = {
  _element = nil,
  _element_name = nil,
  _type = "IrNode",
  _base_class = "IrNode",
  text = nil,
  formatting = nil,
  affixes = nil,
  children = nil,
  delimiter = nil,
}

---@param children IrNode[]
---@param element Element
---@return IrNode
function IrNode:new(children, element)
  local o = {
    _element = element,
    _element_name = element.element_name,
    _type = self._type,
    children = children,
    group_var = GroupVar.Plain,
  }

  o.group_var = GroupVar.Missing
  for _, child_ir in ipairs(children) do
    if child_ir.group_var == GroupVar.Important then
      o.group_var = GroupVar.Important
      break
    elseif child_ir.group_var == GroupVar.Plain then
      o.group_var = GroupVar.Plain
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

---@param level integer
---@return string
function IrNode:_debug(level)
  level = level or 0
  local ir_info_str = ""
  local ir_info = {}
  if self.delimiter then
    table.insert(ir_info, string.format('delimiter: "%s"', self.delimiter))
  end
  if self.should_inherit_delim then
    table.insert(ir_info, "should_inherit_delim: true")
  end
  if self.person_name_irs then
    table.insert(ir_info, "person_name_irs: " .. tostring(#self.person_name_irs))
  end
  if #ir_info > 0 then
    ir_info_str = string.format("{%s}", table.concat(ir_info, ' '))
  end
  local element_info = self._element.element_name
  for _, attr in ipairs({"name", "variable"}) do
    if self._element[attr] then
      element_info = element_info .. string.format(' %s="%s"', attr, self._element[attr])
    end
  end
  local text = string.format("\n%s [%s] %s <%s> %s", string.rep("    ", level), self.group_var, self._type, element_info, ir_info_str)
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
  if self._type == "Rendered" and self._element then
    local element = self._element
    ---@cast element Text
    if (element.term == "ibid" or element.term == "and") then
      self.inlines[1]:capitalize_first_term()
    end
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
  -- This also find the citation-label IR
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


---@class Rendered: IrNode
local Rendered = IrNode:derive("Rendered")

function Rendered:new(inlines, element)
  local o = {
    _element = element,
    _element_name = element.element_name,
    _type = self._type,
    element = element,  -- required for capitalizing first term
    inlines = inlines,
    group_var = GroupVar.Plain,
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


---@class YearSuffix: IrNode
local YearSuffix = IrNode:derive("YearSuffix")

function YearSuffix:new(inlines, element)
  local o = {
    _element = element,
    _element_name = element.element_name,
    _type = self._type,
    element = element,
    inlines = inlines,
    group_var = GroupVar.Plain,
  }

  setmetatable(o, self)
  self.__index = self
  return o
end


---@class NameIr: IrNode
local NameIr = IrNode:derive("NameIr")


---@class PersonNameIr: IrNode
local PersonNameIr = IrNode:derive("PersonNameIr")

function PersonNameIr:new(inlines, element)
  local o = {
    _element = element,
    _element_name = element.element_name,
    _type = self._type,
    inlines = inlines,
    group_var = GroupVar.Plain,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end


---@class SeqIr: IrNode
---@field children IrNode[]
---@field disambiguate_branch_ir IrNode?
local SeqIr = IrNode:derive("SeqIr")

-- function SeqIr:new(children)
--   o = IrNode.new(self, children)
--   local o = {
--     children = children,
--     group_var = GroupVar.Plain,
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

irnode.GroupVar = GroupVar

return irnode
