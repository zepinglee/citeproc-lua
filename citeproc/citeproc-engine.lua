--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local engine = {}

local dom
local context
local element
local nodes
local node_locale
local node_style
local output
local util

local using_luatex, _ = pcall(require, "kpse")
if using_luatex then
  dom = require("luaxml-domobject")
  context = require("citeproc-context")
  element = require("citeproc-element")
  nodes = require("citeproc-nodes")
  node_locale = require("citeproc-node-locale")
  node_style = require("citeproc-node-style")
  output = require("citeproc-output")
  util = require("citeproc-util")
else
  dom = require("citeproc.luaxml.domobject")
  context = require("citeproc.context")
  element = require("citeproc.element")
  nodes = require("citeproc.nodes")
  node_locale = require("citeproc.node-locale")
  node_style = require("citeproc.node-style")
  output = require("citeproc.output")
  util = require("citeproc.util")
end

local Element = element.Element
local Style = node_style.Style
local Locale = node_locale.Locale
local Context = context.Context
local IrState = context.IrState
local LatexWriter = output.LatexWriter
local HtmlWriter = output.HtmlWriter
local SortStringFormat = output.SortStringFormat

local Position = util.Position


---@alias CitationId string
---@alias ItemId string | number
---@alias NoteIndex integer
---@alias ChapterIndex number

---@class CitationData
---@field citationID CitationId
---@field citationItems CitationItem[]
---@field properties CitationProperties
---@field citation_index integer
---@field sorted_items CitationItem[]

---@class CitationItem
---@field id CiteId
---@field prefix string?
---@field suffix string?
---@field locator string?
---@field label string?
---@field position_level Position?
---@field near_note boolean?
---@field num_citations integer?

---@class CitationProperties
---@field noteIndex NoteIndex,
---@field chapterIndex ChapterIndex,
---@field mode string?
---@field prefix string?
---@field suffix string?
---@field unsorted boolean?


---@class NameVariable
---@field family string?
---@field given string?
---@field dropping-particle string?
---@field non-dropping-particle string?
---@field suffix string?
---@field comma-suffix string | number | boolean?
---@field static-ordering string | number | boolean?
---@field literal string | number | boolean?
---@field parse-names string | number | boolean?

---@class DateVariable
---@field date-parts (string | number)[][]
---@field season (string | number)
---@field circa (string | number | boolean)
---@field literal string
---@field raw string

---@alias ItemData { id: ItemId, type: string, language: string?, [string]: string | number | NameVariable[] | DateVariable }


---@class Registry
---@field citations_by_id table<ItemId, CitationData>
---@field citation_list CitationData[]
---@field citations_by_item_id table<ItemId, CitationData[]>
---@field registry table<ItemId, ItemData>
---@field reflist ItemId[]
---@field uncited_list ItemId[]
---@field previous_citation CitationData?
---@field requires_sorting boolean
---@field widest_label string
---@field maxoffset integer
local Registry = {}


---@class CiteProc
---@field style Style
---@field sys CiteProcSys
---@field locales table<LanguageCode, Locale>
---@field system_locales table<LanguageCode, Locale>
---@field lang LanguageCode
---@field output_format OutputFormat
---@field opt table
---@field registry Registry
---@field cite_first_note_numbers table<ItemId, NoteIndex>
---@field cite_last_note_numbers table<ItemId, NoteIndex>
---@field tainted_item_ids table<ItemId, boolean>
---@field disam_irs IrNode[]
---@field cite_irs_by_output table<string, IrNode[]>
---@field person_names PersonNameIr[]
---@field person_names_by_output table<string, PersonNameIr[]>
---@field locale_tags_info_dict table<LanguageCode, table>
local CiteProc = {}

---@class CiteProcSys
---@field retrieveLocale fun(LanguageCode): string?
---@field retrieveItem fun(ItemId): ItemData?

---@param sys table
---@param style string
---@param lang string?
---@param force_lang boolean?
---@return CiteProc
function CiteProc.new(sys, style, lang, force_lang)
  if not sys then
    error("\"citeprocSys\" required")
  end
  if sys.retrieveLocale == nil then
    error("\"citeprocSys.retrieveLocale\" required")
  end
  if sys.retrieveItem == nil then
    error("\"citeprocSys.retrieveItem\" required")
  end
  local parsed_style = Style:parse(style)
  local engine_lang = parsed_style.default_locale
  if not engine_lang or force_lang then
    engine_lang = lang or "en-US"
  end
  ---@type CiteProc
  local o = {
    style = parsed_style,
    sys = sys,
    locales = {},
    system_locales = {},
    lang = engine_lang,
    output_format = LatexWriter:new(),
    opt = {
      -- Similar to citeproc-js's development_extensions.wrap_url_and_doi
      wrap_url_and_doi = false,
      citation_link = false,
      title_link = false,
    },
    registry = {
      citations_by_id = {},  -- A map
      citation_list = {},  -- A list
      citations_by_item_id = {},  -- A map from item id to a map of citations
      registry = {},  -- A map of bibliographic meta data
      reflist = {},  -- list of cited ids
      uncited_list = {},
      previous_citation = nil,
      requires_sorting = false,
      widest_label = "",
      maxoffset = 0,
    },

    cite_first_note_numbers = {},
    cite_last_note_numbers = {},

    tainted_item_ids = {},

    disam_irs = {},
    -- { <ir1>, <ir2>, ...  }

    cite_irs_by_output = {},
    -- {
    --   ["Roe, J"] = {<ir1>},
    --   ["Doe, J"] = {<ir2>, <ir3>},
    --   ["Doe, John"] = {<ir2>},
    --   ["Doe, Jack"] = {<ir2>},
    -- }

    person_names = {},
    person_names_by_output = {},

    locale_tags_info_dict = {},
  }

  setmetatable(o, {__index = CiteProc})
  return o
