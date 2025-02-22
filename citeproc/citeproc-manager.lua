--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local citeproc_manager = {}

local using_luatex, kpse = pcall(require, "kpse")
if not using_luatex then
  error("This module must be run under LuaTeX.")
end

require("lualibs")
local json_encode = utilities.json.tojson
local json_decode = utilities.json.tolua

local citeproc = require("citeproc")
local bibtex_data = require("citeproc-bibtex-data")
local bibtex_parser = require("citeproc-bibtex-parser")
local latex_parser = require("citeproc-latex-parser")
local util = citeproc.util
local unicode = require("citeproc-unicode")
local bibtex2csl = require("citeproc-bibtex2csl")
local yaml = require("citeproc-yaml")


---@param file_name string
---@param ftype "bib" | nil
---@param file_info string
---@return string? contents
local function read_file(file_name, ftype, file_info)
  if file_info then
    file_info = unicode.capitalize(file_info)
  else
    file_info = "File"
  end
  local path
  if ftype then
    path = kpse.find_file(file_name, ftype)
  else
    path = kpse.find_file(file_name)
  end

  if not path then
    if ftype and not util.endswith(file_name, ftype) then
      file_name = file_name .. ftype
    end
    util.error(string.format("%s '%s' not found", file_info, file_name))
    return nil
  end
  local file = io.open(path, "r")
  if not file then
    util.error(string.format("Cannot open %s '%s'", file_info, path))
    return nil
  end
  local contents = file:read("*a")
  contents = util.remove_bom(contents)
  file:close()
  return contents
end


---@param filename string
---@return string file
---@return string format
---@return string? contents
local function read_data_file(filename)
  local file = filename
  local format = "json"
  local contents = nil

  if util.endswith(filename, ".json") then
    format = "json"
    contents = read_file(filename, nil, "database file")
  elseif string.match(filename, "%.ya?ml$") then
    format = "yaml"
    contents = read_file(filename, nil, "database file")
  elseif util.endswith(filename, ".bib") then
    format = "bibtex"
    contents = read_file(filename, "bib", "database file")
  else
    file = filename .. ".json"
    local path = kpse.find_file(file)
    if path then
      format = "json"
      contents = read_file(file, nil, "database file")
    else
      path = kpse.find_file(filename .. ".yaml") or kpse.find_file(filename .. ".yml")
      if path then
        format = "yaml"
        file = filename .. string.match(path, "%.ya?ml$")
        contents = read_file(path, nil, "database file")
      else
        path = kpse.find_file(filename, "bib")
        if path then
          file = filename .. ".bib"
          format = "bibtex"
          contents = read_file(filename, "bib", "database file")
        else
          util.error(string.format("Cannot find database file '%s'", filename .. ".json"))
          return file, format, nil
        end
      end
    end
  end
  return file, format, contents
end


---@param item_dict table<ItemId, ItemData>
---@return CiteProcSys
local function make_citeproc_sys(item_dict)
  local citeproc_sys = {
    retrieveLocale = function (lang)
      local locale_file_format = "csl-locales-%s.xml"
      local filename = string.format(locale_file_format, lang)
      return read_file(filename, nil, "locale file")
    end,
    retrieveItem = function (id)
      local res = item_dict[id]
      if not res and not luatexbase then
        util.warning(string.format("Didn't find a database entry for '%s'", id))
      end
      return res
    end
  }
  return citeproc_sys
end


---@alias StyleId string
---@alias FilePath string
---@alias LanguageCode string

---@class RefSection
---@field index integer
---@field initialized boolean
---@field style_id string?
---@field bib_resources FilePath[]
---@field lang LanguageCode?
---@field engine CiteProc?
---@field cited_ids ItemId[]
---@field uncited_ids ItemId[]
---@field items ItemData[]
---@field item_dict table<ItemId, ItemData>
---@field citations CitationData[]
---@field citations_pre table[]
---@field bibliography_configs string[]
---@field style string
---@field bibtex_entries table<string, BibtexEntry>
---@field entries_with_crossref BibtexEntry[]
---@field bibtex_strings table<string, string>
---@field item_index table<ItemId, integer>
local RefSection = {}

