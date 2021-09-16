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
    reflist = {}
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
  o.style.version = o.style:get_attribute("version")

  o.formatter = formats.html

  setmetatable(o, self)
  self.__index = self
  return o
end

function CiteProc:updateItems (ids)
  for _, id in ipairs(ids) do
    local item = self:retrieve_item(id)
    table.insert(self.registry.reflist, item)
  end
end

function CiteProc:processCitationCluster (citation, citationsPre, citationsPost)
  local output = {}
  local params = {}
  return {params, output}
end

function CiteProc:makeCitationCluster (citation_items)
  local items = {}
  for _, cite_item in ipairs(citation_items) do
    local item = self:retrieve_item(cite_item.id)
    table.insert(items, item)
    table.insert(self.registry.reflist, item)
  end
  return self.style:render_citation(items, {})
end

function CiteProc:makeBibliography ()
  local res = self.style:render_biblography(self.registry.reflist, {})
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

function CiteProc:retrieve_item (id)
  local item = {}
  local item_raw = self.sys:retrieveItem(id)
  if not item_raw then
    error("Failed to retrieve \"" .. id .. "\"")
  end
  for key, value in pairs(item_raw) do
    if key == "page" then
      item["page"] = value
      local page_first = util.split(value, "%s*[&,-]%s*")[1]
      page_first = util.split(page_first, util.unicode["en dash"])[1]
      item["page-first"] = page_first
    else
      item[key] = value
    end
  end
  return item
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
    locale:root_node().engine = self
    locale:root_node().style = self.style
    self.system_locales[lang] = locale
  end
  return locale
end


return CiteProc