end

---@return boolean
function CiteProc:is_dependent_style()
  return self.style.info.independent_parent ~= nil
end

---@return string?
function CiteProc:get_independent_parent()
  return self.style.info.independent_parent
end

---@param ids CiteId[]
function CiteProc:updateItems(ids)
  self.registry.reflist = {}
  self.registry.registry = {}
  self.person_names = {}
  self.person_names_by_output = {}
  self.disam_irs = {}
  self.cite_irs_by_output = {}

  local cite_items = {}
  local loaded_ids = {}

  for _, id in ipairs(ids) do
    if not loaded_ids[id] then
      table.insert(cite_items, {id = id})
      loaded_ids[id] = true
    end
  end
  for _, id in ipairs(self.registry.uncited_list) do
    if not loaded_ids[id] then
      table.insert(cite_items, {id = id})
      loaded_ids[id] = true
    end
  end

  -- Clean the first note number to reset all the positions
  self.cite_first_note_numbers = {}

  -- TODO: optimize this
  self:makeCitationCluster(cite_items)

  self.registry.previous_citation = nil
  self.cite_first_note_numbers = {}
  self.cite_last_note_numbers = {}

  for _, item in ipairs(self.registry.registry) do
    item.year_suffix_number = nil
    item["year-suffix"] = nil
  end
end

function CiteProc:updateUncitedItems(uncited_ids)
  -- self.registry.reflist = {}
  self.registry.registry = {}
  self.registry.uncited_list = {}
  self.person_names = {}
  self.person_names_by_output = {}
  self.disam_irs = {}
  self.cite_irs_by_output = {}

  local cite_items = {}
  local loaded_ids = {}

  for _, id in ipairs(self.registry.reflist) do
    if not loaded_ids[id] then
      table.insert(cite_items, {id = id})
      loaded_ids[id] = true
    end
  end
  self.registry.reflist = {}

  for _, id in ipairs(uncited_ids) do
    if not loaded_ids[id] then
      table.insert(cite_items, {id = id})
      loaded_ids[id] = true
    end
  end

  loaded_ids = {}
  for _, id in ipairs(uncited_ids) do
    if not loaded_ids[id] then
      table.insert(self.registry.uncited_list, id)
      loaded_ids[id] = true
    end
  end

  -- TODO: optimize this
  self:makeCitationCluster(cite_items)

  self.registry.previous_citation = nil
  self.cite_first_note_numbers = {}
  self.cite_last_note_numbers = {}
end


---@alias PreCitation [CitationId, NoteIndex, ChapterIndex?]
---@alias PostCitation [CitationId, NoteIndex, ChapterIndex?]

---@param citation CitationData
---@param citations_pre PreCitation[]
---@param citations_post PostCitation[]
---@return [table, [integer, string, CitationId][]]
function CiteProc:processCitationCluster(citation, citations_pre, citations_post)
  self:_check_valid_citation_element()
  citation = self:_normalize_citation_input(citation)
  self:_check_input(citation, citations_pre, citations_post)

  local citation_list, item_ids = self:_build_reconstituted_citation_list(citation, citations_pre, citations_post)
  self:updateItems(item_ids)
  if #citation.sorted_items > 1 and self.style.citation.sort and not citation.properties.unsorted then
    citation.sorted_items = self.style.citation:sorted_citation_items(citation.citationItems, self)
  end

  local tainted_citation_ids = self:_set_positions(citation_list)

  tainted_citation_ids[citation.citationID] = true

  local params = {
    bibchange = false,
    citation_errors = {},
  }
  -- TODO: evaluate params.bibchange

  local result = self:_rerun_changed_cites(tainted_citation_ids)

  return {params, result}
end