---@return RefSection
function RefSection:new()
  local ref_section = {
    index = 0,
    initialized = false,
    style_id = nil,
    bib_resources = {},
    lang = nil,
    engine = nil,
    cited_ids = {},
    uncited_ids = {},
    items = {},
    item_dict = {},
    citations = {},
    citations_pre = {},
    bibliography_configs = {},
    style = "",
    bibtex_entries = {},
    entries_with_crossref = {},
    bibtex_strings = {},
    item_index = {},
  }
  setmetatable(ref_section, self)
  self.__index = self
  return ref_section
end

---@param data_file string
---@param option_str string?
function RefSection:add_bib_resource(data_file, option_str)
  local item_dict = self.item_dict
  local items = self.items

  local file, format, contents = read_data_file(data_file)
  table.insert(self.bib_resources, file)

  local options = {}
  if option_str then
    for option, value in string.gmatch(option_str, "([%w%-]+)%s*=%s*([%w%-]+)") do
      options[option] = value
    end
  end

  if contents then
    if format == "bibtex" then
      local bib_data, exceptions = bibtex_parser.parse(contents, self.bibtex_strings)
      if bib_data then
        for _, entry in ipairs(bib_data.entries) do
          if item_dict[entry.key] then
            util.warning(string.format("Duplicate entry key '%s' in '%s'.", entry.key, file))
          else
            self.bibtex_entries[entry.key] = entry
            if entry.fields.crossref then
              table.insert(self.entries_with_crossref, entry)
              self.item_index[entry.key] = #items + 1
            end
            local disable_journal_abbreviation = options["journal-abbreviation"] == "false"
            local csl_item = bibtex2csl.convert_to_csl_item(entry, true, true, true, true, disable_journal_abbreviation)
            item_dict[csl_item.id] = csl_item
            table.insert(items, csl_item)
          end
        end
        for string_name, value in pairs(bib_data.strings) do
          self.bibtex_strings[string_name] = value
        end
      end
    else

      local ok, csl_items
      if format == "json" then
        ok, csl_items = pcall(json_decode, contents)
      elseif format == "yaml" then
        ok, csl_items = pcall(yaml.parse, contents)
      end

      if not ok or not csl_items then
        util.error(string.format("%s decode error in file '%s'.", format:upper(), file))
      else
        -- TODO: validate csl_items
        ---@cast csl_items ItemData[]
        for _, item in ipairs(csl_items) do
          if item_dict[item.id] then
            util.warning(string.format("Duplicate entry key '%s' in '%s'.", item.id, file))
          else
            item_dict[item.id] = item
            table.insert(items, item)
          end
        end
      end
    end
  end
end

function RefSection:make_citeproc_engine()
  if not self.style_id or self.style_id == "" then
    self.style_id = "apa"
  end
  local style = read_file(self.style_id .. ".csl", nil, "style")
  if not style then
    return
  end

  -- Resolve BibTeX with crossref
  if #self.entries_with_crossref > 0 then
    bibtex_parser.resolve_crossrefs(self.entries_with_crossref, self.bibtex_entries)
    for _, entry in ipairs(self.entries_with_crossref) do
      local item = bibtex2csl.convert_to_csl_item(entry, true, true, true, true)
      self.item_dict[item.id] = item
      self.items[self.item_index[entry.key]] = item
    end
  end

  local citeproc_sys = make_citeproc_sys(self.item_dict)

  local force_lang = false
  if self.lang and self.lang ~= "" then
    force_lang = true
  else
    self.lang = nil
  end

  self.style = style
  -- self.items

  self.engine = citeproc.new(citeproc_sys, style, self.lang, force_lang)
  self:_check_dependent_style(citeproc_sys)

  if self.engine and self.engine.style.citation then
    self.initialized = true
  end

  self.engine:updateItems(self.cited_ids)

  self:_update_uncited_items()

end

