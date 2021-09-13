local unicode = require("unicode")

local util = require("citeproc.citeproc-util")


local Element = {}

function Element:new ()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

Element.option_type = {
  ["et-al-min"] = "integer",
  ["et-al-use-first"] = "integer",
  ["et-al-subsequent-min"] = "integer",
  ["et-al-subsequent-use-first"] = "integer",
  ["near-note-distance"] = "integer",
  ["near"] = "integer",
  ["line-spacing"] = "integer",
  ["names-min"] = "integer",
  ["names-use-first"] = "integer",
  ["limit-day-ordinals-to-day-1"] = "boolean",
  ["punctuation-in-quote"] = "boolean",
  ["et-al-use-last"] = "boolean",
  ["initialize"] = "boolean",
  ["plural"] = "boolean",
  ["initialize-with-hyphen"] = "boolean",
  ["disambiguate-add-names"] = "boolean",
  ["disambiguate-add-givenname"] = "boolean",
  ["disambiguate-add-year-suffix"] = "boolean",
  ["hanging-indent"] = "boolean",
  ["names-use-last"] = "boolean",
  ["quotes"] = "boolean",
  ["strip-periods"] = "boolean",
}

Element.inheritable_options = {
  -- Debug
  ["level"] = true,
  -- Engine
  ["engine"] = true,
  -- Syle
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = true,
  -- Text
  ["item"] = true,
  -- Text
  rendered_quoted_text = true,
  -- Date
  ["date-parts"] = true,
  is_locale_date = true,
  date_part_attributes = true,
  -- Names
  ["and"] = true,
  ["delimiter-precedes-et-al"] = true,
  ["delimiter-precedes-last"] = true,
  ["et-al-min"] = true,
  ["et-al-use-first"] = true,
  ["et-al-subsequent-min"] = true,
  ["et-al-subsequent-use-first"] = true,
  ["et-al-use-last"] = true,
  ["initialize-with"] = true,
  ["name-as-sort-order"] = true,
  ["sort-separator"] = true,
  ["name-form"] = true,
  ["name-delimiter"] = true,
  ["names-delimiter"] = true,
  et_al = true,
  ["variable"] = true,
  -- Group
  ["variable_attempt"] = true,
  -- Choose
  ["position"] = true,
}

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
    util.debug(text)
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

function Element:get_term (name, form, lang)
  local term = nil
  local style = self:get_style()
  if form == "long" then
    form = nil
  end
  local query = string.format("term[name=\"%s\"]", name)
  -- LuaXML v0.1o does not support multiple attribute selectors
  -- if form then
  --     query = query .. string.format("[form=\"%s\"]", form)
  -- end
  for _, locale in ipairs(style:get_locales(lang)) do
    -- LuaXML v0.1o does not support multiple attribute selectors
    for _, t in ipairs(locale:query_selector(query)) do
      if t:get_attribute("form") == form then
        term = t
        break
      end
    end
    if term then
      break
    end
  end
  if not term then
    if name ~= "author" then
      util.warning(string.format("Failed to find '%s'", query))
    end
    return nil
  end
  return term
end

function Element:get_macro (name)
  local query = string.format("macro[name=\"%s\"]", name)
  local macro = self:root_node():query_selector(query)[1]
  if not macro then
    error(string.format("Failed to find %s.", query))
  end
  return macro
end

function Element:set_default_options (options)
  self.default_options = options
end

function Element:process_context (context)
  local state = {}
  if self.default_options then
    for key, value in pairs(self.default_options) do
      state[key] = value
    end
  end
  if context then
    for key, value in pairs(context) do
      if self.inheritable_options[key] then
        state[key] = value
      end
    end
    if self:get_element_name() == "name" then
      if context["name-form"] then
        state["form"] = context["name-form"]
      end
      if context["name-delimiter"] then
        state["delimiter"] = context["name-delimiter"]
      end
    end
    if self:get_element_name() == "names" then
      if context["names-delimiter"] then
        state["delimiter"] = context["names-delimiter"]
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
      if self.option_type[key] == "integer" then
        value = tonumber(value)
      elseif self.option_type[key] == "boolean" then
        value = (value == "true")
      end
      state[key] = value
    end
  end
  return state
