--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local element = {}

local unicode = require("unicode")

local IrNode = require("citeproc-ir-node").IrNode
local SeqIr = require("citeproc-ir-node").SeqIr

local InlineElement = require("citeproc-output").InlineElement

local richtext = require("citeproc-richtext")
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

function Element:from_node(node)
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
    value = true
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = value
  elseif value == "false" then
    value = false
    local key = string.gsub(attribute, "%-" , "_")
    self[key] = value
  end
end

function Element:process_children_nodes(node)
  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      local element_type = self.element_type_map[element_name] or Element
      local child_element = element_type:from_node(child)
      if child_element then
        self.children = self.children or {}
        table.insert(self.children, child_element)
      end
    end
  end

end

function Element:build_ir(engine, state, context)
  return self:build_children_ir(engine, state, context)
end

function Element:build_children_ir(engine, state, context)
  local child_irs = {}
  if self.children then
    for _, child_element in ipairs(self.children) do
      local child_ir = child_element:build_ir(engine, state, context)
      if child_ir and child_ir.group_var ~= "missing" then
        table.insert(child_irs, child_ir)
      end
    end
  end
  return SeqIr:new(child_irs, self)
end

function Element:render_text_inlines(str, context)
  str = self:apply_strip_periods(str)
  -- TODO: try links

  local output_format = context.format
  local localized_quotes = nil
  if self.quotes then
    localized_quotes = context:get_localized_quotes()
  end

  local inlines = InlineElement:parse(str)
  output_format:apply_text_case(inlines, self.text_case)
  inlines = output_format:with_format(inlines, self.formatting)
  inlines = output_format:affixed_quoted(inlines, self.affixes, localized_quotes)
  return output_format:with_display(inlines, self.display)
end


function Element:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  return self:render_children(item, context)
end

function Element:render_children (item, context)
  local output = {}
  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      if child.render == nil then
        local element_name = child:get_element_name()
        util.warning("Unkown type \"" .. element_name .. "\"")
      end
      local str = child:render(item, context)
      table.insert(output, str)
    end
  end
  return self:concat(output, context)
end

function Element:set_base_class (node)
  if node:is_element() then
    local org_meta_table = getmetatable(node)
    setmetatable(node, {__index = function (_, key)
      if self[key] then
        return self[key]
      else
        return org_meta_table[key]
      end
    end})
  end
end

function Element:debug_info (context, debug)
  -- debug = true
  if debug then
    local text = ""
    local level = 0
    if context and context.level then
      level = context.level + 1
    end
    text = text .. string.rep(" ", 2 * level)
    text = text .. self:get_element_name()
    local attrs = {}
    if self._attr then
      for attr, value in pairs(self._attr) do
        table.insert(attrs, attr .. "=\"" .. value .. "\"")
      end
      text = text .. "[" .. table.concat(attrs, " ") .. "]"
    end
    io.stderr:write(text .. "\n")
  end
end

function Element:get_child (type)
  for _, child in ipairs(self:get_children()) do
    if child:get_element_name() == type then
      return child
    end
  end
  return nil
end

function Element:get_style ()
  local style = self:root_node().style
  assert(style ~= nil)
  return style
end

function Element:get_engine ()
  local engine = self:root_node().engine
  assert(engine ~= nil)
  return engine
end

function Element:process_context (context)
  local state = {
    -- The `build` table is directly passed to new context.
    build = context.build or {},
    -- The `option` table is copied.
    options = {},
    -- Other items in `context` is copied.
  }
  for key, value in pairs(self._default_options) do
    state.options[key] = value
  end
  if context then
    local element_name = self:get_element_name()
    for key, value in pairs(context) do
      if key == "options" then
        for k, v in pairs(context.options) do
          if self._inheritable_options[k] then
            state.options[k] = v
            if element_name == "name" then
              if k == "name-form" then
                state.options["form"] = v
              end
              if k == "name-delimiter" then
                state.options["delimiter"] = v
              end
            elseif element_name == "names" then
              if k == "names-delimiter" then
                state.options["delimiter"] = v
              end
            end
          end
        end
      else
        state[key] = value
      end
    end
    if state.level then
      state.level = state.level + 1
    else
      state.level = 0
    end
  end
  if self._attr then
    for key, value in pairs(self._attr) do
      if self._option_type[key] == "integer" then
        value = tonumber(value)
      elseif self._option_type[key] == "boolean" then
        value = (value == "true")
      end
      state.options[key] = value
    end
  end
  return state