---@param citeproc_sys CiteProcSys
function RefSection:_check_dependent_style(citeproc_sys)
  if self.engine:is_dependent_style() then
    local parent_style_link = self.engine:get_independent_parent()
    if not parent_style_link then
      return nil
    end
    local parent_style_id = string.match(string.gsub(parent_style_link, "/+$", ""), "[^/]+$")
    util.info(string.format('Style "%s" is a dependent style linked to "%s".', self.style_id, parent_style_id))
    local style = read_file(parent_style_id .. ".csl", nil, "style")
    if not style then
      util.error(string.format("Failed to load style '%s.csl'", parent_style_id))
      return nil
    end
    local default_locale = self.engine.style.default_locale;
    local force_lang = false
    if self.lang and self.lang ~= "" then
      force_lang = true
    elseif default_locale and default_locale ~= "" then
      self.lang = default_locale
    else
      self.lang = nil
    end
    self.engine = citeproc.new(citeproc_sys, style, self.lang, force_lang)
  end
end

function RefSection:_update_uncited_items()
  local uncited_ids = {}
  for _, id in ipairs(self.uncited_ids) do
    if id == "*" then
      for _, item in ipairs(self.items) do
        table.insert(uncited_ids, item.id)
      end
      break
    else
      table.insert(uncited_ids, id)
    end
  end
  if self.initialized then
    self.engine:updateUncitedItems(uncited_ids)
  end
  self.uncited_ids = uncited_ids
end

function RefSection:record_fixture()
  if not self.fixture then
    self.fixture = {
      mode = "citation",
      description = tex.jobname,
      result = "",
      bibliography_result = "",
      citations = "",
      ["citation-items"] = "",
      csl = self.style,
      input = "",
      version = "1.0",
      citation_results = {},
    }
  end
  local fixture = self.fixture

  local cited_id_dict = {}
  for _, citation in ipairs(self.citations) do
    for _, cite_item in ipairs(citation.citationItems) do
      cited_id_dict[cite_item.id] = true
    end
  end
  local input_items = {}
  for _, item in ipairs(self.items) do
    if cited_id_dict[item.id] then
      table.insert(input_items, item)
    end
  end
  fixture.input = json_encode(input_items)

  local citation_items = {}
  for _, citation in ipairs(self.citations) do
    table.insert(citation_items, util.clone(citation.citationItems))
  end
  fixture["citation-items"] = json_encode(citation_items)

  local citations = {}
  local citations_pre = {}
  for _, citation in ipairs(self.citations) do
    table.insert(citations, {citation, util.clone(citations_pre), {}})
    table.insert(citations_pre, {citation.citationID, citation.properties.noteIndex})
  end
  fixture.citations = string.gsub(json_encode(citations), "{%s*}", "[]")

  local result = {}
  for i, citation_result in ipairs(fixture.citation_results) do
    if i == #fixture.citation_results then
      table.insert(result, string.format(">>[%d] %s", i - 1, citation_result))
    else
      table.insert(result, string.format("..[%d] %s", i - 1, citation_result))
    end
  end
  fixture.result = table.concat(result, "\n")

  local fixture_output = {}
  local function make_block(section, str)
    return string.format(">>===== %s =====>>\n%s\n<<===== %s =====<<\n", string.upper(section), str, string.upper(section))
  end
  for _, section in ipairs({"mode", "description", "result", "bibliography_result", "citations", "citation-items", "csl", "input", "version"}) do
    if not (section == "bibliography_result" and fixture[section] == "") then
      table.insert(fixture_output, make_block(section, fixture[section]))
    end
  end
  local fixture_str = table.concat(fixture_output, "\n\n")

  local file_name = string.format("%s.txt", tex.jobname)
  if self.index > 0 then
    file_name = string.format("%s-%d.txt", tex.jobname, self.index)
  end

  local fixture_file = io.open(file_name, "w")
  if fixture_file then
    fixture_file:write(fixture_str)
    fixture_file:close()
  else
    error(string.format("Failed to write fixture file '%s'", file_name))
  end
end


---@class CslCitationManager
---@field global_ref_section RefSection
---@field max_ref_section_index integer
---@field ref_section_index integer
---@field ref_sections table<integer, RefSection>
---@field ref_section RefSection
---@field hyperref_loaded boolean
---@field regression_test boolean
local CslCitationManager = {}