end

Element.get_locale_option = function (self, key)
  local locales = self:get_style():get_locales()
  for i, locale in ipairs(locales) do
    local option = locale:get_option(key)
    if option then
      return option
    end
  end
  return nil
end

-- Formatting
function Element:format (str, context)
  if not str then
    return nil
  end
  local attributes = {
    "font-style",
    "font-variant",
    "font-weight",
    "text-decoration",
    "vertical-align",
  }
  for _, attribute in ipairs(attributes) do
    local value = context[attribute]
    if value then
      local key = string.format("@%s/%s", attribute, value)
      local formatter = self:get_engine().formatter[key]
      if formatter then
        if type(formatter) == "string" then
          str = string.gsub(formatter, "%%%%STRING%%%%", str)
        elseif type(formatter) == "function" then
          str = formatter(str, context.item)
        end
      end
    end
  end
  return str
end

-- Affixes
function Element:wrap (str, context)
  if not str then
    return nil
  end
  local prefix = context['prefix'] or ""
  local suffix = context['suffix'] or ""
  local res = prefix .. str
  res = self:_concat(res, suffix, context)
  return res
end

function Element:_concat (str1, str2, context)
  -- a helper function that concatenates two strings with `punctuation-in-quote`
  if not str1 then
    return nil
  end
  if not str2 or str2 == "" then
    return str1
  end
  local res = str1 .. str2
  if context.rendered_quoted_text[#context.rendered_quoted_text] == true then
    local prefix = string.sub(str2, 1, 1)
    if prefix == "," or prefix == "." then
      if self:get_locale_option("punctuation-in-quote") then
        local close_quote = self:get_term("close-quote"):render(context)
        if util.endswith(str1, close_quote) then
          res = string.sub(str1, 1, #str1 - #close_quote)
          res = res .. string.sub(str2, 1, 1)
          res = res .. close_quote
          res = res .. string.sub(str2, 2)
        end
      end
    end
  end
  return res
end

function Element:_concat_list (strings, delimiter, context)
  local res = nil
  for _, s in ipairs(strings) do
    if s and s ~= "" then
      if res then
        res = self:_concat(res, delimiter, context)
        res = self:_concat(res, s, context)
      else
        res = s
      end
    end
  end
  return res
end

-- Delimiters
function Element:concat (strings, context)
  local delimiter = context["delimiter"] or ""
  return self:_concat_list(strings, delimiter, context)
end

-- Quotes
function Element:quote (str, context)
  local quotes = context["quotes"] or false
  if quotes then
    local open_quote = self:get_term("open-quote"):render(context)
    local close_quote = self:get_term("close-quote"):render(context)
    str = open_quote .. str .. close_quote
  end
  return str
end

-- Text-case
function Element:case (str, context)
  if not str then
    return nil
  end
  local text_case = context["text-case"]
  local language = context.item["language"]
  if not language then
    language = self:get_style():get_attribute("default-locale") or "en-US"
  end
  if not util.startswith(language, "en") then
    return str
  end
  if not text_case then
    return str
  elseif text_case == "lowercase" then
    return string.lower(str)
  elseif text_case == "uppercase" then
    return unicode.utf8.upper(str)
  elseif text_case == "capitalize-first" then
    return util.capitalize_first(str)
  elseif text_case == "capitalize-all" then
    return util.capitalize_all(str)
  elseif text_case == "sentence" then
    return util.sentence(str)
  elseif text_case == "title" then
    return util.title(str)
  else
    error("Ivalid attribute \"text-case\"")
  end
end


return Element
