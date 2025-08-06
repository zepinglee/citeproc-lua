--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local text_module = {}

local element
local ir_node
local output
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  element = require("citeproc-element")
  ir_node = require("citeproc-ir-node")
  output = require("citeproc-output")
  util = require("citeproc-util")
else
  element = require("citeproc.element")
  ir_node = require("citeproc.ir-node")
  output = require("citeproc.output")
  util = require("citeproc.util")
end

local Element = element.Element
local Rendered = ir_node.Rendered
local SeqIr = ir_node.SeqIr
local YearSuffix = ir_node.YearSuffix
local GroupVar = ir_node.GroupVar
local PlainText = output.PlainText
local Linked = output.Linked


-- [Text](https://docs.citationstyles.org/en/stable/specification.html#text)
---@class Text: Element
---@field variable string?
---@field form string?
---@field macro string?
---@field term string?
---@field plural string?
---@field value string?
---@field prefix string?
---@field suffix string?
---@field display string?
---@field quotes boolean?
---@field strip_periods string?
---@field text_case string?
local Text = Element:derive("text", {
  -- Default attributes
  variable = nil,
  form = "long",
  macro = nil,
  term = nil,
  plural = false,
  value = nil,
  -- Style behavior
  formatting = nil,
  affixes = nil,
  display = nil,
  quotes = false,
  strip_periods = false,
  text_case = nil,
})

function Text:from_node(node)
  local o = Text:new()
  o:set_attribute(node, "variable")
  o:set_attribute(node, "form")
  o:set_attribute(node, "macro")
  o:set_attribute(node, "term")
  o:set_bool_attribute(node, "plural")
  o:set_attribute(node, "value")

  o:set_formatting_attributes(node)
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_quotes_attribute(node)
  o:set_strip_periods_attribute(node)
  o:set_text_case_attribute(node)
  -- `apa-annotated-bibliography.csl` uses `display="block"` for annotation.
  -- Use display="indent" instead
  if o.display == "block" and (o.variable == "note" or o.variable == "abstract") then
    o.display = "indent"
  end
  return o
end

function Text:build_ir(engine, state, context)
  local ir = nil
  if self.variable then
    ir = self:build_variable_ir(engine, state, context)
  elseif self.macro then
    ir = self:build_macro_ir(engine, state, context)
  elseif self.term then
    ir = self:build_term_ir(engine, state, context)
  elseif self.value then
    ir = self:build_value_ir(engine, state, context)
  end
  return ir
end

function Text:build_variable_ir(engine, state, context)
  ---@type string
  local variable = self.variable
  local text

  if variable == "year-suffix" then
    return self:build_year_suffix_ir(engine, state, context)
  elseif variable == "citation-label" then
    return self:build_citation_label_ir(engine, state, context)
  end

  if not state.suppressed[variable] then
    text = context:get_variable(variable, self.form)
    ---@case text string | number?
  end

  if not text or text == "" then
    local ir = Rendered:new({}, self)
    ir.group_var = GroupVar.Missing
    return ir
  end
  if type(text) == "number" then
    text = tostring(text)
  end
  if util.variable_types[variable] == "number" then
    text = self:format_number(text, variable, "numeric", context)
  end

  local inlines
  -- if not engine.opt then
  --   print(debug.traceback())
  -- end
  -- if engine.opt.wrap_url_and_doi and (variable == "URL" or variable == "DOI" or
  --     variable == "PMID" or variable == "PMID") then
  if variable == "URL" or variable == "DOI" or variable == "PMID" or variable == "PMCID" then
    inlines = self:render_linked(engine, state, context, variable, text)
  else
    inlines = self:render_text_inlines(text, context)
  end

  local ir = Rendered:new(inlines, self)
  ir.group_var = GroupVar.Important

  if variable == "citation-number" then
    ir.citation_number = context.reference["citation-number"]
  end

  -- Suppress substituted name variable
  if state.name_override and not context.sort_key then
    state.suppressed[variable] = true
  end

  return ir
end

function Text:render_linked(engine, state, context, variable, text)
  local href
  local url_prefix = false  -- The prefix is used as part of the URL.
  if variable == "URL" then
    href = text
  elseif self.affixes and self.affixes.prefix and string.match(self.affixes.prefix, "https?://") then
    text = self.affixes.prefix .. text
    href = text
    url_prefix = true
  elseif variable == "DOI" then
    href = "https://doi.org/" .. text
  elseif variable == "PMID" then
    href = "https://www.ncbi.nlm.nih.gov/pubmed/" .. text
  elseif variable == "PMCID" then
    href = "https://www.ncbi.nlm.nih.gov/pmc/articles/" .. text
  end

  local inlines = {Linked:new(text, href)}
  local output_format = context.format
  local localized_quotes = nil
  if self.quotes then
    localized_quotes = context:get_localized_quotes()
  end
  inlines = output_format:with_format(inlines, self.formatting)
  inlines = output_format:affixed_quoted(inlines, self.affixes, localized_quotes)
  if url_prefix then
    table.remove(inlines, 1)
  end
  return output_format:with_display(inlines, self.display)
end

function Text:build_year_suffix_ir(engine, state, context)
  local text = context:get_variable(self.variable, self.form)
  local group_var
  if text then
    group_var = GroupVar.Important
  else
    text = ""
    group_var = GroupVar.Missing
  end

  local ir = YearSuffix:new({PlainText:new(text)}, self)
  ir.group_var = group_var
  ir.affixes = util.clone(self.affixes)
  ir.display = self.display
  if self.display == "left-margin" then
    engine.registry.second_field_align = "flush"
  end
  ir.formatting = util.clone(self.formatting)
  if self.quotes then
    ir.quotes = context:get_localized_quotes()
  end
  return ir
end

function Text:build_citation_label_ir(engine, state, context)
  local text = context:get_variable(self.variable, self.form)
  local group_var
  if text then
    group_var = GroupVar.Important
  else
    text = ""
    group_var = GroupVar.Missing
  end

  local ir = Rendered:new({PlainText:new(text)}, self)
  -- The citation-label may have a year-suffix
  ir = SeqIr:new({ir}, self)
  ir.group_var = group_var
  ir.affixes = util.clone(self.affixes)
  ir.display = self.display
  ir.formatting = util.clone(self.formatting)
  if self.quotes then
    ir.quotes = context:get_localized_quotes()
  end

  ir.is_year = true
  return ir
end

function Text:build_macro_ir(engine, state, context)
  ---@type Macro
  local macro = context:get_macro(self.macro)
  if not macro then
    util.error(string.format("Macro '%s' not found", self.macro))
    return nil
  end
  state:push_macro(self.macro)
  local ir = macro:build_ir(engine, state, context)
  state:pop_macro(self.macro)
  if ir then
    ir.affixes = util.clone(self.affixes)
    ir.display = self.display
    ir.formatting = util.clone(self.formatting)
    if self.quotes then
      ir.quotes = context:get_localized_quotes()
    end
  end
  return ir
end

function Text:build_term_ir(engine, state, context)
  local str = context:get_simple_term(self.term, self.form, self.plural)
  if not str then
    return nil
  end
  local inlines = self:render_text_inlines(str, context)
  return Rendered:new(inlines, self)
end

function Text:build_value_ir(engine, state, context)
  local inlines = self:render_text_inlines(self.value, context)
  return Rendered:new(inlines, self)
end


text_module.Text = Text

return text_module
