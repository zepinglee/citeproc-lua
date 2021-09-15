local Element = require("citeproc.citeproc-node-element")


local Layout = Element:new()

function Layout:render (items, context)
  self:debug_info(context)

  local mode = self:get_parent():get_element_name()

  -- When used within cs:citation, the delimiter attribute may be used to specify a delimiter for cites within a citation.
  -- Thus the processing of context is put after render_children().
  if mode ~= "citation" then
    context = self:process_context(context)
  end

  local output = {}
  for _, item in pairs(items) do

    context.item = item
    context.rendered_quoted_text = {}
    context.variable_attempt = {}
    context.suppressed_variables = {}
    context.suppress_subsequent_variables = false

    local res = self:render_children(item, context)
    if res then
      if mode == "bibliography" then
        res = self:get_engine().formatter["@bibliography/entry"](res, item)
      end
      table.insert(output, res)
    end
  end
  if next(output) == nil then
    return "[CSL STYLE ERROR: reference with no printed form.]"
  end

  if mode == "citation" then
    context = self:process_context(context)
    local res = self:concat(output, context)
    res = self:wrap(res, context)
    res = self:format(res, context)
    return res
  else
    return output
  end
end


return Layout
