--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local engine = {}

local dom = require("luaxml-domobject")

local nodes = require("citeproc-nodes")
local Style = require("citeproc-node-style").Style
local Locale = require("citeproc-node-locale").Locale
local Context = require("citeproc-context").Context
local IrState = require("citeproc-context").IrState
-- local OutputFormat = require("citeproc-output").OutputFormat
local HtmlWriter = require("citeproc-output").HtmlWriter
local SortStringFormat = require("citeproc-output").SortStringFormat
local InlineElement = require("citeproc-output").InlineElement
local Micro = require("citeproc-output").Micro
local Formatted = require("citeproc-output").Formatted
local PlainText = require("citeproc-output").PlainText
local util = require("citeproc-util")


local CiteProc = {}

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
  local o = {}
  o.registry = {
    citations = {},  -- A map
    registry = {},  -- A map
    reflist = {},  -- A list
    previous_citation = nil,
    requires_sorting = false,
  }

  o.cite_first_note_numbers = {}
  o.cite_last_note_numbers = {}
  o.note_citations_map = {}

  o.disam_irs = {}
  -- { <ir1>, <ir2>, ...  }

  o.person_names_by_output = {}
  o.cite_irs_by_output = {}
  -- {
  --   ["Roe, J"] = {<ir1>},
  --   ["Doe, J"] = {<ir2>, <ir3>},
  --   ["Doe, John"] = {<ir2>},
  --   ["Doe, Jack"] = {<ir2>},
  -- }

  o.sys = sys
  o.locales = {}
  o.system_locales = {}

  o.style = Style:parse(style)

  o.lang = o.style.default_locale
  if not o.lang or force_lang then
    o.lang = lang or "en-US"
  end

  -- TODO
  -- o.formatter = formats.latex
  o.linking_enabled = false

  setmetatable(o, { __index = CiteProc })
  return o
end

function CiteProc:updateItems(ids)
  self.registry.reflist = {}
  self.registry.registry = {}
  local cite_items = {}
  for _, id in ipairs(ids) do
    table.insert(cite_items, {id = id})
  end
  self:makeCitationCluster(cite_items)

  self.registry.previous_citation = nil
  self.cite_first_note_numbers = {}
  self.cite_last_note_numbers = {}
  self.note_citations_map = {}
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
  self.registry.citations[citation.citationID] = citation
  -- Fix missing noteIndex: sort_CitationNumberPrimaryAscendingViaMacroCitation.txt
  if not citation.properties then
    citation.properties = {}
  end
  if not citation.properties.noteIndex then
    citation.properties.noteIndex = 0
  end

  local citations_to_build = {}
  util.extend(citations_to_build, citationsPre)
  table.insert(citations_to_build, {citation.citationID, citation.properties.noteIndex})
  util.extend(citations_to_build, citationsPost)
  -- util.debug(citations_to_build)

  local params = {
    bibchange = false,
    citation_errors = {},
  }
  local output = {}

  local tainted_citation_ids = self:get_tainted_citaion_ids(citations_to_build)
  -- util.debug(tainted_citation_ids)

  -- params.bibchange = #tainted_citation_ids > 0
  for _, citation_id in ipairs(tainted_citation_ids) do
    local citation_ = self.registry.citations[citation_id]

    local citation_index = citation_.citation_index
    local citation_str = self:build_citation_str(citation_)
    table.insert(output, {citation_index, citation_str, citation_id})
  end

  -- util.debug(output)
  return {params, output}
end


function CiteProc:get_tainted_citaion_ids(citations_to_build)
  local tainted_citation_ids = {}

  self.cite_first_note_numbers = {}
  self.cite_last_note_numbers = {}
  self.note_citations_map = {}
  -- {
  --   1 = {"citation-1", "citation-2"},
  --   2 = {"citation-2"},
  -- }

  local previous_citation
  for citation_index, tuple in ipairs(citations_to_build) do
    local citation_id, note_number = table.unpack(tuple)
    -- util.debug(citation_id)
    local citation = self.registry.citations[citation_id]
    citation.properties.noteIndex = note_number
    citation.citation_index = citation_index

    local tainted = false

    local previous_cite
    for _, cite_item in ipairs(citation.citationItems) do
      tainted = self:set_cite_item_position(cite_item, note_number, previous_cite, previous_citation)
      self.cite_last_note_numbers[cite_item.id] = note_number
      previous_cite = cite_item
    end

    if tainted then
      table.insert(tainted_citation_ids, citation.citationID)
    end

    if not self.note_citations_map[note_number] then
      self.note_citations_map[note_number] = {}
    end
    table.insert(self.note_citations_map[note_number], citation.citationID)
    previous_citation = citation
  end
  return tainted_citation_ids
