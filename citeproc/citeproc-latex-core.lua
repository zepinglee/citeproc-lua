--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local core = {}

require("lualibs")
local json_decode = utilities.json.tolua

local citeproc = require("citeproc")
local bibtex_data = require("citeproc-bibtex-data")
local bibtex_parser = require("citeproc-bibtex-parser")
local latex_parser = require("citeproc-latex-parser")
local yaml  -- = require("citeproc-yaml")  -- load on demand
local bibtex2csl  -- = require("citeproc-bibtex2csl")  -- load on demand
local unicode =  require("citeproc-unicode")
local util = citeproc.util


core.locale_file_format = "csl-locales-%s.xml"
core.uncited_ids = {}
core.uncite_all_items = false

core.item_list = {}
core.item_dict = {}

---@param file_name string
---@param ftype "bib"?
---@param file_info string
---@return string? contents
function core.read_file(file_name, ftype, file_info)
  if file_info then
    file_info = unicode.capitalize(file_info)
  else
    file_info = "File"
  end
  local path = kpse.find_file(file_name, ftype)
  if not path then
    if ftype and not util.endswith(file_name, ftype) then
      file_name = file_name .. ftype
    end
    util.error(string.format('%s "%s" not found', file_info, file_name))
    return nil
  end
  local file = io.open(path, "r")
  if not file then
    util.error(string.format('Cannot open %s "%s"', file_info, path))
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
    contents = core.read_file(filename, nil, "database file")
  elseif string.match(filename, "%.ya?ml$") then
    format = "yaml"
    contents = core.read_file(filename, nil, "database file")
  elseif util.endswith(filename, ".bib") then
    format = "bibtex"
    contents = core.read_file(filename, "bib", "database file")
  else
    file = filename .. ".json"
    local path = kpse.find_file(file)
    if path then
      format = "json"
      contents = core.read_file(file, nil, "database file")
    else
      path = kpse.find_file(filename .. ".yaml") or kpse.find_file(filename .. ".yml")
      if path then
        format = "yaml"
        file = filename .. string.match(path, "%.ya?ml$")
        contents = core.read_file(path, nil, "database file")
      else
        path = kpse.find_file(filename, "bib")
        if path then
          file = filename .. ".bib"
          format = "bibtex"
          contents = core.read_file(filename, "bib", "database file")
        else
          util.error(string.format('Cannot find database file "%s"', filename .. ".json"))
          return file, format, nil
        end
      end
    end
  end
  return file, format, contents
end


local function read_data_files(data_files)
  local item_list = {}
  local item_dict = {}

  --- Store BibTeX entries for later resolving crossref
  ---@type table<string, BibtexEntry>
  local bibtex_entries = {}
  ---@type table<string, string>
  local bibtex_strings = {}
  for name, macro in pairs(bibtex_data.macros) do
    bibtex_strings[name] = macro.value
  end
  ---@type BibtexEntry[]
  local entries_with_crossref = {}

  for _, data_file in ipairs(data_files) do
    -- local file_name, csl_items = read_data_file(data_file)

    local csl_items = {}

    local file, format, contents = read_data_file(data_file)

    if contents then

      if format == "json" then
        local ok, res = pcall(json_decode, contents)
        if ok then
          ---@cast res CslData
          csl_items = res
        else
          util.error(string.format('JSON decode error in file "%s".', file))
        end

      elseif format == "yaml" then
        yaml = yaml or require("citeproc-yaml")
        csl_items = yaml.parse(contents)

      elseif format == "bibtex" then
        local bib_data, exceptions = bibtex_parser.parse(contents, bibtex_strings)
        if bib_data then
          bibtex2csl = bibtex2csl or require("citeproc-bibtex2csl")
          csl_items = bibtex2csl.convert_to_csl_data(bib_data, true, true, true, true)
          for _, entry in ipairs(bib_data.entries) do
            if not bibtex_entries[entry.key] then
              bibtex_entries[entry.key] = entry
              if entry.fields.crossref then
                table.insert(entries_with_crossref, entry)
              end
            end
          end
          for string_name, value in pairs(bib_data.strings) do
            bibtex_strings[string_name] = value
          end
        end
      end

      for _, item in ipairs(csl_items) do
        local id = item.id
        if item_dict[id] then
          util.warning(string.format('Duplicate entry key "%s" in "%s".', id, file))
        else
          item_dict[id] = item
          table.insert(item_list, item)
        end
      end

    end
  end

  bibtex_parser.resolve_crossrefs(entries_with_crossref, bibtex_entries)

  for _, entry in ipairs(entries_with_crossref) do
    local new_item = bibtex2csl.convert_to_csl_item(entry, true, true, true, true)
    item_dict[new_item.id] = new_item
    for i, item in ipairs(item_list) do
      if item.id == new_item.id then
        item_list[i] = new_item
        break
      end
    end
  end

  return item_list, item_dict
