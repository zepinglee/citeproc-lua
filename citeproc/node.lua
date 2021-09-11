--[[
  Copyright (C) 2021 Zeping Lee
--]]

local dom = require("luaxml-domobject")

local util = require("citeproc.util")


local Node = {}

Node.Element = {}

function Node.Element:new()
  local o = {}
  setmetatable(o, self)
  self.__index = self
  return o
end

Node.Element.option_type = {
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

Node.Element.inheritable_options = {
  ["engine"] = true,
  -- Debug
  ["level"] = true,
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
  et_al = true,
  ["variable"] = true,
  -- Group
  ["variable_attempt"] = true,
  -- Choose
  ["position"] = true,
}

function Node.Element:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  return self:render_children(item, context)
end

function Node.Element:render_children(item, context)
  local output = {}
  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if Node[element_name] == nil then
        util.warning("Unkown type \"" .. element_name .. "\"")
      else
        local str = child:render(item, context)
        table.insert(output, str)
      end
    end
  end
  return self:join(output, context)
end

function Node.Element:make_base_class(node)
  if node:is_element() then
    local org_meta_table = getmetatable(node)
    local element_name = node:get_element_name()
    local element_class = Node[element_name]
    if element_class then
      setmetatable(node, {__index = function (_, key)
        if element_class[key] then
          return element_class[key]
        else
          return org_meta_table[key]
        end
      end})
    else
      util.warning("Unkown type \"" .. element_name .. "\"")
      setmetatable(node, {__index = function (_, key)
        if Node.Element[key] then
          return Node.Element[key]
        else
          return org_meta_table[key]
        end
      end})
    end
  end
end

function Node.Element:debug_info(context, debug)
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

function Node.Element:get_child(type)
  for _, child in ipairs(self:get_children()) do
    if child:get_element_name() == type then
      return child
    end
  end
  return nil
end

function Node.Element:get_style()
  -- TODO: get style from date in locale file
  local style = self:get_path("style")[1]
  if not style then
    style = self:root_node().style
  end
  assert(style ~= nil)
  return style
end

function Node.Element:get_engine()
  return self:get_style().engine
end

function Node.Element:get_term (name, form, lang)
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

function Node.Element:get_macro (name)
  local query = string.format("macro[name=\"%s\"]", name)
  local macro = self:root_node():query_selector(query)[1]
  if not macro then
    error(string.format("Failed to find %s.", query))
  end
  return macro
end

function Node.Element:set_default_options(options)
  self.default_options = options
end

function Node.Element:process_context(context)
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

Node.Element.get_locale_option = function (self, key)
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
function Node.Element:format (str, context)
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
      local formatter = context.engine.formatter[key]
      if formatter then
        if type(formatter) == "string" then
          str = string.gsub(formatter, "%%%%STRING%%%%", str)
        elseif type(formatter) == "function" then
          str = formatter(str)
        end
      end
    end
  end
  return str
end

-- Affixes
function Node.Element:wrap (str, context)
  if not str then
    return nil
  end
  local prefix = context['prefix'] or ""
  local suffix = context['suffix'] or ""
  local res = prefix .. str
  res = self:concat(res, suffix, context)
  return res
end

function Node.Element:concat (str1, str2, context)
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
        if  util.endswith(str1, close_quote) then
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

-- Delimiters
function Node.Element:join (strings, context)
  assert(type(strings) == "table")
  local delimiter = context["delimiter"] or ""
  -- return util.join_non_empty(strings, delimiter)
  -- TODO: replace every join(outputs) to join(res, child:render())
  local res = nil
  for _, string in ipairs(strings) do

    if string and string ~= "" then
      if res then
        if delimiter and delimiter ~= "" then
          res = self:concat(res, delimiter, context)
        end
        res = res .. string
      else
        res = string
      end
    end
  end
  return res
end

-- Quotes
function Node.Element:quote (str, context)
  local quotes = context["quotes"] or false
  if quotes then
    local open_quote = self:get_term("open-quote"):render(context)
    local close_quote = self:get_term("close-quote"):render(context)
    str = open_quote .. str .. close_quote
  end
  return str
end

-- Text-case
function Node.Element:case (str, context)
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
    return string.upper(str)
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


Node.style = Node.Element:new()

Node.style:set_default_options({
  rendered_quoted_text = {},
  variable_attempt = {},
})

function Node.style:render_citation (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  local citation = self:get_child("citation")
  return citation:render(items, context)
end

function Node.style:render_biblography (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local bibliography = self:get_child("bibliography")
  return bibliography:render(item, context)
end

function Node.style:get_locales (lang)
  lang = lang or self:get_attribute("default-locale") or "en-US"

  if not self.locale_dict then
    self.locale_dict = {}
  end
  local locales = self.locale_dict[lang]
  if not locales then
    locales = self:get_locale_list(lang)
    self.locale_dict[lang] = locales
  end
  return locales
end

function Node.style:get_locale_list (lang)
  assert(lang ~= nil)
  local language = util.split(lang, '-')[1]
  local primary_dialect = util.primary_dialects[language]
  if not primary_dialect then
    util.warning(string.format("Failed to find primary dialect of \"%s\"", language))
  end
  local locale_list = {}
  -- In-style cs:locale elements
  -- xml:lang set to chosen dialect, “de-AT”
  if lang == language then
    lang = primary_dialect
  end
  -- LuaXML v0.1o does not support colons in attribute selectors
  -- local query = string.format("locale[xml:lang=\"%s\"]", lang)
  -- local locale = self:query_selector(query)[1]
  if lang then
    for _, locale in ipairs(self:query_selector("locale")) do
      if locale:get_attribute("xml:lang") == lang then
        table.insert(locale_list, locale)
        break
      end
    end
  end
  -- xml:lang set to matching language, “de” (German)
  if language and language ~= lang then
    -- query = string.format("locale[xml:lang=\"%s\"]", language)
    -- locale = self:query_selector(query)[1]
    for _, locale in ipairs(self:query_selector("locale")) do
      if locale:get_attribute("xml:lang") == language then
        table.insert(locale_list, locale)
      end
    end
  end
  -- xml:lang not set
  for _, locale in ipairs(self:query_selector("locale")) do
    if locale:get_attribute("xml:lang") == nil then
      table.insert(locale_list, locale)
      break
    end
  end
  -- Locale files
  -- xml:lang set to chosen dialect, “de-AT”
  if lang then
    local locale = self:get_system_locale(lang)
    if locale then
      table.insert(locale_list, locale)
    end
  end
  -- xml:lang set to matching primary dialect, “de-DE” (Standard German) (only applicable when the chosen locale is a secondary dialect)
  if primary_dialect and primary_dialect ~= lang then
    local locale = self:get_system_locale(primary_dialect)
    if locale then
      table.insert(locale_list, locale)
    end
  end
  -- xml:lang set to “en-US” (American English)
  if lang ~= "en-US" and primary_dialect ~= "en-US" then
    local locale = self:get_system_locale("en-US")
    if locale then
      table.insert(locale_list, locale)
    end
  end
  return locale_list
end

function Node.style:get_system_locale (lang)
  if not self.system_locales then
    self.system_locales = {}
  end
  local locale = self.system_locales[lang]
  if not locale then
    locale = self.engine.sys:retrieveLocale(lang)
    if not locale then
      util.warning(string.format("Failed to retrieve locale \"%s\"", lang))
      return nil
    end
    if type(locale) == "string" then
      locale = dom.parse(locale)
    end
    locale:root_node().style = self
    locale:traverse_elements(function (node)
      Node.Element:make_base_class(node)
    end)
    self.system_locales[lang] = locale
  end
  return locale
end

Node.info = Node.Element:new()

Node.author = Node.Element:new()
Node.contributor = Node.Element:new()

Node.category = Node.Element:new()

Node.id = Node.Element:new()

Node.issn = Node.Element:new()
Node.eissn = Node.Element:new()
Node.issnl = Node.Element:new()

Node.link = Node.Element:new()

Node.published = Node.Element:new()

Node.rights = Node.Element:new()

Node.summary = Node.Element:new()

Node.title = Node.Element:new()

Node["title-short"] = Node.Element:new()

Node.updated = Node.Element:new()

-- Node.name = Node.Element:new()
Node.email = Node.Element:new()
Node.uri = Node.Element:new()

Node.locale = Node.Element:new()

function Node.locale:get_option(key)
  local query = string.format("style-options[%s]", key)
  local option = self:query_selector(query)[1]
  if option then
    return option:get_attribute(key)
  else
    return nil
  end
end

Node.translator = Node.Element:new()

Node["style-options"] = Node.Element:new()

Node.terms = Node.Element:new()

Node.term = Node.Element:new()

function Node.term:render (context, is_plural)
  self:debug_info(context)
  local output = {
    single = self:get_text(),
  }
  for _, child in ipairs(self:get_children()) do
    if child:is_element() then
      output[child:get_element_name()] = context.engine.formatter.text_escape(child:get_text())
    end
  end
  local res = output.single
  if is_plural then
    if output.multiple then
      res = output.multiple
    end
  end
  res = context.engine.formatter.text_escape(res)
  return res
end


Node.single = Node.Element:new()
Node.multiple = Node.Element:new()


Node.macro = Node.Element:new()


Node.citation = Node.Element:new()

function Node.citation:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  local sort = self:get_child("sort")
  local layout = self:get_child("layout")
  -- util.debug(inspect(items))
  if sort then
    sort:sort(items, context)
  end
  -- util.debug(inspect(items))
  return layout:render_citation(items, context)
end


Node.bibliography = Node.Element:new()

function Node.bibliography:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local layout = self:get_child("layout")
  return layout:render(item, context)
end


Node.layout = Node.Element:new()

function Node.layout:render_citation (items, context)
  self:debug_info(context)
  local output = {}
  for _, item in pairs(items) do
    context.item = item
    local res = self:render_children(item, context)
    if res then
      table.insert(output, res)
    end
  end
  if next(output) == nil then
    return "[CSL STYLE ERROR: reference with no printed form.]"
  end
  -- When used within cs:citation, the delimiter attribute may be used to specify a delimiter for cites within a citation.
  -- Thus the processing of context is put after render_children().
  context = self:process_context(context)

  local res = self:join(output, context)
  res = self:wrap(res, context)
  res = self:format(res, context)
  return res
end


Node.text = Node.Element:new()

function Node.text:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local res = nil

  local variable_name = self:get_attribute("variable")
  if variable_name then
    local form = self:get_attribute("form")
    if form == "short" then
      variable_name = variable_name .. "-" .. form
    end
    res = item[variable_name]
    if res then
      res = tostring(res)
      if variable_name == "page" then
        local page_range_delimiter = self:get_term("page-range-delimiter"):render(context) or util.unicode["en dash"]
        res = string.gsub(res, "-", page_range_delimiter, 1)
      end
    end

    table.insert(context.variable_attempt, res ~= nil)
  end

  local macro_name = self:get_attribute("macro")
  if macro_name then
    local macro = self:get_macro(macro_name)
    res = macro:render(item, context)
  end

  local term_name = self:get_attribute("term")
  if term_name then
    local form = self:get_attribute("form")

    local term = self:get_term(term_name, form)
    if term then
      res = term:render(context)
    end
  end

  local value = self:get_attribute("value")
  if value then
    res = value
    res = context.engine.formatter.text_escape(res)
  end

  if res and context["quotes"] then
    table.insert(context.rendered_quoted_text, true)
  else
    table.insert(context.rendered_quoted_text, false)
  end

  res = self:case(res, context)
  res = self:format(res, context)
  res = self:quote(res, context)
  res = self:wrap(res, context)

  return res
end


Node.date = Node.Element:new()

function Node.date:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local variable_name = context["variable"]

  local date = item[variable_name]
  if not date then
    return nil
  end

  local res = nil
  local form = context["form"]
  if form and not context.is_locale_date then
    context.is_locale_date = true
    for _, date_part in ipairs(self:query_selector("date-part")) do
      local name = date_part:get_attribute("name")
      if not context.date_part_attributes then
        context.date_part_attributes = {}
      end
      if not context.date_part_attributes[name] then
        context.date_part_attributes[name] = {}
      end

      for attr, value in pairs(date_part._attr) do
        if attr ~= name then
          context.date_part_attributes[name][attr] = value
        end
      end
    end
    res = self:get_locale_date(form):render(item, context)
  else
    if #date["date-parts"] == 0 then
      local literal = date["literal"]
      if literal then
        res = literal
      else
        local raw = date["raw"]
        if raw then
          res = raw
        end
      end

    else
      if #date["date-parts"] == 1 then
        res = self:_render_single_date(date, context)
      elseif #date["date-parts"] == 2 then
        res = self:_render_date_range(date, context)
      end
    end
  end

  table.insert(context.variable_attempt, res ~= nil)
  table.insert(context.rendered_quoted_text, false)

  res = self:format(res, context)
  res = self:wrap(res, context)
  return res
end

function Node.date:get_locale_date (form, lang)
  local date = nil
  local style = self:get_style()
  local query = string.format("date[form=\"%s\"]", form)
  for _, locale in ipairs(style:get_locales(lang)) do
    date = locale:query_selector(query)[1]
    if date then
      break
    end
  end
  if not date then
    error(string.format("Failed to find '%s'", query))
  end
  return date
end

function Node.date:_render_single_date (date, context)
  local show_parts = self:_get_show_parts(context)

  local output = {}
  for _, child in ipairs(self:query_selector("date-part")) do
    if show_parts[child:get_attribute("name")] then
      table.insert(output, child:render(date, context))
    end
  end
  return self:join(output, context)
end

function Node.date:_render_date_range (date, context)
  local show_parts = self:_get_show_parts(context)
  local part_index = {}

  local largest_diff_part = nil
  for i, name in ipairs({"year", "month", "day"}) do
    part_index[name] = i
    local part_value1 = date["date-parts"][1][i]
    if show_parts[name] and part_value1 then
      if not largest_diff_part then
        largest_diff_part = name
      end
    end
  end

  local date_parts = {}
  for _, date_part in ipairs(self:query_selector("date-part")) do
    if show_parts[date_part:get_attribute("name")] then
      table.insert(date_parts, date_part)
    end
  end

  local diff_begin = 0
  local diff_end = #date_parts
  local range_delimiter = nil

  for i, date_part in ipairs(date_parts) do
    local name = date_part:get_attribute("name")
    if name == largest_diff_part then
      range_delimiter = date_part:get_attribute("range-delimiter")
      if not range_delimiter then
        range_delimiter = util.unicode["en dash"]
      end
    end

    local index = part_index[name]
    local part_value1 = date["date-parts"][1][index]
    local part_value2 = date["date-parts"][2][index]
    if part_value1 and part_value1 ~= part_value2 then
      if diff_begin == 0 then
        diff_begin = i
      end
      diff_end = i
    end
  end

  local same_prefix = {}
  local range_begin = {}
  local range_end = {}
  local same_suffix = {}

  local no_suffix_context = self:process_context(context)
  no_suffix_context["suffix"] = nil

  for i, date_part in ipairs(date_parts) do
    local res = nil
    if i == diff_end then
      res = date_part:render(date, no_suffix_context, true)
    else
      res = date_part:render(date, context)
    end
    if i < diff_begin then
      table.insert(same_prefix, res)
    elseif i <= diff_end then
      table.insert(range_begin, res)
      table.insert(range_end, date_part:render(date, context, false, true))
    else
      table.insert(same_suffix, res)
    end
  end

  -- util.debug(inspect(same_prefix))
  -- util.debug(inspect(range_begin))
  -- util.debug(inspect(range_end))
  -- util.debug(inspect(same_suffix))

  local prefix_output = self:join(same_prefix, context) or ""
  local range_begin_output = self:join(range_begin, context) or ""
  local range_end_output = self:join(range_end, context) or ""
  local suffix_output = self:join(same_suffix, context)
  local range_output = range_begin_output .. range_delimiter .. range_end_output

  local res = self:join({prefix_output, range_output, suffix_output}, context)

  return res
end

function Node.date:_get_show_parts (context)
  local show_parts = {}
  local date_parts = context["date-parts"] or "year-month-day"
  for _, date_part in ipairs(util.split(date_parts, "-")) do
    show_parts[date_part] = true
  end
  return show_parts
end

Node["date-part"] = Node.Element:new()

Node["date-part"].render = function (self, date, context, last_range_begin, range_end)
  -- util.debug(self:get_info())
  context = self:process_context(context)
  local name = context["name"]
  local range_delimiter = context["range-delimiter"] or false

  -- The attributes set on cs:date-part elements of a cs:date with form
  -- attribute override those specified for the localized date formats
  if context.date_part_attributes then
    local context_attributes = context.date_part_attributes[name]
    if context_attributes then
      for attr, value in pairs(context_attributes) do
        context[attr] = value
      end
    end
  end

  if last_range_begin then
    context["suffix"] = ""
  end

  local date_parts_index = 1
  if range_end then
    date_parts_index = 2
  end

  local res = nil
  if name == "day" then
    local day = date["date-parts"][date_parts_index][3]
    if not day then
      return nil
    end
    day = tonumber(day)
    -- range open
    if day == 0 then
      return nil
    end
    local form = context["form"] or "numeric"

    if form == "ordinal" then
      local option = self:get_locale_option('limit-day-ordinals-to-day-1')
      if option and option ~= "false" and day > 1 then
        form = "numeric"
      end
    end
    if form == "numeric" then
      res = tostring(day)
    elseif form == "numeric-leading-zeros" then
      res = string.format("%02d", day)
    elseif form == "ordinal" then
      res = util.to_ordinal(day)
    end

  elseif name == "month" then
    local form = context["form"] or "long"
    local strip_periods = context["strip-periods"] or false

    local month = date["date-parts"][date_parts_index][2]
    if month then
      month = tonumber(month)
      -- range open
      if month == 0 then
        return nil
      end
    end

    if form == "long" or form == "short" then
      local term_name = nil
      if month then
        if month >= 1 and month <= 12 then
          term_name = string.format("month-%02d", month)
        elseif month >= 13 and month <= 24 then
          local season = month % 4
          if season == 0 then
            season = 4
          end
          term_name = string.format("season-%02d", season)
        else
          util.warning("Invalid month value")
          return nil
        end
      else
        local season = date["season"]
        if season then
          season = tonumber(season)
          term_name = string.format("season-%02d", season)
        else
          return nil
        end
      end
      res = self:get_term(term_name, form):render(context)
    elseif form == "numeric" then
      res = tostring(month)
    elseif form == "numeric-leading-zeros" then
      res = string.format("%02d", month)
    end

  elseif name == "year" then
    local year = date["date-parts"][date_parts_index][1]
    if year then
      year = tonumber(year)
      -- range open
      if year == 0 then
        return nil
      end
      local form = context["form"] or "long"
      if form == "long" then
        year = tonumber(year)
        if year < 0 then
          res = tostring(-year) .. self:get_term("bc"):render(context)
        elseif year < 1000 then
          res = tostring(year) .. self:get_term("ad"):render(context)
        else
          res = tostring(year)
        end
      elseif form == "short" then
        res = string.sub(tostring(year), -2)
      end
    end
  end
  res = self:case(res, context)
  res = self:format(res, context)
  res = self:wrap(res, context)
  return res
end


Node.number = Node.Element:new()

function Node.number:render (item, context)
  context = self:process_context(context)
  local form = context["form"] or "numeric"
  local variable = item[context["variable"]]

  table.insert(context.variable_attempt, variable ~= nil)
  table.insert(context.rendered_quoted_text, false)

  local text = ""
  if form == "numeric" then
    text = tostring(variable)
  elseif form == "ordinal" then
    text = util.to_ordinal(variable)
  elseif form == "long-ordinal" then
    text = tostring(variable)
  elseif form == "roman" then
    text = tostring(variable)
  end
  return text
end


Node.names = Node.Element:new()

function Node.names:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local et_al = self:get_child("et-al")
  if et_al == nil then
    et_al = self:create_element("et-al", {}, self)
    Node.Element:make_base_class(et_al)
  end
  et_al = et_al:render(item, context)
  context.et_al = et_al

  local name = self:get_child("name")
  if name == nil then
    name = self:create_element("name", {}, self)
    Node.Element:make_base_class(name)
  end

  local label = self:get_child("label")

  local output = {}
  for _, role in ipairs(util.split(context["variable"])) do
    local names = item[role]

    table.insert(context.variable_attempt, names ~= nil)

    if names then
      local res = name:render(names, context)
      if res and label then
        local label_result = label:render(item, context)
        if label_result then
          res = res .. label_result
        end
      end
      table.insert(output, res)
    end
  end

  local res = self:join(output, context)

  table.insert(context.rendered_quoted_text, false)

  if res then
    return res
  else
    local substitute = self:get_child("substitute")
    if substitute then
      return substitute:render(item, context)
    else
      return nil
    end
  end
end


Node.name = Node.Element:new()

Node.name:set_default_options({
  ["and"] = "text",
  ["delimiter"] = ", ",
  ["delimiter-precedes-et-al"] = "contextual",
  ["delimiter-precedes-last"] = "contextual",
  ["et-al-min"] = 0,
  ["et-al-use-first"] = 0,
  ["et-al-subsequent-min"] = 0,
  ["et-al-subsequent-use-first "] = 0,
  ["et-al-use-last"] = false,
  ["form"] = "long",
  ["initialize"] = true,
  ["initialize-with"] = false,
  ["name-as-sort-order"] = false,
  ["sort-separator"] = ", ",
  ["prefix"] = "",
  ["suffix"] = "",
})

function Node.name:render (names, context)
  self:debug_info(context)
  context = self:process_context(context)
  local and_ = context["and"]
  local delimiter = context["delimiter"]
  local delimiter_precedes_et_al = context["delimiter-precedes-et-al"]
  local delimiter_precedes_last = context["delimiter-precedes-last"]
  local et_al_min = context["et-al-min"]
  local et_al_use_first = context["et-al-use-first"]
  local et_al_subsequent_min = context["et-al-subsequent-min"]
  local et_al_subsequent_use_first = context["et-al-subsequent-use-first "]
  local opt_et_al_use_last = context["et-al-use-last"]

  local form = context["form"]
  local initialize = context["initialize"]
  local initialize_with = context["initialize-with"]
  local name_as_sort_order = context["name-as-sort-order"]
  local sort_separator = context["sort-separator"]

  local output = {}
  local et_al_truncate = false
  if et_al_min > 0 and #names >= et_al_min and et_al_use_first > 0 then
    et_al_truncate = true
    names = util.slice(names, 1, et_al_use_first)
  end

  if form == "count" then
    return tostring(#names)
  end

  for i, name in ipairs(names) do
    local given = name["given"] or ""
    local family = name["family"] or ""
    local suffix = name["suffix"] or ""

    if initialize and initialize_with then
      given = util.initialize(given, initialize_with)
    end

    for _, child in ipairs(self:get_children()) do
      if child:is_element() and child:get_element_name() == "name-part" then
        family, given = child:format_parts(family, given)
      end
    end

    local order = {given, family, suffix}
    local res
    if form == "long" then
      if (name_as_sort_order == 'all' or (name_as_sort_order == 'first' and i == 1)) then
        order = {family, given, suffix}
        res = util.join_non_empty(order, sort_separator)
      else
        order = {given, family}
        res = util.join_non_empty(order, " ")
        if name["comma-suffix"] then
          res = util.join_non_empty({res, suffix}, ", ")
        else
          res = util.join_non_empty({res, suffix}, " ")
        end
      end
    elseif form == "short" then
      res = family
    else
      error("Invalid \"form\" attribute of \"name\".")
    end
    table.insert(output, res)
  end

  local ret = nil

  if et_al_truncate then
    local et_al = context.et_al
    ret = self:join(output, context)
    if et_al ~= "" then
      if (delimiter_precedes_et_al == 'always' or
        (delimiter_precedes_et_al == 'contextual' and
        #(output) > 1)) then
        ret = ret .. delimiter .. et_al
      else
        ret = ret .. " " .. et_al
      end
    end
  elseif #output > 1 then
    ret = self:join(util.slice(output, 1, -2), context)
    if delimiter_precedes_last == "always" or (#output > 2 and delimiter_precedes_last == "contextual") then
      ret = ret .. delimiter
    else
      ret = ret .. " "
    end
    local and_term = ""
    if context["and"] == "text" then
      and_term = self:get_term("and"):render(context)
    elseif context["and"] == "symbol" then
      and_term = context.engine.formatter.text_escape("&")
    end
    ret = ret .. and_term .. " " .. output[#output]
  else
    ret = output[1]
  end

  ret = string.gsub(ret, "(%a)'(%a)", "%1" .. util.unicode["apostrophe"] .. "%2")

  ret = self:wrap(ret, context)
  ret = self:format(ret, context)
  return ret
end


Node["name-part"] = Node.Element:new()

Node["name-part"].format_parts = function (self, family, given)
  local context = self:process_context()
  local name = context["name"]
  local has_formatting_attributes = false
  for key, value in pairs(self._attr) do
    if key ~= "name" then
      has_formatting_attributes = true
      break
    end
  end
  if not has_formatting_attributes then
    util.warning("Invalid attribute of \"date-part\"")
  end
  if name == "family" then
    if not has_formatting_attributes then
      family = ""
    else
      family = self:case(family, context)
      family = self:wrap(family, context)
      family = self:format(family, context)
    end
  elseif name == "given" then
    if not has_formatting_attributes then
      given = ""
    else
      given = self:case(given, context)
      given = self:format(given, context)
      given = self:wrap(given, context)
    end
  end
  return family, given
end


Node["et-al"] = Node.Element:new()

Node["et-al"]:set_default_options({
  term = "et-al",
})

Node["et-al"].render = function (self, item, context)
  context = self:process_context(context)
  local res = self:get_term(context["term"]):render(context)
  res = self:format(res, context)
  return res
end


Node.substitute = Node.Element:new()

function Node.substitute:render (item, context)
  self:debug_info(context)
  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local result = child:render(item, context)
      if result and result ~= "" then
        return result
      end
    end
  end
  return nil
end


Node.label = Node.Element:new()

function Node.label:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local variable_name = context["variable"]
  local form = context["form"]
  local plural = context["plural"] or "contextual"

  local term = self:get_term(variable_name, form)
  local res = nil
  if term then
    if plural == "contextual" and self:_is_plural(item, context) or plural == "always" then
      res = term:render(context, true)
    else
      res = term:render(context, false)
    end

    res = self:case(res, context)
    res = self:format(res, context)
    res = self:wrap(res, context)
  end
  return res
end

function Node.label:_is_plural (item, context)
  local variable_name = context["variable"]
  local variable_type = util.variable_types[variable_name]
  local value = item[variable_name]
  local res =false
  if variable_type == "name" then
    res = #value > 1
  elseif variable_type == "number" then
    if util.startswith(variable_name, "number-of-") then
      res = tonumber(value) > 1
    else
      res = string.match(tostring(value), "%d+%D+%d+") ~= nil
    end
  else
    util.warning("Invalid attribute \"variable\".")
  end
  return res
end


Node.group = Node.Element:new()

function Node.group:render (item, context)
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
  return res
end


Node.choose = Node.Element:new()

function Node.choose:render(item, context)
  self:debug_info(context)
  context = self:process_context(context)
  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local result, status = child:render(item, context)
      if status then
        return result
      end
    end
  end
  return nil
end


Node["if"] = Node.Element:new()

Node["if"].render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  local results = {}

  local variable_names = context["is-numeric"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      table.insert(results, util.is_numeric(variable))
    end
  end

  variable_names = context["is-uncertain-date"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      table.insert(results, util.is_uncertain_date(variable))
    end
  end

  local position = context["position"]
  if position then
    -- TODO:
    table.insert(results, position == "first")
  end

  local type_names = context["type"]
  if type_names then
    for _, type_name in ipairs(util.split(type_names)) do
      table.insert(results, item["type"] == type_name)
    end
  end

  variable_names = context["variable"]
  if variable_names then
    for _, variable_name in ipairs(util.split(variable_names)) do
      local variable = item[variable_name]
      local res = (variable ~= nil and variable ~= "")
      table.insert(results, res)
    end
  end

  local match = context["match"] or "all"
  local status = false
  if match == "any" then
    status = util.any(results)
  elseif match == "none" then
    status = not util.any(results)
  else
    status = util.all(results)
  end
  if status then
    return self:render_children(item, context), status
  else
    return nil, false
  end
end


Node["else-if"] = Node["if"]:new()


Node["else"] = Node.Element:new()

Node["else"].render = function (self, item, context)
  self:debug_info(context)
  context = self:process_context(context)
  return self:render_children(item, context), true
end


Node.sort = Node.Element:new()

function Node.sort:sort (items, context)
  local key_dict = {}
  for _, item in ipairs(items) do
    key_dict[item.id] = {}
  end
  local descendings = {}
  for i, key in ipairs(self:query_selector("key")) do
    local descending = key:get_attribute("sort") == "descending"

    table.insert(descendings, descending)
    for _, item in ipairs(items) do
      context.item = item
      local value = key:render(item, context)
      -- util.debug(value)
      if value == nil then
        value = false
      end
      table.insert(key_dict[item.id], value)
    end
  end
  local compare_entry = function (item1, item2)
    for i, value1 in ipairs(key_dict[item1.id]) do
      local descending = descendings[i]
      local value2 = key_dict[item2.id][i]
      if value1 and value2 then
        if value1 < value2 then
          if descending then
            return false
          else
            return true
          end
        elseif value1 > value2 then
          if descending then
            return true
          else
            return false
          end
        end
      elseif value1 then
        return true
      elseif value2 then
        return false
      end
    end
  end
  table.sort(items, compare_entry)
  return items
end


Node.key = Node.Element:new()

function Node.key:render (item, context)
  context = self:process_context(context)
  local variable = self:get_attribute("variable")
  if variable then
    local variable_type = util.variable_types[variable]
    if variable_type == "name" then
      return self:_render_name(item, context)
    elseif variable_type == "date" then
      return self:_render_date(item, context)
    elseif variable_type == "number" then
      return item[variable]
    else
      return item[variable]
    end
  else
    local macro = self:get_attribute("macro")
    if macro then
      return self:get_macro(macro):render(item, context)
    end
  end
end

function Node.key:_render_name (item, context)
  if not self.names then
    self.names = self:create_element("names", {}, self)
    Node.Element:make_base_class(self.names)
  end
  context["form"] = "long"
  context["name-as-sort-order"] = "all"
  return self.names:render(item, context)
end

function Node.key:_render_date (item, context)
  local variable = item[context["variable"]]
  if not variable then
    return nil
  end
  local date_parts = variable["date-parts"][1]
  local date_parts_number = {}
  for i = 1, 3 do
    local number = 0
    if date_parts[i] then
      number = tonumber(date_parts[i])
    end
    table.insert(date_parts_number, number)
  end
  local year, month, day = table.unpack(date_parts_number)
  return string.format("%05d%02d%02d", year + 10000, month, day)
end


return Node
