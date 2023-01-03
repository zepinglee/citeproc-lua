--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local date_module = {}

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local Rendered = require("citeproc-ir-node").Rendered
local SeqIr = require("citeproc-ir-node").SeqIr
local PlainText = require("citeproc-output").PlainText
local util = require("citeproc-util")


-- [Date](https://docs.citationstyles.org/en/stable/specification.html#date)
local Date = Element:derive("date")

function Date:from_node(node)
  local o = Date:new()

  o:set_attribute(node, "variable")
  o:set_attribute(node, "form")
  o:set_attribute(node, "date-parts")

  if o.form and not o.date_parts then
    o.date_parts = "year-month-day"
  end

  o:get_delimiter_attribute(node)
  o:set_formatting_attributes(node)
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_text_case_attribute(node)

  o.children = {}
  o:process_children_nodes(node)

  for _, date_part in ipairs(o.children) do
    o[date_part.name] = date_part
  end

  return o
end

function Date:build_ir(engine, state, context)
  local variable
  if not state.suppressed[self.variable] then
    variable = context:get_variable(self.variable)
  end

  if not variable then
    local ir = Rendered:new({}, self)
    ir.group_var = "missing"
    return ir
  end

  local ir

  if variable["date-parts"] and #variable["date-parts"] > 0 then

    -- TODO: move input normlization in one place
    for i = 1, 2 do
      if variable["date-parts"][i] then
        for j = 1, 3 do
          local variabel_part = variable["date-parts"][i][j]
          if variabel_part == 0 or variabel_part == "" then
            variable["date-parts"][i][j] = nil
          else
            variable["date-parts"][i][j] = tonumber(variabel_part)
          end
        end
      end
    end
    if variable["season"] and not variable["date-parts"][1][2] then
      variable["date-parts"][1][2] = 20 + tonumber(variable["season"])
    end

    variable = variable["date-parts"]
    if self.form then
      ir = self:build_localized_date_ir(variable, engine, state, context)
    else
      ir = self:build_independent_date_ir(variable, engine, state, context)
    end
    ir.affixes = self.affixes

  elseif variable["literal"] then
    local inlines = self:render_text_inlines(variable["literal"], context)
    ir = Rendered:new(inlines, self)
    ir.group_var = "important"

  elseif variable["raw"] then
    local inlines = self:render_text_inlines(variable["raw"], context)
    ir = Rendered:new(inlines, self)
    ir.group_var = "important"

  end

  if not ir then
    -- date_LiteralFailGracefullyIfNoValue.txt
    ir = Rendered:new({}, self)
    if context.sort_key then
      ir.sort_key = false
    end
    ir.group_var = "missing"
    return ir
  end

  if ir.group_var == "important" then
    -- Suppress substituted name variable
    if state.name_override and not context.sort_key then
      state.suppressed[self.variable] = true
    end
  end

  if context.sort_key then
    ir.sort_key = self:render_sort_key(engine, state, context)
  end

  return ir
end

function Date:build_independent_date_ir(variable, engine, state, context)
  -- else
  --   local literal = variable["literal"]
  --   if literal then
  --     res = literal
  --   else
  --     local raw = variable["raw"]
  --     if raw then
  --       res = raw
  --     end
  --   end

  return self:build_date_parts(self.children, variable, self.delimiter, engine, state, context)
end

function Date:build_localized_date_ir(variable, engine, state, context)
  local date_part_mask = {}
  for _, part in ipairs(util.split(self.date_parts or "year-month-day", "%-")) do
    date_part_mask[part] = true
  end
  -- local date_parts = {}
  -- for _, date_part in ipairs(self.children) do
  --   date_parts[date_part.name] = date_part
  -- end
  local localized_date = context:get_localized_date(self.form)
  local date_parts = {}
  for _, date_part in ipairs(localized_date.children) do
    if date_part_mask[date_part.name] then
      date_part = date_part:copy()
      local local_date_part = self[date_part.name]
      if local_date_part then
        local_date_part:override(date_part)
      end
      table.insert(date_parts, date_part)
    end
  end
  return self:build_date_parts(date_parts, variable, localized_date.delimiter, engine, state, context)
end

function Date:build_date_parts(date_parts, variable, delimiter, engine, state, context)
  if #variable >= 2 then
    return self:build_date_range(date_parts, variable, delimiter, engine, state, context)
  elseif #variable == 1 then
    return self:build_single_date(date_parts, variable[1], delimiter, engine, state, context)
  end
end

function Date:build_single_date(date_parts, single_date, delimiter, engine, state, context)
  local irs = {}
  for _, date_part in ipairs(date_parts) do
    local part_ir = date_part:build_ir(single_date, engine, state, context)
    table.insert(irs, part_ir)
  end

  local ir = SeqIr:new(irs, self)
  ir.delimiter = self.delimiter

  -- return Rendered:new(inlines, self)
  return ir
end

local date_part_index = {
  year = 1,
  month = 2,
  day = 3,
}

function Date:build_date_range(date_parts, variable, delimiter, engine, state, context)
  local first, second = variable[1], variable[2]
  local diff_level = 4
  for _, date_part in ipairs(date_parts) do
    local part_index = date_part_index[date_part.name]
    if first[part_index] and first[part_index] ~= second[part_index] then
      if part_index < diff_level then
        diff_level = part_index
      end
    end
  end

  local irs = {}

  local range_part_queue = {}
  local range_delimiter
  for i, date_part in ipairs(date_parts) do
    local part_index = date_part_index[date_part.name]
    if part_index == diff_level then
      range_delimiter = date_part.range_delimiter or util.unicode["en dash"]
    end
    if first[part_index] then
      if part_index >= diff_level then
        table.insert(range_part_queue, date_part)
      else
        if #range_part_queue > 0 then
          table.insert(irs, self:build_date_range_parts(range_part_queue, variable,
              delimiter, engine, state, context, range_delimiter))
          range_part_queue = {}
        end
        table.insert(irs, date_part:build_ir(first, engine, state, context))
      end
    end
  end
  if #range_part_queue > 0 then
    table.insert(irs, self:build_date_range_parts(range_part_queue, variable,
    delimiter, engine, state, context, range_delimiter))
  end

  local ir = SeqIr:new(irs, self)
  ir.delimiter = delimiter

  return ir
end

function Date:build_date_range_parts(range_part_queue, variable, delimiter, engine, state, context, range_delimiter)
  local irs = {}
  local first, second = variable[1], variable[2]

  local date_part_irs = {}
  for i, diff_part in ipairs(range_part_queue) do
    -- if delimiter and i > 1 then
    --   table.insert(date_part_irs, PlainText:new(delimiter))
    -- end
    if i == #range_part_queue then
      table.insert(date_part_irs, diff_part:build_ir(first, engine, state, context, "suffix"))
    else
      table.insert(date_part_irs, diff_part:build_ir(first, engine, state, context))
    end
  end
  local range_part_ir = SeqIr:new(date_part_irs, self)
  range_part_ir.delimiter = delimiter
  table.insert(irs, range_part_ir)

  table.insert(irs, Rendered:new({PlainText:new(range_delimiter)}, self))

  date_part_irs = {}
  for i, diff_part in ipairs(range_part_queue) do
    if i == 1 then
      table.insert(date_part_irs, diff_part:build_ir(second, engine, state, context, "prefix"))
    else
      table.insert(date_part_irs, diff_part:build_ir(second, engine, state, context))
    end
  end
  range_part_ir = SeqIr:new(date_part_irs, self)
  range_part_ir.delimiter = delimiter
  table.insert(irs, range_part_ir)

  local ir = SeqIr:new(irs, self)

  return ir
end

function Date:render_sort_key(engine, state, context)
  local date = context:get_variable(self.variable)
  if not date then
    return false
  end
  if not date["date-parts"] then
    if self.literal then
      return "1" .. self.literal
    else
      return false
    end
  end

  local show_parts = {
    year = false,
    month = false,
    day = false,
  }
  if self.form then
    for _, dp_name in ipairs(util.split(self.date_parts, "%-")) do
      show_parts[dp_name] = true
    end
  else
    for _, date_part in ipairs(self.children) do
      show_parts[date_part.name] = true
    end
  end
  local res = ""
  for _, range_part in ipairs(date["date-parts"]) do
    if res ~= "" then
      res = res .. "/"
    end
    for i, dp_name in ipairs({"year", "month", "day"}) do
      local value = 0
      if show_parts[dp_name] and range_part[i] then
        value = range_part[i]
      end
      if i == 1 then
        res = res .. string.format("%05d", value + 10000)
      else
        res = res .. "-" .. string.format("%02d", value)
      end
    end
  end
  return res
end


-- [Date-part](https://docs.citationstyles.org/en/stable/specification.html#date-part)
local DatePart = Element:derive("date-part")

function DatePart:from_node(node)
  local o = DatePart:new()
  o:set_attribute(node, "name")
  o:set_attribute(node, "form")
  if o.name == "month" then
    o:set_strip_periods_attribute(node)
  end
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  o:set_attribute(node, "range-delimiter")
  o:set_affixes_attributes(node)
  return o
end

function DatePart:build_ir(single_date, engine, state, context, suppressed_affix)
  local text
  if self.name == "year" then
    text = self:render_year(single_date[1], engine, state, context)
  elseif self.name == "month" then
    text = self:render_month(single_date[2], engine, state, context)
  elseif self.name == "day" then
    text = self:render_day(single_date[3], single_date[2], engine, state, context)
  end

  if not text then
    local ir = Rendered:new({}, self)
    ir.group_var = "missing"
    return ir
  end

  local inlines = {PlainText:new(text)}
  local output_format = context.format
  -- if not context.is_english then
  --   print(debug.traceback())
  -- end
  local is_english = context:is_english()
  output_format:apply_text_case(inlines, self.text_case, is_english)
  inlines = output_format:with_format(inlines, self.formatting)

  local ir = Rendered:new(inlines, self)
  ir.group_var = "important"

  if self.name == "year" then
    ir = SeqIr:new({ir}, self)
    ir.is_year = true
  end

  ir.affixes = util.clone(self.affixes)
  if ir.affixes and suppressed_affix then
    ir.affixes[suppressed_affix] = nil
  end

  return ir
end

function DatePart:render_day(day, month, engine, state, context)
  if not day or day == "" then
    return nil
  end
  day = tonumber(day)
  if day < 1 or day > 31 then
    return nil
  end
  local form = self.form or "numeric"
  if form == "ordinal" then
    local limit_day_1 = context.locale.style_options.limit_day_ordinals_to_day_1
    if limit_day_1 and day > 1 then
      form = "numeric"
    end
  end
  if form == "numeric-leading-zeros" then
    return string.format("%02d", day)
  elseif form == "ordinal" then
    -- When the “day” date-part is rendered in the “ordinal” form, the ordinal
    -- gender is matched against that of the month term.
    local gender = context.locale:get_number_gender(string.format("month-%02d", month))
    local suffix = context.locale:get_ordinal_term(day, gender)
    return tostring(day) .. suffix
  else  -- numeric
    return tostring(day)
  end
end

function DatePart:render_month(month, engine, state, context)
  if not month or month == "" then
    return nil
  end
  month = tonumber(month)
  if not month or month < 1 or month > 24 then
    return nil
  end
  local form = self.form or "long"
  local res
  if form == "long" or form == "short" then
    if month >= 1 and month <= 12 then
      res = context:get_simple_term(string.format("month-%02d", month), form)
    else
      local season = month % 4
      if season == 0 then
        season = 4
      end
      res = context:get_simple_term(string.format("season-%02d", season))
    end
  elseif form == "numeric-leading-zeros" then
    res = string.format("%02d", month)
  else
    res = tostring(month)
  end
  return self:apply_strip_periods(res)
end

function DatePart:render_year(year, engine, state, context)
  if not year or year == "" then
    return nil
  end
  year = tonumber(year)
  if year == 0 then
    return nil
  end
  local form = self.form or "long"
  if form == "long" then
    if year < 0 then
      return tostring(-year) .. context:get_simple_term("bc")
    elseif year < 1000 then
      return tostring(year) .. context:get_simple_term("ad")
    else
      return tostring(year)
    end
  elseif form == "short" then
    return string.sub(tostring(year), -2)
  end
end

function DatePart:copy()
  local o = {}
  for key, value in pairs(self) do
    if type(value) == "table" then
      o[key] = {}
      for k, v in pairs(value) do
        o[key][k] = v
      end
    else
      o[key] = value
    end
  end
  setmetatable(o, DatePart)
  return o
end

function DatePart:override(localized_date_part)
  for key, value in pairs(self) do
    if type(value) == "table" and localized_date_part[key] then
      for k, v in pairs(value) do
        localized_date_part[key][k] = v
      end
    else
      localized_date_part[key] = value
    end
  end
end


date_module.Date = Date
date_module.DatePart = DatePart

return date_module
