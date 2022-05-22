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
csl.citations = {}
csl.citations_pre = {}


function csl.error(str)
  luatexbase.module_error("csl", str)
end
function csl.warning(str)
  luatexbase.module_warning("csl", str)
end
function csl.info(str)
  luatexbase.module_info("csl", str)
end


function csl.init(style_name, bib_files, lang)
  bib_files = util.split(util.strip(bib_files), "%s*,%s*")

  csl.engine = core.init(style_name, bib_files, lang)

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

end


function csl.register_citation_info(citation_info)
  local citation = core.make_citation(citation_info)
  table.insert(csl.citations, citation)
end


function csl.enable_linking()
  csl.engine:enable_linking()
end


function csl.cite(citation_info)
  if not csl.engine then
    csl.error("CSL engine is not initialized.")
  end

  local citation = core.make_citation(citation_info)

  local res = csl.engine:processCitationCluster(citation, csl.citations_pre, {})

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


function csl.nocite(ids_string)
  local cite_ids = util.split(ids_string, "%s*,%s*")
  if csl.engine then
    local ids = {}
    for _, cite_id in ipairs(cite_ids) do
      if cite_id == "*" then
        for item_id, _ in pairs(core.bib) do
          table.insert(ids, item_id)
        end
      else
        table.insert(ids, cite_id)
      end
    end
    csl.engine:updateUncitedItems(ids)
  else
    -- `\nocite` in preamble, where csl.engine is not initialized yet
    for _, cite_id in ipairs(cite_ids) do
      if cite_id == "*" then
        core.uncite_all_items = true
      else
        if not core.loaded_ids[cite_id] then
          table.insert(core.ids, cite_id)
          core.loaded_ids[cite_id] = true
        end
      end
    end
  end
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
