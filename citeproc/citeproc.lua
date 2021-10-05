--[[
  Copyright (C) 2021 Zeping Lee
--]]

local dom = require("luaxml-domobject")

local FormattedText = require("citeproc.citeproc-formatted-text")
local Node = require("citeproc.citeproc-node")
local formats = require("citeproc.citeproc-formats")
local util = require("citeproc.citeproc-util")

local inspect = require("inspect")


local CiteProc = {}

function CiteProc:new (sys, style, mode)
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
    requires_sorting = false,
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

  o.mode = mode

  o.formatter = formats.html

  setmetatable(o, self)
  self.__index = self
  return o
end

function CiteProc:updateItems (ids)
  self.registry.reslist = {}
  self.registry.registry = {}
  for _, id in ipairs(ids) do
    self:get_item(id)
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
    cite.id = tostring(cite.id)
    local position_first = (self.registry.registry[cite.id] == nil)
    local res = self:get_item(cite.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local item = {}
    for key, value in pairs(cite) do
      item[key] = value
    end
    setmetatable(item, {__index = res})

    if not item.position and position_first then
      item.position = util.position_map["first"]
    end
    table.insert(items, item)
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local res = self.style:render_citation(items, {engine=self})
  self.registry.previous_citation = items
  return res
end

function CiteProc:makeBibliography ()
  local items = {}

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  for _, id in pairs(self.registry.reflist) do
    local item = self.registry.registry[id]
    table.insert(items, item)
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
  local item = self.registry.registry[id]
  if not item then
    item = self:_retrieve_item(id)
    table.insert(self.registry.reflist, id)
    item["citation-number"] = #self.registry.reflist
    self.registry.registry[id] = item
    self.registry.requires_sorting = true
  end
  local res = {}
  setmetatable(res, {__index = item})
  return res
end

function CiteProc:_retrieve_item (id)
  -- Retrieve, copy, and normalize
  local res = {}
  local item = self.sys:retrieveItem(id)
  if not item then
    error("Failed to retrieve \"" .. id .. "\"")
  end

  item.id = tostring(item.id)

  for key, value in pairs(item) do
    if key == "title" then
      value = self.normalize_string(value)
    end
    res[key] = value
  end

  if res["page"] and not res["page-first"] then
    local page_first = util.split(res["page"], "%s*[&,-]%s*")[1]
    page_first = util.split(page_first, util.unicode["en dash"])[1]
    res["page-first"] = page_first
  end

  return res
end

function CiteProc.normalize_string (str)
  if not str or str == "" then
    return str
  end
  -- French punctuation spacing
  if type(str) == "string" then
    str = string.gsub(str, " ;", util.unicode["narrow no-break space"] .. ";")
    str = string.gsub(str, " %?", util.unicode["narrow no-break space"] .. "?")
    str = string.gsub(str, " !", util.unicode["narrow no-break space"] .. "!")
    str = string.gsub(str, " »", util.unicode["narrow no-break space"] .. "»")
    str = string.gsub(str, "« ", "«" .. util.unicode["narrow no-break space"])
  end
  -- local text = str
  local text = FormattedText.new(str)
  return text
end

function CiteProc:sort_bibliography()
  -- Sort the items in registry according to the `sort` in `bibliography.`
  -- This will update the `citation-number` of each item.
  local bibliography_sort = self.style:get_path("style bibliography sort")[1]
  if not bibliography_sort then
    return
  end
  local items = {}
  for _, id in ipairs(self.registry.reflist) do
    table.insert(items, self.registry.registry[id])
  end

  local context = {
    engine = self,
    style = self.style,
    mode = "bibliography",
  }
  context = self.style:process_context(context)
  context = self.style:get_path("style bibliography")[1]:process_context(context)

  bibliography_sort:sort(items, context)
  self.registry.reflist = {}
  for i, item in ipairs(items) do
    item["citation-number"] = i
    table.insert(self.registry.reflist, item.id)
  end
  self.registry.requires_sorting = false
end

function CiteProc:get_system_locale (lang)
  local locale = self.system_locales[lang]
  if not locale then
    locale = self.sys:retrieveLocale(lang)
    if not locale then
      self:warning(string.format("Failed to retrieve locale \"%s\"", lang))
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

function CiteProc:warning(message)
  if self.mode ~= "test" then
    if message == nil then
      message = ""
    else
      message = tostring(message)
    end
    io.stderr:write("Warning: " .. message .. "\n")
  end
end


return CiteProc
