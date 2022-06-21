--
-- Copyright (c) 2021-2022 Zeping Lee
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
  local variable = context:get_variable(self.variable)

  if not variable then
    local ir = Rendered:new()
    ir.group_var = "missing"
    return ir
  end

  local ir

  if variable["date-parts"] and #variable["date-parts"] > 0 then

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
    ir.group_var = "important"

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
    ir = Rendered:new()
    ir.group_var = "missing"
    return ir
  end

  ir.affixes = self.affixes

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

  return self:build_date_parts(self.children, variable, engine, state, context)
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
  return self:build_date_parts(date_parts, variable, engine, state, context)
end

function Date:build_date_parts(date_parts, variable, engine, state, context)
  if #variable >= 2 then
    return self:build_date_range(date_parts, variable, engine, state, context)
  elseif #variable == 1 then
    return self:build_single_date(date_parts, variable[1], engine, state, context)
  end
end

function Date:build_single_date(date_parts, single_date, engine, state, context)
  local irs = {}
  for _, date_part in ipairs(date_parts) do
    local ir = date_part:build_ir(single_date, engine, state, context)
    table.insert(irs, ir)
  end
  return SeqIr:new(irs)
end

local date_part_index = {
  year = 1,
  month = 2,
  day = 3,
}

function Date:build_date_range(date_parts, variable, engine, state, context)
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
  for _, date_part in ipairs(date_parts) do
    local part_index = date_part_index[date_part.name]
    if part_index == diff_level then
      range_delimiter = date_part.range_delimiter or util.unicode["en dash"]
    end
    if first[part_index] then
      if part_index >= diff_level then
        table.insert(range_part_queue, date_part)
      else
        if #range_part_queue > 0 then
          for _, ir in ipairs(self:build_date_range_irs(range_part_queue, variable,
              engine, state, context, range_delimiter)) do
            table.insert(irs, ir)
          end
          range_part_queue = {}
        end
        table.insert(irs, date_part:build_ir(first, engine, state, context))
      end
    end
  end
  if #range_part_queue > 0 then
    for _, ir in ipairs(self:build_date_range_irs(range_part_queue, variable,
        engine, state, context, range_delimiter)) do
      table.insert(irs, ir)
    end
  end
  return SeqIr:new(irs)
end

function Date:build_date_range_irs(range_part_queue, variable, engine, state, context, range_delimiter)
  local first, second = variable[1], variable[2]
  local irs = {}
  for i, diff_part in ipairs(range_part_queue) do
    if i == #range_part_queue then
      table.insert(irs, diff_part:build_ir(first, engine, state, context, "suffix"))
    else
      table.insert(irs, diff_part:build_ir(first, engine, state, context))
    end
  end
  table.insert(irs, Rendered:new({PlainText:new(range_delimiter)}, self))
  for i, diff_part in ipairs(range_part_queue) do
    if i == 1 then
      table.insert(irs, diff_part:build_ir(second, engine, state, context, "prefix"))
    else
      table.insert(irs, diff_part:build_ir(second, engine, state, context))
    end
  end
  return irs
end

function Date:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  if context.sorting then
    return self:render_sort_key(item, context)
  end

  local variable_name = context.options["variable"]

  local is_locale_date
  if variable_name then
    context.variable = variable_name
    is_locale_date = false
  else
    variable_name = context.variable
    is_locale_date = true
  end

  local date = self:get_variable(item, variable_name, context)
  if not date then
    return nil
  end

  local res = nil
  local form = context.options["form"]
  if form and not is_locale_date then
    for _, date_part in ipairs(self:query_selector("date-part")) do
      local name = date_part:get_attribute("name")
      if not context.date_part_attributes then
        context.date_part_attributes = {}
      end
      if not context.date_part_attributes[name] then
        context.date_part_attributes[name] = {}
      end

      for attr, value in pairs(date_part._attr) do
        if attr ~= name then
          context.date_part_attributes[name][attr] = value
        end
      end
    end
    res = self:get_locale_date(context, form):render(item, context)
  else
    if not date["date-parts"] or #date["date-parts"] == 0 then
      local literal = date["literal"]
      if literal then
        res = literal
      else
        local raw = date["raw"]
        if raw then
          res = raw
        end
      end

    else
      if #date["date-parts"] == 1 then
        res = self:_render_single_date(date, context)
      elseif #date["date-parts"] == 2 then
        res = self:_render_date_range(date, context)
      end
    end
  end

  table.insert(context.variable_attempt, res ~= nil)

  res = self:_apply_format(res, context)
  res = self:_apply_affixes(res, context)
  return res
end

function Date:get_locale_date(context, form)
  local date = nil
  local style = context.style
  local query = string.format("date[form=\"%s\"]", form)
  for _, locale in ipairs(style:get_locales()) do
    date = locale:query_selector(query)[1]
    if date then
      break
    end
  end
  if not date then
    error(string.format("Failed to find '%s'", query))
  end
  return date
end

