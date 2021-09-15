local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Number = Element:new()

function Number:render (item, context)
  context = self:process_context(context)
  local form = context.options["form"] or "numeric"
  local variable = self:get_variable(item, context.options["variable"], context)

  table.insert(context.variable_attempt, variable ~= nil)
  table.insert(context.rendered_quoted_text, false)

  local text = ""
  if form == "numeric" then
    text = tostring(variable)
  elseif form == "ordinal" then
    text = util.to_ordinal(variable)
  elseif form == "long-ordinal" then
    text = tostring(variable)
  elseif form == "roman" then
    text = tostring(variable)
  end
  return text
end


return Number
