--[[
  Copyright (C) 2021 Zeping Lee
--]]

local csl = {}

local citeproc = require("citeproc")
local util = citeproc.util
require("lualibs")
local core = require("csl-core")


csl.initialized = "false"
csl.citations = {}
csl.citations_pre = {}
csl.citations_post = {}
-- csl.ids = {}
-- csl.loaded_ids = {}
-- csl.include_all_items = false


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

  if csl.engine then
    csl.initialized = "true"
  else
    return
  end

  -- csl.init is called via \AtBeginDocument and it's executed after
  -- loading .aux file.  The csl.ids are already registered.
  csl.citation_strings = core.process_citations(csl.engine, csl.citations)
  csl.style_class = csl.engine:get_style_class()

  for _, citation in ipairs(csl.citations) do
    local citation_id = citation.citationID
    local citation_str = csl.citation_strings[citation_id]
    local bibcite_command = string.format("\\bibcite{%s}{{%s}{%s}}", citation.citationID, csl.style_class, citation_str)
    tex.sprint(bibcite_command)
  end

  for i, citation in ipairs(csl.citations) do
    csl.citations_post[i] = {citation.citationID, citation.properties.noteIndex}
  end

end


function csl.register_citation_info(citation_info)
  local citation = core.make_citation(citation_info)
  table.insert(csl.citations, citation)
end


function csl.cite(citation_info)
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local citation = core.make_citation(citation_info)

  if csl.citations_post[1] and csl.citations_post[1][1] == citation.citationID then
    table.remove(csl.citations_post, 1)
  end

  local res = csl.engine:processCitationCluster(citation, csl.citations_pre, csl.citations_post)

  local citation_str
  for _, citation_res in ipairs(res[2]) do
    local citation_id = citation_res[3]
    -- csl.citation_strings[citation_id] = citation_res[2]
    if citation_id == citation.citationID then
      citation_str = citation_res[2]
    end
  end
  tex.sprint(citation_str)

  table.insert(csl.citations_pre, {citation.citationID, citation.properties.noteIndex})
end

function csl.bibliography()
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
    return
  end

  -- if csl.include_all_items then
  --   for id, _ in pairs(csl.bib) do
  --     if not csl.loaded_ids[id] then
  --       table.insert(csl.ids, id)
  --       csl.loaded_ids[id] = true
  --     end
  --   end
  -- end
  -- csl.engine:updateItems(csl.ids)

  local result = core.make_bibliography(csl.engine)

  tex.print(util.split(result, "\n"))
end


return csl
