--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

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
    citation_strings = {},  -- A list
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
  o.linking_enabled = false

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

function CiteProc:updateUncitedItems(ids)
  for _, id in ipairs(ids) do
    if not self.registry.registry[id] then
      self:get_item(id)
    end
  end
  -- TODO: disambiguation
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

    if item_data then
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

  local citation_id_note_list = {}
  for _, citation_id_note in ipairs(citationsPre) do
    table.insert(citation_id_note_list, citation_id_note)
  end
  local note_index = 0
  if citation.properties and citation.properties.noteIndex then
    note_index = citation.properties.noteIndex
  end
  table.insert(citation_id_note_list, {citation.citationID, note_index})
  for _, citation_id_note in ipairs(citationsPost) do
    table.insert(citation_id_note_list, citation_id_note)
  end

  local citation_id_cited = {}
  for _, citation_id_note in ipairs(citation_id_note_list) do
    citation_id_cited[citation_id_note[1]] = true
  end
  for citation_id, _ in pairs(self.registry.citations) do
    if not citation_id_cited[citation_id] then
      self.registry.citations[citation_id] = nil
      self.registry.citation_strings[citation_id] = nil
    end
  end

  local output = {}

  for i, citation_id_note in ipairs(citation_id_note_list) do
    local citation_id = citation_id_note[1]
    -- local note_index = citation_id_note[2]
    if citation_id == citation.citationID then
      local context = {
        build = {},
        engine = self,
      }
      local citation_str = self.style:render_citation(items, context)

      self.registry.citation_strings[citation_id] = citation_str
      table.insert(output, {i - 1, citation_str, citation_id})
    else
      -- TODO: correct note_index
      -- TODO: update other citations after disambiguation
      local citation_str = self.registry.citation_strings[citation_id]
      if self.registry.citation_strings[citation_id] ~= citation_str then
        params.bibchange = true
        self.registry.citation_strings[citation_id] = citation_str
        table.insert(output, {i - 1, citation_str, citation_id})
      end
    end
  end

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

function CiteProc:enable_linking()
  self.linking_enabled = true
end

function CiteProc:disable_linking()
  self.linking_enabled = false
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

function CiteProc:get_style_class()
  return self.style:get_attribute("class") or "in-text"
end

function CiteProc:get_item (id)
  local item = self.registry.registry[id]
  if not item then
    item = self:_retrieve_item(id)
    if not item then
      return nil
    end
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
    util.warning(string.format('Failed to retrieve item "%s"', id))
    return nil
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
    str = string.gsub(str, " ??", util.unicode["narrow no-break space"] .. "??")
    str = string.gsub(str, "?? ", "??" .. util.unicode["narrow no-break space"])
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
