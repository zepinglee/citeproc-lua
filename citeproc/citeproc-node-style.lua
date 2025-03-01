--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local style_module = {}

local dom
local element
local node_names
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  dom = require("luaxml-domobject")
  element = require("citeproc-element")
  node_names = require("citeproc-node-names")
  util = require("citeproc-util")
else
  dom = require("citeproc.luaxml.domobject")
  element = require("citeproc.element")
  node_names = require("citeproc.node-names")
  util = require("citeproc.util")
end

local Element = element.Element


---@class Style: Element
---@field class string
---@field default_locale string?
---@field version string?
---@field initialize_with_hyphen boolean
---@field page_range_format string?
---@field demote_non_dropping_particle boolean?
---@field info Element
---@field locales { [string]: Locale }
---@field macros { [string]: Element }
---@field citation Citation
---@field intext Citation?
---@field bibliography Bibliography?
---@field full_citation Citation This is used for the `\fullcite` command.
---@field has_disambiguate boolean
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
  -- The parsing error is not caught by busted in some situcations and thus it's processed here.
  -- discretionary_CitationNumberAuthorOnlyThenSuppressAuthor.txt
  local status, csl_xml = pcall(dom.parse, xml_str)
  if not status then
    local error_message = string.match(csl_xml, "^.-: (.*)$")
    util.error("CSL parsing error: " .. util.rstrip(error_message))
  end
  local style_node = csl_xml:get_path("style")[1]
  if not style_node then
    error('Element "style" not found.')
  end
  return Style:from_node(style_node)
end

---@param node any
---@return Style
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
  o.name_inheritance = node_names.Name:new()
  Element.make_name_inheritance(o.name_inheritance, node)

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
    elseif element_name == "intext" then
      o.intext = child
    elseif element_name == "macro" then
      o.macros[child.name] = child
    elseif element_name == "locale" then
      local xml_lang = child.xml_lang or "@generic"
      o.locales[xml_lang] = child
    end
  end

  o.full_citation = Style._make_full_citation(o.citation, o.bibliography)

  o.has_disambiguate = false
  if #node:query_selector('[disambiguate="true"]') > 0 then
    o.has_disambiguate = true
  end

  return o
end


Style._default_options = {
  ["initialize-with-hyphen"] = true,
  ["page-range-format"] = nil,
  ["demote-non-dropping-particle"] = "display-and-sort",
}

local function remove_display_attribute(element)
  if not element.children then
    return
  end
  for i = #element.children, 1, -1 do
    local child = element.children[i]
    if child.display == "left-margin" then
      table.remove(element.children, i)
    elseif child.display then
      child.display = nil
      remove_display_attribute(child)
    else
      remove_display_attribute(child)
    end
  end
end

--- This is used for the `\fullcite` command.
---@param citation Citation
---@param bibliography Bibliography
function Style._make_full_citation(citation, bibliography)
  if not citation then
    return nil
  end
  local full_citation = util.clone(citation)

  full_citation.cite_group_delimiter = nil
  full_citation.cite_grouping = false
  full_citation.collapse = nil

  if not bibliography then
    full_citation.children = {}
    full_citation.layout = nil
    full_citation.layouts_by_language = {}
    return full_citation
  end

  full_citation.name_inheritance = bibliography.name_inheritance
  full_citation.children = util.deep_copy(bibliography.children)
  if bibliography.second_field_align then
    for _, child in ipairs(full_citation.children) do
      if child.element_name == "layout" then
        if #child.children > 1 then
          table.remove(child.children, 1)
        end
      end
    end
  end
  remove_display_attribute(full_citation)
  full_citation.layout = nil
  full_citation.layouts_by_language = {}
  for _, child in ipairs(full_citation.children) do
    local element_name = child.element_name
    if element_name == "layout" then
      if child.locale then
        for _, lang in ipairs(util.split(util.strip(child.locale))) do
          full_citation.layouts_by_language[lang] = child
        end
      else
        full_citation.layout = child
      end
    elseif element_name == "sort" then
      full_citation.sort = child
    end
  end

  return full_citation
end

---@class Info: Element
---@field author table?
---@field contributors table[]
---@field citation_format string?
---@field fields string[]
---@field id string?
---@field issn string?
---@field eissn string?
---@field issnl string?
---@field links string[]
---@field link_rel table<string, string>
---@field independent_parent string?
---@field published string?
---@field rghts string?
---@field summary string?
---@field title string?
---@field title_short string?
---@field updated string?
local Info = Element:derive("info")


function Info:from_node(node)
  ---@type Info
  local o = Info:new()

  o.contributors = {}
  o.fields = {}
  o.links = {}
  o.link_rel = {}

  for _, child in ipairs(node:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()

      if element_name == "author" or element_name == "contributor" then
        -- TODO
      elseif element_name == "category" then
        local citation_format = child:get_attribute("citation-format")
        local field = child:get_attribute("field")
        if citation_format then
          o.citation_format = citation_format
        elseif field then
          table.insert(o.fields, field)
        end
      elseif element_name == "link" then
        local href = child:get_attribute("href")
        local rel = child:get_attribute("rel")
        if href and rel then
          table.insert(o.links, href)
          o.link_rel[href] = rel
          if rel == "independent-parent" then
            o.independent_parent = href
          end
        end
      else
        o[element_name] = child:get_text()
      end
    end
  end

  return o
end


style_module.Style = Style


return style_module
