--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local layout = {}

local Element = require("citeproc-element").Element
local util = require("citeproc-util")


local Layout = Element:derive("layout")

function Layout:from_node(node)
  local o = Layout:new()
  o:set_affixes_attributes(node)
  o:set_formatting_attributes(node)
  o:get_delimiter_attribute(node)

  o:process_children_nodes(node)

  return o
end

function Layout:build_ir(engine, state, context)
  local ir = self:build_children_ir(engine, state, context)
  if not ir then
    return nil
  end
  if context.in_bibliography then
    ir.delimiter = self.delimiter
    ir.affixes = util.clone(self.affixes)
    -- if self.affixes then
    --   local irs = {}
    --   if self.affixes.prefix then
    --     table.insert(irs, Rendered:new(PlainText:new(self.affixes.prefix)))
    --   end
    --   table.insert(irs, ir)
    --   if self.affixes.suffix then
    --     table.insert(irs, Rendered:new(PlainText:new(self.affixes.suffix)))
    --   end
    --   ir = SeqIr:new(irs, self)
    -- end
    ir.formatting = util.clone(self.formatting)
  end
  return ir
end


-- function Layout:_collapse_citations(output, context)
--   if context.options["collapse"] == "citation-number" then
--     assert(#output == #context.items)
--     local citation_numbers = {}
--     for i, item in ipairs(context.items) do
--       citation_numbers[i] = context.build.item_citation_numbers[item.id] or 0
--     end

--     local collapsed_output = {}
--     local citation_number_range_delimiter = util.unicode["en dash"]
--     local index = 1
--     while index <= #citation_numbers do
--       local stop_index = index + 1
--       if output[index] == context.build.item_citation_number_text[index] then
--         while stop_index <= #citation_numbers  do
--           if output[stop_index] ~= context.build.item_citation_number_text[stop_index] then
--             break
--           end
--           if citation_numbers[stop_index - 1] + 1 ~= citation_numbers[stop_index] then
--             break
--           end
--           stop_index = stop_index + 1
--         end
--       end

--       if stop_index >= index + 3 then
--         local range_text = output[index] .. citation_number_range_delimiter .. output[stop_index - 1]
--         table.insert(collapsed_output, range_text)
--       else
--         for i = index, stop_index - 1 do
--           table.insert(collapsed_output, output[i])
--         end
--       end

--       index = stop_index
--     end

--     return self:concat(collapsed_output, context)
--   end
--   return self:concat(output, context)
-- end


layout.Layout = Layout

return layout
