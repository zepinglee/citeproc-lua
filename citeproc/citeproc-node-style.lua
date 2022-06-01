--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style = {}

local dom = require("luaxml-domobject")

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local util = require("citeproc-util")


local Style = Element:derive("style")

function Style:new()
  local o = Element:new()
  o.children = {}
  o.macros = {}
  o.locales = {}
  o.initialize_with_hyphen = true
  o.demote_non_dropping_particle = "display-and-sort"
  return o
end

function Style:parse(xml_str)
  local csl_xml = dom.parse(xml_str)
  if not csl_xml then
    error("Failed to parse CSL style.")
  end
  local style_node = csl_xml:get_path("style")[1]
  if not csl_xml then
    error('Element "style" not found.')
  end
  return Style:from_node(style_node)
end

function Style:from_node(node)
  local o = Style:new()
  o.children = {}

  o:set_attribute(node, "class")
  o:set_attribute(node, "default-locale")
  o:set_attribute(node, "version")

  o.macros = {}
  o.locales = {}

  o:process_children_nodes(node)

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "info" then
      o.info = child
    elseif element_name == "citation" then
      o.citation = child
    elseif element_name == "bibliography" then
      o.bibliography = child
    elseif element_name == "macro" then
      o.macros[child.name] = child
    elseif element_name == "locale" then
      local xml_lang = child.xml_lang or "generic"
      o.locales[xml_lang] = child
    end
  end

  -- Global Options
  o:set_bool_attribute(node, "initialize-with-hyphen")
  o:set_attribute(node, "demote-non-dropping-particle")

  return o
end


Style._default_options = {
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


local Info = Element:derive("info")


function Info:from_node(node)
  local o = Info:new()

  -- o.authors = nil
  -- o.contributors = nil
  o.categories = {}
  o.id = nil
  -- o.issn = nil
  -- o.eissn = nil
  -- o.issnl = nil
  o.links = {
    independent_parent = nil,
  }
  -- o.published = nil
  -- o.rights = nil
  -- o.summary = nil
  o.title = nil
  -- o.title_short = nil
  o.updated = nil

  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "category" then
        local citation_format = child:get_attribute("citation-format")
        if citation_format then
          o.categories.citation_format = citation_format
        end

      elseif element_name == "id" then
        o.id = child:get_text()

      elseif element_name == "link" then
        local href = child:get_attribute("href")
        local rel = child:get_attribute("rel")
        if href and rel == "independent-parent" then
          o.links.independent_parent = href
        end

      elseif element_name == "title" then
        o.title = child:get_text()

      elseif element_name == "updated" then
        o.updated = child:get_text()

      end
    end
  end

  return o
end


local Citation = Element:derive("citation")

function Citation:from_node(node)
  local o = Citation:new()
  o.children = {}

  o:process_children_nodes(node)

  -- o.layouts = nil  -- CSL-M extension

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      o.layout = child
    elseif element_name == "sort" then
      o.sort = child
    end
  end

  -- Disambiguation
  o:set_bool_attribute(node, "disambiguate-add-givenname")
  o:set_attribute(node, "givenname-disambiguation-rule")
  o:set_bool_attribute(node, "disambiguate-add-names")
  o:set_bool_attribute(node, "disambiguate-add-year-suffix")

  -- Cite Grouping
  o:set_attribute(node, "cite-group-delimiter")

  -- Cite Collapsing
  o:set_attribute(node, "collapse")
  o:set_attribute(node, "year-suffix-delimiter")
  o:set_attribute(node, "after-collapse-delimiter")

  -- Note Distance
  o:set_bool_attribute(node, "disambiguate-add-names")

  -- Inheritable Name Options
  -- o.name_inheritance = nil
  -- o.names_delimiter = nil

  return o
end

function Citation:build_ir(engine, state, context)
  if not self.layout then
    util.error("Missing citation layout.")
  end
  return self.layout:build_ir(engine, state, context)
end

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


local Bibliography = Element:derive("citation")

function Bibliography:from_node(node)
  local o = Bibliography:new()
  o.children = {}

  o:process_children_nodes(node)

  -- o.layouts = nil  -- CSL-M extension

  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      o.layout = child
    elseif element_name == "sort" then
      o.sort = child
    end
  end

  -- Whitespace
  o:set_bool_attribute(node, "hanging-indent")
  o:set_attribute(node, "second-field-align")
  o:set_attribute(node, "line-spacing")
  o:set_attribute(node, "entry-spacing")

  -- Reference Grouping
  o:set_attribute(node, "subsequent-author-substitute")
  o:set_attribute(node, "subsequent-author-substitute-rule")

  return o
end

Bibliography._default_options = {
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


local Macro = Element:derive("macro")

function Macro:from_node(node)
  local o = Macro:new()
  o.children = {}
  o:set_attribute(node, "name")
  o:process_children_nodes(node)
  return o
end


style.Style = Style
style.Citation = Citation
style.Bibliography = Bibliography


return style
