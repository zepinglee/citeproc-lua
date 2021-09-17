local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Label = Element:new()

function Label:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local variable_name
  if context.names_element then
    -- The `variable` attribute of names may hold multiple roles.
    -- Each of them may call `Label:render()` to render the term.
    -- When used in `names` element, the role name is the first argument
    -- and the item is accessed via `context.item`.
    -- Bad design
    -- TODO: Redesign the arguments of render()
    variable_name = item
  else
    variable_name = context.options["variable"]
  end

  if variable_name == "locator" then
    variable_name = "page"
  end

  local form = context.options["form"]
  local plural = context.options["plural"] or "contextual"

  local term = self:get_term(variable_name, form)
  local res = nil
  if term then
    if plural == "contextual" and self:_is_plural(variable_name, context) or plural == "always" then
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

function Label:_is_plural (variable_name, context)
  local variable_type = util.variable_types[variable_name]
  -- Don't use self:get_variable here
  local value = context.item[variable_name]
  local res = false
  if variable_type == "name" then
    -- Label inside `names`
    res = #value > 1

  elseif variable_type == "number" then
    if util.startswith(variable_name, "number-of-") then
      res = tonumber(value) > 1
    elseif #util.split(tostring(value), "%s*[,&-]%s*") <= 1 then
      -- check if contains multiple numbers
      -- "i–ix": true
      -- res = string.match(tostring(value), "%d+%D+%d+") ~= nil
      res = false
    elseif string.match(value, "\\%-") then
      res = false
    else
      res = true
    end
  else
    util.warning("Invalid attribute \"variable\".")
  end
  return res
end


return Label
