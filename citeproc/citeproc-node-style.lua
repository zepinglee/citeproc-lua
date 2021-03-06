--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style = {}

local element = require("citeproc-element")
local util = require("citeproc-util")


local Style = element.Element:new()

Style.default_options = {
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
}

function Style:set_lang(lang, force_lang)
  local default_locale = self:get_attribute("default-locale")
  if lang then
    if default_locale and not force_lang then
      self.lang = default_locale
    end
  else
    self.lang = default_locale or "en-US"
  end
end

function Style:render_citation (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  context.style = self
  local citation = self:get_child("citation")
  return citation:render(items, context)
end

function Style:render_biblography (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  context.style = self
  local bibliography = self:get_child("bibliography")
  return bibliography:render(items, context)
end

function Style:get_version ()
  return self:get_attribute("version")
end

function Style:get_locales()
  if not self.locale_dict then
    self.locale_dict = {}
  end
  local locales = self.locale_dict[self.lang]
  if not locales then
    locales = self:get_locale_list(self.lang)
    self.locale_dict[self.lang] = locales
  end
  return locales
end

function Style:get_locale_list (lang)
  assert(lang ~= nil)
  local language = string.sub(lang, 1, 2)
  local primary_dialect = util.primary_dialects[language]
  if not primary_dialect then
    -- util.warning(string.format("Failed to find primary dialect of \"%s\"", language))
  end
  local locale_list = {}

  -- 1. In-style cs:locale elements
  --    i. `xml:lang` set to chosen dialect, “de-AT”
  if lang == language then
    lang = primary_dialect
  end
  table.insert(locale_list, self:get_in_style_locale(lang))

  --    ii. `xml:lang` set to matching language, “de” (German)
  if language and language ~= lang then
    table.insert(locale_list, self:get_in_style_locale(language))
  end

  --    iii. `xml:lang` not set
  table.insert(locale_list, self:get_in_style_locale(nil))

  -- 2. Locale files
  --    iv. `xml:lang` set to chosen dialect, “de-AT”
  if lang then
    table.insert(locale_list, self:get_engine():get_system_locale(lang))
  end

  --    v. `xml:lang` set to matching primary dialect, “de-DE” (Standard German)
  --       (only applicable when the chosen locale is a secondary dialect)
  if primary_dialect and primary_dialect ~= lang then
    table.insert(locale_list, self:get_engine():get_system_locale(primary_dialect))
  end

  --    vi. `xml:lang` set to “en-US” (American English)
  if lang ~= "en-US" and primary_dialect ~= "en-US" then
    table.insert(locale_list, self:get_engine():get_system_locale("en-US"))
  end

  return locale_list
end

function Style:get_in_style_locale (lang)
  for _, locale in ipairs(self:query_selector("locale")) do
    if locale:get_attribute("xml:lang") == lang then
      return locale
    end
  end
  return nil
end

function Style:get_term (...)
  for _, locale in ipairs(self:get_locales()) do
    local res = locale:get_term(...)
    if res then
      return res
    end
  end
  return nil
end


local Citation = element.Element:new()

function Citation:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)

  context.mode = "citation"
  context.citation = self

  local sort = self:get_child("sort")
  if sort then
    sort:sort(items, context)
  end

  local layout = self:get_child("layout")
  return layout:render(items, context)
end


local Bibliography = element.Element:new()

Bibliography.default_options = {
  ["hanging-indent"] = false,
  ["second-field-align"] = nil,
  ["line-spacing"] = 1,
  ["entry-spacing"] = 1,
  ["subsequent-author-substitute"] = nil,
  ["subsequent-author-substitute-rule"] = "complete-all",
}

function Bibliography:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  -- util.debug(context)

  context.mode = "bibliography"
  context.bibliography = self

  -- Already sorted in CiteProc:sort_bibliography()

  local layout = self:get_child("layout")
  local res = layout:render(items, context)

  local params = res[1]

  params.entryspacing = context.options["entry-spacing"]
  params.linespacing = context.options["line-spacing"]
  params.hangingindent = context.options["hanging-indent"]
  params["second-field-align"] = context.options["second-field-align"]
  for _, key in ipairs({"bibstart", "bibend"}) do
    local value = context.engine.formatter[key]
    if type(value) == "function" then
      value = value(context)
    end
    params[key] = value
  end

  params.bibliography_errors = {}
  params.entry_ids = {}
  for _, item in ipairs(items) do
    table.insert(params.entry_ids, item.id)
  end

  return res
end

style.Style = Style
style.Citation = Citation
style.Bibliography = Bibliography


return style
