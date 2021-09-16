local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Number = Element:new()

function Number:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local form = context.options["form"] or "numeric"
  local variable = self:get_variable(item, context.options["variable"], context)

  table.insert(context.variable_attempt, variable ~= nil)
  table.insert(context.rendered_quoted_text, false)

  local res = nil

  if form == "numeric" then
    res = tostring(variable)
  elseif form == "ordinal" then
    if type(variable) == "string" then
      variable = string.match(variable, "^%d+")
      if not variable then
        return nil
      end
      variable = tonumber(variable)
    end
    res = util.to_ordinal(variable)

  elseif form == "long-ordinal" then
    -- TODO
    res = tostring(variable)

  elseif form == "roman" then
    -- TODO
    res = tostring(variable)

  end

  res = self:wrap(res, context)

  return res
end


return Number
