--[[
  Copyright (C) 2021 Zeping Lee
--]]

local csl = {}

local citeproc = require("citeproc")
local util = citeproc.util
require("lualibs")
local core = require("csl-core")


csl.ids = {}
csl.loaded_ids = {}
csl.bib = {}
csl.initialized = "false"
csl.include_all_items = false


function csl.error(str)
  luatexbase.module_error("csl", str)
end
function csl.warning(str)
  luatexbase.module_warning("csl", str)
end
function csl.info(str)
  luatexbase.module_info("csl", str)
end



function csl.init(style_name, bib_files, locale, force_locale)
  bib_files = util.split(util.strip(bib_files), ",%s*")

  csl.engine = core.init(style_name, bib_files, locale, force_locale)

  -- csl.init is called via \AtBeginDocument and it's executed after
  -- loading .aux file.  The csl.ids are already registered.
  if csl.engine then
    csl.engine:updateItems(csl.ids)
    csl.initialized = "true"
  end
end

function csl.cite(prefix, suffix, keys)
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local cite_items = {}
  for key in string.gmatch(keys, "([^,%s]+)") do
    if not csl.loaded_ids[key] then
      table.insert(csl.ids, key)
      csl.loaded_ids[key] = true
    end
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
    if key == "*" then
      csl.include_all_items = true
    elseif not csl.loaded_ids[key] then
      table.insert(csl.ids, key)
      csl.loaded_ids[key] = true
    end
  end
end

function csl.bibliography()
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
    return
  end

  if csl.include_all_items then
    for id, _ in pairs(csl.bib) do
      if not csl.loaded_ids[id] then
        table.insert(csl.ids, id)
        csl.loaded_ids[id] = true
      end
    end
  end
  csl.engine:updateItems(csl.ids)

  local result = core.make_bibliography(csl.engine)

  tex.print(util.split(result, "\n"))
end


return csl