---@return CslCitationManager
function CslCitationManager:new()
  local ref_section = RefSection:new()
  ---@type CslCitationManager
  local o = {
    -- global_style_id = "apa",
    -- global_bib_resources = {},
    -- global_lang = nil,
    global_ref_section = ref_section,
    max_ref_section_index = 0,
    ref_section_index = 0,
    ref_sections = {
      [0] = ref_section,
    },
    ref_section = ref_section,

    hyperref_loaded = false,
    regression_test = false,
  }

  setmetatable(o, self)
  self.__index = self
  return o
end

---@param data_file string
---@param option_str string?
function CslCitationManager:add_bib_resource(data_file, option_str)
  self.ref_section:add_bib_resource(data_file, option_str)
end

--- The init method is called via \AtBeginDocument after loading .aux file.
--- The ref_section.cited_ids are already registered.
---@param style_id StyleId
---@param bib_resources_str FilePathsString
---@param lang LanguageCode?
function CslCitationManager:init(style_id, lang)
  -- TODO: remove bib_resources_str
  local global_ref_section = self.global_ref_section
  global_ref_section.style_id = "apa"
  if style_id and style_id ~= "" then
    global_ref_section.style_id = style_id
  end
  if lang and lang ~= "" then
    global_ref_section.lang = lang
  end

  global_ref_section:make_citeproc_engine()
  if self.hyperref_loaded then
    global_ref_section.engine:enable_linking()
  end
  if self.regression_test then
    self.global_ref_section:record_fixture()
  end

  self.ref_section_index = 0
end


function CslCitationManager:get_style_class()
  if not self.ref_section then
    return nil
  end
  if self.ref_section.engine then
    return self.ref_section.engine:get_style_class()
  else
    return nil
  end
end

---@alias FilePathsString string

---@param style_id string?
---@param bib_resources_str FilePathsString?
---@param lang LanguageCode?
function CslCitationManager:begin_ref_section(style_id, bib_resources_str, lang)
  self.max_ref_section_index = self.max_ref_section_index + 1
  self.ref_section_index = self.max_ref_section_index
  self.ref_section = self.ref_sections[self.ref_section_index]
  if not self.ref_section then
    self.ref_section = RefSection:new()
    self.ref_section.index = self.ref_section_index
    self.ref_sections[self.ref_section_index] = self.ref_section
  end

  self.ref_section.style_id = style_id or self.global_ref_section.style_id
  self.ref_section.bib_resources = self.global_ref_section.bib_resources
  if bib_resources_str and bib_resources_str ~= "" then
    for _, bib_resource in ipairs(util.split(util.strip(bib_resources_str), "%s*,%s*")) do
      -- TODO: options (\addsectionbib)
      self:add_bib_resource(bib_resource)
    end
  else
    self.ref_section.bib_resources = self.global_ref_section.bib_resources
    self.ref_section.items = self.global_ref_section.items
    self.ref_section.item_dict = self.global_ref_section.item_dict
  end
  self.ref_section.lang = self.global_ref_section.lang
  if lang and lang ~= "" then
    self.ref_section.lang = lang
  end
  -- self.ref_section.force_lang = force_lang or false

  self.ref_section:make_citeproc_engine()

  if self.hyperref_loaded then
    self.ref_section.engine:enable_linking()
  end

  if self.regression_test then
    self.ref_section:record_fixture()
  end

end


function CslCitationManager:end_ref_section()
  self.ref_section_index = 0
  self.ref_section = self.ref_sections[0]
end


---This method is called from the `\csl@aux@cite` command from `.aux` file.
---@param ref_section_index_str string
---@param citation_info string
function CslCitationManager:register_citation_info(ref_section_index_str, citation_info)
  local ref_section_index = tonumber(ref_section_index_str)
  if not ref_section_index then
    util.error(string.format("Invalid refsetion index '%s'", ref_section_index_str))
    return
  end
  local ref_section = self.ref_sections[ref_section_index]
  if not ref_section then
    ref_section = RefSection:new()
    self.ref_sections[ref_section_index] = ref_section
    ref_section.index = ref_section_index
  end

  local citation = self:_make_citation(citation_info)

  for _, cite_item in ipairs(citation.citationItems) do
    if citation.citationID == "@nocite" then
      table.insert(ref_section.uncited_ids, cite_item.id)
    else
      table.insert(ref_section.cited_ids, cite_item.id)
    end
  end
