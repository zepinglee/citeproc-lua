--[[
  Copyright (C) 2021 Zeping Lee
--]]

local csl = {
  ids = {},
  initialized = "false"
}

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

local function load_bib(bib_files)
  local bib = {}
  for _, bib_file in ipairs(bib_files) do
    -- TODO: try to load `<bibname>.json` first?
    local bib_contents = read_file(bib_file, "bib")
    local file_name = bib_file
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

local function make_citeproc_sys(bib_files)
  local bib = load_bib(bib_files)
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

function csl.init(style_name, bib_data)
  if style_name == "" or bib_data == "" then
    csl.engine = nil
    return
  end
  local style = read_file(style_name .. ".csl")
  if not style then
    return
  end

  local bib_files = util.split(util.strip(bib_data), ",%s*")

  local citeproc_sys = make_citeproc_sys(bib_files)
  csl.engine = citeproc.new(citeproc_sys, style)

  -- csl.init is called via \AtBeginDocument and it's executed after
  -- loading .aux file.  The csl.ids are already registered.
  csl.engine:updateItems(csl.ids)
  csl.initialized = "true"
end

function csl.cite(prefix, suffix, keys)
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local cite_items = {}
  for key in string.gmatch(keys, "([^,%s]+)") do
    cite_items[#cite_items+1] = {id = key}
  end
  if #cite_items == 0 then
    return cite_items
  end

  if prefix then
    cite_items[1].prefix = prefix
  end
  if suffix then
    if string.match(suffix, "^%s*%d+$") then
      cite_items[1].locator = tonumber(suffix)
    else
      cite_items[1].suffix = suffix
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
  local bib_items = result[2]
  -- util.debug(params)

  tex.print(params.bibstart)
  for _, bib_item in ipairs(bib_items) do
    tex.print(util.split(bib_item, "\n"))
  end
  tex.print(params.bibend)
end


return csl
