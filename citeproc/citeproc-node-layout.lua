local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Layout = Element:new()

function Layout:render (items, context)
  self:debug_info(context)

  -- When used within cs:citation, the delimiter attribute may be used to specify a delimiter for cites within a citation.
  -- Thus the processing of context is put after render_children().
  if context.mode ~= "citation" then
    context = self:process_context(context)
  end

  local output = {}
  local previous_cite = nil
  for _, item in ipairs(items) do

    context.item = item
    context.rendered_quoted_text = {}
    context.variable_attempt = {}
    context.suppressed_variables = {}
    context.suppress_subsequent_variables = false

    if not item.position then
      item.position = self:_get_position(item, previous_cite, context)
    end

    local res = self:render_children(item, context)
    if res then
      if context.mode == "bibliography" then
        res = self:get_engine().formatter["@bibliography/entry"](res, item)
      end
      table.insert(output, res)
    end
    previous_cite = item
  end

  if next(output) == nil then
    return "[CSL STYLE ERROR: reference with no printed form.]"
  end

  if context.mode == "citation" then
    context = self:process_context(context)
    local res = self:concat(output, context)
    res = self:wrap(res, context)
    res = self:format(res, context)
    return res
  else
    return output
  end
end

function Layout:_get_position (item, previous_cite, context)
  local engine = context.engine
  if not engine.registry.registry[item.id] then
    return util.position_map["first"]
  end

  local position = util.position_map["subsequent"]
  -- Find the preceding cite referencing the same item
  local preceding_cite = nil
  if previous_cite then
    -- a. the current cite immediately follows on another cite
    if item.id == previous_cite.id then
      preceding_cite = previous_cite
    end
  elseif engine.registry.previous_citation then
    -- b. first cite in the citation and previous citation exists
    for _, cite in ipairs(engine.registry.previous_citation) do
      if item.id == cite.id then
        preceding_cite = cite
        break
      end
    end
  end

  if preceding_cite then
    if preceding_cite.locator then
      -- Preceding cite does have a locator
      if item.locator then
        if item.locator == preceding_cite.locator then
          position = util.position_map["ibid"]
        else
          position = util.position_map["ibid-with-locator"]
        end
      else
        -- the current cite lacks a locator
        position = util.position_map["subsequent"]
      end
    else
      -- Preceding cite does not have a locator
      if item.locator then
        position = util.position_map["ibid-with-locator"]
      else
        position = util.position_map["ibid"]
      end
    end
  end
  return position
end


return Layout
