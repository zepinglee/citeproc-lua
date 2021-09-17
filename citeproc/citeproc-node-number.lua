local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Number = Element:new()

function Number:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local form = context.options["form"] or "numeric"
  local variable = context.options["variable"]

  local number = self:get_variable(item, variable, context)

  table.insert(context.variable_attempt, variable ~= nil)
  table.insert(context.rendered_quoted_text, false)

  if not number then
    return false
  end
  number = tostring(number)

  local res = nil

  if form == "numeric" then
    -- TODO
    res = number

  elseif form == "ordinal" or form == "long-ordinal" then
    number = string.match(number, "^%d+")
    if not number then
      return nil
    end

    if form == "long-ordinal" then
      local value = tonumber(number)
      if value < 1 or value > 10 then
        form = "ordinal"
      end
    end

    local gender = nil
    local term = self:get_term(variable)
    if term then
      gender = term:get_attribute("gender")
    end

    term = self:get_term(form, nil, number, gender)
    local suffix = term:render(context)
    if form == "ordinal" then
      res = number .. suffix
    else
      res = suffix
    end

  elseif form == "roman" then
    -- TODO
    res = number

  end

  res = self:wrap(res, context)

  return res
end


return Number
