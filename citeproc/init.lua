--[[
  Copyright (C) 2021 Zeping Lee
--]]

local dom = require("luaxml-domobject")

local Node = require("citeproc.node")
local formats = require("citeproc.formats")
local util = require("citeproc.util")


local CiteProc = {}

function CiteProc:new(sys, style)
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
  if type(style) == "string" then
    o.csl = dom.parse(style)
  else
    o.csl = style
  end
  o.sys = sys
  o.registeredItems = {}
  o.root = o.csl:root_node()
  o.style = o.csl:get_path("style")[1]
  o.style.engine = o
  o.locales = {}
  o.csl:traverse_elements(function (node)
    Node.Element:make_base_class(node)
  end)
  o.formatter = formats.html
  setmetatable(o, self)
  self.__index = self
  return o
end

function CiteProc:updateItems(ids)
  for _, id in ipairs(ids) do
    local item = self:retrieve_item(id)
    table.insert(self.registry.reflist, item)
  end
end

function CiteProc:processCitationCluster(citation, citationsPre, citationsPost)
  local output = {}
  local params = {}
  return {params, output}
end

function CiteProc:makeCitationCluster(citation_items)
  local items = {}
  for _, cite_item in ipairs(citation_items) do
    local item = self:retrieve_item(cite_item.id)
    table.insert(items, item)
    table.insert(self.registry.reflist, item)
  end
  return self.style:render_citation(items, {})
end

function CiteProc:makeBibliography()
  local output = {}
  for _, item in ipairs(self.registry.reflist) do
    local res = self.style:render_biblography(item, {item=item})
    table.insert(output, res)
  end
  local params = {}
  return params, output
end

function CiteProc:retrieve_item(id)
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


return CiteProc
