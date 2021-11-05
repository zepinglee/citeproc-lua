-- function csl.init(style_name, bib_data, locale, force_locale)
-- function csl.cite(prefix, suffix, keys)
-- function csl.register_items(keys)
-- function csl.bibliography()

-- local function convert_bib(path, output_path)
-- local function read_aux_file(aux_file)

-- local function make_citation(str)
-- local function make_citations(raw_citations)
-- local function get_citation_ids(citations)
-- local function process_citations(aux_file)
-- local function main()


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


function core.make_bibliography(engine)
  local result = engine:makeBibliography()

  local params = result[1]
  local bib_items = result[2]

  local res = ""

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
