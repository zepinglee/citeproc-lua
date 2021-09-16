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
    local start, stop = string.match(part, "(%w+)%s*%-*%s*(%S*)")
    res = res .. start
    if stop and stop ~= "" then
      res = res .. page_range_delimiter
      if string.match(start, "%d+") and string.match(stop, "%d+") then
        start, stop = self:_format_range(start, stop, page_range_format)
      end
      res = res .. stop
    end
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

function Text:_format_range (start, stop, format)
  if format == "chicago-16" then
  elseif format == "chicago-15" then
    start, stop = tonumber(start), tonumber(stop)
    if start > 100 and start % 100 ~= 0 and start // 100 == stop // 100 then
      stop = stop % 100
    elseif start >= 10000 then
      stop = stop % 1000
    end
    start, stop = tostring(start), tostring(stop)
  elseif format == "expanded" then
    if #start > #stop then
      stop = string.sub(start, 1, #start - #stop) .. stop
    end
  elseif format == "minimal" then
    if #start >= #stop then
      for i in 1, #stop do
        if stop[i] ~= start[i + #start - #stop] then
          stop = string.sub(stop, i)
          break
        end
      end
    end
  elseif format == "minimal-two" then
    if #start >= #stop then
      for i in 1, #stop - 2 do
        if stop[i] ~= start[i + #start - #stop] then
          stop = string.sub(stop, i)
          break
        end
      end
    end
  end
  return start, stop
end

return Text
