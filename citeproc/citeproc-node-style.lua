--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style_module = {}

local dom = require("luaxml-domobject")

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local Rendered = require("citeproc-ir-node").Rendered
local SeqIr = require("citeproc-ir-node").SeqIr
local PlainText = require("citeproc-output").PlainText
local DisamStringFormat = require("citeproc-output").DisamStringFormat
local util = require("citeproc-util")


local Style = Element:derive("style")

function Style:new()
  local o = {
    children = {},
    macros = {},
    locales = {},
    initialize_with_hyphen = true,
    demote_non_dropping_particle = "display-and-sort",
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Style:parse(xml_str)
  local csl_xml = dom.parse(xml_str)
  if not csl_xml then
    error("Failed to parse CSL style.")
  end
  local style_node = csl_xml:get_path("style")[1]
  if not csl_xml then
    error('Element "style" not found.')
  end
  return Style:from_node(style_node)
end

local function make_name_inheritance(name, node)
  name:set_attribute(node, "and")
  name:set_attribute(node, "delimiter-precedes-et-al")
  name:set_attribute(node, "delimiter-precedes-last")
  name:set_number_attribute(node, "et-al-min")
  name:set_number_attribute(node, "et-al-use-first")
  name:set_number_attribute(node, "et-al-subsequent-min")
  name:set_number_attribute(node, "et-al-subsequent-use-first")
  name:set_bool_attribute(node, "et-al-use-last")
  name:set_bool_attribute(node, "initialize")
  name:set_attribute(node, "initialize-with")
  name:set_attribute(node, "name-as-sort-order")
  name:set_attribute(node, "sort-separator")
  local delimiter = node:get_attribute("name-delimiter")
  if delimiter then
    name.delimiter = delimiter
  end
  local form = node:get_attribute("name-form")
  if form then
    name.form = form
  end
  local names_delimiter = node:get_attribute("names-delimiter")
  if names_delimiter then
    name.names_delimiter = names_delimiter
  end
end

function Style:from_node(node)
  local o = Style:new()

  o:set_attribute(node, "class")
  o:set_attribute(node, "default-locale")
  o:set_attribute(node, "version")

  -- Global Options
  o.initialize_with_hyphen = true
  o:set_bool_attribute(node, "initialize-with-hyphen")
  o:set_attribute(node, "page-range-format")
  o:set_attribute(node, "demote-non-dropping-particle")

  -- Inheritable Name Options
  -- https://docs.citationstyles.org/en/stable/specification.html#inheritable-name-options
  o.name_inheritance = require("citeproc-node-names").Name:new()
  make_name_inheritance(o.name_inheritance, node)

  if o.page_range_format == "chicago" then
    if o.version < "1.1" then
      o.page_range_format = "chicago-15"
    else
      o.page_range_format = "chicago-16"
    end
  end

  o.macros = {}
  o.locales = {}

  o.children = {}
  o:process_children_nodes(node)

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "info" then
      o.info = child
    elseif element_name == "citation" then
      o.citation = child
    elseif element_name == "bibliography" then
      o.bibliography = child
    elseif element_name == "macro" then
      o.macros[child.name] = child
    elseif element_name == "locale" then
      local xml_lang = child.xml_lang or "@generic"
      o.locales[xml_lang] = child
    end
  end

  return o
end


Style._default_options = {
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
}

function Style:set_lang(lang, force_lang)
  local default_locale = self:get_attribute("default-locale")
  if lang then
    if default_locale and not force_lang then
      self.lang = default_locale
    end
  else
    self.lang = default_locale or "en-US"
  end
end


local Info = Element:derive("info")


function Info:from_node(node)
  local o = Info:new()

  -- o.authors = nil
  -- o.contributors = nil
  o.categories = {}
  o.id = nil
  -- o.issn = nil
  -- o.eissn = nil
  -- o.issnl = nil
  o.links = {
    independent_parent = nil,
  }
  -- o.published = nil
  -- o.rights = nil
  -- o.summary = nil
  o.title = nil
  -- o.title_short = nil
  o.updated = nil

  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "category" then
        local citation_format = child:get_attribute("citation-format")
        if citation_format then
          o.categories.citation_format = citation_format
        end

      elseif element_name == "id" then
        o.id = child:get_text()

      elseif element_name == "link" then
        local href = child:get_attribute("href")
        local rel = child:get_attribute("rel")
        if href and rel == "independent-parent" then
          o.links.independent_parent = href
        end

      elseif element_name == "title" then
        o.title = child:get_text()

      elseif element_name == "updated" then
        o.updated = child:get_text()

      end
    end
  end

  return o
end


local Citation = Element:derive("citation", {
  givenname_disambiguation_rule = "by-cite",
  cite_group_delimiter = ", ",
  near_note_distance = 5,
})

function Citation:from_node(node, style)

  local o = Citation:new()
  o.children = {}

  o:process_children_nodes(node)

  -- o.layouts = nil  -- CSL-M extension

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      o.layout = child
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

  o.cite_grouping = false
  -- Cite grouping can be activated by setting the cite-group-delimiter
  -- attribute or the collapse attributes on cs:citation.
  if node:get_attribute("cite-group-delimiter") or (o.collapse and o.collapse ~= "citation-number") then
    o.cite_grouping = true
  end

  -- Note Distance
  o:set_number_attribute(node, "near-note-distance")

  local name_inheritance = require("citeproc-node-names").Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

  -- update_mode = "plain" or "numeric" or "position" (or "both"?)

  return o
end

function Citation:build_ir(engine, state, context)
  if not self.layout then
    util.error("Missing citation layout.")
  end
  return self.layout:build_ir(engine, state, context)
end

local Bibliography = Element:derive("bibliography", {
  subsequent_author_substitute_rule = "complete-all"
})

function Bibliography:from_node(node, style)
  local o = Bibliography:new()
  o.children = {}

  o:process_children_nodes(node)

  -- o.layouts = nil  -- CSL-M extension

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      o.layout = child
    elseif element_name == "sort" then
      o.sort = child
    end
  end

  -- Whitespace
  o:set_bool_attribute(node, "hanging-indent")
  o:set_attribute(node, "second-field-align")
  o:set_attribute(node, "line-spacing")
  o:set_attribute(node, "entry-spacing")

  -- Reference Grouping
  o:set_attribute(node, "subsequent-author-substitute")
  o:set_attribute(node, "subsequent-author-substitute-rule")

  local name_inheritance = require("citeproc-node-names").Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

  return o
end

function Bibliography:build_ir(engine, state, context)
  if not self.layout then
    util.error("Missing bibliography layout.")
  end
  local ir = self.layout:build_ir(engine, state, context)
  -- util.debug(ir)
  if self.second_field_align == "flush" and #ir.children >= 2 then
    ir.children[1].display = "left-margin"
    local right_inline_ir = SeqIr:new(util.slice(ir.children, 2), self)
    right_inline_ir.display = "right-inline"
    if ir.affixes then
      right_inline_ir.affixes = util.clone(ir.affixes)
      ir.affixes = nil
    end
    ir.children = {ir.children[1], right_inline_ir}
  end

  if self.subsequent_author_substitute then
    self:substitute_subsequent_authors(engine, ir)
  end

  if not ir then
    ir = Rendered:new(PlainText:new("[CSL STYLE ERROR: reference with no printed form.]"), self)
  end
  return ir
end

function Bibliography:substitute_subsequent_authors(engine, ir)
  ir.first_name_ir = self:find_first_name_ir(ir)  -- should be a SeqIr wiht _element = "names"
  if not ir.first_name_ir then
    engine.previous_bib_names_ir = nil
    return
  end
  if self.subsequent_author_substitute_rule == "complete-all" then
    self:substitute_subsequent_authors_complete_all(engine, ir)
  elseif self.subsequent_author_substitute_rule == "complete-each" then
    self:substitute_subsequent_authors_complete_each(engine, ir)
  elseif self.subsequent_author_substitute_rule == "partial-each" then
    self:substitute_subsequent_authors_partial_each(engine, ir)
  elseif self.subsequent_author_substitute_rule == "partial-first" then
    self:substitute_subsequent_authors_partial_first(engine, ir)
  end
  engine.previous_bib_names_ir = ir.first_name_ir
end

function Bibliography:find_first_name_ir(ir)
  if ir._type == "NameIr" then
    return ir
  elseif ir.children then
    for _, child_ir in ipairs(ir.children) do
      local first_name_ir = self:find_first_name_ir(child_ir)
      if first_name_ir then
        return first_name_ir
      end
    end
  end
  return nil
end

function Bibliography:substitute_subsequent_authors_complete_all(engine, ir)
  local bib_names_str = ""

  if #ir.first_name_ir.person_name_irs > 0 then
    for _, person_name_ir in ipairs(ir.first_name_ir.person_name_irs) do
      if bib_names_str ~= "" then
        bib_names_str = bib_names_str .. "     "
      end
      local name_variants = person_name_ir.disam_variants
      bib_names_str = bib_names_str .. name_variants[#name_variants]
    end
  else
    -- In case of a <text variable="title"/> in <substitute>
    local disam_format = DisamStringFormat:new()
    local inlines = ir.first_name_ir:flatten(disam_format)
    bib_names_str = disam_format:output(inlines)
  end
  ir.first_name_ir.bib_names_str = bib_names_str

  if engine.previous_bib_names_ir and
      engine.previous_bib_names_ir.bib_names_str == bib_names_str then
    local text = self.subsequent_author_substitute
    if text == "" then
      ir.first_name_ir.children = {}
      ir.first_name_ir.group_var = "missing"
    else
      -- the output of label is not substituted
      -- util.debug(ir.first_name_ir)
      ir.first_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
    end
  end
end

function Bibliography:substitute_subsequent_authors_complete_each(engine, ir)
end

function Bibliography:substitute_subsequent_authors_partial_each(engine, ir)
  local bib_names_str = ""

  if #ir.first_name_ir.person_name_irs > 0 then
    if engine.previous_bib_names_ir then
      for i, person_name_ir in ipairs(ir.first_name_ir.person_name_irs) do
        local prev_name_ir = engine.previous_bib_names_ir.person_names[i]
        if prev_name_ir then
          local prev_name_variants = prev_name_ir.disam_variants
          local prev_full_name_str = prev_name_variants[#prev_name_variants]
          local name_variants = person_name_ir.disam_variants
          local full_name_str = name_variants[#name_variants]
          if prev_full_name_str == full_name_str then
            local text = self.subsequent_author_substitute
            person_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
          else
            break
          end
        end
      end
    end
  else
    -- In case of a <text variable="title"/> in <substitute>
    local disam_format = DisamStringFormat:new()
    local inlines = ir.first_name_ir:flatten(disam_format)
    bib_names_str = disam_format:output(inlines)
    ir.first_name_ir.bib_names_str = bib_names_str
    if engine.previous_bib_names_ir and
        engine.previous_bib_names_ir.bib_names_str == bib_names_str then
      local text = self.subsequent_author_substitute
      if text == "" then
        ir.first_name_ir.children = {}
        ir.first_name_ir.group_var = "missing"
      else
        ir.first_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
      end
    end
  end
end

function Bibliography:substitute_subsequent_authors_partial_first(engine, ir)
end

local Macro = Element:derive("macro")

function Macro:from_node(node)
  local o = Macro:new()
  o.children = {}
  o:set_attribute(node, "name")
  o:process_children_nodes(node)
  return o
end

function Macro:build_ir(engine, state, context)
  local ir = self:build_group_ir(engine, state, context)
  return ir
end


style_module.Style = Style
style_module.Citation = Citation
style_module.Bibliography = Bibliography


return style_module