end

function Element:get_option (key, context)
  assert(context ~= nil)
  return context.options[key]
end

function Element:get_locale_option (key)
  print(debug.traceback())
  local locales = self:get_style():get_locales()
  for i, locale in ipairs(locales) do
    local option = locale:get_option(key)
    if option ~= nil then
      return option
    end
  end
  return nil
end

function Element:get_variable (item, name, context)
  if context.suppressed_variables and context.suppressed_variables[name] then
    return nil
  else
    local res = item[name]
    if type(res) == "table" and res._type == "RichText" then
      -- TODO: should be deep copy
      res = res:shallow_copy()
    end

    if res and res ~= "" then
      if context.suppress_subsequent_variables then
        context.suppressed_variables[name] = true
      end
    end
    return res
  end
end

function Element:get_macro (name)
  local query = string.format("macro[name=\"%s\"]", name)
  local macro = self:root_node():query_selector(query)[1]
  if not macro then
    error(string.format("Failed to find %s.", query))
  end
  return macro
end

-- Formatting
function Element:escape (str, context)
  return str
  -- return self:get_engine().formatter.text_escape(str)
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


function Element:_apply_format(text, context)
  if not text or text == "" then
    return nil
  end
  if text._type ~= "RichText" then
    text = richtext.new(text)
  end
  local attributes = {
    "font-style",
    "font-variant",
    "font-weight",
    "text-decoration",
    "vertical-align",
  }
  for _, attribute in ipairs(attributes) do
    local value = context.options[attribute]
    if value then
      if text.formats[attribute] then
        local new = richtext.new()
        new.contents = {text}
        text = new
      end
      text:add_format(attribute, value)
    end
  end
  return text
end

-- Affixes
function Element:_apply_affixes(str, context)
  if not str or str == "" then
    return nil
  end
  local prefix = context.options["prefix"]
  local suffix = context.options["suffix"]
  local res = str
  if prefix and prefix ~= "" then
    local linkable = false
    local variable_name = context.options["variable"]
    if variable_name == "DOI" or variable_name == "PMID" or variable_name == "PMCID" then
      linkable = true
    end
    if variable_name == "URL" or (linkable and not string.match(prefix, "^https?://")) then
      res:add_format(variable_name, "true")
    end
    res = richtext.concat(prefix, res)
    if linkable and string.match(prefix, "^https?://") then
      res:add_format("URL", "true")
    end
  end
  if suffix and suffix ~= "" then
    res = richtext.concat(res, suffix)
  end
  return res
end

-- Delimiters
function Element:concat (strings, context)
  local delimiter = context.options["delimiter"]
  return richtext.concat_list(strings, delimiter)
end

-- Display
function Element:_apply_display(text, context)
  if not text then
    return text
  end
  local value = context.options["display"]
  if not value then
    return text
  end
  if type(text) == "string" then
    text = richtext.new(text)
  end
  text:add_format("display", value)
  return text
end

-- Quotes
function Element:_apply_quote(str, context)
  if not str then
    return nil
  end
  if context.sorting then
    return str
  end
  if not str._type == "RichText" then
    str = richtext.new(str)
  end
  local quotes = context.options["quotes"] or false
  if quotes then
    str:add_format("quotes", "true")
  end
  return str
end

-- Strip periods
function Element:_apply_strip_periods(str, context)
  if not str then
    return nil
  end
  if str._type ~= "RichText" then
    str = richtext.new(str)
  end
  local strip_periods = context.options["strip-periods"]
  if strip_periods then
    str:_apply_strip_periods()
  end
  return str
end

-- Text-case
function Element:_apply_case(text, context)
  if not text or text == "" then
    return nil
  end
  if text._type ~= "RichText" then
    text = richtext.new(text)
  end
  local text_case = context.options["text-case"]
  if not text_case then
    return text
  end
  if text_case == "title" then
    -- title case conversion only affects English-language items
    local language = context.item["language"]
    if not language then
      language = self:get_style():get_attribute("default-locale") or "en-US"
    end
    if not util.startswith(language, "en") then
      return text
    end
  end
  text:add_format("text-case", text_case)
  return text
end


element.Element = Element

return element
