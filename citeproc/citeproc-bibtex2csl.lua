--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local bibtex2csl = {}

local bibtex_parser = require("citeproc-bibtex-parser")
local bibtex_data = require("citeproc-bibtex-data")
local latex_parser = nil -- load as needed
local util = require("citeproc-util")


---@alias CslItem table
---@alias CslData CslItem[]


local parser = bibtex_parser.BibtexParser:new()


---Parse BibTeX content and convert to CSL-JSON
---@param str string
---@param keep_unknown_commands boolean? Keep unknown latex markups in <code>.
---@param case_protection boolean? Add case-protection to braces as in BibTeX.
---@param sentence_case_title boolean? Convert `title` and `booktitle` to sentence case.
---@param check_sentence_case boolean? Check titles that are already sentence cased and do not conver them.
---@return CslData?, Exception[]
function bibtex2csl.parse_bibtex_to_csl(str, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)
  local strings = {}
  for name, macro in pairs(bibtex_data.macros) do
    strings[name] = macro.value
  end
  local bib_data, exceptions = bibtex_parser.parse(str, strings)
  local csl_json_items = nil
  if bib_data then
    csl_json_items = bibtex2csl.convert_to_csl_data(bib_data, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)
  end
  return csl_json_items, exceptions
end


---@param bib BibtexData
---@param keep_unknown_commands boolean?
---@param case_protection boolean?
---@param sentence_case_title boolean?
---@param check_sentence_case boolean?
---@return CslData
function bibtex2csl.convert_to_csl_data(bib, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)
  local csl_data = {}
  for _, entry in ipairs(bib.entries) do
    local item = {
      id = entry.key,
      type = "document",
    }

    -- CSL types
    local type_data = bibtex_data.types[entry.type]
    if type_data and type_data.csl then
      item.type = type_data.csl
    end

    --TODO: language

    -- TODO: preprosse
    -- Merge title, maintitle, substitle, titleaddon

    for field, value in pairs(entry.fields) do
      local csl_field, csl_value = bibtex2csl.convert_field(
        field, value, keep_unknown_commands, case_protection, sentence_case_title, item.language, check_sentence_case)
      if csl_field and csl_value and not item[csl_field] then
        item[csl_field] = csl_value
      end
    end

    bibtex2csl.process_special_fields(item, entry.fields)

    table.insert(csl_data, item)
  end
  return csl_data
end


---Convert BibTeX field to CSL field
---@param bib_field string
---@param value string
---@param keep_unknown_commands boolean?
---@param case_protection boolean?
---@param sentence_case_title boolean?
---@param language string?
---@param check_sentence_case boolean?
---@return string? csl_field
---@return string | table | number?  csl_value
function bibtex2csl.convert_field(bib_field, value, keep_unknown_commands, case_protection, sentence_case_title, language, check_sentence_case)
  local field_data = bibtex_data.fields[bib_field]
  if not field_data then
    return nil, nil
  end
  local csl_field = field_data.csl
  if not (csl_field and type(csl_field) == "string") then
    return nil, nil
  end

  latex_parser = latex_parser or require("citeproc-latex-parser")

  local field_type = field_data.type
  local csl_value
  if field_type == "name" then
  -- 1. unicode 2. prify (remove LaTeX markups) 3. plain text 4. split name parts
    value = latex_parser.latex_to_unicode(value)
    local names = bibtex_parser.split_names(value)
    csl_value = {}
    for i, name_str in ipairs(names) do
      local name_dict = bibtex_parser.split_name_parts(name_str)
      csl_value[i] = bibtex2csl.convert_to_csl_name(name_dict)
    end

  elseif bib_field == "title" or bib_field == "booktitle" then
    -- util.debug(value)
    -- 1. unicode 2. sentence case 3. html tag
    if sentence_case_title and (not language or util.startswith(language, "en")) then
      -- util.debug(value)
      csl_value = latex_parser.latex_to_sentence_case_pseudo_html(value, keep_unknown_commands, case_protection, check_sentence_case)
      -- util.debug(csl_value)
    else
      csl_value = latex_parser.latex_to_pseudo_html(value, keep_unknown_commands, case_protection)
    end

  else
    -- 1. unicode 2. html tag
    csl_value = latex_parser.latex_to_pseudo_html(value, keep_unknown_commands, case_protection)
    if field_type == "date" then
      csl_value = bibtex2csl._parse_edtf_date(csl_value)
    elseif csl_field == "volume" or csl_field == "page" then
      csl_value = string.gsub(csl_value, util.unicode["en dash"], "-")
    end
  end

  return csl_field, csl_value
