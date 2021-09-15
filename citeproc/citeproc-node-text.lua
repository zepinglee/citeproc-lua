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
        local page_range_delimiter = self:get_term("page-range-delimiter"):render(context) or util.unicode["en dash"]
        res = string.gsub(res, "-", page_range_delimiter, 1)
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


return Text
