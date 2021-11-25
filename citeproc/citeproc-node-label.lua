local label = {}

local element = require("citeproc-element")
local util = require("citeproc-util")


local Label = element.Element:new()

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

  local form = context.options["form"]
  local plural = context.options["plural"] or "contextual"

  if not context.names_element then
    local variable_type = util.variable_types[variable_name]
    -- variable must be or one of the number variables.
    if variable_type ~= "number" then
      return nil
    end
    -- The term is only rendered if the selected variable is non-empty
    local variable = item[variable_name]
    if not variable then
      return nil
    end
    if type(variable) == "string" then
      local first_word = string.match(variable, "^%S+")
      if not util.is_numeric(first_word) then
        return nil
      end
    end
  end

  local term
  if variable_name == "locator" then
    local locator_type = item.label or "page"
    term = self:get_term(locator_type, form)
  else
    term = self:get_term(variable_name, form)
  end

  local res = nil
  if term then
    if plural == "contextual" and self:_is_plural(variable_name, context) or plural == "always" then
      res = term:render(context, true)
    else
      res = term:render(context, false)
    end

    res = self:strip_periods(res, context)
    res = self:case(res, context)
    res = self:format(res, context)
    res = self:wrap(res, context)
  end
  return res
end

function Label:_is_plural (variable_name, context)
  local variable_type = util.variable_types[variable_name]
  -- Don't use self:get_variable here
  local variable = context.item[variable_name]
  local res = false
  if variable_type == "name" then
    -- Label inside `names`
    res = #variable > 1

  elseif variable_type == "number" then
    if util.startswith(variable_name, "number-of-") then
      res = tonumber(variable) > 1
    else
      variable = tostring(variable)
      if #util.split(variable, "%s*[,&-]%s*") > 1 then
        -- check if contains multiple numbers
        -- "i–ix": true
        -- res = string.match(tostring(variable), "%d+%D+%d+") ~= nil
        res = true
      elseif string.match(variable, "%Aand%A") then
        res = true
      else
        res = false
      end
    end
  else
    util.warning("Invalid attribute \"variable\".")
  end
  return res
end


label.Label = Label

return label
