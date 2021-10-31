local number_module = {}

local element = require("citeproc-element")
local util = require("citeproc-util")


local Number = element.Element:new()

function Number:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local variable = context.options["variable"]
  local content = self:get_variable(item, variable, context)

  table.insert(context.variable_attempt, content ~= nil)

  if not content then
    return nil
  end

  local numbers = {}
  local punct_list = {}
  local last_position = 1
  for number, punct, pos in string.gmatch(content, "(.-)%s*([-,&])%s*()") do
    table.insert(numbers, number)
    table.insert(punct_list, punct)
    last_position = pos
  end
  table.insert(numbers, string.sub(content, last_position))

  local res = ""
  for i, number in ipairs(numbers) do
    local punct = punct_list[i]
    number = self:_format_single_number(number, context)
    res = res .. number

    if punct == "-" then
      res = res .. punct
    elseif punct == "," then
      res = res .. punct .. " "
    elseif punct == "&" then
      res = res .. " " .. punct .. " "
    end
  end

  res = self:case(res, context)
  res = self:wrap(res, context)
  res = self:display(res, context)

  return res
end

function Number:_format_single_number(number, context)
  local form = context.options["form"] or "numeric"
  if form  == "numeric" or not string.match(number, "^%d+$") then
    return number
  end
  number = tonumber(number)
  if form == "ordinal" or form == "long-ordinal" then
    return self:_format_oridinal(number, form, context)
  elseif form == "roman" then
    return util.convert_roman(number)
  end
end

function Number:_format_oridinal(number, form, context)
  assert(type(number) == "number")
  local variable = context.options["variable"]

  if form == "long-ordinal" then
    if number < 1 or number > 10 then
      form = "ordinal"
    end
  end

  local gender = nil
  local term = self:get_term(variable)
  if term then
    gender = term:get_attribute("gender")
  end

  term = self:get_term(form, nil, number, gender)
  local res = term:render(context)
  if form == "ordinal" then
    return number .. res
  else
    return res
  end
end


number_module.Number = Number

return number_module
