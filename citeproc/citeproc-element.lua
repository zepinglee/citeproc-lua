--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local element = {}

local SeqIr = require("citeproc-ir-node").SeqIr

local InlineElement = require("citeproc-output").InlineElement
local Micro = require("citeproc-output").Micro

local util = require("citeproc-util")


local Element = {
  element_name = nil,
  children = nil,
  element_type_map = {},
  _default_options = {},
}

Element._option_type = {
  ["et-al-min"] = "integer",
  ["et-al-use-first"] = "integer",
  ["et-al-subsequent-min"] = "integer",
  ["et-al-subsequent-use-first"] = "integer",
  ["near-note-distance"] = "integer",
  ["line-spacing"] = "integer",
  ["entry-spacing"] = "integer",
  ["names-min"] = "integer",
  ["names-use-first"] = "integer",
  ["limit-day-ordinals-to-day-1"] = "boolean",
  ["punctuation-in-quote"] = "boolean",
  ["et-al-use-last"] = "boolean",
  ["initialize"] = "boolean",
  ["initialize-with-hyphen"] = "boolean",
  ["disambiguate-add-names"] = "boolean",
  ["disambiguate-add-givenname"] = "boolean",
  ["disambiguate-add-year-suffix"] = "boolean",
  ["hanging-indent"] = "boolean",
  ["names-use-last"] = "boolean",
  ["quotes"] = "boolean",
  ["strip-periods"] = "boolean",
}

Element._inheritable_options = {
  -- Style
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = true,
  ["demote-non-dropping-particle"] = true,
  -- Citation
  ["disambiguate-add-givenname"] = true,
  ["givenname-disambiguation-rule"] = true,
  ["disambiguate-add-names"] = true,
  ["disambiguate-add-year-suffix"] = true,
  ["cite-group-delimiter"] = true,
  ["collapse"] = true,
  ["year-suffix-delimiter"] = true,
  ["after-collapse-delimiter"] = true,
  ["near-note-distance"] = true,
  -- Bibliography
  ["second-field-align"] = true,  -- for use in layout
  ["subsequent-author-substitute"] = true,
  ["subsequent-author-substitute-rule"] = true,
  -- Date
  ["date-parts"] = true,
  -- Names
  ["and"] = true,
  ["delimiter-precedes-et-al"] = true,
  ["delimiter-precedes-last"] = true,
  ["et-al-min"] = true,
  ["et-al-use-first"] = true,
  ["et-al-use-last"] = true,
  ["et-al-subsequent-min"] = true,
  ["et-al-subsequent-use-first"] = true,
  ["names-min"] = true,
  ["names-use-first"] = true,
  ["names-use-last"] = true,
  ["initialize-with"] = true,
  ["name-as-sort-order"] = true,
  ["sort-separator"] = true,
  ["name-form"] = true,
  ["name-delimiter"] = true,
  ["names-delimiter"] = true,
}

