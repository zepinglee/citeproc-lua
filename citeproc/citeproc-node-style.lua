--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style_module = {}

local dom = require("luaxml-domobject")

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-ir-node").IrNode
local util = require("citeproc-util")


local Style = Element:derive("style")

function Style:new()
  local o = {
    children = {},
    macros = {},
    locales = {},
    initialize_with_hyphen = true,
    demote_non_dropping_particle = "display-and-sort",
  }
  setmetatable(o, self)
  self.__index = self
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

local function make_name_inheritance(name, node)
  name:set_attribute(node, "and")
  name:set_attribute(node, "delimiter-precedes-et-al")
  name:set_attribute(node, "delimiter-precedes-last")
  name:set_number_attribute(node, "et-al-min")
  name:set_number_attribute(node, "et-al-use-first")
  name:set_number_attribute(node, "et-al-subsequent-min")
  name:set_number_attribute(node, "et-al-subsequent-use-first")
  name:set_bool_attribute(node, "et-al-use-last")
  name:set_bool_attribute(node, "initialize")
  name:set_attribute(node, "initialize-with")
  name:set_attribute(node, "name-as-sort-order")
  name:set_attribute(node, "sort-separator")
  name.delimiter = node:get_attribute("name-delimiter")
  name.form = node:get_attribute("name-form")
  name.names_delimiter = node:get_attribute("names-delimiter")
end

function Style:from_node(node)
  local o = Style:new()

  o:set_attribute(node, "class")
  o:set_attribute(node, "default-locale")
  o:set_attribute(node, "version")

  -- Global Options
  o.initialize_with_hyphen = true
  o:set_bool_attribute(node, "initialize-with-hyphen")
  o:set_attribute(node, "page-range-format")
  o:set_attribute(node, "demote-non-dropping-particle")

  -- Inheritable Name Options
  -- https://docs.citationstyles.org/en/stable/specification.html#inheritable-name-options
  o.name_inheritance = require("citeproc-node-names").Name:new()
  make_name_inheritance(o.name_inheritance, node)

  if o.page_range_format == "chicago" then
    if o.version < "1.1" then
      o.page_range_format = "chicago-15"
    else
      o.page_range_format = "chicago-16"
    end
  end

  o.macros = {}
  o.locales = {}

  o.children = {}
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
      local xml_lang = child.xml_lang or "@generic"
      o.locales[xml_lang] = child
    end
  end

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

function Citation:from_node(node, style)

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

  local name_inheritance = require("citeproc-node-names").Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

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


local Bibliography = Element:derive("bibliography")

function Bibliography:from_node(node, style)
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

  local name_inheritance = require("citeproc-node-names").Name:new()
  for key, value in pairs(style.name_inheritance) do
    if value ~= nil then
      name_inheritance[key] = value
    end
  end
  make_name_inheritance(name_inheritance, node)
  o.name_inheritance = name_inheritance

  return o
end

function Bibliography:build_ir(engine, state, context)
  if not self.layout then
    util.error("Missing citation layout.")
  end
  return self.layout:build_ir(engine, state, context)
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


style_module.Style = Style
style_module.Citation = Citation
style_module.Bibliography = Bibliography


return style_module