-- A variant of processCitationCluster() for easy use with LaTeX.
-- It should be run after refreshing the registry (updateItems()) with all items
---@param citation CitationData
---@return string
function CiteProc:process_citation(citation)
  self:_check_valid_citation_element()
  citation = self:_normalize_citation_input(citation)

  local citations_pre = {}
  for _, citation_ in ipairs(self.registry.citation_list) do
    table.insert(citations_pre, {citation_.citationID, citation_.properties.noteIndex})
  end
  self:_check_input(citation, citations_pre, {})

  local citation_list, item_ids = self:_build_reconstituted_citation_list(citation, citations_pre, {})
  -- self:updateItems(item_ids)
  for _, cite_item in ipairs(citation.citationItems) do
    self:get_item(cite_item.id)
  end
  if #citation.sorted_items > 1 and self.style.citation.sort and not citation.properties.unsorted then
    citation.sorted_items = self.style.citation:sorted_citation_items(citation.citationItems, self)
  end

  self:_set_positions(citation_list)
  local tainted_citation_ids = {[citation.citationID] = true}
  local result = self:_rerun_changed_cites(tainted_citation_ids)
  return result[1][2]
end

function CiteProc:makeCitationCluster(citation_items)
  local special_form = nil
  local items = {}

  for i, cite_item in ipairs(citation_items) do
    cite_item = self:_normalize_cite_item(cite_item)
    local item_data = self:get_item(cite_item.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local cite_item = setmetatable(cite_item, {__index = item_data})

    if not special_form then
      for _, form in ipairs({"author-only", "suppress-author", "coposite"}) do
        if cite_item[form] then
          special_form = form
        end
      end
    end

    -- Set "first-reference-note-number" variable when called from
    -- processCitationCluster() > updateItems()
    local citations = self.registry.citations_by_item_id[cite_item.id]
    if citations and #citations > 0 then
      cite_item["first-reference-note-number"] = citations[1].properties.noteIndex
    end

    cite_item.position_level = Position.First
    if self.cite_first_note_numbers[cite_item.id] then
      cite_item.position_level = Position.Subsequent
    else
      self.cite_first_note_numbers[cite_item.id] = 0
    end

    local preceding_cite
    if i == 1 then
      local previous_citation = self.registry.previous_citation
      if previous_citation then
        if #previous_citation.citationItems == 1 and previous_citation.citationItems[1].id == cite_item.id then
          preceding_cite = previous_citation.citationItems[1]
        end
      end
    elseif citation_items[i - 1].id == cite_item.id then
      preceding_cite = citation_items[i - 1]
    end

    if preceding_cite then
      cite_item.position_level = self:_get_ibid_position(cite_item, preceding_cite)
    end

    table.insert(items, cite_item)
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  self:_check_valid_citation_element()
  local citation_element = self.style.citation
  if special_form == "author-only" and self.style.intext then
    citation_element = self.style.intext
  end

  if #items > 1 and self.style.citation.sort then
    items = self.style.citation:sorted_citation_items(items, self)
  end
  local res = citation_element:build_cluster(items, self)

  -- local context = {
  --   build = {},
  --   engine=self,
  -- }
  -- local res = self.style:render_citation(items, context)

  self.registry.previous_citation = {
    citationID = "pseudo-citation",
    citationItems = items,
    properties = {
      noteIndex = 0,
    },
  }
  return res
end

---@param bibsection any
---@return [{[string]: string | number | boolean}, string[]]
function CiteProc:makeBibliography(bibsection)
  -- The bibsection works as a filter described in
  -- <https://citeproc-js.readthedocs.io/en/latest/running.html#selective-output-with-makebibliography>.
  if not self.style.bibliography then
    return {{}, {}}
  end

  local res = {}

  self.registry.widest_label = ""
  self.registry.maxoffset = 0

  local ids = self:_get_sorted_refs()
  local excluded_ids
  if bibsection then
    ids, excluded_ids = self:_filter_with_bibsection(ids, bibsection)
  end
  for _, id in ipairs(ids) do
    local str = self.style.bibliography:build_bibliography_str(id, self)
    table.insert(res, str)
  end

  local bib_start = self.output_format.markups["bibstart"]
  local bib_end = self.output_format.markups["bibend"]
  if type(bib_start) == "function" then
    bib_start = bib_start(self)
  end
  if type(bib_end) == "function" then
    bib_end = bib_end(self)
  end

  local params = {
    hangingindent = self.style.bibliography.hanging_indent,
    ["second-field-align"] = self.style.bibliography.second_field_align or false,
    linespacing = self.style.bibliography.line_spacing,
    entryspacing = self.style.bibliography.entry_spacing,
    maxoffset = self.registry.maxoffset,
    widest_label = self.registry.widest_label,
    bibstart = bib_start,
    bibend = bib_end,
    entry_ids = ids,
    excluded_ids = excluded_ids,
  }

  return {params, res}
end

function CiteProc:_check_valid_citation_element()
  if not self.style.citation then
    if self.style.info and self.style.info.independent_parent then
      util.error(string.format("This is a dependent style linked to '%s'.", self.style.info.independent_parent))
    else
      util.error("No <citation> in style.")
    end
  end
end

---@param citation CitationData
---@return CitationData
function CiteProc:_normalize_citation_input(citation)
  citation = util.deep_copy(citation)

  if not citation.citationID then
    citation.citationID = "CITATION-" .. tostring(#self.registry.citation_list)
  end

  if not citation.citationItems then
    citation.citationItems = {}
  end
  for i, cite_item in ipairs(citation.citationItems) do
    citation.citationItems[i] = self:_normalize_cite_item(cite_item)
  end

  -- Fix missing noteIndex: sort_CitationNumberPrimaryAscendingViaMacroCitation.txt
  if not citation.properties then
    citation.properties = {}
  end
  if not citation.properties.noteIndex then
    citation.properties.noteIndex = 0
  end
  if not citation.properties.chapterIndex then
    citation.properties.chapterIndex = 0
  end

  citation.sorted_items = util.clone(citation.citationItems)

  return citation
end

---@param cite_item CitationItem
---@return CitationItem
function CiteProc:_normalize_cite_item(cite_item)
  -- Shallow copy
  cite_item = util.clone(cite_item)
  cite_item.id = tostring(cite_item.id)

  -- Use "page" as locator label if missing
  -- label_PluralWithAmpersand.txt
  if cite_item.locator and not cite_item.label then
    cite_item.label = "page"
  end

  local the_context = Context:new()
  the_context.engine = self
  the_context.style = self.style
  the_context.area = self
  the_context.in_bibliography = false
  the_context.lang = self.lang
  the_context.locale = self:get_locale(self.lang)
  the_context.format = self.output_format

  if cite_item.prefix then
    -- Assert CSL rich-text or HTML-like tagged string
    if cite_item.prefix == "" then
      cite_item.prefix = nil
    end
  end
  if cite_item.suffix then
    if cite_item.suffix == "" then
      cite_item.suffix = nil
    end
  end

  return cite_item
end

---@param citation CitationData
---@param citations_pre PreCitation[]
---@param citations_post PostCitation[]
function CiteProc:_check_input(citation, citations_pre, citations_post)
  local citation_info_list = {}
  do
    for i, pre_citation in ipairs(citations_pre) do
      local citation_id = pre_citation[1]
      local note_index = pre_citation[2]
      local chapter_number = pre_citation[3] or self.registry.citations_by_id[citation_id].properties.chapterIndex or 0
      local name = string.format("citationsPre[%d]", i)
      table.insert(citation_info_list, {citation_id, note_index, chapter_number, name})
    end
    table.insert(citation_info_list,
      {citation.citationID, citation.properties.noteIndex, citation.properties.chapterIndex or 0, "citation"})
    for i, post_citation in ipairs(citations_post) do
      local citation_id = post_citation[1]
      local note_index = post_citation[2]
      local chapter_number = post_citation[3] or self.registry.citations_by_id[citation_id].properties.chapterIndex or
          0
      local name = string.format("citationsPost[%d]", i)
      table.insert(citation_info_list, {citation_id, note_index, chapter_number, name})
    end
  end

  ---@type table<CitationId, boolean>
  local citation_dict = {}
  local last_note_number = 0
  local last_chapter_number = 0

  for _, citation_info in ipairs(citation_info_list) do
    local citation_id, note_index, chapter_number, name = table.unpack(citation_info)
    if citation_dict[citation_id] then
      error(string.format("Previously referenced citationID '%s' encountered at %s", name))
    end
    citation_dict[citation_id] = true
    if chapter_number and chapter_number > 0 then
      if chapter_number < last_chapter_number then
        util.warning(string.format("Chapter index sequence is not sane at %s", name))
      end
      if chapter_number ~= last_chapter_number then
        last_note_number = 0
      end
      last_chapter_number = chapter_number
    end
    if note_index > 0 then
      if note_index < last_note_number then
        util.warning(string.format("Note index sequence is not sane at %s", name))
      end
      last_note_number = note_index
    end
  end

end

---@param citation CitationData
---@param citations_pre PreCitation[]
---@param citations_post PostCitation[]
---@return CitationData[]
---@return CiteId[]
function CiteProc:_build_reconstituted_citation_list(citation, citations_pre, citations_post)
  self.registry.citations_by_id[citation.citationID] = citation

  ---@type [CitationId, NoteIndex][]
  local citation_note_pairs = {}
  util.extend(citation_note_pairs, citations_pre)
  table.insert(citation_note_pairs, {citation.citationID, citation.properties.noteIndex})
  util.extend(citation_note_pairs, citations_post)

  ---@type CiteId[]
  local item_ids = {}
  ---@type table<ItemId, boolean>
  local item_id_dict = {}
  ---@type CitationData[]
  local citation_list = {}
  ---@type table<CitationId, CitationData>
  local citations_by_id = {}
  -- TODO: Remove citations_by_item_id
  ---@type table<ItemId, CitationData[]>
  local citations_by_item_id = {}

  for citation_index, pair in ipairs(citation_note_pairs) do
    local citation_id, note_index = table.unpack(pair)
    local citation_ = self.registry.citations_by_id[citation_id]
    if not citation_ then
      util.error("Citation not in registry.")
    end
    citation_.citation_index = citation_index
    citation_.properties.noteIndex = note_index

    table.insert(citation_list, citation_)
    citations_by_id[citation_.citationID] = citation_
    for _, cite_item in ipairs(citation_.citationItems) do
      if not item_id_dict[cite_item.id] then
        item_id_dict[cite_item.id] = true
        table.insert(item_ids, cite_item.id)
        citations_by_item_id[cite_item.id] = {}
      end
      table.insert(citations_by_item_id[cite_item.id], citation_)
    end
  end
  self.registry.citation_list = citation_list
  self.registry.citations_by_id = citations_by_id
  self.registry.citations_by_item_id = citations_by_item_id
  return citation_list, item_ids
end

---@param citation_list CitationData[]
---@return table<CitationId, boolean>
function CiteProc:_set_positions(citation_list)
  ---@type table<CitationId, boolean>
  local tainted_citation_ids = {}

  ---@type {[integer]: CitationData[]}
  local chapter_citations = {}
  for _, citation in ipairs(citation_list) do
    local chapter_number = citation.properties.chapterIndex
    if not chapter_citations[chapter_number] then
      chapter_citations[chapter_number] = {}
    end
    table.insert(chapter_citations[chapter_number], citation)
  end

  for _, citations in pairs(chapter_citations) do
    self:_update_chapter_positions(citations, tainted_citation_ids)
  end

  -- Update tainted citation ids because of citation-number's change
  -- The self.tainted_item_ids were added in the sort_bibliography() procedure.
  for item_id, _ in pairs(self.tainted_item_ids) do
    if self.registry.citations_by_item_id[item_id] then
      for _, citation in ipairs(self.registry.citations_by_item_id[item_id]) do
        tainted_citation_ids[citation.citationID] = true
      end
    end
  end

  return tainted_citation_ids
end

---@param citation_list CitationData[]
---@param tainted_citation_ids table<CitationId, boolean>
---@return table<string, boolean>
function CiteProc:_update_chapter_positions(citation_list, tainted_citation_ids)
  ---@type CitationData[]
  local in_text_citations = {}
  ---@type CitationData[]
  local note_citations = {}
  for _, citation in ipairs(citation_list) do
    if citation.properties.noteIndex == 0 then
      table.insert(in_text_citations, citation)
    else
      table.insert(note_citations, citation)
    end
  end

  for _, citations in ipairs({in_text_citations, note_citations}) do
    ---@type table<CiteId, NoteIndex>
    local first_ref = {}
    ---@type table<CiteId, NoteIndex>
    local last_ref = {}
    ---@type table<NoteIndex, CitationId[]>
    local num_citations_in_note = {}

    for _, citation in ipairs(citations) do
      local note_index = citation.properties.noteIndex
      if not num_citations_in_note[note_index] then
        num_citations_in_note[note_index] = {}
      end
      table.insert(num_citations_in_note[note_index], citation.citationID)
    end

    local previous_citation
    for _, citation in ipairs(citations) do
      local mode = citation.properties.mode
      local note_index = citation.properties.noteIndex
      local previous_cite
      for _, cite_item in ipairs(citation.sorted_items) do
        local position_properties = {
          position_level = cite_item.position_level,
          ["first-reference-note-number"] = cite_item["first-reference-note-number"],
          near_note = cite_item.near_note,
        }

        self:_set_cite_item_position(cite_item, note_index, previous_cite, previous_citation, citation, first_ref,
          last_ref, num_citations_in_note)

        if self:_check_tainted_position_change(cite_item, position_properties) then
          tainted_citation_ids[citation.citationID] = true
        end

        -- https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html#citations
        -- Citations within the main text of the document have a noteIndex of zero.
        if mode ~= "author-only" and mode ~= "full-cite" then
          if not first_ref[cite_item.id] and note_index > 0 then
            -- note_index == 0 implied an in-text citation
            first_ref[cite_item.id] = note_index
          end
          last_ref[cite_item.id] = note_index
          previous_cite = cite_item
        end
      end

      if mode ~= "author-only" and mode ~= "full-cite" then
        previous_citation = citation
      end
    end

    if self.style.class == "note" and self.style.has_disambiguate then
      ---@type table<CiteId, CitationData[]>
      local citations_by_item_id = {}
      for _, citation in ipairs(citations) do
        if citation.properties.mode ~= "author-only" and citation.properties.mode ~= "full-cite" then
          for _, cite_item in ipairs(citation.sorted_items) do
            if not citations_by_item_id[cite_item.id] then
              citations_by_item_id[cite_item.id] = {}
            end
            table.insert(citations_by_item_id[cite_item.id], citation)
          end
        end
      end
      for _, citation in ipairs(citations) do
        if citation.properties.mode ~= "author-only" and citation.properties.mode ~= "full-cite" then
          for _, cite_item in ipairs(citation.sorted_items) do
            assert(citations_by_item_id[cite_item.id])
            local num_citations = #citations_by_item_id[cite_item.id]
            if not cite_item.num_citations or (num_citations < 2) ~= (cite_item.num_citations < 2) then
              -- self.tainted_item_ids[cite_item.id] = true
              for _, citation_ in ipairs(citations_by_item_id[cite_item.id]) do
                tainted_citation_ids[citation_.citationID] = true
              end
            end
            cite_item.num_citations = num_citations
          end
        end
      end
    end
  end

  return tainted_citation_ids
end

function CiteProc:_set_cite_item_position(cite_item, note_index, previous_cite, previous_citation, citation, first_ref,
    last_ref, num_citations_in_note)
  -- https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html#citations
  -- Citations within the main text of the document have a noteIndex of zero.
  if citation.properties.mode == "author-only" or citation.properties.mode == "full-cite" then
    -- discretionary_IbidInAuthorDateStyleWithoutIntext.txt
    cite_item.position_level = Position.First
    cite_item.near_note = false
    return
  end

  local first_reference_note_number = first_ref[cite_item.id]
  if first_reference_note_number then
    cite_item.position_level = Position.Subsequent
    cite_item["first-reference-note-number"] = first_reference_note_number
  else
    cite_item.position_level = Position.First
  end

  local preceding_cite_item = self:_find_preceding_ibid_item(cite_item, previous_cite, previous_citation, note_index,
    num_citations_in_note)

  if preceding_cite_item then
    cite_item.position_level = self:_get_ibid_position(cite_item, preceding_cite_item)
  end

  cite_item.near_note = false
  local last_note_number = last_ref[cite_item.id]
  if last_note_number then
    local note_distance = note_index - last_note_number
    cite_item.near_note = (note_distance <= self.style.citation.near_note_distance)
  end

end

-- Find the preceding cite referencing the same item
function CiteProc:_find_preceding_ibid_item(cite_item, previous_cite, previous_citation, note_index,
    num_citations_in_note)
  if previous_cite then
    -- a. the current cite immediately follows on another cite, within the same
    --    citation, that references the same item
    if cite_item.id == previous_cite.id then
      return previous_cite
    end
  elseif previous_citation then
    -- (hidden) The previous citation is the only one in the previous note.
    --    See also
    --    https://github.com/citation-style-language/documentation/issues/121
    --    position_IbidWithMultipleSoloCitesInBackref.txt
    -- b. the current cite is the first cite in the citation, and the previous
    --    citation consists of a single cite referencing the same item
    local previous_note_number = previous_citation.properties.noteIndex
    local num_previous_note_citations = #num_citations_in_note[previous_note_number]
    if (previous_note_number == note_index - 1 and num_previous_note_citations == 1)
        or previous_note_number == note_index then
      if #previous_citation.sorted_items == 1 then
        previous_cite = previous_citation.sorted_items[1]
        if previous_cite.id == cite_item.id then
          return previous_cite
        end
      end
    end
  end
  return nil
end

function CiteProc:_get_ibid_position(item, preceding_cite)
  if preceding_cite.locator then
    if item.locator then
      if item.locator == preceding_cite.locator and item.label == preceding_cite.label then
        return Position.Ibid
      else
        return Position.IbidWithLocator
      end
    else
      return Position.Subsequent
    end
  else
    if item.locator then
      return Position.IbidWithLocator
    else
      return Position.Ibid
    end
  end
end

function CiteProc:_check_tainted_position_change(cite_item, position_properties)
  for key, value in pairs(position_properties) do
    if cite_item[key] ~= value then
      return true
    end
  end
  return false
end

---@param tainted_citation_ids table<CitationId, boolean>
---@return [integer, string, CitationId][]
function CiteProc:_rerun_changed_cites(tainted_citation_ids)
  local result = {}
  for citation_id, _ in pairs(tainted_citation_ids) do
    local citation = self.registry.citations_by_id[citation_id]
    local citation_index = citation.citation_index
    local mode = citation.properties.mode
    if mode == "suppress-author" and self.style.class == "note" then
      mode = nil
    end
    local citation_element = self.style.citation
    if mode == "author-only" and self.style.intext then
      citation_element = self.style.intext
    elseif mode == "full-cite" then
      if self.style.class == "note" then
        citation_element = self.style.citation
      else
        citation_element = self.style.full_citation
      end
    end

    local citation_str = citation_element:build_citation_str(citation, self)
    table.insert(result, {citation_index, citation_str, citation_id})
  end
  return result
end

function CiteProc:_get_sorted_refs()
  if self.registry.requires_sorting then
    self:sort_bibliography()
  end
  return self.registry.reflist
end

---@param ids CiteId[]
---@param bibsection any
---@return CiteId[]
---@return CiteId[]
function CiteProc:_filter_with_bibsection(ids, bibsection)
  if bibsection.quash then
    return self:filter_quash(ids, bibsection)
  elseif bibsection.select then
    return self:filter_select(ids, bibsection)
  elseif bibsection.include then
    return self:filter_include(ids, bibsection)
  elseif bibsection.exclude then
    return self:filter_exclude(ids, bibsection)
  else
    return ids, {}
  end
end

function CiteProc:match_bibsection_object(item, bibsection_object)
  local field = bibsection_object.field
  local value = bibsection_object.value
  local match = false
  if value == "" then
    if not item[field] or item[field] == "" then
      match = true
    end
  else
    if type(item[field]) == "table" then
      if util.in_list(value, item[field]) then
        match = true
      end
    elseif field == "keyword" then
      if item.keyword and util.in_list(value, util.split(item.keyword, "%s*[;,]%s*")) then
        match = true
      end
    elseif item[field] == value then
      match = true
    end
  end
  if bibsection_object.negative then
    match = not match
  end
  return match
end

function CiteProc:filter_select(ids, bibsection)
  -- Include the item if, and only if, all of the objects match.
  local res = {}
  local excluded_ids = {}
  for _, id in ipairs(ids) do
    local item = self.registry.registry[id]
    local match = true
    for _, bibsection_object in ipairs(bibsection.select) do
      if not self:match_bibsection_object(item, bibsection_object) then
        match = false
        break
      end
    end
    if match then
      table.insert(res, id)
    else
      table.insert(excluded_ids, id)
    end
  end
  return res, excluded_ids
end

function CiteProc:filter_include(ids, bibsection)
  -- Include the item if any of the objects match.
  local res = {}
  local excluded_ids = {}
  for _, id in ipairs(ids) do
    local item = self.registry.registry[id]
    local match = false
    for _, bibsection_object in ipairs(bibsection.include) do
      if self:match_bibsection_object(item, bibsection_object) then
        match = true
        break
      end
    end
    if match then
      table.insert(res, id)
    else
      table.insert(excluded_ids, id)
    end
  end
  return res, excluded_ids
end

function CiteProc:filter_exclude(ids, bibsection)
  -- Include the item if none of the objects match.
  local res = {}
  local excluded_ids = {}
  for _, id in ipairs(ids) do
    local item = self.registry.registry[id]
    local match = false
    for _, bibsection_object in ipairs(bibsection.exclude) do
      if self:match_bibsection_object(item, bibsection_object) then
        match = true
        break
      end
    end
    if not match then
      table.insert(res, id)
    else
      table.insert(excluded_ids, id)
    end
  end
  return res, excluded_ids
end

function CiteProc:filter_quash(ids, bibsection)
  -- Skip the item if all of the objects match.
  local res = {}
  local excluded_ids = {}
  for _, id in ipairs(ids) do
    local item = self.registry.registry[id]
    local match = true
    for _, bibsection_object in ipairs(bibsection.quash) do
      if not self:match_bibsection_object(item, bibsection_object) then
        match = false
        break
      end
    end
    if not match then
      table.insert(res, id)
    else
      table.insert(excluded_ids, id)
    end
  end
  return res, excluded_ids
end

function CiteProc:set_output_format(format)
  if format == "latex" then
    self.output_format = LatexWriter:new()
  elseif format == "html" then
    self.output_format = HtmlWriter:new()
  end
end

function CiteProc:enable_linking()
  self.opt.wrap_url_and_doi = true
  self.opt.citation_link = true
end

function CiteProc:disable_linking()
  self.opt.wrap_url_and_doi = false
  self.opt.citation_link = false
end

function CiteProc.create_element_tree(node)
  local element_name = node:get_element_name()
  local element_class = nodes[element_name]
  local el = nil
  if element_class then
    el = element_class:from_node(node)
  end
  if el then
    for _, child in ipairs(node:get_children()) do
      if child:is_element() then
        local child_element = CiteProc.create_element_tree(child)
        if child_element then
          if not el.children then
            el.children = {}
          end
          table.insert(el.children, child_element)
        end
      end
    end
  end
  return el
end

---@param id ItemId
---@return ItemData?
function CiteProc:get_item(id)
  ---@type ItemData?
  local item = self.registry.registry[id]
  if not item then
    item = self:_retrieve_item(id)
    if not item then
      return nil
    end
    item = self:process_extra_note(item)
    table.insert(self.registry.reflist, id)
    item["citation-number"] = #self.registry.reflist
    self.registry.registry[id] = item
    self.registry.requires_sorting = true
  end
  -- local res = {}
  -- setmetatable(res, {__index = item})
  -- return res
  return item
end

---@param id ItemId
---@return ItemData?
function CiteProc:_retrieve_item(id)
  -- Retrieve, copy, and normalize
  local res = {}
  local item = self.sys.retrieveItem(id)
  if not item then
    return nil
  end

  -- TODO: normalize data input
  item.id = tostring(item.id)

  for key, value in pairs(item) do
    res[key] = value
  end

  -- if res["page"] and not res["page-first"] then
  --   local page_first = util.split(res["page"], "%s*[&,-]%s*")[1]
  --   page_first = util.split(page_first, util.unicode["en dash"])[1]
  --   res["page-first"] = page_first
  -- end

  return res
end

-- TODO: Nomalize all inputs
function CiteProc:process_extra_note(item)
  if item.note then
    local note_fields = {}
    local note_lines = {}
    for _, line in ipairs(util.split(item.note, "%s*\r?\n%s*")) do
      local field, value = string.match(line, "^([%w-_ ]+):%s*(.*)$")
      if field then
        local variable_type = util.variable_types[field]
        if not item[field] or field == "type" or variable_type == "date" then
          if variable_type == "number" then
            item[field] = value
          elseif variable_type == "date" then
            item[field] = util.parse_edtf(value)
          elseif variable_type == "name" then
            if not note_fields[field] then
              note_fields[field] = {}
            end
            table.insert(note_fields[field], util.parse_extra_name(value))
          else
            item[field] = value
          end
        end
      else
        table.insert(note_lines, line)
      end
    end
    for field, value in pairs(note_fields) do
      item[field] = value
    end
    item.note = table.concat(note_lines, "\n")
  end
  return item
end

function CiteProc:sort_bibliography()
  -- Sort the items in registry according to the `sort` in `bibliography.`
  -- This will update the `citation-number` of each item.
  local bibliography_sort = nil
  if self.style.bibliography and self.style.bibliography.sort then
    bibliography_sort = self.style.bibliography.sort
  end
  if not bibliography_sort then
    return
  end
  local items = {}
  for _, id in ipairs(self.registry.reflist) do
    table.insert(items, self.registry.registry[id])
  end

  local state = IrState:new()
  local context = Context:new()
  context.engine = self
  context.style = self.style
  context.area = self.style.bibliography
  context.in_bibliography = true
  context.lang = self.lang
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style.bibliography.name_inheritance
  context.format = SortStringFormat:new()
  -- context.id = id
  context.cite = nil
  -- context.reference = self:get_item(id)

  bibliography_sort:sort(items, state, context)
  self.registry.reflist = {}
  self.tainted_item_ids = {}
  for i, item in ipairs(items) do
    if item["citation-number"] ~= i then
      self.tainted_item_ids[item.id] = true
    end
    item["citation-number"] = i
    self.registry.reflist[i] = item.id
  end
  self.registry.requires_sorting = false
end

---@param lang string
---@return Locale
function CiteProc:get_locale(lang)
  lang = util.primary_dialects[lang] or lang
  local locale = self.locales[lang] or self:get_merged_locales(lang)
  return locale
end

function CiteProc:get_merged_locales(lang)
  local fall_back_locales = {}

  local language = string.sub(lang, 1, 2)
  local primary_dialect = util.primary_dialects[language]

  -- 1. In-style cs:locale elements
  --    i. `xml:lang` set to chosen dialect, “de-AT”
  table.insert(fall_back_locales, self.style.locales[lang])

  --    ii. `xml:lang` set to matching language, “de” (German)
  if language and language ~= lang then
    table.insert(fall_back_locales, self.style.locales[language])
  end

  --    iii. `xml:lang` not set
  table.insert(fall_back_locales, self.style.locales["@generic"])

  -- 2. Locale files
  --    iv. `xml:lang` set to chosen dialect, “de-AT”
  if lang then
    table.insert(fall_back_locales, self:get_system_locale(lang))
  end

  --    v. `xml:lang` set to matching primary dialect, “de-DE” (Standard German)
  --       (only applicable when the chosen locale is a secondary dialect)
  if primary_dialect and primary_dialect ~= lang then
    table.insert(fall_back_locales, self:get_system_locale(primary_dialect))
  end

  --    vi. `xml:lang` set to “en-US” (American English)
  if lang ~= "en-US" and primary_dialect ~= "en-US" then
    table.insert(fall_back_locales, self:get_system_locale("en-US"))
  end

  -- Merge locales

  local locale = Locale:new()
  for i = #fall_back_locales, 1, -1 do
    local fall_back_locale = fall_back_locales[i]
    locale:merge(fall_back_locale)
  end

  self.locales[lang] = locale
  return locale
end

function CiteProc:get_system_locale(lang)
  local locale = self.system_locales[lang]
  if locale then
    return locale
  end

  local locale_str = self.sys.retrieveLocale(lang)
  if not locale_str then
    util.warning(string.format("Failed to retrieve locale '%s'", lang))
    return nil
  end
  local locale_xml = dom.parse(locale_str)
  local root_element = locale_xml:get_path("locale")[1]
  locale = Locale:from_node(root_element)
  self.system_locales[lang] = locale
  return locale
end


function CiteProc:get_style_class()
  if self.style and self.style.class then
    return self.style.class
  else
    return nil
  end
end


---@class Macro: Element
local Macro = Element:derive("macro")

function Macro:from_node(node)
  local o = Macro:new()
  o.children = {}
  o:set_attribute(node, "name")
  o:process_children_nodes(node)
  return o
end

---@param engine CiteProc
---@param state IrState
---@param context Context
---@return IrNode?
function Macro:build_ir(engine, state, context)
  local ir = self:build_group_ir(engine, state, context)
  return ir
end


engine.CiteProc = CiteProc

return engine