function Element:new(element_name)
  local o = {
    element_name = element_name or self.element_name,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Element:derive(element_name, default_options)
  local o = {
    element_name = element_name or self.element_name,
    children = nil,
  }

  if default_options then
    for key, value in pairs(default_options) do
      o[key] = value
    end
  end

  Element.element_type_map[element_name] = o
  setmetatable(o, self)
  self.__index = self
  return o
end

function Element:from_node(node, parent)
  local o = self:new()
  o.element_name = self.element_name or node:get_element_name()
  return o
end

function Element:set_attribute(node, attribute)
  local value = node:get_attribute(attribute)
  if value then
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = value
  end
end

function Element:set_bool_attribute(node, attribute)
  local value = node:get_attribute(attribute)
  if value == "true" then
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = true
  elseif value == "false" then
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = false
  end
end

function Element:set_number_attribute(node, attribute)
  local value = node:get_attribute(attribute)
  if value then
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = tonumber(value)
  end
end

function Element:process_children_nodes(node)
  if not self.children then
    self.children = {}
  end
  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      local element_type = self.element_type_map[element_name] or Element
      local child_element = element_type:from_node(child, self)
      table.insert(self.children, child_element)
    end
  end

end

function Element:build_ir(engine, state, context)
  return self:build_children_ir(engine, state, context)
end

function Element:build_children_ir(engine, state, context)
  local child_irs = {}
  local ir_sort_key
  local group_var = "plain"
  if self.children then
    for _, child_element in ipairs(self.children) do
      local child_ir = child_element:build_ir(engine, state, context)
      if child_ir and child_ir.group_var ~= "missing" then
        if child_ir.sort_key ~= nil then
          ir_sort_key = child_ir.sort_key
        end
        if child_ir.group_var == "important" then
          group_var = "important"
        end
        table.insert(child_irs, child_ir)
      end
    end
  end
  if #child_irs == 0 then
    return nil
  end
  local ir = SeqIr:new(child_irs, self)
  ir.sort_key = ir_sort_key
  ir.group_var = group_var
  return ir
end

-- Used in cs:group and cs:macro
function Element:build_group_ir(engine, state, context)
  if not self.children then
    return nil
  end
  local irs = {}
  local name_count
  local ir_sort_key
  local group_var = "plain"

  for _, child_element in ipairs(self.children) do
    -- util.debug(child_element.element_name)
    local child_ir = child_element:build_ir(engine, state, context)
    -- util.debug(child_ir)
    -- util.debug(child_ir.group_var)

    if child_ir then
      -- cs:group and its child elements are suppressed if
      --   a) at least one rendering element in cs:group calls a variable (either
      --      directly or via a macro), and
      --   b) all variables that are called are empty. This accommodates
      --      descriptive cs:text and `cs:label` elements.
      local child_group_var = child_ir.group_var
      if child_group_var == "important" then
        group_var = "important"
      elseif child_group_var == "missing" then
        if group_var == "plain" then
          group_var = "missing"
        end
      end

      if child_ir.name_count then
        if not name_count then
          name_count = 0
        end
        name_count = name_count + child_ir.name_count
      end

      if child_ir.sort_key ~= nil then
        ir_sort_key = child_ir.sort_key
      end

      -- The condition can be simplified
      if child_ir.group_var ~= "missing" then
        table.insert(irs, child_ir)
      end
    end
  end

  if #irs == 0 or group_var == "missing" then
    local ir = SeqIr:new()
    ir.name_count = name_count
    ir.sort_key = ir_sort_key
    ir.group_var = "missing"
    return ir
  end

  -- A non-empty nested cs:group is treated as a non-empty variable for the
  -- puropses of determining suppression of the outer cs:group.
  local ir = SeqIr:new(irs, self)
  ir.name_count = name_count
  ir.sort_key = ir_sort_key
  ir.group_var = "important"

  return ir
end

function Element:render_text_inlines(str, context)
  str = self:apply_strip_periods(str)
  -- TODO: try links

  local output_format = context.format
  local localized_quotes = nil
  if self.quotes then
    localized_quotes = context:get_localized_quotes()
  end

  local inlines = InlineElement:parse(str, context)
  local is_english = context:is_english()
  output_format:apply_text_case(inlines, self.text_case, is_english)
  inlines = {Micro:new(inlines)}
  inlines = output_format:with_format(inlines, self.formatting)
  inlines = output_format:affixed_quoted(inlines, self.affixes, localized_quotes)
  return output_format:with_display(inlines, self.display)
end

function Element:set_formatting_attributes(node)
  for _, attribute in ipairs({
    "font-style",
    "font-variant",
    "font-weight",
    "text-decoration",
    "vertical-align",
  }) do
    local value = node:get_attribute(attribute)
    if value then
      if not self.formatting then
        self.formatting = {}
      end
      self.formatting[attribute] = value
    end
  end
end

function Element:set_affixes_attributes(node)
  for _, attribute in ipairs({"prefix", "suffix"}) do
    local value = node:get_attribute(attribute)
    if value then
      if not self.affixes then
        self.affixes = {}
      end
      self.affixes[attribute] = value
    end
  end
end

function Element:get_delimiter_attribute(node)
  self:set_attribute(node, "delimiter")
end

function Element:set_display_attribute(node)
  self:set_attribute(node, "display")
end

function Element:set_quotes_attribute(node)
  self:set_bool_attribute(node, "quotes")
end

