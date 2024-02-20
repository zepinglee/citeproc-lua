--
-- Copyright (c) 2021-2024 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local bibtex2csl = {}

local uni_utf8
local bibtex_parser
local bibtex_data
local latex_parser
local unicode
local util
if kpse then
  uni_utf8 = require("unicode").utf8
  bibtex_parser = require("citeproc-bibtex-parser")
  bibtex_data = require("citeproc-bibtex-data")
  unicode = require("citeproc-unicode")
  util = require("citeproc-util")
else
  uni_utf8 = require("lua-utf8")
  bibtex_parser = require("citeproc.bibtex-parser")
  bibtex_data = require("citeproc.bibtex-data")
  unicode = require("citeproc.unicode")
  util = require("citeproc.util")
end


---@alias CslItem ItemData
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
    bibtex_parser.resolve_crossrefs(bib_data.entries, bibtex_data.entries_by_id)
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

  -- BibTeX looks for crossref in a case-insensitive manner.
  local entries_by_id = {}
  for _, entry in ipairs(bib.entries) do
    entries_by_id[unicode.casefold(entry.key)] = entry
  end

  for _, entry in ipairs(bib.entries) do
    local item = bibtex2csl.convert_to_csl_item(entry, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)
    table.insert(csl_data, item)
  end
  return csl_data
end


---@param entry BibtexEntry
---@param keep_unknown_commands boolean?
---@param case_protection boolean?
---@param sentence_case_title boolean?
---@param check_sentence_case boolean?
---@return CslItem
function bibtex2csl.convert_to_csl_item(entry, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)
  ---@type CslItem
  local item = {
    id = entry.key,
    type = "document",
  }

  bibtex2csl.pre_process_special_fields(item, entry)

  -- First convert primary fields
  for field, csl_field in pairs(bibtex_data.primary_fields) do
    local value = entry.fields[field]
    if value then
      local _, csl_value = bibtex2csl.convert_field(
        field, value, keep_unknown_commands, case_protection, sentence_case_title, item.language, check_sentence_case)
      if csl_field and csl_value and not item[csl_field] then
        item[csl_field] = csl_value
      end
    end
  end

  -- Convert the fields in a fixed order
  local field_list = {}
  for field, _ in pairs(entry.fields) do
    table.insert(field_list, field)
  end
  table.sort(field_list)

  for _, field in ipairs(field_list) do
    local value = entry.fields[field]
    local csl_field, csl_value = bibtex2csl.convert_field(
      field, value, keep_unknown_commands, case_protection, sentence_case_title, item.language, check_sentence_case)
    if csl_field and csl_value and not item[csl_field] then
      item[csl_field] = csl_value
    end
  end

  bibtex2csl.post_process_special_fields(item, entry)
  return item
end


---@param item CslItem
---@param entry BibtexEntry
function bibtex2csl.pre_process_special_fields(item, entry)
  -- CSL types
  local type_data = bibtex_data.types[entry.type]
  if type_data and type_data.csl then
    item.type = type_data.csl
  elseif entry.fields.url then
    item.type = "webpage"
  end

  -- BibTeX's `edition` is expected to be an ordinal.
  if entry.fields.edition then
    item.edition = util.convert_ordinal_to_arabic(entry.fields.edition)
  end

  -- language: convert `babel` language to ISO 639-1 language code
  local lang = entry.fields.langid or entry.fields.language
  if lang then
    item.language = bibtex_data.language_code_map[unicode.casefold(lang)]
  end
  -- if not item.language then
  --   if util.has_cjk_char(item.title) then
  --     item.language = "zh"
  --   end
  -- end

  -- Merge title, maintitle, subtitle, titleaddon
  bibtex2csl.process_titles(entry)

end