end

function CiteProc:set_cite_item_position(cite_item, note_number, previous_cite, previous_citation)
  local position = util.position_map["first"]

  local first_reference_note_number = self.cite_first_note_numbers[cite_item.id]
  if first_reference_note_number then
    position = util.position_map["subsequent"]
  else
    self.cite_first_note_numbers[cite_item.id] = note_number
  end

  local preceding_cite_item = self:get_preceding_cite_item(cite_item, previous_cite, previous_citation, note_number)
  if preceding_cite_item then
    position = self:_get_cite_position(cite_item, preceding_cite_item)
  end

  local near_note = false
  local last_note_number = self.cite_last_note_numbers[cite_item.id]
  if last_note_number then
    local note_distance = note_number - last_note_number
    if note_distance <= self.style.citation.near_note_distance then
      near_note = true
    end
  end

  local tainted = false
  if cite_item.position ~= position then
    tainted = true
    cite_item.position = position
  end
  if cite_item["first-reference-note-number"] ~= first_reference_note_number then
    tainted = true
    cite_item["first-reference-note-number"] = first_reference_note_number
  end
  if cite_item.near_note ~= near_note then
    tainted = true
    cite_item.near_note = near_note
  end
  return tainted
end

-- Find the preceding cite referencing the same item
function CiteProc:get_preceding_cite_item(cite_item, previous_cite, previous_citation, note_number)
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
    local num_previous_note_citations = #self.note_citations_map[previous_note_number]
    if (previous_note_number == note_number - 1 and num_previous_note_citations == 1)
        or previous_note_number == note_number then
      if #previous_citation.citationItems == 1 then
        previous_cite = previous_citation.citationItems[1]
        if previous_cite.id == cite_item.id then
          return previous_cite
        end
      end
    end
  end
  return nil
end

function CiteProc:_get_cite_position(item, preceding_cite)
  if preceding_cite.locator then
    if item.locator then
      if item.locator == preceding_cite.locator and item.label == preceding_cite.label then
        return util.position_map["ibid"]
      else
        return util.position_map["ibid-with-locator"]
      end
    else
      return util.position_map["subsequent"]
    end
  else
    if item.locator then
      return util.position_map["ibid-with-locator"]
    else
      return util.position_map["ibid"]
    end
  end
end

function CiteProc:build_citation_str(citation)
  -- util.debug(citation.citationID)
  local items = {}
  for i, cite_item in ipairs(citation.citationItems) do
    cite_item.id = tostring(cite_item.id)
    -- util.debug(cite_item.id)
    local item_data = self:get_item(cite_item.id)

    if item_data then
      -- Create a wrapper of the orignal item from registry so that
      -- it may hold different `locator` or `position` values for cites.
      local item = setmetatable(cite_item, {__index = item_data})

      -- Use "page" as locator label if missing
      -- label_PluralWithAmpersand.txt
      if item.locator and not item.label then
        item.label = "page"
      end

      table.insert(items, item)
    end
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local citation_str = self:build_cluster(items)
  return citation_str
end

