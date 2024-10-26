--
-- Copyright (c) 2021-2024 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local citation_module = {}

local context
local element
local ir_node
local output
local node_names
local util

if kpse then
  context = require("citeproc-context")
  element = require("citeproc-element")
  ir_node = require("citeproc-ir-node")
  output = require("citeproc-output")
  node_names = require("citeproc-node-names")
  util = require("citeproc-util")
else
  context = require("citeproc.context")
  element = require("citeproc.element")
  ir_node = require("citeproc.ir-node")
  output = require("citeproc.output")
  node_names = require("citeproc.node-names")
  util = require("citeproc.util")
end

local Context = context.Context
local IrState = context.IrState
local Element = element.Element
local IrNode = ir_node.IrNode
local Rendered = ir_node.Rendered
local SeqIr = ir_node.SeqIr
local YearSuffix = ir_node.YearSuffix
local GroupVar = ir_node.GroupVar
local Micro = output.Micro
local Formatted = output.Formatted
local PlainText = output.PlainText
local InlineElement = output.InlineElement
local UndefinedCite = output.UndefinedCite
local CiteInline = output.CiteInline
local DisamStringFormat = output.DisamStringFormat
local SortStringFormat = output.SortStringFormat

local Position = util.Position


-- local DEBUG_DISAMBIGUATE = true


---@class Citation: Element
---@field disambiguate_add_givenname boolean?
---@field givenname_disambiguation_rule string
---@field disambiguate_add_names boolean?
---@field disambiguate_add_year_suffix boolean?
---@field cite_group_delimiter string
---@field cite_grouping boolean?
---@field collapse string?
---@field year_suffix_delimiter string
---@field after_collapse_delimiter string
---@field near_note_distance integer
---@field style Style
---@field sort Sort
---@field layout Layout
---@field layouts_by_language { [string]: Layout }
---@field name_inheritance Name
local Citation = Element:derive("citation", {
  givenname_disambiguation_rule = "by-cite",
  -- https://github.com/citation-style-language/schema/issues/338
  -- The cite_group_delimiter may be changed to inherit the delimiter in citation > layout.
  cite_group_delimiter = ", ",
  near_note_distance = 5,
})

function Citation:from_node(node, style)

  local o = self:new()
  o.children = {}
  o.style = style
  o.layout = nil
  o.layouts_by_language = {}

  o:process_children_nodes(node)

  -- o.layouts = nil  -- CSL-M extension

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      if child.locale then
        for _, lang in ipairs(util.split(util.strip(child.locale))) do
          o.layouts_by_language[lang] = child
        end
      else
        o.layout = child
      end
    elseif element_name == "sort" then
      o.sort = child
    end
  end

  -- Disambiguation
  o:set_bool_attribute(node, "disambiguate-add-givenname")
  o:set_attribute(node, "givenname-disambiguation-rule")
  o:set_bool_attribute(node, "disambiguate-add-names")
  o:set_bool_attribute(node, "disambiguate-add-year-suffix")

  -- Cite Grouping
  o:set_attribute(node, "cite-group-delimiter")
  -- In the current citeproc-js implementation and test suite,
  -- cite grouping is activated by setting the cite-group-delimiter
  -- attribute or the collapse attributes on cs:citation.
  -- It may be changed to an independent procedure.
  -- https://github.com/citation-style-language/schema/issues/338
  if node:get_attribute("cite-group-delimiter") then
    o.cite_grouping = true
  else
    o.cite_grouping = false
  end


  -- Cite Collapsing
  o:set_attribute(node, "collapse")
  o:set_attribute(node, "year-suffix-delimiter")
  if not o.year_suffix_delimiter then
    o.year_suffix_delimiter = o.layout.delimiter
  end
  o:set_attribute(node, "after-collapse-delimiter")
  if not o.after_collapse_delimiter then
    o.after_collapse_delimiter = o.layout.delimiter
  end

  -- Note Distance
  o:set_number_attribute(node, "near-note-distance")

  local name_inheritance = node_names.Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  Element.make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

  -- update_mode = "plain" or "numeric" or "position" (or "both"?)

  return o
end

---@param citation CitationData
---@param engine CiteProc
---@return string
function Citation:build_citation_str(citation, engine)
  if engine.registry.requires_sorting then
    engine:sort_bibliography()
  end

  local citation_str = self:build_cluster(citation.citationItems, engine, citation.properties)
  return citation_str
end

-- Formatting is stripped from the author-only and composite renderings
-- of the author name
local function remove_name_formatting(ir)
  if ir._element_name == "name" then
    ir.formatting = nil
  end
  if ir.children then
    for _, child in ipairs(ir.children) do
      remove_name_formatting(child)
    end
  end
end

---@alias CiteId string | number

