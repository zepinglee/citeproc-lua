local style = {}

local element = require("citeproc.citeproc-element")
local util = require("citeproc.citeproc-util")


local Style = element.Element:new()

Style.default_options = {
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
}

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

function Style:get_locales (lang)
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

function Style:get_locale_list (lang)
  assert(lang ~= nil)
  local language = string.sub(lang, 1, 2)
  local primary_dialect = util.primary_dialects[language]
  if not primary_dialect then
    -- context.engine:warning(string.format("Failed to find primary dialect of \"%s\"", language))
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

  local sort = self:get_child("sort")
  if sort then
    sort:sort(items, context)
  end

  local layout = self:get_child("layout")
  return layout:render(items, context)
end


local Bibliography = element.Element:new()

function Bibliography:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)

  context.mode = "bibliography"

  -- Already sorted in CiteProc:sort_bibliography()

  local layout = self:get_child("layout")
  return layout:render(items, context)
end

style.Style = Style
style.Citation = Citation
style.Bibliography = Bibliography


return style