function CiteProc:build_cluster(citation_items)
  local output_format = HtmlWriter:new()
  local irs = {}
  citation_items = self:sorted_citation_items(citation_items)
  for _, cite_item in ipairs(citation_items) do
    local ir = self:build_fully_disambiguated_ir(cite_item, output_format)
    table.insert(irs, ir)
  end

  -- util.debug(irs)

  -- TODO: disambiguation

  -- TODO: collapsing

  -- Capitalize first
  for i, ir in ipairs(irs) do
    if i == 1 then
      -- local layout_prefix
      -- local layout_affixes = self.style.citation.layout.affixes
      -- if layout_affixes then
      --   layout_prefix = layout_affixes.prefix
      -- end
      local prefix = citation_items[i].prefix
      if not prefix or (string.match(prefix, "[.!?]%s*$") and #util.split(util.strip(prefix)) > 1) then
        ir:capitalize_first_term()
      end
    else
      local delimiter = self.style.citation.layout.delimiter
      if not delimiter or string.match(delimiter, "[.!?]%s*$") then
        ir:capitalize_first_term()
      end
    end
  end

  -- util.debug(irs)

  local citation_delimiter = self.style.citation.layout.delimiter
  local citation_stream = {}

  local context = Context:new()
  context.engine = self
  context.style = self.style
  context.area = self.style.citation
  context.in_bibliography = false
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style.citation.name_inheritance
  context.format = output_format

  for i, ir in ipairs(irs) do
    local cite_prefix = citation_items[i].prefix
    local cite_suffix = citation_items[i].suffix
    if citation_delimiter and i > 1 and not (cite_prefix and util.startswith(cite_prefix, ",")) then
      table.insert(citation_stream, PlainText:new(citation_delimiter))
    end

    if cite_prefix then
      table.insert(citation_stream, Micro:new(InlineElement:parse(cite_prefix, context)))
    end

    -- util.debug(ir)
    util.extend(citation_stream, ir:flatten(output_format))
    -- util.debug(citation_stream)

    if cite_suffix then
      table.insert(citation_stream, Micro:new(InlineElement:parse(cite_suffix, context)))
    end
  end
  -- util.debug(citation_stream)

  if context.area.layout.affixes then
    local affixes = context.area.layout.affixes
    if affixes.prefix then
      table.insert(citation_stream, 1, PlainText:new(affixes.prefix))
    end
    if affixes.suffix then
      table.insert(citation_stream, PlainText:new(affixes.suffix))
    end
  end
  -- util.debug(citation_stream)

  if #citation_stream > 0 and context.area.layout.formatting then
    citation_stream = {Formatted:new(citation_stream, context.area.layout.formatting)}
  end

  if #citation_stream == 0 then
    citation_stream = {PlainText:new("[CSL STYLE ERROR: reference with no printed form.]")}
  end

  -- util.debug(citation_stream)
  local str = output_format:output(citation_stream)
  str = util.strip(str)

  return str
end

function CiteProc:sorted_citation_items(items)
  local citation_sort = self.style.citation.sort
  if not citation_sort then
    return items
  end

  local state = IrState:new()
  local context = Context:new()
  context.engine = self
  context.style = self.style
  context.area = self.style.citation
  context.in_bibliography = false
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style.citation.name_inheritance
  context.format = SortStringFormat:new()
  -- context.id = id
  context.cite = nil
  -- context.reference = self:get_item(id)

  items = citation_sort:sort(items, state, context)
  return items
end

function CiteProc:build_fully_disambiguated_ir(cite_item, output_format)
  local cite_ir = self:build_ambiguous_ir(cite_item, output_format)
  -- util.debug(cite_ir)
  cite_ir = self:disambiguate_add_givenname(cite_ir)
  cite_ir = self:disambiguate_add_names(cite_ir)
  cite_ir = self:disambiguate_conditionals(cite_ir)
  cite_ir = self:disambiguate_add_year_suffix(cite_ir)
  return cite_ir
end

function CiteProc:build_ambiguous_ir(cite_item, output_format)
  local state = IrState:new(self.style)
  cite_item.id = tostring(cite_item.id)
  local context = Context:new()
  context.engine = self
  context.style = self.style
  context.area = self.style.citation
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style.citation.name_inheritance
  context.format = output_format
  context.id = cite_item.id
  context.cite = cite_item
  context.reference = self:get_item(cite_item.id)

  local ir = self.style.citation:build_ir(self, state, context)

  ir.cite_item = cite_item
  ir.reference = context.reference
  ir.ir_index = #self.disam_irs + 1
  table.insert(self.disam_irs, ir)
  ir.is_ambiguous = false
  ir.disam_level = 0

  -- Formattings like font-style are ignored for disambiguation.
  local disam_format = SortStringFormat:new()
  local inlines = ir:flatten(disam_format)
  local disam_str = disam_format:output(inlines)
  ir.disam_str = disam_str

  if not self.cite_irs_by_output[disam_str] then
    self.cite_irs_by_output[disam_str] = {}
  end

  for ir_index, ir_ in pairs(self.cite_irs_by_output[disam_str]) do
    if ir_.cite_item.id ~= cite_item.id then
      ir.is_ambiguous = true
      break
    end
  end
  self.cite_irs_by_output[disam_str][ir.ir_index] = ir

  return ir
end

function CiteProc:disambiguate_add_givenname(cite_ir)
  if self.style.citation.disambiguate_add_givenname then
    local gn_disam_rule = self.style.citation.givenname_disambiguation_rule
    if gn_disam_rule == "all-names" or gn_disam_rule == "all-names-with-initials" then
      cite_ir = self:disambiguate_add_givenname_all_names(cite_ir)
    elseif gn_disam_rule == "primary-name" or gn_disam_rule == "primary-name-with-initials" then
      cite_ir = self:disambiguate_add_givenname_primary_name(cite_ir)
    elseif gn_disam_rule == "by-cite" then
      cite_ir = self:disambiguate_add_givenname_by_cite(cite_ir)
    end
  end
  return cite_ir
end

-- TODO: reorganize this code
function CiteProc:disambiguate_add_givenname_all_names(cite_ir)
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end
  for _, person_name_ir in ipairs(cite_ir.person_name_irs) do
    local name_output = person_name_ir.name_output
    -- util.debug(name_output)
    if not self.person_names_by_output[name_output] then
      self.person_names_by_output[name_output] = {}
    end
    table.insert(self.person_names_by_output[name_output], person_name_ir)

    local ambiguous_name_irs = {}
    local ambiguous_same_output_irs = {}

    for _, pn_ir in ipairs(self.person_names_by_output[person_name_ir.name_output]) do
      if pn_ir.full_name ~= person_name_ir.full_name then
        table.insert(ambiguous_name_irs, pn_ir)
      end
      if pn_ir.name_output == person_name_ir.name_output then
        table.insert(ambiguous_same_output_irs, pn_ir)
      end
    end

    for _, name_variant in ipairs(person_name_ir.disam_variants) do
      if #ambiguous_name_irs == 0 then
        break
      end

      for _, pn_ir in ipairs(ambiguous_same_output_irs) do
        -- expand one name
        if pn_ir.disam_variants_index < #pn_ir.disam_variants then
          pn_ir.disam_variants_index = pn_ir.disam_variants_index + 1
          pn_ir.name_output = pn_ir.disam_variants[pn_ir.disam_variants_index]
          pn_ir.inlines = pn_ir.disam_inlines[pn_ir.name_output]

          if not self.person_names_by_output[pn_ir.name_output] then
            self.person_names_by_output[pn_ir.name_output] = {}
          end
          table.insert(self.person_names_by_output[pn_ir.name_output], person_name_ir)
        end
      end

      -- update ambiguous_name_irs and ambiguous_same_output_irs
      ambiguous_name_irs = {}
      ambiguous_same_output_irs = {}
      for _, pn_ir in ipairs(self.person_names_by_output[person_name_ir.name_output]) do
        if pn_ir.full_name ~= person_name_ir.full_name then
          table.insert(ambiguous_name_irs, pn_ir)
        end
        if pn_ir.name_output == person_name_ir.name_output then
          table.insert(ambiguous_same_output_irs, pn_ir)
        end
      end
    end
  end

  return cite_ir
end

function CiteProc:disambiguate_add_givenname_primary_name(cite_ir)
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end
  local person_name_ir = cite_ir.person_name_irs[1]
  local name_output = person_name_ir.name_output
  -- util.debug(name_output)
  if not self.person_names_by_output[name_output] then
    self.person_names_by_output[name_output] = {}
  end
  table.insert(self.person_names_by_output[name_output], person_name_ir)

  local ambiguous_name_irs = {}
  local ambiguous_same_output_irs = {}

  for _, pn_ir in ipairs(self.person_names_by_output[person_name_ir.name_output]) do
    if pn_ir.full_name ~= person_name_ir.full_name then
      table.insert(ambiguous_name_irs, pn_ir)
    end
    if pn_ir.name_output == person_name_ir.name_output then
      table.insert(ambiguous_same_output_irs, pn_ir)
    end
  end

  for _, name_variant in ipairs(person_name_ir.disam_variants) do
    if #ambiguous_name_irs == 0 then
      break
    end

    for _, pn_ir in ipairs(ambiguous_same_output_irs) do
      -- expand one name
      if pn_ir.disam_variants_index < #pn_ir.disam_variants then
        pn_ir.disam_variants_index = pn_ir.disam_variants_index + 1
        pn_ir.name_output = pn_ir.disam_variants[pn_ir.disam_variants_index]
        pn_ir.inlines = pn_ir.disam_inlines[pn_ir.name_output]

        if not self.person_names_by_output[pn_ir.name_output] then
          self.person_names_by_output[pn_ir.name_output] = {}
        end
        table.insert(self.person_names_by_output[pn_ir.name_output], person_name_ir)
      end
    end

    -- update ambiguous_name_irs and ambiguous_same_output_irs
    ambiguous_name_irs = {}
    ambiguous_same_output_irs = {}
    for _, pn_ir in ipairs(self.person_names_by_output[person_name_ir.name_output]) do
      if pn_ir.full_name ~= person_name_ir.full_name then
        table.insert(ambiguous_name_irs, pn_ir)
      end
      if pn_ir.name_output == person_name_ir.name_output then
        table.insert(ambiguous_same_output_irs, pn_ir)
      end
    end
  end

  return cite_ir
end

function CiteProc:disambiguate_add_givenname_by_cite(cite_ir)
  if not cite_ir.is_ambiguous then
    return cite_ir
  end
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end

  for _, ir_ in ipairs(self.disam_irs) do
    -- util.debug(ir_.cite_item.id)
    -- util.debug(ir_.disam_str)
  end

  local disam_format = SortStringFormat:new()

  local ambiguous_cite_irs = {}
  local ambiguous_same_output_irs = {}

  for ir_index, ir_ in pairs(self.cite_irs_by_output[cite_ir.disam_str]) do
    if ir_.cite_item.id ~= cite_ir.cite_item.id then
      table.insert(ambiguous_cite_irs, ir_)
    end
    if ir_.disam_str == cite_ir.disam_str then
      table.insert(ambiguous_same_output_irs, ir_)
    end
  end

  for i, person_name_ir in ipairs(cite_ir.person_name_irs) do
    -- util.debug(person_name_ir.name_output)
    -- util.debug(person_name_ir.disam_variants)
    if #ambiguous_cite_irs == 0 then
      cite_ir.is_ambiguous = false
      break
    end

    -- util.debug(person_name_ir.disam_variants)
    while person_name_ir.disam_variants_index < #person_name_ir.disam_variants do
      -- util.debug(person_name_ir.name_output)

      local is_different_name = false
      for _, ir_ in ipairs(ambiguous_cite_irs) do
        if ir_.person_name_irs[i] then
          if ir_.person_name_irs[i].full_name ~= person_name_ir.full_name then
            -- util.debug(ir_.cite_item.id)
            is_different_name = true
            break
          end
        end
      end
      -- util.debug(is_different_name)
      if not is_different_name then
        break
      end

      for _, ir_ in ipairs(ambiguous_same_output_irs) do
        -- util.debug(ir_.cite_item.id)
        local person_name_ir_ = ir_.person_name_irs[i]
        if person_name_ir_ then
          if person_name_ir_.disam_variants_index < #person_name_ir_.disam_variants then
            person_name_ir_.disam_variants_index = person_name_ir_.disam_variants_index + 1
            local disam_variant = person_name_ir_.disam_variants[person_name_ir_.disam_variants_index]
            person_name_ir_.name_output = disam_variant
            -- util.debug(disam_variant)
            person_name_ir_.inlines = person_name_ir_.disam_inlines[disam_variant]
            -- Update cite ir output
            local inlines = ir_:flatten(disam_format)
            local disam_str = disam_format:output(inlines)
            ir_.disam_str = disam_str
            if not self.cite_irs_by_output[disam_str] then
              self.cite_irs_by_output[disam_str] = {}
            end
            self.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
          end
        end
      end

      -- update ambiguous_cite_irs and ambiguous_same_output_irs
      ambiguous_cite_irs = {}
      ambiguous_same_output_irs = {}
      for ir_index, ir_ in pairs(self.cite_irs_by_output[cite_ir.disam_str]) do
        -- util.debug(ir_.cite_item.id)
        if ir_.cite_item.id ~= cite_ir.cite_item.id then
          table.insert(ambiguous_cite_irs, ir_)
        end
        if ir_.disam_str == cite_ir.disam_str then
          table.insert(ambiguous_same_output_irs, ir_)
        end
      end

      -- util.debug(#ambiguous_cite_irs)

      if #ambiguous_cite_irs == 0 then
        cite_ir.is_ambiguous = false
        return cite_ir
      end

    end
  end

  return cite_ir
end

local function find_first_name_ir(ir)
  if ir._type == "NameIr" then
    return ir
  end
  if ir.children then
    for _, child in ipairs(ir.children) do
      local name_ir = find_first_name_ir(child)
      if name_ir then
        return name_ir
      end
    end
  end
  return nil
end

function CiteProc:disambiguate_add_names(cite_ir)
  if not self.style.citation.disambiguate_add_names then
    return cite_ir
  end

  local name_ir = find_first_name_ir(cite_ir)
  cite_ir.name_ir = name_ir

  if name_ir then
    -- util.debug(cite_ir.cite_item.id)
    -- util.debug(cite_ir.disam_str)
    -- util.debug(cite_ir.name_ir.full_name_str)
    -- util.debug(cite_ir.is_ambiguous)
  end

  if not cite_ir.is_ambiguous then
    return cite_ir
  end

  if not name_ir or not name_ir.et_al_abbreviation then
    return cite_ir
  end

  local disam_format = SortStringFormat:new()

  while cite_ir.is_ambiguous do
    local ambiguous_cite_irs = {}
    local ambiguous_same_output_irs = {}

    for _, ir_ in pairs(self.cite_irs_by_output[cite_ir.disam_str]) do
      if ir_.cite_item.id ~= cite_ir.cite_item.id then
        table.insert(ambiguous_cite_irs, ir_)
      end
      if ir_.disam_str == cite_ir.disam_str then
        table.insert(ambiguous_same_output_irs, ir_)
      end
    end

    if #ambiguous_cite_irs == 0 then
      cite_ir.is_ambiguous = false
      break
    end

    -- check if the cite can be (fully) disambiguated by adding names
    local can_be_disambuguated = false
    for _, ir_ in ipairs(ambiguous_cite_irs) do
      if ir_.name_ir.full_name_str ~= cite_ir.name_ir.full_name_str then
        can_be_disambuguated = true
        break
      end
    end
    -- util.debug(can_be_disambuguated)
    if not can_be_disambuguated then
      break
    end

    local expansion_succeeded = false
    for _, ir_ in ipairs(ambiguous_same_output_irs) do
      local added_person_name_ir = ir_.name_ir.name_inheritance:expand_one_name(ir_.name_ir)
      if added_person_name_ir then
        ir_.person_name_irs = ir_.name_ir.person_name_irs
        local inlines = ir_:flatten(disam_format)
        local disam_str = disam_format:output(inlines)
        -- util.debug(disam_str)
        ir_.disam_str = disam_str
        if not self.cite_irs_by_output[disam_str] then
          self.cite_irs_by_output[disam_str] = {}
        end
        -- table.insert(self.cite_irs_by_output[disam_str], ir_)
        self.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
        expansion_succeeded = true
      end
    end
    if not expansion_succeeded then
      break
    end
    if self.style.citation.disambiguate_add_givenname then
      local gn_disam_rule = self.style.citation.givenname_disambiguation_rule
      if gn_disam_rule == "all-names" or gn_disam_rule == "all-names-with-initials" then
        cite_ir = self:disambiguate_add_givenname_all_names(cite_ir)
      elseif gn_disam_rule == "by-cite" then
        cite_ir = self:disambiguate_add_givenname_by_cite(cite_ir)
      end
    end
  end

  return cite_ir
end

function CiteProc:disambiguate_conditionals(cite_ir)
  return cite_ir
end

function CiteProc:disambiguate_add_year_suffix(cite_ir)
  return cite_ir
end

function CiteProc:makeCitationCluster(citation_items)
  local items = {}
  for i, cite_item in ipairs(citation_items) do
    cite_item.id = tostring(cite_item.id)
    local item_data = self:get_item(cite_item.id)

    -- Create a wrapper of the orignal item from registry so that
    -- it may hold different `locator` or `position` values for cites.
    local item = setmetatable(cite_item, {__index = item_data})

    -- Use "page" as locator label if missing
    -- label_PluralWithAmpersand.txt
    if item.locator and not item.label then
      item.label = "page"
    end

    item.position = util.position_map["first"]
    if self.cite_first_note_numbers[cite_item.id] then
      item.position = util.position_map["subsequent"]
    else
      self.cite_first_note_numbers[cite_item.id] = 0
    end

    local preceding_cite
    if i == 1 then
      local previous_citation = self.registry.previous_citation
      if previous_citation then
        if #previous_citation.citationItems == 1 and previous_citation.citationItems[1].id == item.id then
          preceding_cite = previous_citation.citationItems[1]
        end
      end
    elseif citation_items[i - 1].id == item.id then
      preceding_cite = citation_items[i - 1]
    end

    if preceding_cite then
      item.position = self:_get_cite_position(item, preceding_cite)
    end

    table.insert(items, item)
  end

  if self.registry.requires_sorting then
    self:sort_bibliography()
  end

  local res = self:build_cluster(items)

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
    }
  }
  return res
