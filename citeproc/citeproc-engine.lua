--[[
  Copyright (C) 2021 Zeping Lee
--]]

local engine = {}

local dom = require("luaxml-domobject")

local richtext = require("citeproc-richtext")
local element = require("citeproc-element")
local nodes = require("citeproc-nodes")
local formats = require("citeproc-formats")
local util = require("citeproc-util")


local CiteProc = {}

function CiteProc.new (sys, style, lang, force_lang)
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
    citations = {},  -- A map
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
  o.csl:traverse_elements(CiteProc.set_base_class)
  o.csl:root_node().engine = o
  o.style = o.csl:get_path("style")[1]
  o.style.lang = lang
  o.csl:root_node().style = o.style

  o.style:set_lang(lang, force_lang)

  o.formatter = formats.latex

  setmetatable(o, { __index = CiteProc })
  return o
end

function CiteProc:updateItems (ids)
  self.registry.reflist = {}
  self.registry.registry = {}
  for _, id in ipairs(ids) do
    self:get_item(id)
  end
end

function CiteProc:processCitationCluster(citation, citationsPre, citationsPost)
  -- citation = {
  --   citationID = "CITATION-3",
  --   citationItems = {
  --     { id = "ITEM-1" },
  --     { id = "ITEM-2" },
  --   },
  --   properties = {
  --     noteIndex = 3,
  --   },
  -- }
  -- citationsPre = {
  --   {"CITATION-1", 1},
  --   {"CITATION-2", 2},
  -- }
  -- citationsPost = {
  --   {"CITATION-4", 4},
  -- }
  -- returns = {
  --   {
  --     bibchange = true,
  --     citation_errors = {},
  --   },
  --   {
  --     { 2, "[1,2]", "CITATION-3" }
  --   }
  -- }
  self.registry.citations[citation.citationID] = citation

  local items = {}

  for _, cite_item in ipairs(citation.citationItems) do
    cite_item.id = tostring(cite_item.id)
    local position_first = (self.registry.registry[cite_item.id] == nil)
    local item_data = self:get_item(cite_item.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local item = setmetatable({}, {__index = function (_, key)
      if cite_item[key] then
        return cite_item[key]
      else
        return item_data[key]
      end
    end})

    if not item.position and position_first then
      item.position = util.position_map["first"]
    end

    local first_reference_note_number = nil
    for _, pre_citation in ipairs(citationsPre) do
      pre_citation = self.registry.citations[pre_citation[1]]
      for _, pre_cite_item in ipairs(pre_citation.citationItems) do
        if pre_cite_item.id == cite_item.id then
          first_reference_note_number = pre_citation.properties.noteIndex
        end
        break
      end
      if first_reference_note_number then
        break
      end
    end
    item["first-reference-note-number"] = first_reference_note_number

    table.insert(items, item)
  end

  if #citationsPre > 0 then
    local previous_citation_id = citationsPre[#citationsPre][1]
    local previous_citation = self.registry.citations[previous_citation_id]
    self.registry.previous_citation = previous_citation
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local params = {
    bibchange = false,
    citation_errors = {},
  }

  local output = {}

  -- for _, citation_pre in ipairs(citationsPre) do
  --   local citation_id = citation_pre[1]
  --   local note_index = citation_pre[2]
  --   local context = {
  --     build = {},
  --     engine = self,
  --   }
  --   local citation_pre_items = {}
  --   local res = self.style:render_citation(citation_pre_items, context)
  --   -- TODO: correct citation_index
  --   local citation_index = 0
  --   table.insert(output, {citation_index, res, citation.citationID})
  -- end

  local context = {
    build = {},
    engine = self,
  }
  local res = self.style:render_citation(items, context)
  -- TODO: correct citation_index
  local citation_index = 0
  table.insert(output, {citation_index, res, citation.citationID})

  return {params, output}
end

function CiteProc:makeCitationCluster (citation_items)
  local items = {}
  for _, cite_item in ipairs(citation_items) do
    cite_item.id = tostring(cite_item.id)
    local position_first = (self.registry.registry[cite_item.id] == nil)
    local item_data = self:get_item(cite_item.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local item = setmetatable({}, {__index = function (_, key)
      if cite_item[key] then
        return cite_item[key]
      else
        return item_data[key]
      end
    end})

    if not item.position and position_first then
      item.position = util.position_map["first"]
    end
    table.insert(items, item)
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local context = {
    build = {},
    engine=self,
  }
  local res = self.style:render_citation(items, context)
  self.registry.previous_citation = {
    citationID = "pseudo-citation",
    citationItems = items,
    properties = {
      noteIndex = 1,
    }
  }
  return res
end

function CiteProc:makeBibliography()
  local items = {}

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  for _, id in ipairs(self.registry.reflist) do
    local item = self.registry.registry[id]
    table.insert(items, item)
  end

  local context = {
    build = {},
    engine=self,
  }
  local res = self.style:render_biblography(items, context)
  return res
end

function CiteProc:set_formatter(format)
  self.formatter = formats[format]
end

function CiteProc.set_base_class (node)
  if node:is_element() then
    local name = node:get_element_name()
    local element_class = nodes[name]
    if element_class then
      element_class:set_base_class(node)
    else
      element.Element:set_base_class(node)
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
  local item = self.sys.retrieveItem(id)
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
  local text = richtext.new(str)
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
    locale = self.sys.retrieveLocale(lang)
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


engine.CiteProc = CiteProc

return engine