end


local function clean_name_part(name_part)
  if not name_part then
    return nil
  end
  return string.gsub(name_part, "[{}]", "")
end


function bibtex2csl.convert_to_csl_name(bibtex_name)
  if bibtex_name.last and not (bibtex_name.first or bibtex_name.von or bibtex_name.jr)
    and string.match(bibtex_name.last, "^%b{}$") then
    -- util.debug(bibtex_name)
    return {
      literal = string.sub(bibtex_name.last, 2, -2)
    }
  end
  local csl_name = {
    family = clean_name_part(bibtex_name.last),
    ["non-dropping-particle"] = clean_name_part(bibtex_name.von),
    given = clean_name_part(bibtex_name.first),
    suffix = clean_name_part(bibtex_name.jr),
  }
  return csl_name
end


function bibtex2csl.process_special_fields(item, bib_fields)
  -- Default entry type `document`
  if item.type == "document" then
    if item.URL then
      item.type = "webpage"
    else
      item.type = "article"
    end
  end

  -- event-title: for compatibility with CSL v1.0.1 and earlier versions
  if item["event-title"] then
    item.event = item["event-title"]
  end

  -- issued date
  if bib_fields.year and not item.issued then
    item.issued = bibtex2csl._parse_edtf_date(bib_fields.year)
  end
  local month = bib_fields.month
  if month and string.match(month, "^%d+$") then
    if item.issued and item.issued["date-parts"] and
        item.issued["date-parts"][1] and
        item.issued["date-parts"][1][2] == nil then
      item.issued["date-parts"][1][2] = tonumber(month)
    end
  end

  -- language: convert `babel` language to ISO 639-1 language code
  if not item.language and bib_fields.language then
    item.language = bib_fields.language
  end
  if item.language then
    local language_code = bibtex_data.language_code_map[item.language]
    if language_code then
      item.language = language_code
    end
  end
  -- if not item.language then
  --   if util.has_cjk_char(item.title) then
  --     item.language = "zh"
  --   end
  -- end

  -- Jounal abbreviations
  if item.type == "article-journal" or item.type == "article-magazine"
      or item.type == "article-newspaper" then
    util.check_journal_abbreviations(item)
  end

  -- number
  if item.number then
    if item.type == "article-journal" or item.type == "article-magazine" or
        item.type == "article-newspaper" or item.type == "periodical" then
      if not item.issue then
        item.issue = item.number
        item.number = nil
      end
    elseif item["collection-title"] and not item["collection-number"] then
      item["collection-number"] = item.number
      item.number = nil
    end
  end

  -- PMID
  if bib_fields.eprint and string.lower(bib_fields.eprinttype) == "pubmed" and not item.PMID then
    item.PMID = bib_fields.eprint
  end

end


function bibtex2csl._parse_edtf_date(str)
  local date_range = util.split(str, "/")
  if #date_range == 1 then
    date_range = util.split(str, util.unicode["en dash"])
  end

  local literal = { literal = str }

  if #date_range > 2 then
    return literal
  end

  local date = {}
  date["date-parts"] = {}
  for _, date_part in ipairs(date_range) do
    local date_ = bibtex2csl._parse_single_date(date_part)
    if not date_ then
      return literal
    end
    table.insert(date["date-parts"], date_)
  end
  return date
end


function bibtex2csl._parse_single_date(str)
  local date = {}
  for _, date_part in ipairs(util.split(str, "%-")) do
    if not string.match(date_part, "^%d+$") then
      return nil
    end
    table.insert(date, tonumber(date_part))
  end
  return date
end


return bibtex2csl