function Date:render_sort_key (item, context)
  local variable_name = context.options["variable"]
  local date = self:get_variable(item, variable_name, context)
  if not date or not date["date-parts"] then
    return nil
  end
  local show_parts = {
    year = false,
    month = false,
    day = false,
  }
  if self:get_attribute("form") then
    local date_parts = self:get_attribute("date-parts") or "year-month-day"
    for _, dp_name in ipairs(util.split(date_parts, "%-")) do
      show_parts[dp_name] = true
    end
  else
    for _, child in ipairs(self:query_selector("date-part")) do
      show_parts[child:get_attribute("name")] = true
    end
  end
  local res = ""
  for _, date_parts in ipairs(date["date-parts"]) do
    for i, dp_name in ipairs({"year", "month", "day"}) do
      local value = date_parts[i]
      if not value or not show_parts[dp_name] then
        value = 0
      end
      if i == 1 then
        res = res .. string.format("%05d", value + 10000)
      else
        res = res .. string.format("%02d", value)
      end
    end
  end
  return res
end

function Date:_render_single_date(date, context)
  local show_parts = self:_get_show_parts(context)

  local output = {}
  for _, child in ipairs(self:query_selector("date-part")) do
    if show_parts[child:get_attribute("name")] then
      table.insert(output, child:render(date, context))
    end
  end
  return self:concat(output, context)
end

function Date:_render_date_range(date, context)
  local show_parts = self:_get_show_parts(context)
  local part_index = {}

  local largest_diff_part = nil
  for i, name in ipairs({"year", "month", "day"}) do
    part_index[name] = i
    local part_value1 = date["date-parts"][1][i]
    if show_parts[name] and part_value1 then
      if not largest_diff_part then
        largest_diff_part = name
      end
    end
  end

  local date_parts = {}
  for _, date_part in ipairs(self:query_selector("date-part")) do
    if show_parts[date_part:get_attribute("name")] then
      table.insert(date_parts, date_part)
    end
  end

  local diff_begin = 0
  local diff_end = #date_parts
  local range_delimiter = nil

  for i, date_part in ipairs(date_parts) do
    local name = date_part:get_attribute("name")
    if name == largest_diff_part then
      range_delimiter = date_part:get_attribute("range-delimiter")
      if not range_delimiter then
        range_delimiter = util.unicode["en dash"]
      end
    end

    local index = part_index[name]
    local part_value1 = date["date-parts"][1][index]
    local part_value2 = date["date-parts"][2][index]
    if part_value1 and part_value1 ~= part_value2 then
      if diff_begin == 0 then
        diff_begin = i
      end
      diff_end = i
    end
  end

  local same_prefix = {}
  local range_begin = {}
  local range_end = {}
  local same_suffix = {}

  local no_suffix_context = self:process_context(context)
  no_suffix_context.options["suffix"] = nil

  for i, date_part in ipairs(date_parts) do
    local res = nil
    if i == diff_end then
      res = date_part:render(date, no_suffix_context, true)
    else
      res = date_part:render(date, context)
    end
    if i < diff_begin then
      table.insert(same_prefix, res)
    elseif i <= diff_end then
      table.insert(range_begin, res)
      table.insert(range_end, date_part:render(date, context, false, true))
    else
      table.insert(same_suffix, res)
    end
  end

  local prefix_output = self:concat(same_prefix, context) or ""
  local range_begin_output = self:concat(range_begin, context) or ""
  local range_end_output = self:concat(range_end, context) or ""
  local suffix_output = self:concat(same_suffix, context)
  local range_output = range_begin_output .. range_delimiter .. range_end_output

  local res = self:concat({prefix_output, range_output, suffix_output}, context)

  return res
end

function Date:_get_show_parts (context)
  local show_parts = {}
  local date_parts = context.options["date-parts"] or "year-month-day"
  for _, date_part in ipairs(util.split(date_parts, "%-")) do
    show_parts[date_part] = true
  end
  return show_parts
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
    text = self:render_day(single_date[3], engine, state, context)
  end

  if not text then
    return nil
  end

  local inlines = {PlainText:new(text)}
  local output_format = context.format
  local is_english = context:is_english()
  output_format:apply_text_case(inlines, self.text_case, is_english)
  inlines = output_format:with_format(inlines, self.formatting)
  if self.affixes and self.affixes.prefix and suppressed_affix ~= "prefix" then
    table.insert(inlines, 1, PlainText:new(self.affixes.prefix))
  end
  if self.affixes and self.affixes.suffix and suppressed_affix ~= "suffix" then
    table.insert(inlines, PlainText:new(self.affixes.suffix))
  end
  return Rendered:new(inlines, self)
end

function DatePart:render_day(day, engine, state, context)
  if not day or day == "" then
    return nil
  end
  day = tonumber(day)
  if day < 1 or day > 31 then
    return nil
  end
  local form = self.form or "numeric"
  if form == "ordinal" then
    local limit_day_1 = context:get_locale_option("limit-day-ordinals-to-day-1")
    if limit_day_1 and day > 1 then
      form = "numeric"
    end
  end
  if form == "numeric-leading-zeros" then
    return string.format("%02d", day)
  elseif form == "ordinal" then
    -- TODO: render localed ordinal
    return string.format("%02dth", day)
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