---comment
---@param citation_items CitationItem[]
---@param engine CiteProc
---@param properties CitationProperties
---@return string
function Citation:build_cluster(citation_items, engine, properties)
  properties = properties or {}
  local output_format = engine.output_format
  ---@type CiteIr[]
  local irs = {}
  -- The citation_items are already sorted when evaluate the positions
  -- To be removed
  citation_items = self:sorted_citation_items(citation_items, engine)
  for _, cite_item in ipairs(citation_items) do
    local ir = self:build_fully_disambiguated_ir(cite_item, output_format, engine, properties)
    table.insert(irs, ir)
  end

  -- Special citation forms
  -- https://citeproc-js.readthedocs.io/en/latest/running.html#special-citation-forms
  self:_apply_special_citation_form(irs, properties, output_format, engine)

  if self.cite_grouping then
    irs = self:group_cites(irs)
  else
    local citation_collapse = self.collapse
    if citation_collapse == "year" or citation_collapse == "year-suffix" or
        citation_collapse == "year-suffix-ranged" then
      irs = self:group_cites(irs)
    end
  end

  if self.collapse then
    self:collapse_cites(irs)
  end

  -- Capitalize first
  for i, ir in ipairs(irs) do
      -- local layout_prefix
      -- local layout_affixes = self.layout.affixes
      -- if layout_affixes then
      --   layout_prefix = layout_affixes.prefix
      -- end
    local prefix_inlines = ir.cite_prefix
    if prefix_inlines then
      -- Prefix is inlines
      local prefix_str = output.SortStringFormat:new():output(prefix_inlines, context)
      if (string.match(prefix_str, "[.!?]%s*$")
          -- position_IbidWithPrefixFullStop.txt
          -- `Book A. He said “Please work.” Ibid.`
          or string.match(prefix_str, "[.!?]”%s*$")
         ) and InlineElement.has_space(prefix_inlines) then
        ir:capitalize_first_term()
      end
    else
      local delimiter = self.layout.delimiter
      if i == 1 or not delimiter or string.match(delimiter, "[.!?]%s*$") then
        ir:capitalize_first_term()
      end
    end
  end

  -- util.debug(irs)

  local citation_stream = {}

  local context = Context:new()
  context.engine = engine
  context.style = engine.style
  context.area = self
  context.in_bibliography = false
  context.lang = engine.lang
  context.locale = engine:get_locale(engine.lang)
  context.name_inheritance = self.name_inheritance
  context.format = output_format

  local previous_ir
  for i, ir in ipairs(irs) do
    local cite_prefix = ir.cite_prefix
    local cite_suffix = ir.cite_suffix
    if not ir.collapse_suppressed then
      local cite_inlines = ir:flatten(output_format)
      if #cite_inlines > 0 then
        -- Make sure cite_inlines has outputs contents.
        -- collapse_AuthorCollapseNoDateSorted.txt
        if previous_ir then
          local delimiter = previous_ir.own_delimiter or previous_ir.cite_delimiter
          if delimiter then
            if cite_prefix then
              local left_most_str
              left_most_str = cite_prefix[1]:get_left_most_string()
              if string.match(left_most_str, "^[,.;?!]") then
                delimiter = nil
              end
            end
            if delimiter then
              table.insert(citation_stream, PlainText:new(delimiter))
            end
          end
        end

        if cite_prefix then
          table.insert(citation_stream, Micro:new(cite_prefix))
        end

        -- util.debug(ir.cite_item.id)
        -- util.debug(cite_inlines)
        -- if context.engine.opt.citation_link then
          cite_inlines = {CiteInline:new(cite_inlines, ir.cite_item)}
        -- end
        util.extend(citation_stream, cite_inlines)

        if cite_suffix then
          table.insert(citation_stream, Micro:new(cite_suffix))
          local cite_delimiter = ir.own_delimiter or ir.cite_delimiter
          if cite_delimiter and string.match(cite_delimiter, "^[,.;?]") then
            -- affix_WithCommas.txt
            local right_most_str = cite_suffix[#cite_suffix]:get_right_most_string()
            if string.match(right_most_str, "[,.;?]%s*$") then
              ir.own_delimiter = string.gsub(cite_delimiter,  "^[,.;?]", "")
            end
          end
        end

        previous_ir = ir
      end
    end
  end

  -- util.debug(citation_stream)

  local has_printed_form = true
  if #citation_items == 0 then
    -- bugreports_AuthorOnlyFail.txt
    citation_stream = {PlainText:new("[NO_PRINTED_FORM]")}
    has_printed_form = false
  elseif #citation_stream == 0 then
    -- date_DateNoDateNoTest.txt
    has_printed_form = false
    citation_stream = {PlainText:new("[CSL STYLE ERROR: reference with no printed form.]")}
  elseif #citation_stream == 1 and citation_stream[1]._type == "CiteInline" and
      #citation_stream[1].inlines == 1 and citation_stream[1].inlines[1].value == "[NO_PRINTED_FORM]" then
    has_printed_form = false
  end

  -- Ouput citation affixes
  if has_printed_form then
    if properties.prefix and properties.prefix ~= "" then
      local citation_prefix = util.check_prefix_space_append(properties.prefix)
      local inlines = InlineElement:parse(citation_prefix, context, true)
      table.insert(citation_stream, 1, Micro:new(inlines))
    end
    if properties.suffix and properties.suffix ~= "" then
      local citation_suffix = util.check_suffix_prepend(properties.suffix)
      local inlines = InlineElement:parse(citation_suffix, context, true)
      table.insert(citation_stream, Micro:new(inlines))
    end
  end

  local suppress_layout_affixes = (properties.mode == "author-only"
    or (#citation_items >= 1 and citation_items[1]["author-only"])
    or properties.mode == "cite-year")
  if has_printed_form and context.area.layout.affixes and not suppress_layout_affixes then
    if irs[1].layout_prefix then
      table.insert(citation_stream, 1, PlainText:new(irs[1].layout_prefix))
    end
    if irs[#irs].layout_suffix then
      table.insert(citation_stream, PlainText:new(irs[#irs].layout_suffix))
    end
  end

  if has_printed_form and context.area.layout.formatting then
    citation_stream = {Formatted:new(citation_stream, context.area.layout.formatting)}
  end

  if properties.mode == "composite" then
    local author_ir
    if irs[1] then
      author_ir = irs[1].author_ir
    end
    if author_ir then
      local infix = properties.infix
      if infix then
        if string.match(infix, "^%w") then
          -- discretionary_SingleNarrativeCitation.txt
          infix = " " .. infix
        end
        if string.match(infix, "%w$") then
          infix = infix .. " "
        end
        if infix == "" then
          -- discretionary_AuthorOnlySuppressLocator.txt
          infix = " "
        end
        for i, inline in ipairs(InlineElement:parse(infix, context, true)) do
          table.insert(citation_stream, i, inline)
        end
      else
        table.insert(citation_stream, 1, PlainText:new(" "))
      end

      local author_inlines = author_ir:flatten(output_format)
      for i, inline in ipairs(author_inlines) do
        table.insert(citation_stream, i, inline)
      end
    end
  end

  local str = output_format:output(citation_stream, context)
  str = util.strip(str)

  return str
end

function Citation:sorted_citation_items(items, engine)
  local citation_sort = self.sort
  if not citation_sort then
    return items
  end

  local state = IrState:new()
  local context = Context:new()
  context.engine = engine
  context.style = engine.style
  context.area = self
  context.in_bibliography = false
  context.lang = engine.lang
  context.locale = engine:get_locale(engine.lang)
  context.name_inheritance = self.name_inheritance
  context.format = SortStringFormat:new()
  -- context.id = id
  context.cite = nil
  -- context.reference = self:get_item(id)

  items = citation_sort:sort(items, state, context)
  return items
end


---@class CiteIr: IrNode
---@field cite_item CitationItem
---@field reference table
---@field ir_index any
---@field is_ambiguous boolean
---@field disam_level integer
---@field disam_str string?
---@field cite_delimiter string?
---@field layout_prefix string?
---@field layout_suffix string?
---@field cite_prefix InlineElement[]?
---@field cite_suffix InlineElement[]?

---@param cite_item CitationItem
---@param output_format OutputFormat
---@param engine CiteProc
---@param properties CitationProperties
---@return CiteIr
function Citation:build_fully_disambiguated_ir(cite_item, output_format, engine, properties)
  -- util.debug(cite_item.id)
  local cite_ir = self:build_ambiguous_ir(cite_item, output_format, engine)
  cite_ir = self:apply_disambiguate_add_givenname(cite_ir, engine)
  cite_ir = self:apply_disambiguate_add_names(cite_ir, engine)
  cite_ir = self:apply_disambiguate_conditionals(cite_ir, engine)
  cite_ir = self:apply_disambiguate_add_year_suffix(cite_ir, engine)

  if engine.style.class == "note" and cite_item.position_level == Position.First then
    -- Disambiguation should be based on the subsequent form
    -- disambiguate_BasedOnEtAlSubsequent.txt
    cite_item.position_level = Position.Subsequent
    cite_item["first-reference-note-number"] = properties.noteIndex
    local disam_ir = self:build_ambiguous_ir(cite_item, output_format, engine)
    disam_ir = self:apply_disambiguate_add_givenname(disam_ir, engine)
    disam_ir = self:apply_disambiguate_add_names(disam_ir, engine)
    disam_ir = self:apply_disambiguate_conditionals(disam_ir, engine)
    disam_ir = self:apply_disambiguate_add_year_suffix(disam_ir, engine)
    cite_item.position_level = Position.First
    cite_item["first-reference-note-number"] = nil
  end

  return cite_ir
end

---comment
---@param cite_item CitationItem
---@param output_format OutputFormat
---@param engine CiteProc
---@return CiteIr
function Citation:build_ambiguous_ir(cite_item, output_format, engine)
  local state = IrState:new(engine.style)
  local context = Context:new()
  context.engine = engine
  context.style = engine.style
  context.area = self
  context.name_inheritance = self.name_inheritance
  context.format = output_format
  context.id = cite_item.id
  context.cite = cite_item
  -- context.reference = self:get_item(cite_item.id)
  context.reference = engine.registry.registry[cite_item.id]

  local active_layout, context_lang = util.get_layout_by_language(self, engine, context.reference)
  context.lang = context_lang
  context.locale = engine:get_locale(context_lang)

  local ir
  if context.reference then
    ir = self:build_ir(engine, state, context, active_layout)
  else
    ir = Rendered:new({UndefinedCite:new({PlainText:new(tostring(cite_item.id))}, cite_item)}, self)
  end

  ir.cite_item = cite_item
  ir.reference = context.reference
  ir.ir_index = #engine.disam_irs + 1
  table.insert(engine.disam_irs, ir)
  ir.is_ambiguous = false
  ir.disam_level = 0

  ir.cite_delimiter = active_layout.delimiter
  if active_layout.affixes then
    ir.layout_prefix = active_layout.affixes.prefix
    ir.layout_suffix = active_layout.affixes.suffix
  end

  if cite_item.prefix and cite_item.prefix ~= "" then
    local cite_prefix = util.check_prefix_space_append(cite_item.prefix)
    ir.cite_prefix = InlineElement:parse(cite_prefix, context, true)
  end
  if cite_item.suffix and cite_item.suffix ~= "" then
    local cite_suffix = util.check_suffix_prepend(cite_item.suffix)
    ir.cite_suffix = InlineElement:parse(cite_suffix, context, true)
  end

  -- Formattings like font-style are ignored for disambiguation.
  local disam_format = DisamStringFormat:new()
  local inlines = ir:flatten(disam_format)
  local disam_str = disam_format:output(inlines, context)
  ir.disam_str = disam_str

  if not engine.cite_irs_by_output[disam_str] then
    engine.cite_irs_by_output[disam_str] = {}
  end

  for ir_index, ir_ in pairs(engine.cite_irs_by_output[disam_str]) do
    if ir_.cite_item.id ~= cite_item.id then
      ir.is_ambiguous = true
      break
    end
  end
  if DEBUG_DISAMBIGUATE then
    if ir.is_ambiguous then
      util.debug("[CLASH]")
      util.debug(string.format("%s: %s", cite_item.id, disam_str))
      for ir_index, ir_ in pairs(engine.cite_irs_by_output[disam_str]) do
        util.debug(string.format("%s: %s", ir_.cite_item.id, ir_.disam_str))
      end
    else
      util.debug("[clear]")
      util.debug(string.format("%s: %s", cite_item.id, disam_str))
    end
  end
  engine.cite_irs_by_output[disam_str][ir.ir_index] = ir

  return ir
end

---@param engine CiteProc
---@param state State
---@param context Context
---@param active_layout Layout
---@return CiteIr
function Citation:build_ir(engine, state, context, active_layout)
  if not active_layout then
    util.error("Missing citation layout.")
  end
  return active_layout:build_ir(engine, state, context)
end

function Citation:apply_disambiguate_add_givenname(cite_ir, engine)
  if self.disambiguate_add_givenname then
    if DEBUG_DISAMBIGUATE then
      util.debug("[Method (1)] disambiguate-add-givenname: " .. cite_ir.cite_item.id)
    end

    local gn_disam_rule = self.givenname_disambiguation_rule
    if gn_disam_rule == "all-names" or gn_disam_rule == "all-names-with-initials" then
      cite_ir = self:apply_disambiguate_add_givenname_all_names(cite_ir, engine)
    elseif gn_disam_rule == "primary-name" or gn_disam_rule == "primary-name-with-initials" then
      cite_ir = self:apply_disambiguate_add_givenname_primary_name(cite_ir, engine)
    elseif gn_disam_rule == "by-cite" then
      cite_ir = self:apply_disambiguate_add_givenname_by_cite(cite_ir, engine)
    end
  end
  return cite_ir
end

-- TODO: reorganize this code
function Citation:apply_disambiguate_add_givenname_all_names(cite_ir, engine)
  -- util.debug("disambiguate_add_givenname_all_names: " .. cite_ir.cite_item.id)
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end

  -- util.debug(cite_ir.disam_str)

  for _, person_name_ir in ipairs(cite_ir.person_name_irs) do
    local name_output = person_name_ir.name_output
    -- util.debug(name_output)

    if not person_name_ir.person_name_index then
      person_name_ir.person_name_index = #engine.person_names + 1
      table.insert(engine.person_names, person_name_ir)
    end

    if not engine.person_names_by_output[name_output] then
      engine.person_names_by_output[name_output] = {}
    end
    engine.person_names_by_output[name_output][person_name_ir.person_name_index] = person_name_ir

    local ambiguous_name_irs = {}
    local ambiguous_same_output_irs = {}

    for _, pn_ir in pairs(engine.person_names_by_output[person_name_ir.name_output]) do
      if pn_ir.full_name ~= person_name_ir.full_name then
        table.insert(ambiguous_name_irs, pn_ir)
      end
      if pn_ir.name_output == person_name_ir.name_output then
        table.insert(ambiguous_same_output_irs, pn_ir)
      end
    end

    -- util.debug(person_name_ir.name_output)
    -- util.debug(person_name_ir.full_name)
    -- util.debug(#ambiguous_name_irs)
    -- util.debug(person_name_ir.disam_variants_index)
    -- util.debug(person_name_ir.disam_variants)

    while person_name_ir.disam_variants_index < #person_name_ir.disam_variants do
      if #ambiguous_name_irs == 0 then
        break
      end

      for _, pn_ir in ipairs(ambiguous_same_output_irs) do
        -- expand one name
        if pn_ir.disam_variants_index < #pn_ir.disam_variants then
          pn_ir.disam_variants_index = pn_ir.disam_variants_index + 1
          pn_ir.name_output = pn_ir.disam_variants[pn_ir.disam_variants_index]
          pn_ir.inlines = pn_ir.disam_inlines[pn_ir.name_output]

          if not engine.person_names_by_output[pn_ir.name_output] then
            engine.person_names_by_output[pn_ir.name_output] = {}
          end
          engine.person_names_by_output[pn_ir.name_output][pn_ir.person_name_index] = pn_ir
        end
      end

      -- util.debug(person_name_ir.name_output)

      -- update ambiguous_name_irs and ambiguous_same_output_irs
      ambiguous_name_irs = {}
      ambiguous_same_output_irs = {}
      for _, pn_ir in pairs(engine.person_names_by_output[person_name_ir.name_output]) do
        if pn_ir.full_name ~= person_name_ir.full_name then
          -- util.debug(pn_ir.full_name .. ": " .. pn_ir.name_output)
          table.insert(ambiguous_name_irs, pn_ir)
        end
        if pn_ir.name_output == person_name_ir.name_output then
          table.insert(ambiguous_same_output_irs, pn_ir)
        end
      end

    end
  end

  -- update cite_ir output
  local disam_format = DisamStringFormat:new()
  local inlines = cite_ir:flatten(disam_format)
  local disam_str = disam_format:output(inlines, nil)
  cite_ir.disam_str = disam_str
  if not engine.cite_irs_by_output[disam_str] then
    engine.cite_irs_by_output[disam_str] = {}
  end
  engine.cite_irs_by_output[disam_str][cite_ir.ir_index] = cite_ir

  -- update ambiguous_cite_irs and ambiguous_same_output_irs
  local ambiguous_cite_irs = {}
  for ir_index, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
    -- util.debug(ir_.cite_item.id)
    if ir_.cite_item.id ~= cite_ir.cite_item.id then
      table.insert(ambiguous_cite_irs, ir_)
    end
  end
  if #ambiguous_cite_irs == 0 then
    cite_ir.is_ambiguous = false
  end

  return cite_ir
end

function Citation:apply_disambiguate_add_givenname_primary_name(cite_ir, engine)
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end
  local person_name_ir = cite_ir.person_name_irs[1]
  local name_output = person_name_ir.name_output
  -- util.debug(name_output)

  if not person_name_ir.person_name_index then
    person_name_ir.person_name_index = #engine.person_names + 1
    table.insert(engine.person_names, person_name_ir)
  end
  if not engine.person_names_by_output[name_output] then
    engine.person_names_by_output[name_output] = {}
  end
  engine.person_names_by_output[name_output][person_name_ir.person_name_index] = person_name_ir

  local ambiguous_name_irs = {}
  local ambiguous_same_output_irs = {}

  for _, pn_ir in pairs(engine.person_names_by_output[person_name_ir.name_output]) do
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

        if not engine.person_names_by_output[pn_ir.name_output] then
          engine.person_names_by_output[pn_ir.name_output] = {}
        end
        engine.person_names_by_output[pn_ir.name_output][person_name_ir.person_name_index] = person_name_ir
      end
    end

    -- update ambiguous_name_irs and ambiguous_same_output_irs
    ambiguous_name_irs = {}
    ambiguous_same_output_irs = {}
    for _, pn_ir in pairs(engine.person_names_by_output[person_name_ir.name_output]) do
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

function Citation:apply_disambiguate_add_givenname_by_cite(cite_ir, engine)
  -- util.debug(cite_ir.is_ambiguous)
  if not cite_ir.is_ambiguous then
    return cite_ir
  end
  -- util.debug(cite_ir)
  if not cite_ir.person_name_irs or #cite_ir.person_name_irs == 0 then
    return cite_ir
  end

  -- for _, ir_ in ipairs(engine.disam_irs) do
  --   util.debug(ir_.cite_item.id)
  --   util.debug(ir_.disam_str)
  -- end

  local disam_format = DisamStringFormat:new()

  local ambiguous_cite_irs = {}
  local ambiguous_same_output_irs = {}

  for ir_index, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
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
            local disam_str = disam_format:output(inlines, nil)
            ir_.disam_str = disam_str
            if not engine.cite_irs_by_output[disam_str] then
              engine.cite_irs_by_output[disam_str] = {}
            end
            engine.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
          end
        end
      end

      -- update ambiguous_cite_irs and ambiguous_same_output_irs
      ambiguous_cite_irs = {}
      ambiguous_same_output_irs = {}
      for ir_index, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
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

function Citation:apply_disambiguate_add_names(cite_ir, engine)
  if not self.disambiguate_add_names then
    return cite_ir
  end

  if not cite_ir.name_ir then
    cite_ir.name_ir = find_first_name_ir(cite_ir)
  end
  local name_ir =  cite_ir.name_ir

  if not cite_ir.is_ambiguous then
    return cite_ir
  end

  if not name_ir or not name_ir.et_al_abbreviation then
    return cite_ir
  end

  if DEBUG_DISAMBIGUATE then
    util.debug("[Method (3)] disambiguate-add-names: " .. cite_ir.cite_item.id)
  end

  -- if name_ir then
  --   util.debug(cite_ir.disam_str)
  --   util.debug(cite_ir.name_ir.full_name_str)
  --   util.debug(cite_ir.is_ambiguous)
  -- end

  local disam_format = DisamStringFormat:new()

  while cite_ir.is_ambiguous do
    if #cite_ir.name_ir.hidden_name_irs == 0 then
      break
    end

    local ambiguous_cite_irs = {}
    local ambiguous_same_output_irs = {}
    for _, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
      if ir_.cite_item.id ~= cite_ir.cite_item.id then
        table.insert(ambiguous_cite_irs, ir_)
      end
      if ir_.disam_str == cite_ir.disam_str then
        table.insert(ambiguous_same_output_irs, ir_)
      end
    end

    -- util.debug(#ambiguous_same_output_irs)
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

    for _, ir_ in ipairs(ambiguous_same_output_irs) do
      local added_person_name_ir = ir_.name_ir.name_inheritance:expand_one_name(ir_.name_ir)
      if added_person_name_ir then
        -- util.debug("Updated: " .. ir_.cite_item.id)
        table.insert(ir_.person_name_irs, added_person_name_ir)

        if not added_person_name_ir.person_name_index then
          added_person_name_ir.person_name_index = #engine.person_names + 1
          table.insert(engine.person_names, added_person_name_ir)
        end
        local name_output = added_person_name_ir.name_output
        if not engine.person_names_by_output[name_output] then
          engine.person_names_by_output[name_output] = {}
        end
        engine.person_names_by_output[name_output][added_person_name_ir.person_name_index] = added_person_name_ir

        -- Update ir output
        local inlines = ir_:flatten(disam_format)
        local disam_str = disam_format:output(inlines, nil)
        -- util.debug(disam_str)
        ir_.disam_str = disam_str
        if not engine.cite_irs_by_output[disam_str] then
          engine.cite_irs_by_output[disam_str] = {}
        end
        engine.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
      end
    end

    -- util.debug("disambiguate_add_givenname")

    if self.disambiguate_add_givenname then
      local gn_disam_rule = self.givenname_disambiguation_rule
      if gn_disam_rule == "all-names" or gn_disam_rule == "all-names-with-initials" then
        cite_ir = self:apply_disambiguate_add_givenname_all_names(cite_ir, engine)
      elseif gn_disam_rule == "by-cite" then
        cite_ir = self:apply_disambiguate_add_givenname_by_cite(cite_ir, engine)
      end
    end

    cite_ir.is_ambiguous = self:check_ambiguity(cite_ir, engine)

    -- for _, ir_ in ipairs(engine.disam_irs) do
    --   util.debug(ir_.cite_item.id .. ": " .. ir_.disam_str)
    -- end

  end


  return cite_ir
end

function Citation:collect_irs_with_disambiguate_branch(ir)
  local irs_with_disambiguate_branch = {}
  if ir.children then
    for i, child_ir in ipairs(ir.children) do
      if child_ir.disambiguate_branch_ir then
        table.insert(irs_with_disambiguate_branch, child_ir)
      elseif child_ir.children then
        util.extend(irs_with_disambiguate_branch,
          self:collect_irs_with_disambiguate_branch(child_ir))
      end
    end
  end
  return irs_with_disambiguate_branch
end

function Citation:apply_disambiguate_conditionals(cite_ir, engine)
  if DEBUG_DISAMBIGUATE then
    util.debug("[Method (3)] disambiguate with condition testing “true”: " .. cite_ir.cite_item.id)
  end

  cite_ir.irs_with_disambiguate_branch = self:collect_irs_with_disambiguate_branch(cite_ir)

  local disam_format = DisamStringFormat:new()

  while cite_ir.is_ambiguous do
    if #cite_ir.irs_with_disambiguate_branch == 0 then
      break
    end

    -- util.debug(cite_ir.cite_item.id)
    -- util.debug(cite_ir.disam_str)

    -- update ambiguous_same_output_irs
    local ambiguous_same_output_irs = {}
    for _, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
      if ir_.disam_str == cite_ir.disam_str then
        table.insert(ambiguous_same_output_irs, ir_)
      end
    end

    for _, ir_ in ipairs(ambiguous_same_output_irs) do
      if #ir_.irs_with_disambiguate_branch > 0 then
        -- Disambiguation is incremental
        -- disambiguate_IncrementalExtraText.txt
        ---@type SeqIr
        local condition_ir = ir_.irs_with_disambiguate_branch[1]
        condition_ir.children[1] = condition_ir.disambiguate_branch_ir
        -- condition_ir.person_name_irs are no longer used and we ignore them
        condition_ir.group_var = condition_ir.disambiguate_branch_ir.group_var
        table.remove(ir_.irs_with_disambiguate_branch, 1)
        -- disambiguate_DisambiguateTrueReflectedInBibliography.txt
        ir_.reference.disambiguate = true

        -- Update ir output
        local inlines = ir_:flatten(disam_format)
        local disam_str = disam_format:output(inlines, nil)
        ir_.disam_str = disam_str
        if not engine.cite_irs_by_output[disam_str] then
          engine.cite_irs_by_output[disam_str] = {}
        end
        engine.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
      end
    end

    cite_ir.is_ambiguous = self:check_ambiguity(cite_ir, engine)
    -- util.debug(cite_ir.is_ambiguous)
    -- for _, ir_ in ipairs(engine.disam_irs) do
    --   util.debug(ir_.cite_item.id .. ": " .. ir_.disam_str)
    -- end

  end
  return cite_ir
end

function Citation:check_ambiguity(cite_ir, engine)
  local is_ambiguous = false
  for _, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
    if ir_.cite_item.id ~= cite_ir.cite_item.id then
      is_ambiguous = true
    end
  end
  if DEBUG_DISAMBIGUATE then
    if is_ambiguous then
      util.debug("[CLASH]")
      util.debug(string.format("%s, %s", cite_ir.cite_item.id, cite_ir.disam_str))
      for _, ir_ in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
        if ir_.cite_item.id ~= cite_ir.cite_item.id then
          util.debug(string.format("%s: %s", ir_.cite_item.id, ir_.disam_str))
        end
      end
    else
      util.debug("[clear]")
      util.debug(string.format("%s, %s", cite_ir.cite_item.id, cite_ir.disam_str))
    end
  end
  return is_ambiguous
end

function Citation:get_ambiguous_cite_irs(cite_ir, engine)
  local res = {}
  for _, ir in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
    if ir.cite_item.id ~= cite_ir.cite_item.id then
      table.insert(res, ir)
    end
  end
  return res
end

function Citation:get_ambiguous_same_output_cite_irs(cite_ir, engine)
  -- This includes the cite_ir itself.
  local res = {}
  for _, ir in pairs(engine.cite_irs_by_output[cite_ir.disam_str]) do
    if ir.disam_str == cite_ir.disam_str then
      table.insert(res, ir)
    end
  end
  return res
end

function Citation:apply_disambiguate_add_year_suffix(cite_ir, engine)
  if not cite_ir.is_ambiguous or not self.disambiguate_add_year_suffix then
    return cite_ir
  end

  if DEBUG_DISAMBIGUATE then
    util.debug("[Method (4)] disambiguate-add-year-suffix”: " .. cite_ir.cite_item.id)
  end

  local ambiguous_same_output_irs = self:get_ambiguous_same_output_cite_irs(cite_ir, engine)

  table.sort(ambiguous_same_output_irs, function (a, b)
    -- return a.ir_index < b.ir_index
    return a.reference["citation-number"] < b.reference["citation-number"]
  end)

  local disam_format = DisamStringFormat:new()

  for _, ir_ in ipairs(ambiguous_same_output_irs) do
    ir_.reference.year_suffix_number = nil
  end

  -- TODO: clear year-suffix after updateItems
  local year_suffix_number = 0
  for _, ir_ in ipairs(ambiguous_same_output_irs) do
    if not ir_.reference.year_suffix_number then
      year_suffix_number = year_suffix_number + 1
      ir_.reference.year_suffix_number = year_suffix_number
      ir_.reference["year-suffix"] = self:render_year_suffix(year_suffix_number)
    end
    -- util.debug(string.format('%s: %s "%s"', ir_.cite_item.id, tostring(ir_.reference.year_suffix_number), ir_.reference["year-suffix"]))

    if not ir_.year_suffix_irs then
      ir_.year_suffix_irs = ir_:collect_year_suffix_irs()
      if #ir_.year_suffix_irs == 0 then
        -- The style does not have a "year-suffix" variable.
        -- Then the year-suffix is appended the first year rendered through cs:date or citation-label
        local year_ir = ir_:find_first_year_ir()
        -- util.debug(year_ir)
        if year_ir then
          local year_suffix_ir = YearSuffix:new({}, self)
          table.insert(year_ir.children, year_suffix_ir)
          table.insert(ir_.year_suffix_irs, year_suffix_ir)
        else
          util.warning("No date variable for year-suffix")
        end
      end
    end

    -- Render all the year-suffix irs.
    for _, year_suffix_ir in ipairs(ir_.year_suffix_irs) do
      -- util.debug(ir_.reference["year-suffix"])
      year_suffix_ir.inlines = { PlainText:new(ir_.reference["year-suffix"]) }
      year_suffix_ir.year_suffix_number = ir_.reference.year_suffix_number
      year_suffix_ir.group_var = GroupVar.Important
    end

    -- DisamStringFormat doesn't render YearSuffix and this can be skipped.
    -- local inlines = ir_:flatten(disam_format)
    -- local disam_str = disam_format:output(inlines, nil)
    -- util.debug(string.format('update %s: "%s" to "%s"', ir_.cite_item.id, ir_.disam_str, disam_str))
    -- ir_.disam_str = disam_str
    -- if not engine.cite_irs_by_output[disam_str] then
    --   engine.cite_irs_by_output[disam_str] = {}
    -- end
    -- engine.cite_irs_by_output[disam_str][ir_.ir_index] = ir_
  end

  cite_ir.is_ambiguous = false

  return cite_ir
end

function Citation:render_year_suffix(year_suffix_number)
  if year_suffix_number <= 0 then
    return nil
  end
  local year_suffix = ""
  while year_suffix_number > 0 do
    local i = (year_suffix_number - 1) % 26
    year_suffix = string.char(i + 97) .. year_suffix
    year_suffix_number = (year_suffix_number - 1) // 26
  end
  -- util.debug(year_suffix)
  return year_suffix
end

local function find_first(ir, check)
  if check(ir) then
    return ir
  end
  if ir.children then
    for _, child in ipairs(ir.children) do
      local target_ir = find_first(child, check)
      if target_ir then
        return target_ir
      end
    end
  end
  return nil
end

-- Find the first rendering element and it should be produced by and names element
local function find_first_names_ir(ir)
  if ir.first_names_ir then
    return ir.first_names_ir
  end

  local first_rendering_ir = find_first(ir, function (ir_)
    return (ir_._element_name == "text"
      or ir_._element_name == "date"
      or ir_._element_name == "number"
      or ir_._element_name == "names"
      or ir_._element_name == "label")
      and ir_.group_var ~= GroupVar.Missing
  end)
  local first_names_ir
  if first_rendering_ir and first_rendering_ir._element_name == "names" then
    first_names_ir = first_rendering_ir
  end
  if first_names_ir then
    local disam_format = DisamStringFormat:new()
    local inlines = first_names_ir:flatten(disam_format)
    first_names_ir.disam_str = disam_format:output(inlines, nil)
  end
  ir.first_names_ir = first_names_ir
  return first_names_ir

end

function Citation:_apply_special_citation_form(irs, properties, output_format, engine)
  if properties.mode then
    if properties.mode == "author-only" then
      for _, ir in ipairs(irs) do
        self:_apply_citation_mode_author_only(ir)
      end
    elseif properties.mode == "suppress-author" then
      -- suppress-author mode does not work in note style
      -- discretionary_FirstReferenceNumberWithIntext.txt
      if engine.style.class ~= "note" then
        for _, ir in ipairs(irs) do
          self:_apply_suppress_author(ir)
        end
      end

    elseif properties.mode == "cite-year" then
      if engine.style.class ~= "note" then
        for i, ir in ipairs(irs) do
          self:_apply_suppress_author(ir)
          local cite_str = output_format:output(ir:flatten(output_format), nil)
          if ir.reference and ir.reference.issued and ir.reference.issued["date-parts"] then
            local year = tostring(ir.reference.issued["date-parts"][1][1])
            if not string.match(cite_str, year) then
              irs[i] = Rendered:new({PlainText:new(year)}, self)
            end
          end
        end
      end

    elseif properties.mode == "composite" then
      self:_apply_composite(irs[1], output_format, engine)

    end

  else
    for _, ir in ipairs(irs) do
      if ir.cite_item["author-only"] then
        self:_apply_cite_author_only(ir)
      elseif ir.cite_item["suppress-author"] then
        self:_apply_suppress_author(ir)
      end
    end
  end
end

function Citation:_apply_citation_mode_author_only(ir)
  -- Used in pr
  local author_ir = find_first_names_ir(ir)

  if author_ir then
    remove_name_formatting(author_ir)
    ir.children = {author_ir}
  else
    ir.children = {Rendered:new({PlainText:new("[NO_PRINTED_FORM]")}, self)}
  end
  return ir
end

-- Citation flags with makeCitationCluster
-- In contrast to Citation flags with processCitationCluster, this funciton
-- looks for the first rendering element instead of names element.
-- See discretionary_AuthorOnly.txt
function Citation:_apply_cite_author_only(ir)
  local author_ir = find_first(ir, function (ir_)
    return (ir_._element_name == "text"
      or ir_._element_name == "date"
      or ir_._element_name == "number"
      or ir_._element_name == "names"
      or ir_._element_name == "label")
      and ir_.group_var ~= GroupVar.Missing
  end)

  if author_ir then
    remove_name_formatting(author_ir)
    ir.children = {author_ir}
  else
    ir.children = {Rendered:new({PlainText:new("[NO_PRINTED_FORM]")}, self)}
  end
  return ir
end

function Citation:_apply_suppress_author(ir)
  local author_ir = find_first_names_ir(ir)
  if author_ir then
    -- util.debug(author_ir)
    author_ir.collapse_suppressed = true
  end
  return ir
end

function Citation:_apply_composite(ir, output_format, engine)
  -- local first_names_ir = find_first_names_ir(ir)

  local first_names_ir = find_first_names_ir(ir)
  if first_names_ir and engine.style.class ~= "note" then
    -- util.debug(first_names_ir)
    first_names_ir.collapse_suppressed = true
  end

  local author_ir
  if engine.style.intext then
    local properties = {mode = "author-only"}
    author_ir = engine.style.intext:build_fully_disambiguated_ir(ir.cite_item, output_format, engine, properties)
  elseif first_names_ir then
    author_ir = first_names_ir
  end

  if author_ir then
    remove_name_formatting(author_ir)
    ir.author_ir = author_ir
  else
    ir.author_ir = Rendered:new({PlainText:new("[NO_PRINTED_FORM]")}, self)
  end

  return ir
end

function Citation:group_cites(irs)
  local disam_format = DisamStringFormat:new()
  for _, ir in ipairs(irs) do
    local first_names_ir = ir.first_names_ir
    if not first_names_ir then
      first_names_ir = find_first(ir, function (ir_)
        return ir_._element_name == "names" and ir_.group_var ~= GroupVar.Missing
      end)
      if first_names_ir then
        local inlines = first_names_ir:flatten(disam_format)
        first_names_ir.disam_str = disam_format:output(inlines, nil)
      end
      ir.first_names_ir = first_names_ir
    end
  end

  local irs_by_name = {}
  local name_list = {}

  for _, ir in ipairs(irs) do
    local name_str = ""
    if ir.first_names_ir then
      name_str = ir.first_names_ir.disam_str
    end
    if not irs_by_name[name_str] then
      irs_by_name[name_str] = {}
      table.insert(name_list, name_str)
    end
    table.insert(irs_by_name[name_str], ir)
  end

  local grouped = {}
  for _, name_str in ipairs(name_list) do
    local irs_with_same_name = irs_by_name[name_str]
    for i, ir in ipairs(irs_with_same_name) do
      if i < #irs_with_same_name then
        ir.own_delimiter = self.cite_group_delimiter
      end
      table.insert(grouped, ir)
    end
  end
  return grouped
end

function Citation:collapse_cites(irs)
  if self.collapse == "citation-number" then
    self:collapse_cites_by_citation_number(irs)
  elseif self.collapse == "year" then
    self:collapse_cites_by_year(irs)
  elseif self.collapse == "year-suffix" then
    self:collapse_cites_by_year_suffix(irs)
  elseif self.collapse == "year-suffix-ranged" then
    self:collapse_cites_by_year_suffix_ranged(irs)
  end
end

function Citation:collapse_cites_by_citation_number(irs)
  local cite_groups = {}
  local current_group = {}
  local previous_citation_number
  for i, ir in ipairs(irs) do
    local citation_number
    local only_citation_number_ir = self:get_only_citation_number(ir)
    if only_citation_number_ir then
      -- Other irs like locators are not rendered.
      -- collapse_CitationNumberRangesWithAffixesGrouped.txt
      citation_number = only_citation_number_ir.citation_number
    end
    if i == 1 then
      table.insert(current_group, ir)
    elseif citation_number and previous_citation_number and
      previous_citation_number + 1 == citation_number then
      table.insert(current_group, ir)
    else
      table.insert(cite_groups, current_group)
      current_group = {ir}
    end
    previous_citation_number = citation_number
  end
  table.insert(cite_groups, current_group)

  for _, cite_group in ipairs(cite_groups) do
    if #cite_group >= 3 then
      cite_group[1].own_delimiter = util.unicode["en dash"]
      for i = 2, #cite_group - 1 do
        cite_group[i].collapse_suppressed = true
      end
      cite_group[#cite_group].own_delimiter = self.after_collapse_delimiter
    end
  end
end

function Citation:get_only_citation_number(ir)
  if ir.citation_number then
    return ir
  end
  if not ir.children then
    return nil
  end
  local only_citation_number_ir
  for _, child in ipairs(ir.children) do
    if child.group_var ~= GroupVar.Missing then
      local citation_number_ir = self:get_only_citation_number(child)
      if citation_number_ir then
        if only_citation_number_ir then
          return nil
        else
          only_citation_number_ir = citation_number_ir
        end
      else
        return false
      end
    end
  end
  return only_citation_number_ir
end

function Citation:collapse_cites_by_year(irs)
  local cite_groups = {{}}
  local previous_name_str
  for i, ir in ipairs(irs) do
    local name_str
    if ir.first_names_ir then
      name_str = ir.first_names_ir.disam_str
    end
    if i == 1 then
      table.insert(cite_groups[#cite_groups], ir)
    elseif name_str and name_str == previous_name_str then
      -- ir.first_names_ir was set in the cite grouping stage
      -- TODO: and not previous cite suffix
      table.insert(cite_groups[#cite_groups], ir)
    else
      table.insert(cite_groups, {ir})
    end
    previous_name_str = name_str
  end

  for _, cite_group in ipairs(cite_groups) do
    if #cite_group > 1 then
      for i, cite_ir in ipairs(cite_group) do
        if i > 1 and cite_ir.first_names_ir then
          cite_ir.first_names_ir.collapse_suppressed = true
        end
        if i == #cite_group then
          cite_ir.own_delimiter = self.after_collapse_delimiter
        elseif i < #cite_group then
          if self.style.class == "in-text" then
            if cite_ir.cite_item.locator then
              -- Special hack
              cite_ir.own_delimiter = self.after_collapse_delimiter
            else
              cite_ir.own_delimiter = self.cite_group_delimiter or self.layout.delimiter
            end
          else
            -- In note style, the layout delimiter is tried first before falling back to the default.
            -- See <https://github.com/citation-style-language/test-suite/issues/56>
            cite_ir.own_delimiter = self.layout.delimiter or self.cite_group_delimiter
          end
        end
      end
    end
  end
end

local function find_rendered_year_suffix(ir)
  if ir._type == "YearSuffix" then
    return ir
  end
  if ir.children then
    for _, child in ipairs(ir.children) do
      if child.group_var ~= GroupVar.Missing then
        local year_suffix = find_rendered_year_suffix(child)
        if year_suffix then
          return year_suffix
        end
      end
    end
  end
  return nil
end

function Citation:collapse_cites_by_year_suffix(irs)
  self:collapse_cites_by_year(irs)
  -- Group by disam_str
  -- The year-suffix is ommitted in DisamStringFormat
  local cite_groups = {{}}
  local previous_ir
  local previous_year_suffix
  for i, ir in ipairs(irs) do
    local year_suffix = find_rendered_year_suffix(ir)
    ir.rendered_year_suffix_ir = year_suffix
    if i == 1 then
      table.insert(cite_groups[#cite_groups], ir)
    elseif year_suffix and previous_ir.disam_str == ir.disam_str and previous_year_suffix then
      -- TODO: and not previous cite suffix
      table.insert(cite_groups[#cite_groups], ir)
    else
      table.insert(cite_groups, {ir})
    end
    previous_ir = ir
    previous_year_suffix = year_suffix
  end

  for _, cite_group in ipairs(cite_groups) do
    if #cite_group > 1 then
      for i, cite_ir in ipairs(cite_group) do
        if i > 1 then
          -- cite_ir.children = {cite_ir.rendered_year_suffix_ir}
          -- Set the collapse_suppressed flag rather than removing the child irs.
          -- This leaves the disamb ir structure unchanged.
          self:suppress_ir_except_child(cite_ir, cite_ir.rendered_year_suffix_ir)
        end
        if i < #cite_group then
          if self.cite_grouping then
            -- In the current citeproc-js impplementation, explicitly set
            -- cite-group-delimiter takes precedence over year-suffix-delimiter.
            -- May be changed in the future.
            -- https://github.com/citation-style-language/test-suite/issues/50
            cite_ir.own_delimiter = self.cite_group_delimiter
          else
            cite_ir.own_delimiter = self.year_suffix_delimiter
          end
        elseif i == #cite_group then
          cite_ir.own_delimiter = self.after_collapse_delimiter
        end
      end
    end
  end
end

function Citation:suppress_ir_except_child(ir, target)
  if ir == target then
    ir.collapse_suppressed = false
    return false
  end
  ir.collapse_suppressed = true
  if ir.children then
    for _, child in ipairs(ir.children) do
      if child.group_var ~= GroupVar.Missing and not child.collapse_suppressed then
        if not self:suppress_ir_except_child(child, target) then
          ir.collapse_suppressed = false
        end
      end
    end
  end
  return ir.collapse_suppressed
end

function Citation:collapse_cites_by_year_suffix_ranged(irs)
  self:collapse_cites_by_year_suffix(irs)
  -- Group by disam_str
  local cite_groups = {{}}
  local previous_ir
  local previous_year_suffix
  for i, ir in ipairs(irs) do
    local year_suffix_ir = find_rendered_year_suffix(ir)
    ir.rendered_year_suffix_ir = year_suffix_ir
    if i == 1 then
      table.insert(cite_groups[#cite_groups], ir)
    elseif year_suffix_ir and previous_ir.disam_str == ir.disam_str and previous_year_suffix and
        year_suffix_ir.year_suffix_number == previous_year_suffix.year_suffix_number + 1 then
      -- TODO: and not previous cite suffix
      table.insert(cite_groups[#cite_groups], ir)
    else
      table.insert(cite_groups, {ir})
    end
    previous_ir = ir
    previous_year_suffix = year_suffix_ir
  end

  for _, cite_group in ipairs(cite_groups) do
    if #cite_group > 2 then
      for i, cite_ir in ipairs(cite_group) do
        if i == 1 then
          cite_ir.own_delimiter = util.unicode["en dash"]
        elseif i < #cite_group then
          cite_ir.collapse_suppressed = true
        end
      end
    end
  end
end


local InText = Citation:derive("intext", {
  givenname_disambiguation_rule = "by-cite",
  cite_group_delimiter = ", ",
  near_note_distance = 5,
})


citation_module.Citation = Citation
citation_module.InText = InText


return citation_module