function Element:set_strip_periods_attribute(node)
  self:set_bool_attribute(node, "strip-periods")
end

function Element:set_text_case_attribute(node)
  self:set_attribute(node, "text-case")
end

-- function Element:apply_formatting(ir)
--   local attributes = {
--     "font_style",
--     "font_variant",
--     "font_weight",
--     "text_decoration",
--     "vertical_align",
--   }
--   for _, attribute in ipairs(attributes) do
--     local value = self[attribute]
--     if value then
--       if not ir.formatting then
--         ir.formatting = {}
--       end
--       ir.formatting[attribute] = value
--     end
--   end
--   return ir
-- end

function Element:apply_affixes(ir)
  if ir then
    if self.prefix then
      ir.prefix = self.prefix
    end
    if self.suffix then
      ir.suffix = self.suffix
    end
  end
  return ir
end

function Element:apply_delimiter(ir)
  if ir and ir.children then
    ir.delimiter = self.delimiter
  end
  return ir
end

function Element:apply_display(ir)
  ir.display = self.display
  return ir
end

function Element:apply_quotes(ir)
  if ir and self.quotes then
    ir.quotes = true
    ir.children = {ir}
    ir.open_quote = nil
    ir.close_quote = nil
    ir.open_inner_quote = nil
    ir.close_inner_quote = nil
    ir.punctuation_in_quote = false
  end
  return ir
end

function Element:apply_strip_periods(str)
  local res = str
  if str and self.strip_periods then
    res = string.gsub(str, "%.", "")
  end
  return res
end


function Element:format_number(number, variable, form, context)
  -- if not util.is_numeric(number) then
  --   number = string.gsub(number, "\\%-", "-")
  --   return number
  -- end
  if variable == "locator" then
    variable = context:get_variable("label")
  end
  form = form or "numeric"
  local number_part_list = self:split_number_parts(number, context)
  -- {
  --   {"1", "",  " & "}
  --   {"5", "8", ", "}
  -- }
  -- util.debug(number_part_list)

  for _, number_parts in ipairs(number_part_list) do
    if form == "roman" then
      self:format_roman_number_parts(number_parts)
    elseif form == "ordinal" or form == "long-ordinal" then
      local gender = context.locale:get_number_gender(variable)
      self:format_ordinal_number_parts(number_parts, form, gender, context)
    elseif number_parts[2] ~= "" and variable == "page" then
      local page_range_format = context.style.page_range_format
      self:format_page_range(number_parts, page_range_format)
    else
      self:format_numeric_number_parts(number_parts)
    end
  end

  local range_delimiter = util.unicode["en dash"]
  if variable == "page" then
    local page_range_delimiter = context:get_simple_term("page-range-delimiter")
    if page_range_delimiter then
      range_delimiter = page_range_delimiter
    end
  end

  local res = ""
  for _, number_parts in ipairs(number_part_list) do
    res = res .. number_parts[1]
    if number_parts[2] ~= "" then
      res = res .. range_delimiter
      res = res .. number_parts[2]
    end
    res = res .. number_parts[3]
  end
  return res

end

function Element:split_number_parts(number, context)
  -- number = string.gsub(number, util.unicode["en dash"], "-")
  local and_symbol
  and_symbol = context.locale:get_simple_term("and", "symbol")
  if and_symbol then
    and_symbol = " " .. and_symbol .. " "
  end
  local number_part_list = {}
  for _, tuple in ipairs(util.split(number, "%s*[,&]%s*", nil, true)) do
    local single_number, delim = table.unpack(tuple)
    delim = util.strip(delim)
    if delim == "," then
      delim = ", "
    elseif delim == "&" then
      delim = and_symbol or " & "
    end
    local start = single_number
    local stop = ""
    local splits = util.split(start, "%s*%-%s*")
    if #splits == 2 then
      start, stop = table.unpack(splits)
      if util.endswith(start, "\\") then
        start = string.sub(start, 1, -2)
        start = start .. "-" .. stop
        stop = ""
      end
      -- if string.match(start, "^%a*%d+%a*$") and string.match(stop, "^%a*%d+%a*$") then
      --   if s
        table.insert(number_part_list, {start, stop, delim})
      -- else
        -- table.insert(number_part_list, {start .. "-" .. stop, "", delim})
      -- end
    else
      table.insert(number_part_list, {start, stop, delim})
    end
  end
  return number_part_list
