--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local text_module = {}

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-richtext").IrNode
local richtext = require("citeproc-richtext")
local util = require("citeproc-util")

-- [Text](https://docs.citationstyles.org/en/stable/specification.html#text)
local Text = Element:derive("text")
Text.variable = nil
Text.form = "long"
Text.macro = nil
Text.term = nil
Text.plural = false
Text.value = nil
-- Style behavior
Text.font_style = nil
Text.font_variant = nil
Text.font_weight = nil
Text.text_decoration = nil
Text.vertical_align = nil
Text.prefix = nil
Text.suffix = nil
Text.delimiter = nil
Text.display = nil
Text.quotes = false
Text.strip_periods = false
Text.text_case = nil

function Text:from_node(node)
  local o = Text:new()
  o.variable = node:get_attribute("variable")
  o.form = node:get_attribute("form")
  o.macro = node:get_attribute("macro")
  o.term = node:get_attribute("term")
  o.plural = util.to_boolean(node:get_attribute("plural"))
  o.value = node:get_attribute("value")

  o:get_formatting_attributes(node)
  o:get_affixes_attributes(node)
  o:get_display_attribute(node)
  o:get_quotes_attribute(node)
  o:get_strip_periods_attribute(node)
  o:get_text_case_attribute(node)
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
  ir = self:_apply_formatting(ir)
  ir = self:_apply_quotes(ir)
  ir = self:_apply_affixes(ir)
  ir = self:_apply_display(ir)
  return ir
end

function Text:build_variable_ir(engine, state, context)
  local value = context:get_variable(self.name, self.form)
  if not value then
    return nil
  end

  if type(value) == "number" then
    value = tostring(value)
  end
  -- if self.name == "page" or self.name == "locator" then
  --   value = util.lstrip(value)
  --   value = self:_format_page(value, context)
  -- end
  value = self._apply_strip_periods(value)
  value = self._apply_text_case(value)

  return IrNode:new("text", value)
end

function Text:build_macro_ir(engine, state, context)
  local macro = context:get_macro(self.macro)
  state:push_macro(self.macro)
  local res = macro:build_ir(engine, state, context)
  state:push_macro(self.macro)
  return res
end

function Text:build_term_ir(engine, state, context)
  local term = context:get_term(self.term, self.form, self.plural)
  -- assert(type(term) == "string")
  term = self._apply_strip_periods(term)
  term = self._apply_text_case(term)
  return IrNode:new("text", term)
end

function Text:build_value_ir(engine, state, context)
  local value = self.value
  value = self._apply_strip_periods(value)
  value = self._apply_text_case(value)
  return IrNode:new("text", value)
end

function Text:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local res = nil

  local variable = nil
  local variable_name = self:get_attribute("variable")
  if variable_name then
    local form = self:get_attribute("form")
    if form == "short" then
      variable = self:get_variable(item, variable_name  .. "-" .. form, context)
    end
    if not variable then
      variable = self:get_variable(item, variable_name, context)
    end
    if variable then
      res = variable
      if type(res) == "number" then
        res = tostring(res)
      end
      if variable_name == "page" or variable_name == "locator" then
        res = util.lstrip(res)
        res = self:_format_page(res, context)
      end
    end

    table.insert(context.variable_attempt, res ~= nil)
  end

  local macro_name = self:get_attribute("macro")
  if macro_name then
    local macro = self:get_macro(macro_name)
    res = macro:render(item, context)
  end

  local term_name = self:get_attribute("term")
  if term_name then
    local form = self:get_attribute("form")

    local term = self:get_term(term_name, form)
    if term then
      res = term:render(context)
    end
  end

  local value = self:get_attribute("value")
  if value then
    res = value
    res = self:escape(res)
  end

  if type(res) == "string" and res ~= "" then
    res = richtext.new(res)
  end

  if res and variable_name == "URL" then
    res:add_format("URL", "true")
  end

  res = self:apply_strip_periods(res, context)
  res = self:case(res, context)
  res = self:format(res, context)
  res = self:quote(res, context)
  res = self:wrap(res, context)
  res = self:display(res, context)

  if variable_name == "citation-number" then
    res = self:_process_citation_number(variable, res, context)
  end

  return res
end


function Text:_process_citation_number(citation_number, res, context)
  if context.mode == "citation" and not context.sorting and context.options["collapse"] == "citation-number" then
    context.build.item_citation_numbers[context.item.id] = citation_number
    if type(res) == "string" then
      res = richtext.new(res)
    end
    table.insert(context.build.item_citation_number_text, res)
  end
  return res
end


function Text:_format_page (page, context)
  local res = nil

  local page_range_delimiter = self:get_term("page-range-delimiter"):render(context) or util.unicode["en dash"]
  local page_range_format = context.options["page-range-format"]
  if page_range_format == "chicago" then
    if self:get_style():get_version() >= "1.1" then
      page_range_format = "chicago-16"
    else
      page_range_format = "chicago-15"
    end
  end

  local last_position = 1
  local page_parts = {}
  local punct_list = {}
  for part, punct, pos in string.gmatch(page, "(.-)%s*([,&])%s*()") do
    table.insert(page_parts, part)
    table.insert(punct_list, punct)
    last_position = pos
  end
  table.insert(page_parts, string.sub(page, last_position))

  res = ""
  for i, part in ipairs(page_parts) do
    res = res .. self:_format_range(part, page_range_format, page_range_delimiter)
    local punct = punct_list[i]
    if punct then
      if punct == "&" then
        res = res .. " " .. punct .. " "
      else
        res = res .. punct .. " "
      end
    end
  end
  res = self:escape(res)
  return res
end

function Text:_format_range (str, format, range_delimiter)
  local start, delimiter, stop = string.match(str, "(%w+)%s*(%-+)%s*(%S*)")
  if not stop or stop == "" then
    return string.gsub(str, "\\%-", "-")
  end


  local start_prefix, start_num  = string.match(start, "(.-)(%d*)$")
  local stop_prefix, stop_num = string.match(stop, "(.-)(%d*)$")

  if start_prefix ~= stop_prefix then
    -- Not valid range: "n11564-1568" -> "n11564-1568"
    -- 110-N6
    -- N110-P5
    return start .. delimiter .. stop
  end

  if format == "chicago-16" then
    stop = self:_format_range_chicago_16(start_num, stop_num)
  elseif format == "chicago-15" then
    stop = self:_format_range_chicago_15(start_num, stop_num)
  elseif format == "expanded" then
    stop = stop_prefix .. self:_format_range_expanded(start_num, stop_num)
  elseif format == "minimal" then
    stop = self:_format_range_minimal(start_num, stop_num)
  elseif format == "minimal-two" then
    stop = self:_format_range_minimal(start_num, stop_num, 2)
  end

  return start .. range_delimiter .. stop
end

function Text:_format_range_chicago_16(start, stop)
  if #start < 3 or string.sub(start, -2) == "00" then
    return self:_format_range_expanded(start, stop)
  elseif string.sub(start, -2, -2) == "0" then
    return self:_format_range_minimal(start, stop)
  else
    return self:_format_range_minimal(start, stop, 2)
  end
  return stop
end

function Text:_format_range_chicago_15(start, stop)
  if #start < 3 or string.sub(start, -2) == "00" then
    return self:_format_range_expanded(start, stop)
  else
    local changed_digits = self:_format_range_minimal(start, stop)
    if string.sub(start, -2, -2) == "0" then
      return changed_digits
    elseif #start == 4 and #changed_digits == 3 then
      return self:_format_range_expanded(start, stop)
    else
      return self:_format_range_minimal(start, stop, 2)
    end
  end
  return stop
end

function Text:_format_range_expanded(start, stop)
  -- Expand  "1234–56" -> "1234–1256"
  if #start <= #stop then
    return stop
  end
  return string.sub(start, 1, #start - #stop) .. stop
end

function Text:_format_range_minimal(start, stop, threshold)
  threshold = threshold or 1
  if #start < #stop then
    return stop
  end
  local offset = #start - #stop
  for i = 1, #stop - threshold do
    local j = i + offset
    if string.sub(stop, i, i) ~= string.sub(start, j, j) then
      return string.sub(stop, i)
    end
  end
  return string.sub(stop, -threshold)
end


text_module.Text = Text

return text_module
