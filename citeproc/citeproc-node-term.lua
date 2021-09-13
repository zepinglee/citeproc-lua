local Element = require("citeproc.citeproc-node-element")


local Term = Element:new()

function Term:render (context, is_plural)
  self:debug_info(context)
  context = self:process_context(context)

  local output = {
    single = self:get_text(),
  }
  for _, child in ipairs(self:get_children()) do
    if child:is_element() then
      output[child:get_element_name()] = self:get_engine().formatter.text_escape(child:get_text())
    end
  end
  local res = output.single
  if is_plural then
    if output.multiple then
      res = output.multiple
    end
  end
  res = self:get_engine().formatter.text_escape(res)
  return res
end


return Term