---@param entry BibtexEntry
function bibtex2csl.process_titles(entry)
  local fields = entry.fields
  if fields.subtitle then
    if not fields.shorttitle then
      fields.shorttitle = fields.title
    end
    if fields.title then
      fields.title = util.join_title(fields.title, fields.subtitle)
    else
      fields.title = fields.subtitle
    end
  end
  if fields.booksubtitle then
    if not fields.shorttitle then
      fields["container-title-short"] = fields.booktitle
    end
    if fields.booktitle then
      fields.booktitle = util.join_title(fields.booktitle, fields.booksubtitle)
    else
      fields.booktitle = fields.booksubtitle
    end
  end
  if fields.journalsubtitle then
    if fields.journaltitle then
      fields.journaltitle = util.join_title(fields.journaltitle, fields.journalsubtitle)
    elseif fields.journal then
      fields.journal = util.join_title(fields.journal, fields.journal)
    end
  end
  if fields.issuesubtitle then
    if not fields.shorttitle then
      fields["volume-title-short"] = fields.issuetitle
    end
    if fields.issuetitle then
      fields.issuetitle = util.join_title(fields.issuetitle, fields.issuesubtitle)
    else
      fields.issuetitle = fields.issuesubtitle
    end
  end
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

  if kpse then
    latex_parser = latex_parser or require("citeproc-latex-parser")
  else
    latex_parser = latex_parser or require("citeproc.latex-parser")
  end

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

  elseif field_type == "date" then
    csl_value = latex_parser.latex_to_pseudo_html(value, false, false)
    csl_value = bibtex2csl._parse_edtf_date(csl_value)

  elseif bib_field == "title" or bib_field == "shorttitle"
      or bib_field == "booktitle" or bib_field == "container-title-short" then
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
    if csl_field == "volume" or csl_field == "page" then
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


---@param item CslItem
---@param entry BibtexEntry
function bibtex2csl.post_process_special_fields(item, entry)
  local bib_type = entry.type
  local bib_fields = entry.fields
  -- event-title: for compatibility with CSL v1.0.1 and earlier versions
  if item["event-title"] then
    item.event = item["event-title"]
  end

  -- Jounal abbreviations
  if item.type == "article-journal" or item.type == "article-magazine"
      or item.type == "article-newspaper" then
    util.check_journal_abbreviations(item)
  end

  -- month
  -- local month = bib_fields.month
  local month_text = bib_fields.month
  if month_text then
    month_text = latex_parser.latex_to_pseudo_html(month_text, false, false)
    local month, day = uni_utf8.match(month_text, "^(%a+)%.?,?%s+(%d+)%a*$")
    if not month then
      day, month = uni_utf8.match(month_text, "^(%d+)%a*%s+(%a+)%.?$")
    end
    if not month then
      month = string.match(month_text, "^(%a+)%.?$")
    end
    if month then
      month = bibtex_data.months[unicode.casefold(month)]
    end
    if month and item.issued and item.issued["date-parts"] and
        item.issued["date-parts"][1] and
        item.issued["date-parts"][1][2] == nil then
      item.issued["date-parts"][1][2] = tonumber(month)
      if day then
        item.issued["date-parts"][1][3] = tonumber(day)
      end
    end
  end

  -- number
  if bib_fields.number then
    if item.type == "article-journal" or item.type == "article-magazine" or
        item.type == "article-newspaper" or item.type == "periodical" then
      if not item.issue then
        item.issue = bib_fields.number
      end
    elseif item["collection-title"] and not item["collection-number"] then
      item["collection-number"] = bib_fields.number
    elseif not item.number then
      item.number = bib_fields.number
    end
  end

  -- organization: the `organizer` that sponsors a conference or a `publisher` that publishes a `@manual` or `@online`.
  if bib_fields.organization then
    if item.publisher or bib_type == "inproceedings" or bib_type == "proceedings" then
      if not item.organizer then
        item.organizer = {
          literal = bib_fields.organization
        }
      end
    elseif not item.publisher then
      item.publisher = bib_fields.organization
    end
  end

  -- PMID
  if bib_fields.eprint and type(bib_fields.eprinttype) == "string" and
      string.lower(bib_fields.eprinttype) == "pubmed" and not item.PMID then
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
