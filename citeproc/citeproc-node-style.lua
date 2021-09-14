local dom = require("luaxml-domobject")

local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Style = Element:new()

Style:set_default_options({
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
  rendered_quoted_text = {},
  variable_attempt = {},
})

function Style:render_citation (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  local citation = self:get_child("citation")
  return citation:render(items, context)
end

function Style:render_biblography (items, context)
  self:debug_info(context)
  context = self:process_context(context)
  local bibliography = self:get_child("bibliography")
  return bibliography:render(items, context)
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
  local language = util.split(lang, '%-')[1]
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
    local locale = self:get_engine():get_system_locale(lang)
    if locale then
      table.insert(locale_list, locale)
    end
  end
  -- xml:lang set to matching primary dialect, “de-DE” (Standard German) (only applicable when the chosen locale is a secondary dialect)
  if primary_dialect and primary_dialect ~= lang then
    local locale = self:get_engine():get_system_locale(primary_dialect)
    if locale then
      table.insert(locale_list, locale)
    end
  end
  -- xml:lang set to “en-US” (American English)
  if lang ~= "en-US" and primary_dialect ~= "en-US" then
    local locale = self:get_engine():get_system_locale("en-US")
    if locale then
      table.insert(locale_list, locale)
    end
  end
  return locale_list
end


local Citation = Element:new()

function Citation:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)

  local sort = self:get_child("sort")
  if sort then
    sort:sort(items, context)
  end

  local layout = self:get_child("layout")
  return layout:render(items, context)
end


local Bibliography = Element:new()

function Bibliography:render (items, context)
  self:debug_info(context)
  context = self:process_context(context)

  local sort = self:get_child("sort")
  if sort then
    sort:sort(items, context)
  end

  local layout = self:get_child("layout")
  return layout:render(items, context)
end


return {
  style = Style,
  citation = Citation,
  bibliography = Bibliography,
}
