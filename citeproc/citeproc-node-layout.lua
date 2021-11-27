local layout = {}

local richtext = require("citeproc-richtext")
local element = require("citeproc-element")
local util = require("citeproc-util")


local Layout = element.Element:new()

function Layout:render (items, context)
  self:debug_info(context)

  context.items = items

  -- When used within cs:citation, the delimiter attribute may be used to specify a delimiter for cites within a citation.
  -- Thus the processing of context is put after render_children().
  if context.mode == "citation" then
    if context.options["collapse"] == "citation-number" then
      context.build.item_citation_numbers = {}
      context.build.item_citation_number_text = {}
    end
  elseif context.mode == "bibliography" then
    context.build.longest_label = ""
    context.build.preceding_first_rendered_names = nil
    context = self:process_context(context)
  end

  local output = {}
  local previous_cite = nil
  for _, item in ipairs(items) do

    context.item = item
    context.variable_attempt = {}
    context.suppressed_variables = {}
    context.suppress_subsequent_variables = false
    if context.mode == "bibliography" then
      context.build.first_rendered_names = {}
    end

    if not item.position then
      item.position = self:_get_position(item, previous_cite, context)
    end

    local first = nil
    local second = {}
    local element_index = 0
    for _, child in ipairs(self:get_children()) do
      if child:is_element() then
        element_index = element_index + 1
        local text = child:render(item, context)
        if element_index == 1 then
          first = text
        else
          table.insert(second, text)
        end
      end
    end
    second = self:concat(second, context)

    if context.mode == "bibliography" then
      if first and context.options["prefix"] then
        first = richtext.new(context.options["prefix"]) .. first
      end
      if second and context.options["suffix"] then
        second = second .. richtext.new(context.options["suffix"])
      end
    end

    local res = nil
    if context.options["second-field-align"] == "flush" then
      if first then
        first:add_format("display", "left-margin")
        res = first
      end
      if second then
        second:add_format("display", "right-inline")
        if res then
          res = richtext.concat(res, second)
        else
          res = second
        end
      end
    else
      res = self:concat({first, second}, context)
    end

    if context.mode == "citation" then
      if res and item["prefix"] then
        res = richtext.new(item["prefix"]) .. res
      end
      if res and item["suffix"] then
        res = res .. richtext.new(item["suffix"])
      end
    elseif context.mode == "bibliography" then
      if not res then
        res = richtext.new("[CSL STYLE ERROR: reference with no printed form.]")
      end
      res = self:wrap(res, context)
      -- util.debug(text)
      res = res:render(context.engine.formatter, context)
      res = context.engine.formatter["@bibliography/entry"](res, context)
    end
    table.insert(output, res)
    previous_cite = item
  end

  if next(output) == nil then
    return "[CSL STYLE ERROR: reference with no printed form.]"
  end

  if context.mode == "citation" then
    context = self:process_context(context)
    local res
    if context.options["collapse"] then
      res = self:_collapse_citations(output, context)
    else
      res = self:concat(output, context)
    end
    res = self:wrap(res, context)
    res = self:format(res, context)
    if res then
      -- util.debug(res)
      res = res:render(context.engine.formatter, context)
    end
    return res

  else
    local params = {
      maxoffset = #context.build.longest_label,
    }

    return {params, output}
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
    for _, cite in ipairs(engine.registry.previous_citation.citationItems) do
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


function Layout:_collapse_citations(output, context)
  if context.options["collapse"] == "citation-number" then
    assert(#output == #context.items)
    local citation_numbers = {}
    for i, item in ipairs(context.items) do
      citation_numbers[i] = context.build.item_citation_numbers[item.id] or 0
    end

    local collapsed_output = {}
    local citation_number_range_delimiter = util.unicode["en dash"]
    local index = 1
    while index <= #citation_numbers do
      local stop_index = index + 1
      if output[index] == context.build.item_citation_number_text[index] then
        while stop_index <= #citation_numbers  do
          if output[stop_index] ~= context.build.item_citation_number_text[stop_index] then
            break
          end
          if citation_numbers[stop_index - 1] + 1 ~= citation_numbers[stop_index] then
            break
          end
          stop_index = stop_index + 1
        end
      end

      if stop_index >= index + 3 then
        local range_text = output[index] .. citation_number_range_delimiter .. output[stop_index - 1]
        table.insert(collapsed_output, range_text)
      else
        for i = index, stop_index - 1 do
          table.insert(collapsed_output, output[i])
        end
      end

      index = stop_index
    end

    return self:concat(collapsed_output, context)
  end
  return self:concat(output, context)
end


layout.Layout = Layout

return layout
