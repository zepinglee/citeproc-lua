local core = {}

local citeproc = require("citeproc")
local util = citeproc.util
require("lualibs")


core.locale_file_format = nil

function core.error(message)
  if luatexbase then
    luatexbase.module_error("csl", message)
  else
    util.error(message)
  end
end

function core.warning(message)
  if luatexbase then
    luatexbase.module_warning("csl", message)
  else
    util.warning(message)
  end
end

function core.info(message)
  if luatexbase then
    luatexbase.module_info("csl", message)
  else
    util.info(message)
  end
end


function core.read_file(filename, ftype)
  local path = kpse.find_file(filename, ftype)
  if not path then
    if ftype and not util.endswith(filename, ftype) then
      filename = filename .. ftype
    end
    core.error(string.format('Failed to find "%s".', filename))
  end
  local file = io.open(path, "r")
  if not file then
    core.error(string.format('Failed to open "%s".', path))
    return nil
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function load_bib(bib_files)
  local bib = {}
  for _, bib_file in ipairs(bib_files) do
    -- TODO: try to load `<bibname>.json` first?
    local bib_contents = core.read_file(bib_file, "bib")
    local file_name = bib_file
    if not util.endswith(file_name, ".bib") then
      file_name = file_name .. ".bib"
    end
    -- TODO: parse bib entries on demand
    local csl_items = citeproc.parse_bib(bib_contents)
    for _, item in ipairs(csl_items) do
      local id = item.id
      if bib[id] then
        core.error(string.format('Duplicate entry key "%s" in "%s".', id, file_name))
      end
      bib[id] = item
    end
  end
  return bib
end

function core.make_citeproc_sys(bib_files)
  core.bib = load_bib(bib_files)
  local citeproc_sys = {
    retrieveLocale = function (lang)
      local locale_file_format = core.locale_file_format or "locales-%s.xml"
      local filename = string.format(locale_file_format, lang)
      return core.read_file(filename)
    end,
    retrieveItem = function (id)
      local res = core.bib[id]
      if not res then
        core.error(string.format('Failed to find entry "%s".', id))
      end
      return res
    end
  }

  return citeproc_sys
end

function core.init(style_name, bib_files, locale, force_locale)
  if style_name == "" or #bib_files == 0 then
    return nil
  end
  local style = core.read_file(style_name .. ".csl")
  if not style then
    core.error(string.format('Failed to load style "%s".csl.', style_name))
    return nil
  end

  if locale == "" then
    locale = nil
  end

  local citeproc_sys = core.make_citeproc_sys(bib_files)
  local engine = citeproc.new(citeproc_sys, style, locale, force_locale)
  return engine
end


function core.make_citation(citation_info)
  -- `citation_info`: "{ITEM-1@2}{{id={ITEM-1},label={page},locator={6}}}{3}"
  local arguments = {}
  for argument in string.gmatch(citation_info, "(%b{})") do
    table.insert(arguments, string.sub(argument, 2, -2))
  end
  if #arguments ~= 3 then
    error(string.format('Invalid citation "%s"', citation_info))
    return nil
  end
  local citation_id, cite_items_str, note_index = table.unpack(arguments)

  local cite_items = {}
  for item_str in string.gmatch(cite_items_str, "(%b{})") do
    item_str = string.sub(item_str, 2, -2)
    local cite_item = {}
    for key, value in string.gmatch(item_str, "([%w%-]+)=(%b{})") do
      if key == "sub-verbo" then
        key = "sub verbo"
      end
      value = string.sub(value, 2, -2)
      cite_item[key] = value
    end
    table.insert(cite_items, cite_item)
  end

  local citation = {
    citationID = citation_id,
    citationItems = cite_items,
    properties = {
      noteIndex = tonumber(note_index),
    },
  }

  return citation
end


function core.process_citations(engine, citations)
  local citations_pre = {}
  local citations_post = {}

  for _, citation in ipairs(citations) do
    table.insert(citations_post, {citation.citationID, citation.properties.noteIndex})
  end

  -- Should be removed in future.
  local ids = core.get_cite_item_ids(citations)
  engine:updateItems(ids)

  local citation_strings = {}

  for i, citation in ipairs(citations) do
    table.remove(citations_post, 1)

    local res = engine:processCitationCluster(citation, citations_pre, citations_post)

    for _, citation_res in ipairs(res[2]) do
      local citation_str = citation_res[2]
      local citation_id = citation_res[3]
      citation_strings[citation_id] = citation_str
    end

    citations_pre[i] = {citation.citationID, citation.properties.noteIndex}
  end

  return citation_strings
end


function core.get_cite_item_ids(citations)
  local ids = {}
  local loaded = {}
  for _, citation in ipairs(citations) do
    for _, cite_item in ipairs(citation.citationItems) do
      local id = cite_item.id
      if not loaded[id] then
        table.insert(ids, id)
        loaded[id] = true
      end
    end
  end
  return ids
end


function core.make_bibliography(engine)
  local result = engine:makeBibliography()

  local params = result[1]
  local bib_items = result[2]

  local res = ""

  local bib_options = ""
  if params["hangingindent"] then
    bib_options = bib_options .. "\n  hanging-indent = true,"
  end
  if params["linespacing"] then
    bib_options = bib_options .. string.format("\n  line-spacing = %d,", params["linespacing"])
  end
  if params["entryspacing"] then
    bib_options = bib_options .. string.format("\n  entry-spacing = %d,", params["entryspacing"])
  end

  if bib_options ~= "" then
    bib_options = "\\cslsetup{" .. bib_options .. "\n}\n\n"
    res = res .. bib_options
  end

  if params.bibstart then
    res = res .. params.bibstart
  end

  for _, bib_item in ipairs(bib_items) do
    res = res .. "\n" .. bib_item .. "\n"
  end

  if params.bibend then
    res = res .. "\n" .. params.bibend .. "\n"
  end
  return res
end


return core