end

function CslCitationManager:enable_linking()
  self.hyperref_loaded = true
  if self.ref_section.engine then
    self.ref_section.engine:enable_linking()
  end
end


---@param citation_info string
function CslCitationManager:cite(citation_info)
  if not self.ref_section then
    util.error("Refsection is not initialized.")
    return
  end
  local engine = self.ref_section.engine
  if not engine then
    util.error("CSL engine is not initialized.")
    return
  end

  -- util.debug(citation_info)
  local citation = self:_make_citation(citation_info)
  -- util.debug(citation)

  table.insert(self.ref_section.citations, citation)

  local citation_str
  -- if preview_mode then
  --   -- TODO: preview mode in first pass of \blockquote of csquotes
  --   -- citation_str = engine:preview_citation(citation)
  --   citation_str = ""
  -- else
  citation_str = engine:process_citation(citation)
  -- end
  -- util.debug(citation_str)

  -- tex.sprint(citation_str)
  -- tex.setcatcode(35, 12)  -- #
  -- tex.setcatcode(37, 12)  -- %
  -- token.set_macro("l__csl_citation_tl", citation_str)
  -- Don't use `token.set_macro`.
  -- See <https://github.com/zepinglee/citeproc-lua/issues/42>
  -- and <https://tex.stackexchange.com/questions/519954/backslashes-in-macros-defined-in-lua-code>.
  tex.sprint(string.format("\\expandafter\\def\\csname l__csl_citation_tl\\endcsname{%s}", citation_str))

  if self.regression_test then
    table.insert(self.ref_section.fixture.citation_results, citation_str)
    self.ref_section:record_fixture()
  end

  table.insert(self.ref_section.citations_pre, {citation.citationID, citation.properties.noteIndex})
end

local function parse_latex_seq(s)
  local t = {}
  for item in string.gmatch(s, "(%b{})") do
    item = string.sub(item, 2, -2)
    table.insert(t, item)
  end
  return t
end

local function parse_latex_prop(s)
  local t = {}
  for key, value in string.gmatch(s, "([%w%-]+)%s*=%s*(%b{})") do
    value = string.sub(value, 2, -2)
    if value == "true" then
      value = true
    elseif value == "false" then
      value = false
    end
    t[key] = value
  end
  return t
end

---@param citation_info string
---@return CitationData
function CslCitationManager:_make_citation(citation_info)
  -- `citation_info`: "citationID={ITEM-1@2},citationItems={{id={ITEM-1},label={page},locator={6}}},properties={noteIndex={3}}"
  -- util.debug(citation_info)
  local citation = parse_latex_prop(citation_info)
  -- assert(citation.citationID)
  -- assert(citation.citationItems)
  -- assert(citation.properties)

  citation.citationItems = parse_latex_seq(citation.citationItems)

  for i, item in ipairs(citation.citationItems) do
    local citation_item = parse_latex_prop(item)

    if citation_item.locator and type(citation_item.locator) == "string" then
      citation_item.locator = latex_parser.latex_to_pseudo_html(citation_item.locator, true, false)
    end

    if citation_item.prefix then
      -- util.debug(citation_item.prefix)
      citation_item.prefix = latex_parser.latex_to_pseudo_html(citation_item.prefix, true, false)
      -- util.debug(citation_item.prefix)
    end
    if citation_item.suffix then
      citation_item.suffix = latex_parser.latex_to_pseudo_html(citation_item.suffix, true, false)
    end
    citation.citationItems[i] = citation_item
  end

  citation.properties = parse_latex_prop(citation.properties)
  local note_index = citation.properties.noteIndex
  if not note_index or note_index == "" then
    citation.properties.noteIndex = 0
  elseif type(note_index) == "string" and string.match(note_index, "^%d+$") then
    citation.properties.noteIndex = tonumber(note_index)
  else
    util.error(string.format("Invalid note index '%s'.", note_index))
  end

  local chapter_index = citation.properties.chapterIndex
  if not chapter_index or chapter_index == "" then
    citation.properties.chapterIndex = nil
  elseif type(chapter_index) == "string" and string.match(chapter_index, "^%d+$") then
    citation.properties.chapterIndex = tonumber(chapter_index)
  else
    util.error(string.format("Invalid chapter index '%s'.", chapter_index))
  end

  if citation.properties.prefix then
    citation.properties.prefix = latex_parser.latex_to_pseudo_html(citation.properties.prefix, true, false)
  end
  if citation.properties.suffix then
    citation.properties.suffix = latex_parser.latex_to_pseudo_html(citation.properties.suffix, true, false)
  end

  -- util.debug(citation)
  return citation
