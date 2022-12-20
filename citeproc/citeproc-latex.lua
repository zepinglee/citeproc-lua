--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local csl = {}

local citeproc = require("citeproc")
local util = citeproc.util
require("lualibs")
local core = require("citeproc-latex-core")


csl.initialized = "false"
csl.id_list = {}
csl.id_map = {}  -- Boolean map for checking if id in list
csl.uncited_id_list = {}
csl.uncited_id_map = {}
csl.citations_pre = {}

csl.preview_mode = false  -- Whether to use citeproc:preview_citation


function csl.init(style_name, bib_files, lang)
  bib_files = util.split(util.strip(bib_files), "%s*,%s*")

  csl.engine = core.init(style_name, bib_files, lang)

  if csl.engine then
    csl.initialized = "true"
  else
    return
  end

  -- csl.init is called via \AtBeginDocument and it's executed after
  -- loading .aux file.  The csl.id_list are already registered.
  csl.engine:updateItems(csl.id_list)

  if core.uncite_all_items then
    for id, _ in pairs(core.bib) do
      if not csl.uncited_id_map[id] then
        table.insert(csl.uncited_id_list, id)
        csl.uncited_id_map[id] = true
      end
    end
  end
  csl.engine:updateUncitedItems(csl.uncited_id_list)
  csl.style_class = csl.engine:get_style_class()
end


function csl.get_style_class()
  tex.sprint(csl.style_class)
end


function csl.register_citation_info(citation_info)
  local citation = core.make_citation(citation_info)
  if citation.citationID == "@nocite" then
    for _, cite_item in ipairs(citation.citationItems) do
      if cite_item.id == "*" then
        -- \nocite all items
        core.uncite_all_items = true

      elseif not csl.uncited_id_map[cite_item.id] then
        table.insert(csl.uncited_id_list, cite_item.id)
        csl.uncited_id_map[cite_item.id] = true
      end
    end

  else
    for _, cite_item in ipairs(citation.citationItems) do
      if not csl.id_map[cite_item.id] then
        table.insert(csl.id_list, cite_item.id)
        csl.id_map[cite_item.id] = true
      end
    end
  end
end


function csl.enable_linking()
  csl.engine:enable_linking()
end


function csl.cite(citation_info)
  -- "citationID={ITEM-UNAVAILABLE@1},citationItems={{id={ITEM-UNAVAILABLE}}},properties={noteIndex={1}}"
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local citation = core.make_citation(citation_info)

  local citation_str
  if csl.preview_mode then
    -- TODO: preview mode in first pass of \blockquote of csquotes
    -- citation_str = csl.engine:preview_citation(citation)
    citation_str = ""
  else
    citation_str = csl.engine:process_citation(citation)
  end

  -- tex.sprint(citation_str)
  token.set_macro("l__csl_citation_tl", citation_str)

  table.insert(csl.citations_pre, {citation.citationID, citation.properties.noteIndex})
end


function csl.nocite(ids_string)
  local uncited_ids = util.split(ids_string, "%s*,%s*")
  for _, uncited_id in ipairs(uncited_ids) do
    if uncited_id == "*" then
      if csl.engine then
        for id, _ in pairs(core.bib) do
          if not csl.uncited_id_map[id] then
            table.insert(csl.uncited_id_list, id)
            csl.uncited_id_map[id] = true
          end
        end
        csl.engine:updateUncitedItems(csl.uncited_id_list)
      else
        core.uncite_all_items = true
      end
    else
      if not csl.uncited_id_map[uncited_id] then
        table.insert(csl.uncited_id_list, uncited_id)
        csl.uncited_id_map[uncited_id] = true
        if csl.engine then
          csl.engine:updateUncitedItems(csl.uncited_id_list)
        end
      end
    end
  end
end


function csl.bibliography()
  if not csl.engine then
    util.error("CSL engine is not initialized.")
    return
  end

  local result = core.make_bibliography(csl.engine)
  -- util.debug(result)

  -- token.set_macro("g__csl_bibliography_tl", result)

  tex.print(util.split(result, "\n"))
end


return csl
