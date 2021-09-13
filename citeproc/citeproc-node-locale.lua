local Element = require("citeproc.citeproc-node-element")


local Locale = Element:new()

function Locale:get_option (key)
  local query = string.format("style-options[%s]", key)
  local option = self:query_selector(query)[1]
  if option then
    return option:get_attribute(key)
  else
    return nil
  end
end


return Locale
