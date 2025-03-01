--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local bibliography_module = {}

local context
local element
local ir_node
local output
local node_names
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
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
local Rendered = ir_node.Rendered
local SeqIr = ir_node.SeqIr
local GroupVar = ir_node.GroupVar
local PlainText = output.PlainText
local DisamStringFormat = output.DisamStringFormat
local YearSuffix = ir_node.YearSuffix


---@class Bibliography: Element
---@field hanging_indent boolean
---@field second_field_align string?
---@field line_spacing number
---@field entry_spacing number
---@field subsequent_author_substitute string?
---@field subsequent_author_substitute_rule string
---@field layout Layout
---@field layouts_by_language table<string, Layout>
---@field name_inheritance Name
local Bibliography = Element:derive("bibliography", {
  hanging_indent = false,
  line_spacing = 1,
  entry_spacing = 1,
  subsequent_author_substitute_rule = "complete-all",
})

function Bibliography:from_node(node, style)
  local o = Bibliography:new()
  o.children = {}
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

  -- Whitespace
  o:set_bool_attribute(node, "hanging-indent")
  o:set_attribute(node, "second-field-align")
  o:set_number_attribute(node, "line-spacing")
  o:set_number_attribute(node, "entry-spacing")

  -- Reference Grouping
  o:set_attribute(node, "subsequent-author-substitute")
  o:set_attribute(node, "subsequent-author-substitute-rule")

  local name_inheritance = node_names.Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  Element.make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

  return o
end

---@param id string
---@param engine CiteProc
---@return string?
function Bibliography:build_bibliography_str(id, engine)
  local output_format = engine.output_format

  local state = IrState:new()
  local context = Context:new()
  context.engine = engine
  context.style = engine.style
  context.area = self
  context.in_bibliography = true
  context.name_inheritance = self.name_inheritance
  context.format = output_format
  context.id = id
  context.cite = nil
  context.reference = engine:get_item(id)

  -- CSL-M: `layout` extension
  local active_layout, context_lang = util.get_layout_by_language(self, engine, context.reference)
  context.lang = context_lang
  context.locale = engine:get_locale(context_lang)

  local ir = self:build_ir(engine, state, context, active_layout)
  ir.reference = context.reference

  -- Add year-suffix
  self:add_bibliography_year_suffix(ir, engine)

  -- The layout output may be empty: sort_OmittedBibRefNonNumericStyle.txt
  if not ir then
    return nil
  end

  local flat = ir:flatten(output_format)
  local str = output_format:output_bibliography_entry(flat, context)
  return str
end

function Bibliography:build_ir(engine, state, context, active_layout)
  if not active_layout then
    util.error("Missing bibliography layout.")
  end
  local ir = active_layout:build_ir(engine, state, context)
  if self.second_field_align == "flush" and #ir.children >= 2 then
    ir.children[1].display = "left-margin"
    local right_inline_ir = SeqIr:new(util.slice(ir.children, 2), self)
    right_inline_ir.display = "right-inline"
    if ir.affixes then
      right_inline_ir.affixes = ir.affixes
      right_inline_ir.formatting = ir.formatting
      ir.affixes = nil
      ir.formatting = nil
    end
    ir.children = {ir.children[1], right_inline_ir}
  end

  if self.subsequent_author_substitute then
    self:substitute_subsequent_authors(engine, ir)
  end

  if not ir then
    ir = Rendered:new({PlainText:new("[CSL STYLE ERROR: reference with no printed form.]")}, self)
  end
  return ir
end

function Bibliography:substitute_subsequent_authors(engine, ir)
  ir.first_name_ir = self:find_first_name_ir(ir)  -- should be a SeqIr wiht _element_name = "names"
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
    ---@type string
    local text = self.subsequent_author_substitute
    if text == "" then
      ir.first_name_ir.children = {}
      ir.first_name_ir.group_var = GroupVar.Missing
    else
      -- the output of label is not substituted
      ir.first_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
    end
  end
end

function Bibliography:substitute_subsequent_authors_complete_each(engine, ir)
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
    ---@type string
    local text = self.subsequent_author_substitute
    if #ir.first_name_ir.person_name_irs > 0 then
      for _, person_name_ir in ipairs(ir.first_name_ir.person_name_irs) do
        person_name_ir.inlines = {PlainText:new(text)}
      end
    else
      -- In case of a <text variable="title"/> in <substitute>
      if text == "" then
        ir.first_name_ir.children = {}
        ir.first_name_ir.group_var = GroupVar.Missing
      else
        ir.first_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
      end
    end
  end
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
            ---@type string
            local text = self.subsequent_author_substitute
            person_name_ir.inlines = {PlainText:new(text)}
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
      ---@type string
      local text = self.subsequent_author_substitute
      if text == "" then
        ir.first_name_ir.children = {}
        ir.first_name_ir.group_var = GroupVar.Missing
      else
        ir.first_name_ir.children = {Rendered:new({PlainText:new(text)}, self)}
      end
    end
  end
end

function Bibliography:substitute_subsequent_authors_partial_first(engine, ir)
end

function Bibliography:add_bibliography_year_suffix(ir, engine)
  if not ir.reference.year_suffix_number then
    return
  end

  if not ir.year_suffix_irs then
    ir.year_suffix_irs = ir:collect_year_suffix_irs()
    if #ir.year_suffix_irs == 0 then
      local year_ir = ir:find_first_year_ir()
      if year_ir then
        local year_suffix_ir = YearSuffix:new({}, engine.style.citation)
        table.insert(year_ir.children, year_suffix_ir)
        table.insert(ir.year_suffix_irs, year_suffix_ir)
      end
    end
  end

  for _, year_suffix_ir in ipairs(ir.year_suffix_irs) do
    year_suffix_ir.inlines = {PlainText:new(ir.reference["year-suffix"])}
    year_suffix_ir.group_var = GroupVar.Important
  end
end


bibliography_module.Bibliography = Bibliography


return bibliography_module