end

function CiteProc:makeBibliography()
  local output_format = HtmlWriter:new()
  local html_writer = HtmlWriter:new()

  local params = {
    -- TODO: change to other formats
    bibstart = html_writer.markups["bibstart"],
    bibend = html_writer.markups["bibend"],
  }
  local res = {}

  if not self.style.bibliography then
    return params, res
  end

  for _, id in ipairs(self:get_sorted_refs()) do
    local ref = self.registry.registry[id]

    local state = IrState:new()
    local context = Context:new()
    context.engine = self
    context.style = self.style
    context.area = self.style.bibliography
    context.in_bibliography = true
    context.locale = self:get_locale(self.lang)
    context.name_inheritance = self.style.bibliography.name_inheritance
    context.format = output_format
    context.id = id
    context.cite = nil
    context.reference = self:get_item(id)

    local ir = self.style.bibliography:build_ir(self, state, context)

    -- subsequent_author_substitute

    -- The layout output may be empty: sort_OmittedBibRefNonNumericStyle.txt
    if ir then
      local flat = ir:flatten(output_format)
      local str = output_format:output_bibliography_entry(flat)
      table.insert(res, str)
    end

  end

  return {params, res}
end

function CiteProc:get_sorted_refs()
  if self.registry.requires_sorting then
    self:sort_bibliography()
  end
  return self.registry.reflist
