local group = {}

local element = require("citeproc-element")
local util = require("citeproc-util")


local Group = element.Element:new()

function Group:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local num_variable_attempt = #context.variable_attempt

  local res = self:render_children(item, context)

  if #context.variable_attempt > num_variable_attempt then
    if not util.any(util.slice(context.variable_attempt, num_variable_attempt + 1)) then
      res = nil
    end
  end

  res = self:format(res, context)
  res = self:wrap(res, context)
  res = self:display(res, context)
  return res
end


group.Group = Group

return group
