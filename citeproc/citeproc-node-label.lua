--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local label = {}

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local Rendered = require("citeproc-ir-node").Rendered
local PlainText = require("citeproc-output").PlainText
local util = require("citeproc-util")


-- [Label](https://docs.citationstyles.org/en/stable/specification.html#label)
local Label = Element:derive("label")

Label.form = "long"
Label.plural = "contextual"

function Label:from_node(node)
  local o = Label:new()
  o:set_attribute(node, "variable")
  o:set_attribute(node, "form")
  o:set_attribute(node, "plural")
  o:set_affixes_attributes(node)
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  o:set_strip_periods_attribute(node)
  return o
end

function Label:build_ir(engine, state, context)
  -- local variable = context:get_variable(self.variable, self.form)

  local is_plural = false
  if self.plural == "always" then
    is_plural = true
  elseif self.plural == "never" then
    is_plural = false
  elseif self.plural == "contextual" then
    is_plural = self:_is_variable_plural(self.variable, context)
  end

  local variable = self.variable
  if variable == "locator" then
    variable = context:get_variable("label") or "page"
    if variable == "sub verbo" then
      -- bugreports_MovePunctuationInsideQuotesForLocator.txt
      variable = "sub-verbo"
    end
  end
  local text = context:get_simple_term(variable, self.form, is_plural)
  if not text or text == "" then
    return nil
  end

  local inlines = self:render_text_inlines(text, context)
  return Rendered:new(inlines, self)
end

function Label:_is_variable_plural(variable, context)
  local value = context:get_variable(variable)
  if not value then
    return false
  end
  local variable_type = util.variable_types[variable]
  if variable_type == "name" then
    return #variable > 1
  elseif variable_type == "number" then
    if util.startswith(variable, "number-of-") then
      -- Issue #27: "number-of-pages": "91–129"
      value = string.match(tostring(value), "%d+")
      return value and tonumber(value) > 1
    else
      value = tostring(value)
      -- label_CollapsedPageNumberPluralDetection.txt
      -- 327\-30 => single
      value = string.gsub(value, "\\%-", "")
      if string.match(value, "[,&-]") then
        return true
      elseif string.match(value, util.unicode["en dash"]) then
        return true
      elseif string.match(value, "%Wand%W") then
        return true
      elseif string.match(value, "%Wet%W") then
        return true
      end
    end
  end
  return false
end


label.Label = Label

return label
