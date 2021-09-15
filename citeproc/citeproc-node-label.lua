local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Label = Element:new()

function Label:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local variable_name = context.options["variable"]
  local form = context.options["form"]
  local plural = context.options["plural"] or "contextual"

  local term = self:get_term(variable_name, form)
  local res = nil
  if term then
    if plural == "contextual" and self:_is_plural(item, context) or plural == "always" then
      res = term:render(context, true)
    else
      res = term:render(context, false)
    end

    res = self:case(res, context)
    res = self:format(res, context)
    res = self:wrap(res, context)
  end
  return res
end

function Label:_is_plural (item, context)
  local variable_name = context.options["variable"]
  local variable_type = util.variable_types[variable_name]
  -- Don't use self:get_variable here
  local value = item[variable_name]
  local res =false
  if variable_type == "name" then
    res = #value > 1
  elseif variable_type == "number" then
    if util.startswith(variable_name, "number-of-") then
      res = tonumber(value) > 1
    else
      res = string.match(tostring(value), "%d+%D+%d+") ~= nil
    end
  else
    util.warning("Invalid attribute \"variable\".")
  end
  return res
end


return Label
