local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Text = Element:new()

function Text:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local res = nil

  local variable_name = self:get_attribute("variable")
  if variable_name then
    local form = self:get_attribute("form")
    if form == "short" then
      variable_name = variable_name .. "-" .. form
    end
    res = self:get_variable(item, variable_name, context)
    if res then
      res = tostring(res)
      if variable_name == "page" then
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

  if res and context.options["quotes"] then
    table.insert(context.rendered_quoted_text, true)
  else
    table.insert(context.rendered_quoted_text, false)
  end

  res = self:case(res, context)
  res = self:format(res, context)
  res = self:quote(res, context)
  res = self:wrap(res, context)

  return res
end


function Text:_format_page (page, context)
  local res = nil

  local page_range_delimiter = self:get_term("page-range-delimiter"):render(context) or util.unicode["en dash"]
  local page_range_format = context.options["page-range-format"]
  if page_range_format == "chicago" then
    local csl_version = self:get_style().version
    if csl_version and csl_version <= "1.0.1" then
      page_range_format = "chicago-15"
    else
      page_range_format = "chicago-16"
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
  local start, delimiter, stop = string.match(str, "(%w+)%s*(%-*)%s*(%S*)")
  if not stop or stop == "" then
    return str
  end

  local start_prefix, start_num  = string.match(start, "(.-)(%d*)$")
  local stop_prefix, stop_num = string.match(stop, "(.-)(%d*)$")

  if start_prefix ~= stop_prefix then
    -- Not valid range: "n11564-1568" -> "n11564-1568"
    -- 110-N6
    -- N110-P5
    return start .. delimiter .. stop
  end

  -- Expand  "1234–56" -> "1234–1256"
  if #start_num > #stop_num then
    stop_num = string.sub(start_num, 1, #start_num - #stop_num) .. stop_num
  end

  if format == "chicago-16" then
    stop = self:_format_chicago_16(start_num, stop_num)
  elseif format == "chicago-15" then
    stop = self:_format_chicago_15(start_num, stop_num)
  elseif format == "expanded" then
    stop = stop_prefix .. stop_num
  elseif format == "minimal" then
    stop = self:_minimize_range(start_num, stop_num)
  elseif format == "minimal-two" then
    stop = self:_minimize_range(start_num, stop_num, 2)
  end

  return start .. range_delimiter .. stop
end

function Text:_format_chicago_16(start, stop)
end

function Text:_format_chicago_15(start, stop)
  start, stop = tonumber(start), tonumber(stop)
  if start > 100 and start % 100 ~= 0 and start // 100 == stop // 100 then
    stop = stop % 100
  elseif start >= 10000 then
    -- Assuming stop < 20000
    stop = stop % 1000
  end
  return tostring(stop)
end

function Text:_minimize_range(start, stop, threshold)
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

return Text
