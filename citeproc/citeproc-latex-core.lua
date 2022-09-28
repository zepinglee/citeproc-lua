--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local core = {}

local citeproc = require("citeproc")
local bibtex  -- = require("citeproc-bibtex")  -- load on demand
local util = citeproc.util
require("lualibs")


core.locale_file_format = "csl-locales-%s.xml"
core.uncited_ids = {}
core.uncite_all_items = false


function core.read_file(file_name, ftype, file_info)
  if file_info then
    file_info = util.capitalize(file_info)
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
  file:close()
  return contents
end


local function read_data_file(data_file)
  local file_name = data_file
  local extension = nil
  local contents = nil

  if util.endswith(data_file, ".json") then
    extension = ".json"
    contents = core.read_file(data_file, nil, "database file")
  elseif util.endswith(data_file, ".bib") then
    extension = ".bib"
    contents = core.read_file(data_file, "bib", "database file")
  else
    local path = kpse.find_file(data_file .. ".json")
    if path then
      file_name = data_file .. ".json"
      extension = ".json"
      contents = core.read_file(data_file .. ".json", nil, "database file")
    else
      path = kpse.find_file(data_file, "bib")
      if path then
        file_name = data_file .. ".bib"
        extension = ".bib"
        contents = core.read_file(data_file, "bib", "database file")
      else
        util.error(string.format('Cannot find database file "%s"', data_file .. ".json"))
      end
    end
  end

  local csl_items = nil

  if extension == ".json" then
    csl_items = utilities.json.tolua(contents)
  elseif extension == ".bib" then
    bibtex = bibtex or require("citeproc-bibtex")
    csl_items = bibtex.parse(contents)
  end

  return file_name, csl_items
end


local function read_data_files(data_files)
  local bib = {}
  for _, data_file in ipairs(data_files) do
    local file_name, csl_items = read_data_file(data_file)

    -- TODO: parse bib entries on demand
    for _, item in ipairs(csl_items) do
      local id = item.id
      if bib[id] then
        util.warning(string.format('Duplicate entry key "%s" in "%s".', id, file_name))
      else
        bib[id] = item
      end
    end
  end
  return bib
end



function core.make_citeproc_sys(data_files)
  core.bib = read_data_files(data_files)
  local citeproc_sys = {
    retrieveLocale = function (lang)
      local locale_file_format = core.locale_file_format or "locales-%s.xml"
      local filename = string.format(locale_file_format, lang)
      return core.read_file(filename)
    end,
    retrieveItem = function (id)
      local res = core.bib[id]
      return res
    end
  }

  return citeproc_sys
end

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
  local citation = parse_latex_prop(citation_info)
  -- assert(citation.citationID)
  -- assert(citation.citationItems)
  -- assert(citation.properties)

 citation.citationItems = parse_latex_seq(citation.citationItems)

  for i, item in ipairs(citation.citationItems) do
    citation.citationItems[i] = parse_latex_prop(item)
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
            for id, _ in pairs(core.bib) do
              if not uncited_id_map[id] then
                table.insert(uncited_id_list, id)
                uncited_id_map[id] = true
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

function core.make_bibliography(engine)
  local result = engine:makeBibliography()

  local params = result[1]
  local bib_items = result[2]

  local res = ""

  local bib_options = {}
  bib_options["class"] = engine:get_style_class()
  local bib_option_list = {"class"}

  local bib_option_map = {
    ["entry-spacing"] = "entryspacing",
    ["line-spacing"] = "linespacing",
    ["hanging-indent"] = "hangingindent",
  }
  local bib_option_order = {
    "class",
    "hanging-indent",
    "line-spacing",
    "entry-spacing",
  }

  for option, param in pairs(bib_option_map) do
    if params[param] then
      bib_options[option] = params[param]
    end
  end

  local bib_options_str = "\\cslsetup{\n"
  for _, option in ipairs(bib_option_order) do
    local value = bib_options[option]
    if value then
      bib_options_str = bib_options_str .. string.format("  %s = %s,\n", option, tostring(value))
    end
  end
  bib_options_str = bib_options_str .. "}\n"
  res = res .. bib_options_str .. "\n"

  -- util.debug(params.bibstart)
  if params.bibstart then
    res = res .. params.bibstart
  end

  for _, bib_item in ipairs(bib_items) do
    res = res .. "\n" .. bib_item
  end

  if params.bibend then
    res = res .. "\n" .. params.bibend
  end
  return res
end


return core
