local date_module = {}

local element = require("citeproc.citeproc-element")
local util = require("citeproc.citeproc-util")


local Date = element.Element:new()

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
    res = self:get_locale_date(form):render(item, context)
  else
    if #date["date-parts"] == 0 then
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

  res = self:format(res, context)
  res = self:wrap(res, context)
  return res
end

function Date:get_locale_date (form, lang)
  local date = nil
  local style = self:get_style()
  local query = string.format("date[form=\"%s\"]", form)
  for _, locale in ipairs(style:get_locales(lang)) do
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

function Date:_render_single_date (date, context)
  local show_parts = self:_get_show_parts(context)

  local output = {}
  for _, child in ipairs(self:query_selector("date-part")) do
    if show_parts[child:get_attribute("name")] then
      table.insert(output, child:render(date, context))
    end
  end
  return self:concat(output, context)
end

function Date:_render_date_range (date, context)
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


local DatePart = element.Element:new()

DatePart.render = function (self, date, context, last_range_begin, range_end)
  self:debug_info(context)
  context = self:process_context(context)
  local name = context.options["name"]
  local range_delimiter = context.options["range-delimiter"] or false

  -- The attributes set on cs:date-part elements of a cs:date with form
  -- attribute override those specified for the localized date formats
  if context.date_part_attributes then
    local context_attributes = context.date_part_attributes[name]
    if context_attributes then
      for attr, value in pairs(context_attributes) do
        context.options[attr] = value
      end
    end
  end

  if last_range_begin then
    context.options["suffix"] = ""
  end

  local date_parts_index = 1
  if range_end then
    date_parts_index = 2
  end

  local res = nil
  if name == "day" then
    local day = date["date-parts"][date_parts_index][3]
    if not day then
      return nil
    end
    day = tonumber(day)
    -- range open
    if day == 0 then
      return nil
    end
    local form = context.options["form"] or "numeric"

    if form == "ordinal" then
      local option = self:get_locale_option("limit-day-ordinals-to-day-1")
      if option and option ~= "false" and day > 1 then
        form = "numeric"
      end
    end
    if form == "numeric" then
      res = tostring(day)
    elseif form == "numeric-leading-zeros" then
      -- TODO: day == nil?
      if not day then
        return nil
      end
      res = string.format("%02d", day)
    elseif form == "ordinal" then
      res = util.to_ordinal(day)
    end

  elseif name == "month" then
    local form = context.options["form"] or "long"

    local month = date["date-parts"][date_parts_index][2]
    if month then
      month = tonumber(month)
      -- range open
      if month == 0 then
        return nil
      end
    end

    if form == "long" or form == "short" then
      local term_name = nil
      if month then
        if month >= 1 and month <= 12 then
          term_name = string.format("month-%02d", month)
        elseif month >= 13 and month <= 24 then
          local season = month % 4
          if season == 0 then
            season = 4
          end
          term_name = string.format("season-%02d", season)
        else
          context.engine:warning("Invalid month value")
          return nil
        end
      else
        local season = date["season"]
        if season then
          season = tonumber(season)
          term_name = string.format("season-%02d", season)
        else
          return nil
        end
      end
      res = self:get_term(term_name, form):render(context)
    elseif form == "numeric" then
      res = tostring(month)
    elseif form == "numeric-leading-zeros" then
      -- TODO: month == nil?
      if not month then
        return nil
      end
      res = string.format("%02d", month)
    end
    res = self:strip_periods(res, context)

  elseif name == "year" then
    local year = date["date-parts"][date_parts_index][1]
    if year then
      year = tonumber(year)
      -- range open
      if year == 0 then
        return nil
      end
      local form = context.options["form"] or "long"
      if form == "long" then
        year = tonumber(year)
        if year < 0 then
          res = tostring(-year) .. self:get_term("bc"):render(context)
        elseif year < 1000 then
          res = tostring(year) .. self:get_term("ad"):render(context)
        else
          res = tostring(year)
        end
      elseif form == "short" then
        res = string.sub(tostring(year), -2)
      end
    end
  end
  res = self:case(res, context)
  res = self:format(res, context)
  res = self:wrap(res, context)
  res = self:display(res, context)
  return res
end


date_module.Date = Date
date_module.DatePart = DatePart

return date_module
