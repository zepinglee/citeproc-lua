--[[
  Copyright (C) 2021 Zeping Lee
--]]

local csl = {}

csl.ids = {}

local citeproc = require("citeproc")
local util = citeproc.util
require("lualibs")


function csl.error(str)
  luatexbase.module_error("csl", str)
end
function csl.warning(str)
  luatexbase.module_warning("csl", str)
end
function csl.info(str)
  luatexbase.module_info("csl", str)
end

local function read_file(filename, ftype)
  local path = kpse.find_file(filename, ftype)
  if not path then
    if ftype and not util.endswith(filename, ftype) then
      filename = filename .. ftype
    end
    csl.error(string.format('Failed to find "%s".', filename))
  end
  local file = io.open(path, "r")
  if not file then
    csl.error(string.format('Failed to open "%s".', path))
    return nil
  end
  local contents = file:read("*a")
  file:close()
  return contents
end

local function load_bib(bib_names)
  local bib = {}
  bib_names = util.strip(bib_names)
  for _, bib_name in ipairs(util.split(bib_names, ",%s*")) do
    -- TODO: try to load `<bibname>.json` first?
    local bib_contents = read_file(bib_name, "bib")
    local file_name = bib_name
    if not util.endswith(file_name, ".bib") then
      file_name = file_name .. ".bib"
    end
    -- TODO: parse bib entries on demand
    local csl_items = citeproc.parse_bib(bib_contents)
    for _, item in ipairs(csl_items) do
      local id = item.id
      if bib[id] then
        csl.error(string.format('Duplicate entry key "%s" in "%s".', id, file_name))
      end
      bib[id] = item
    end
  end
  return bib
end

local function make_citeproc_sys(bib_names)

  local bib = load_bib(bib_names)
  local citeproc_sys = {
    retrieveLocale = function (lang)
      local locale_name_format = csl.locale_name_format or "locales-%s.xml"
      local filename = string.format(locale_name_format, lang)
      return read_file(filename)
    end,
    retrieveItem = function (id)
      local res = bib[id]
      if not res then
        csl.error(string.format('Failed to find entry "%s".', id))
      end
      return res
    end
  }

  return citeproc_sys
end

function csl.init(style_name, bib_names)
  if style_name == "" or bib_names == "" then
    csl.engine = nil
    return
  end
  local style = read_file(style_name .. ".csl")
  if not style then
    return
  end

  local citeproc_sys = make_citeproc_sys(bib_names)
  csl.engine = citeproc.new(citeproc_sys, style)
  tex.sprint("\\CslEngineInitialized")

  -- csl.init is called via \AtBeginDocument and it's executed after
  -- loading .aux file.  The csl.ids are already registered.
  csl.engine:updateItems(csl.ids)
end

function csl.cite(prenote, postnote, keys)
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local cite_items = {}
  for key in string.gmatch(keys, "([^,%s]+)") do
    cite_items[#cite_items+1] = {id = key}
  end
  if #cite_items == 0 then
    return
  end

  if prenote then
    cite_items[1].prefix = prenote
  end
  if postnote then
    if string.match(postnote, "^%s*%d+$") then
      cite_items[1].locator = tonumber(postnote)
    else
      cite_items[1].suffix = postnote
    end
  end

  -- TODO: Use processCitationCluster()
  local result = csl.engine:makeCitationCluster(cite_items)
  tex.sprint(result)
end

function csl.register_items(keys)
  for key in string.gmatch(keys, "([^,%s]+)") do
    table.insert(csl.ids, key)
  end
end

function csl.bibliography()
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local result = csl.engine:makeBibliography()

  local params = result[1]
  local bibitems = result[2]
  -- util.debug(params)

  tex.print(params.bibstart)
  for _, bibitem in ipairs(bibitems) do
    -- util.debug(bibitem)
    tex.print(bibitem)
  end
  tex.print(params.bibend)
end


return csl
