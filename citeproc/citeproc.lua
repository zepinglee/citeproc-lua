--[[
  Copyright (C) 2021 Zeping Lee
--]]

local dom = require("luaxml-domobject")

local Node = require("citeproc.citeproc-node")
local formats = require("citeproc.citeproc-formats")
local util = require("citeproc.citeproc-util")


local CiteProc = {}

function CiteProc:new (sys, style)
  if sys == nil then
    error("\"citeprocSys\" required")
  end
  if sys.retrieveLocale == nil then
    error("\"citeprocSys.retrieveLocale\" required")
  end
  if sys.retrieveItem == nil then
    error("\"citeprocSys.retrieveItem\" required")
  end
  local o = {}
  o.registry = {
    registry = {},  -- A map
    reflist = {},  -- A list
    previous_citation = nil,
  }

  o.sys = sys
  o.system_locales = {}

  if type(style) == "string" then
    o.csl = dom.parse(style)
  else
    o.csl = style
  end
  o.csl:traverse_elements(self.set_base_class)
  o.csl:root_node().engine = o
  o.style = o.csl:get_path("style")[1]
  o.csl:root_node().style = o.style

  o.formatter = formats.html

  setmetatable(o, self)
  self.__index = self
  return o
end

function CiteProc:updateItems (ids)
  self.registry.reslist = {}
  self.registry.registry = {}
  for _, id in ipairs(ids) do
    local item = self:retrieve_item(id)
  end
end

function CiteProc:processCitationCluster (citation, citationsPre, citationsPost)
  local output = {}
  local params = {}
  return {params, output}
end

function CiteProc:makeCitationCluster (citation_items)
  local items = {}
  for _, cite in ipairs(citation_items) do
    local position_first = false

    local res = self.registry.registry[id]
    if not res then
      position_first = true
      res = self:retrieve_item(cite.id)
    end

    local item = {
      ["locator"] = cite["locator"],
      ["label"]   = cite["label"],
      position    = cite["position"],
    }
    setmetatable(item, {__index = res})

    if not item.position and position_first then
      item.position = util.position_map["first"]
    end
    table.insert(items, item)
  end
  local res = self.style:render_citation(items, {engine=self})
  self.registry.previous_citation = items
  return res
end

function CiteProc:makeBibliography ()
  local items = {}
  for _, id in pairs(self.registry.reflist) do
    table.insert(items, self.registry.registry[id])
  end
  local res = self.style:render_biblography(items, {engine=self})
  local params = {}
  return params, res
end

function CiteProc.set_base_class (node)
  if node:is_element() then
    local name = node:get_element_name()
    local element = Node[name]
    if element then
      element:set_base_class(node)
    else
      Node["Element"]:set_base_class(node)
    end
  end
end

function CiteProc:get_item (id)
  local res = {}
  local item = self.registry.registry[id]
  if not item then
    item = self:retrieve_item(id)
  end
  -- Create a wrapper of the orignal item from registry so that
  -- it may hold different `locator` or `position` values for cites.
   setmetatable(res, {__index = item})
  return res
end

function CiteProc:retrieve_item (id)
  local res = {}
  local item = self.sys:retrieveItem(id)
  if not item then
    error("Failed to retrieve \"" .. id .. "\"")
  end
  setmetatable(res, {__index = item})

  if res["page"] and not res["page-first"] then
    local page_first = util.split(res["page"], "%s*[&,-]%s*")[1]
    page_first = util.split(page_first, util.unicode["en dash"])[1]
    res["page-first"] = page_first
  end

  if not self.registry.registry[id] then
    table.insert(self.registry.reflist, id)
  end
  self.registry.registry[id] = res
  return res
end

function CiteProc:get_system_locale (lang)
  local locale = self.system_locales[lang]
  if not locale then
    locale = self.sys:retrieveLocale(lang)
    if not locale then
      util.warning(string.format("Failed to retrieve locale \"%s\"", lang))
      return nil
    end
    if type(locale) == "string" then
      locale = dom.parse(locale)
    end
    locale:traverse_elements(self.set_base_class)
    locale = locale:get_path("locale")[1]
    locale:root_node().engine = self
    locale:root_node().style = self.style
    self.system_locales[lang] = locale
  end
  return locale
end


return CiteProc