end


function core.make_citeproc_sys(data_files)
  core.item_list, core.item_dict = read_data_files(data_files)
  local citeproc_sys = {
    retrieveLocale = function (lang)
      local locale_file_format = core.locale_file_format or "locales-%s.xml"
      local filename = string.format(locale_file_format, lang)
      return core.read_file(filename)
    end,
    retrieveItem = function (id)
      local res = core.item_dict[id]
      return res
    end
  }

  return citeproc_sys
end

---comment
---@param style_name string
---@param data_files string[]
---@param lang string?
---@return CiteProc?
function core.init(style_name, data_files, lang)
  if style_name == "" or #data_files == 0 then
    return nil
  end
  local style = core.read_file(style_name .. ".csl", nil, "style")
  if not style then
    util.error(string.format('Failed to load style "%s.csl"', style_name))
    return nil
  end

  local force_lang = nil
  if lang and lang ~= "" then
    force_lang = true
  else
    lang = nil
  end

  local citeproc_sys = core.make_citeproc_sys(data_files)
  local engine = citeproc.new(citeproc_sys, style, lang, force_lang)

  if engine:is_dependent_style() then
    local default_locale = engine.style.default_locale;
    local parent_style_link = engine:get_independent_parent()
    if not parent_style_link then
      return nil
    end
    local parent_style_id = string.match(string.gsub(parent_style_link, "/+$", ""), "[^/]+$")
    util.info(string.format('Style "%s" is a dependent style linked to "%s".', style_name, parent_style_id))
    style = core.read_file(parent_style_id .. ".csl", nil, "style")
    if not style then
      util.error(string.format('Failed to load style "%s.csl"', parent_style_id))
      return nil
    end
    engine = citeproc.new(citeproc_sys, style, lang, force_lang)
    engine.style.default_locale = default_locale
  end

  return engine
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

function core.make_citation(citation_info)
  -- `citation_info`: "citationID={ITEM-1@2},citationItems={{id={ITEM-1},label={page},locator={6}}},properties={noteIndex={3}}"
  -- util.debug(citation_info)
  local citation = parse_latex_prop(citation_info)
  -- assert(citation.citationID)
  -- assert(citation.citationItems)
  -- assert(citation.properties)

  citation.citationItems = parse_latex_seq(citation.citationItems)

  for i, item in ipairs(citation.citationItems) do
    local citation_item = parse_latex_prop(item)
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
    util.error(string.format('Invalid note index "%s".', note_index))
  end

  -- util.debug(citation)
  return citation
end


function core.process_citations(engine, citations)
  local citations_pre = {}

  local citation_strings = {}

  core.update_cited_and_uncited_ids(engine, citations)

  for _, citation in ipairs(citations) do
    if citation.citationID ~= "@nocite" then
      -- local res = engine:processCitationCluster(citation, citations_pre, {})
      -- for _, tuple in ipairs(res[2]) do
      --   local citation_str = tuple[2]
      --   local citation_id = tuple[3]
      --   citation_strings[citation_id] = citation_str
      --   util.debug(citation_str)
      -- end

      local citation_str = engine:process_citation(citation)
      citation_strings[citation.citationID] = citation_str

      table.insert(citations_pre, {citation.citationID, citation.properties.noteIndex})
    end
  end

  return citation_strings
