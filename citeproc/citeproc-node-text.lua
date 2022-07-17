--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local text_module = {}

local Element = require("citeproc-element").Element
local Rendered = require("citeproc-ir-node").Rendered
local YearSuffix = require("citeproc-ir-node").YearSuffix
local PlainText = require("citeproc-output").PlainText
local util = require("citeproc-util")


-- [Text](https://docs.citationstyles.org/en/stable/specification.html#text)
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
  delimiter = nil,
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
  local variable = self.variable
  local text

  if variable == "year-suffix" then
    return self:build_year_suffix_ir(engine, state, context)
  end

  if not state.suppressed[variable] then
    text = context:get_variable(variable, self.form)
  end

  if not text then
    local ir = Rendered:new({}, self)
    ir.group_var = "missing"
    return ir
  end
  if type(text) == "number" then
    text = tostring(text)
  end
  if util.variable_types[variable] == "number" then
    text = self:format_number(text, variable, "numeric", context)
  end

  -- util.debug(text)
  local inlines = self:render_text_inlines(text, context)
  local ir = Rendered:new(inlines, self)
  ir.group_var = "important"

  if variable == "citation-number" then
    ir.citation_number = context.reference["citation-number"]
  end

  -- Suppress substituted name variable
  if state.name_override and not context.sort_key then
    state.suppressed[variable] = true
  end

  return ir
end

function Text:build_year_suffix_ir(engine, state, context)
  local text = context:get_variable(self.variable, self.form)
  local group_var
  if text then
    group_var = "important"
  else
    text = ""
    group_var = "missing"
  end

  local ir = YearSuffix:new({PlainText:new(text)}, self)
  ir.group_var = group_var
  ir.affixes = util.clone(self.affixes)
  ir.display = self.display
  ir.formatting = util.clone(self.formatting)
  if self.quotes then
    ir.quotes = context:get_localized_quotes()
  end
  return ir
end

function Text:build_macro_ir(engine, state, context)
  local macro = context:get_macro(self.macro)
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