end

---@param ids_string string The list of item IDs separated by commas
function CslCitationManager:nocite(ids_string)
  local uncited_ids = util.split(util.strip(ids_string), "%s*,%s*")

  local engine = self.ref_section.engine
  if not engine then
    for _, id in ipairs(uncited_ids) do
      table.insert(self.ref_section.uncited_ids, id)
    end
    return
  end

  for _, id in ipairs(uncited_ids) do
    if id == "*" then
      for _, item in ipairs(self.ref_section.items) do
        table.insert(self.ref_section.uncited_ids, item.id)
      end
      break
    else
      table.insert(self.ref_section.uncited_ids, id)
    end
  end
  engine:updateUncitedItems(self.ref_section.uncited_ids)
end


---@param filter_str string
function CslCitationManager:bibliography(filter_str)
  if not self.ref_section then
    util.error("Refsection is not initialized.")
    return
  end
  local bib_lines = self:make_bibliography(filter_str)
  tex.print(util.split(table.concat(bib_lines, "\n"), "\n"))

  if self.regression_test then
    self.ref_section.fixture.bibliography_result = table.concat(bib_lines, "\n")
    self.ref_section:record_fixture()
  end
end

---@param filter_str string
---@return string[]
function CslCitationManager:make_bibliography(filter_str)
  local engine = self.ref_section.engine
  if not engine then
    util.error("CSL engine is not initialized.")
    return {}
  end
  local filter
  local options = {}
  if filter_str and filter_str ~= "" then
    options = latex_parser.parse_prop(filter_str)
    filter = self:_parser_filter(filter_str)
    -- util.debug(filter)
  end
  local result = engine:makeBibliography(filter)

  local params = result[1]
  local bib_items = result[2]

  ---@type table<string, any>
  local bib_options = {
    index = options.index or "1"
  }

  local bib_option_map = {
    ["second-field-align"] = "second-field-align",
    ["hanging-indent"] = "hangingindent",
    ["entry-spacing"] = "entryspacing",
    ["line-spacing"] = "linespacing",
    ["widest-label"] = "widest_label",
    ["entry-ids"] = "entry_ids",
    ["excluded-ids"] = "excluded_ids",
  }
  local bib_option_order = {
    "index",
    "second-field-align",
    "hanging-indent",
    "line-spacing",
    "entry-spacing",
    "widest-label",
    -- "entry-ids",
    -- "excluded-ids",
  }

  local bib_lines = {}

  if #params.entry_ids > 0 then
    local entry_ids_line = string.format("\\csloptions{%d}{entry-ids = {%s}}", self.ref_section.index, table.concat(params.entry_ids, ", "))
    table.insert(bib_lines, entry_ids_line)
  end
  if #params.excluded_ids > 0 then
    local excluded_ids_line = string.format("\\csloptions{%d}{excluded-ids = {%s}}", self.ref_section.index, table.concat(params.excluded_ids, ", "))
    table.insert(bib_lines, excluded_ids_line)
  end

  for option, param in pairs(bib_option_map) do
    if params[param] then
      bib_options[option] = params[param]
    end
  end

  local bib_option_list = {}
  for _, option in ipairs(bib_option_order) do
    local value = bib_options[option]
    if value then
      if type(value) == "table" then
        value = "{" .. table.concat(value, ", ") .. "}"
      else
        value = tostring(value)
      end
      if value ~= "" then
        table.insert(bib_option_list, string.format("%s = %s", option, value))
      end
    end
  end
  local bib_options_str = table.concat(bib_option_list, ", ")

  local bibstart = string.format("\\begin{thebibliography}{%s}\n", bib_options_str)
  table.insert(bib_lines, bibstart)

  for _, bib_item in ipairs(bib_items) do
    table.insert(bib_lines, bib_item)
  end

  if params.bibend then
    table.insert(bib_lines, params.bibend)
  end
  return bib_lines