end

function CiteProc:set_formatter(format)
  -- TODO
  -- self.formatter = formats[format]
end

function CiteProc:enable_linking()
  self.linking_enabled = true
end

function CiteProc:disable_linking()
  self.linking_enabled = false
end

function CiteProc.create_element_tree(node)
  local element_name = node:get_element_name()
  local element_class = nodes[element_name]
  local el = nil
  if element_class then
    el = element_class:from_node(node)
  end
  if el then
    for i, child in ipairs(node:get_children()) do
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

function CiteProc:get_item(id)
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

function CiteProc:_retrieve_item(id)
  -- Retrieve, copy, and normalize
  local res = {}
  local item = self.sys.retrieveItem(id)
  if not item then
    util.warning(string.format('Failed to retrieve item "%s"', id))
    return nil
  end

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
    for _, line in ipairs(util.split(item.note, "%s*\r?\n%s*")) do
      local splits = util.split(line, ":%s+", 1)
      if #splits == 2 then
        local field, value = table.unpack(splits)

        local variable_type = util.variable_types[field]
        if not item[field] or field == "type" or variable_type == "date" then
          if variable_type == "number" then
            item[field] = value
          elseif variable_type == "date" then
            item[field] = util.parse_iso_date(value)
          elseif variable_type == "name" then
            if not note_fields[field] then
              note_fields[field] = {}
            end
            table.insert(note_fields[field], util.parse_extra_name(value))
          else
            item[field] = value
          end
        end
      end
    end
    for field, value in pairs(note_fields) do
      item[field] = value
    end
  end
  -- util.debug(item)
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
  context.locale = self:get_locale(self.lang)
  context.name_inheritance = self.style.bibliography.name_inheritance
  context.format = SortStringFormat:new()
  -- context.id = id
  context.cite = nil
  -- context.reference = self:get_item(id)

  bibliography_sort:sort(items, state, context)
  self.registry.reflist = {}
  for i, item in ipairs(items) do
    item["citation-number"] = i
    self.registry.reflist[i] = item.id
  end
  self.registry.requires_sorting = false
end

function CiteProc:get_locale(lang)
  if string.len(lang) == 2 then
    lang = util.primary_dialects[lang] or lang
  end
  local locale = self.locales[lang]
  if locale then
    return locale
  else
    return self:get_merged_locales(lang)
  end
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
    util.warning(string.format("Failed to retrieve locale \"%s\"", lang))
    return nil
  end
  local locale_xml = dom.parse(locale_str)
  local root_element = locale_xml:get_path("locale")[1]
  locale = Locale:from_node(root_element)
  self.system_locales[lang] = locale
  return locale
end


engine.CiteProc = CiteProc

return engine