end

function Element:format_roman_number_parts(number_parts)
  for i = 1, 2 do
    local part = number_parts[i]
    if string.match(part, "%d+") then
      number_parts[i] = util.convert_roman(tonumber(part))
    end
  end
end

function Element:format_ordinal_number_parts(number_parts, form, gender, context)
  for i = 1, 2 do
    local part = number_parts[i]
    if string.match(part, "%d+") then
      local number = tonumber(part)
      if form == "long-ordinal" and number >= 1 and number <= 10 then
        number_parts[i] = context:get_simple_term(string.format("long-ordinal-%02d", number))
      else
        local suffix = context.locale:get_ordinal_term(number, gender)
        if suffix then
          number_parts[i] = number_parts[i] .. suffix
        end
      end
    end
  end
end

function Element:format_numeric_number_parts(number_parts)
  -- if number_parts[2] ~= "" then
  --   local first_prefix = string.match(number_parts[1], "^(.-)%d+")
  --   local second_prefix = string.match(number_parts[2], "^(.-)%d+")
  --   if first_prefix == second_prefix then
  --     number_parts[1] = number_parts[1] .. "-" .. number_parts[2]
  --     number_parts[2] = ""
  --   end
  -- end
end

-- https://docs.citationstyles.org/en/stable/specification.html#appendix-v-page-range-formats
function Element:format_page_range(number_parts, page_range_format)
  local start = number_parts[1]
  local stop = number_parts[2]
  local start_prefix, start_num  = string.match(start, "^(.-)(%d+)$")
  local stop_prefix, stop_num = string.match(stop, "^(.-)(%d+)$")
  if start_prefix ~= stop_prefix then
    -- Not valid range: "n11564-1568" -> "n11564-1568"
    -- 110-N6
    -- N110-P5
    number_parts[1] = start .. "-" .. stop
    number_parts[2] = ""
    return
  end

  if not page_range_format then
    return
  end
  if page_range_format == "chicago-16" then
    stop = self:_format_range_chicago_16(start_num, stop_num)
  elseif page_range_format == "chicago-15" then
    stop = self:_format_range_chicago_15(start_num, stop_num)
  elseif page_range_format == "expanded" then
    stop = stop_prefix .. self:_format_range_expanded(start_num, stop_num)
  elseif page_range_format == "minimal" then
    stop = self:_format_range_minimal(start_num, stop_num)
  elseif page_range_format == "minimal-two" then
    stop = self:_format_range_minimal(start_num, stop_num, 2)
  end
  number_parts[2] = stop
end

function Element:_format_range_chicago_16(start, stop)
  if #start < 3 or string.sub(start, -2) == "00" then
    return self:_format_range_expanded(start, stop)
  elseif string.sub(start, -2, -2) == "0" then
    return self:_format_range_minimal(start, stop)
  else
    return self:_format_range_minimal(start, stop, 2)
  end
  return stop
end

function Element:_format_range_chicago_15(start, stop)
  if #start < 3 or string.sub(start, -2) == "00" then
    return self:_format_range_expanded(start, stop)
  else
    local changed_digits = self:_format_range_minimal(start, stop)
    if string.sub(start, -2, -2) == "0" then
      return changed_digits
    elseif #start == 4 and #changed_digits == 3 then
      return self:_format_range_expanded(start, stop)
    else
      return self:_format_range_minimal(start, stop, 2)
    end
  end
  return stop
end

function Element:_format_range_expanded(start, stop)
  -- Expand  "1234–56" -> "1234–1256"
  if #start <= #stop then
    return stop
  end
  return string.sub(start, 1, #start - #stop) .. stop
end

function Element:_format_range_minimal(start, stop, threshold)
  threshold = threshold or 1
  if #start < #stop then
    return stop
  end
  local offset = #start - #stop
  for i = 1, #stop - threshold do
    local j = i + offset
    if string.sub(stop, i, i) ~= string.sub(start, j, j) then
      return string.sub(stop, i)
    end
  end
  return string.sub(stop, -threshold)
end

element.Element = Element

return element