end

function CslCitationManager:set_categories(categories_str)
  if self.ref_section.engine then

    local category_dict = latex_parser.parse_prop(categories_str)
    for category, keys in pairs(category_dict) do
      category_dict[category] = latex_parser.parse_seq(keys)
    end
    for category, keys in pairs(category_dict) do
      for _, key in ipairs(keys) do
        local item = self.ref_section.engine.registry.registry[key]
        if item then
          if not item.categories then
            -- TODO: Extend ItemData field types
            item.categories = {}
          end
          if not util.in_list(category, item.categories) then
            table.insert(item.categories, category)
          end
        else
          util.error(string.format("Invalid citation key '%s'.", key))
        end
      end
    end
  end
end

---@type [string, integer][]
local command_info = {
  {"\\csl@aux@style", 2},
  {"\\csl@aux@data", 3},
  {"\\csl@aux@cite", 2},
  {"\\csl@aux@options", 2},
  {"\\csl@aux@bibliography", 2},
  {"\\@input", 1},
}

local balanced = lpeg.P{ "{" * ((1 - lpeg.S"{}") + lpeg.V(1))^0 * "}" }

---@param text string
---@param num_args integer?
---@return string[]
local function get_command_arguments(text, command, num_args)
  num_args = num_args or 1
  local grammar = lpeg.P(command) * lpeg.Ct((lpeg.S(" \t\r\n")^0 * lpeg.C(balanced))^num_args)
  local arguments = grammar:match(text)
  if not arguments then
    return {}
  end
  ---@cast arguments string[]
  for i, argument in ipairs(arguments) do
    arguments[i] = string.sub(argument, 2, -2)
  end
  return arguments
end

---Convert to a filter object described in
--- <https://citeproc-js.readthedocs.io/en/latest/running.html#selective-output-with-makebibliography>
---@param filter_str string e.g., "type={book},notcategory={csl},notcategory={tex}"
---@return table
function CslCitationManager:_parser_filter(filter_str)
  local conditions = {}
  for i, condition in ipairs(latex_parser.parse_seq(filter_str)) do
    local negative
    local field, value = string.match(condition, "(%w+)%s*=%s*{([^}]+)}")
    if field then
      if string.match(field, "^not") then
        negative = true
        field = string.gsub(field, "^not", "")
      end
      if field == "category" then
        field = "categories"
      end
      if field == "keyword" or field == "type" or field == "categories" then
        table.insert(conditions, {
          field = field,
          value = value,
          negative = negative,
        })
      end
    end
  end
  -- util.debug(conditions)
  return {select = conditions}
end