end

function core.update_cited_and_uncited_ids(engine, citations)
  local id_list = {}
  local id_map = {}  -- Boolean map for checking if id in list
  local uncited_id_list = {}
  local uncited_id_map = {}

  for _, citation in ipairs(citations) do
    if citation.citationID == "@nocite" then
      for _, cite_item in ipairs(citation.citationItems) do
        if cite_item.id == "*" then
          if not core.uncite_all_items then
            for _, item in ipairs(core.item_list) do
              if not uncited_id_map[item.id] then
                table.insert(uncited_id_list, item.id)
                uncited_id_map[item.id] = true
              end
            end
            core.uncite_all_items = true
          end
        elseif not uncited_id_map[cite_item.id] then
          table.insert(uncited_id_list, cite_item.id)
          uncited_id_map[cite_item.id] = true
        end
      end

    else  -- Real citation
      for _, cite_item in ipairs(citation.citationItems) do
        if not id_map[cite_item.id] then
          table.insert(id_list, cite_item.id)
          id_map[cite_item.id] = true
        end
      end

    end
  end

  engine:updateItems(id_list)
  engine:updateUncitedItems(uncited_id_list)

end


---Convert to a filter object described in
--- <https://citeproc-js.readthedocs.io/en/latest/running.html#selective-output-with-makebibliography>
---@param filter_str string e.g., "type={book},notcategory={csl},notcategory={tex}"
---@return table
function core.parser_filter(filter_str)
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

---comment
---@param engine CiteProc
---@param option_str string
---@return unknown
function core.make_bibliography(engine, option_str)
  local filter
  local options = {}
  if option_str and option_str ~= "" then
    options = latex_parser.parse_prop(option_str)
    filter = core.parser_filter(option_str)
  end
  local result = engine:makeBibliography(filter)

  local params = result[1]
  local bib_items = result[2]

  local res = ""

  ---@type table<string, any>
  local bib_options = {
    index = options.index or "1"
  }

  local bib_option_map = {
    ["hanging-indent"] = "hangingindent",
    ["entry-spacing"] = "entryspacing",
    ["line-spacing"] = "linespacing",
    ["widest-label"] = "widest_label",
  }
  local bib_option_order = {
    "index",
    "hanging-indent",
    "line-spacing",
    "entry-spacing",
    "widest-label",
  }

  for option, param in pairs(bib_option_map) do
    if params[param] then
      bib_options[option] = params[param]
    end
  end

  local bib_option_list = {}
  for _, option in ipairs(bib_option_order) do
    local value = bib_options[option]
    if value and value ~= "" then
      table.insert(bib_option_list, string.format("%s = %s", option, tostring(value)))
    end
  end
  local bib_options_str = table.concat(bib_option_list, ", ")

  -- util.debug(params.bibstart)
  -- if params.bibstart then
  --   res = res .. params.bibstart
  -- end

  local bibstart = string.format("\\begin{thebibliography}{%s}\n", bib_options_str)
  res = res .. bibstart


  for _, bib_item in ipairs(bib_items) do
    res = res .. "\n" .. bib_item
  end

  if params.bibend then
    res = res .. "\n" .. params.bibend
  end
  return res
end


function core.set_categories(engine, categories_str)
  -- util.debug(categories_str)
  local category_dict = latex_parser.parse_prop(categories_str)
  for category, keys in pairs(category_dict) do
    category_dict[category] = latex_parser.parse_seq(keys)
  end
  for category, keys in pairs(category_dict) do
    for _, key in ipairs(keys) do
      local item = engine.registry.registry[key]
      if item then
        if not item.categories then
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
  -- for id, item in pairs(csl.engine.registry.registry) do
  --   util.debug(id)
  --   util.debug(item.categories)
  -- end
end


return core