---@param aux_content string
---@return string
function CslCitationManager:read_aux_file(aux_content)
  local command_arguments = self:_get_csl_commands(aux_content)

  -- First pass, only register infomation
  for _, command_argument in ipairs(command_arguments) do
    local command, ref_section_index, content = table.unpack(command_argument)

    local ref_section = self.ref_sections[ref_section_index]
    self.ref_section = ref_section
    if not ref_section then
      ref_section = RefSection:new()
      self.ref_sections[ref_section_index] = ref_section
      ref_section.index = ref_section_index
      self.ref_section = ref_section
    end
    if command == "\\csl@aux@style" then
      ref_section.style_id = content
    elseif command == "\\csl@aux@data" then
      local option_str = command_argument[4]
      for _, data_file in ipairs(util.split(content, "%s*,%s*")) do
        ref_section:add_bib_resource(data_file, option_str)
      end
    elseif command == "\\csl@aux@cite" then
      self:register_citation_info(tostring(ref_section_index), content)
      -- TODO: refsection bib resources
    -- elseif command == "\\csl@aux@bibliography" then
    --   -- table.insert(ref_section.bibliography_configs, content)
    end
  end

  local global_style = self.global_ref_section.style_id
  if global_style and global_style ~= "" then
    util.info(string.format("Global style file: %s.csl", global_style))
  else
    util.warning("Missing global style name. Will use default APA style.")
    self.global_ref_section.style_id = "apa"
  end

  -- if #citations == 0 then
  --   util.error(string.format("No citation commands in file %s", aux_file))
  -- end

  -- if #bib_files == 0 then
  --   util.warning("empty bibliography data files")
  -- else
  --   for i, bib_file in ipairs(bib_files) do
  --     util.info(string.format("Database file #%d: %s", i, bib_file))
  --   end
  -- end

  -- Second pass, only register infomation
  local output_lines = {}
  for _, command_argument in ipairs(command_arguments) do
    local command, ref_section_index, content = table.unpack(command_argument)

    local ref_section = self.ref_sections[ref_section_index]
    assert(ref_section)
    self.ref_section = ref_section

    if command == "\\csl@aux@cite" then
      if not ref_section.engine then
        if not ref_section.style_id or ref_section.style_id == "" then
          ref_section.style_id = self.global_ref_section.style_id
        end
        if #ref_section.bib_resources == 0 then
          self.ref_section.bib_resources = self.global_ref_section.bib_resources
          self.ref_section.items = self.global_ref_section.items
          self.ref_section.item_dict = self.global_ref_section.item_dict
        end
        if not ref_section.lang or ref_section.lang == "" then
          ref_section.lang = self.global_ref_section.lang
        end
        ref_section:make_citeproc_engine()
        if self.hyperref_loaded then
          ref_section.engine:enable_linking()
        end
        local style_class = ref_section.engine:get_style_class()
        local style_class_setup = string.format("\\csloptions{%d}{class = {%s = %s}}", ref_section_index, ref_section.style_id, style_class)
        table.insert(output_lines, style_class_setup)
      end
      self:register_citation_info(tostring(ref_section_index), content)
      if ref_section.engine then
        local citation = self:_make_citation(content)
        if citation.citationID == "@nocite" then
          ref_section:_update_uncited_items()
        else
          local citation_str = ref_section.engine:process_citation(citation)
          table.insert(output_lines, string.format("\\cslcitation{%s}{%s}", citation.citationID, citation_str))
        end
      end

    elseif command == "\\csl@aux@bibliography" then
      if not ref_section.engine then
        ref_section:make_citeproc_engine()
      end
      if ref_section.engine then
        local bib_lines = self:make_bibliography(content)
        table.insert(output_lines, "")
        util.extend(output_lines, bib_lines)
        table.insert(output_lines, "")
      end

    elseif command == "\\csl@aux@options" then
      local options = latex_parser.parse_prop(content)
      if options.categories then
        self:set_categories(options.categories)
      end
      if options.locale and options.locale ~= "" then
        ref_section.lang = options.locale
      end
      -- TODO: == "true"?
      if options.linking then
        self.hyperref_loaded = true
      end
    end
  end
  return table.concat(output_lines, "\n") .. "\n"
end

---@param aux_content string
---@return [string, integer, string][]
function CslCitationManager:_get_csl_commands(aux_content)
  ---@type [string, integer, string][]
  local command_arguments = {}
  for _, line in ipairs(util.split(aux_content, "%s*\n")) do
    for _, command_argment in ipairs(command_info) do
      local command, num_args = table.unpack(command_argment)
      if util.startswith(line, command) then
        local arguments = get_command_arguments(line, command, num_args)
        if command == "\\@input" then
          local sub_aux_file = arguments[1]
          self:read_aux_file(sub_aux_file)
        else
          local ref_section_index = tonumber(arguments[1])
          if not ref_section_index then
            util.error(string.format("Invalid refsection index '%s'.", ref_section_index))
            return {}
          end
          local content = util.strip(arguments[2])
          table.insert(command_arguments, {command, ref_section_index, content, arguments[3]})
        end
        break

      end
    end
  end
  return command_arguments
end


citeproc_manager.CslCitationManager = CslCitationManager

return citeproc_manager
