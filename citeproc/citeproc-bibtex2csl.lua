--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local bibtex2csl = {}

local uni_utf8
local bibtex_parser
local bibtex_data
local journal_data
local latex_parser
local unicode
local util
local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
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
    -- TODO: Ideally we should load all .bib files and then resolve crossrefs and related
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
  local bib_entry_dict = {}
  local csl_item_dict = {}

  for _, entry in ipairs(bib.entries) do
    bib_entry_dict[unicode.casefold(entry.key)] = entry
    local item = bibtex2csl.convert_to_csl_item(entry, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case)

    table.insert(csl_data, item)
    csl_item_dict[item.id] = item
  end

  bibtex2csl.resolve_related(csl_item_dict, bib_entry_dict)

  return csl_data
end


---@param entry BibtexEntry
---@param keep_unknown_commands boolean?
---@param case_protection boolean?
---@param sentence_case_title boolean?
---@param check_sentence_case boolean?
---@return CslItem
function bibtex2csl.convert_to_csl_item(entry, keep_unknown_commands, case_protection, sentence_case_title, check_sentence_case, disable_journal_abbreviation)
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

  bibtex2csl.post_process_special_fields(item, entry, disable_journal_abbreviation)
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

  -- biblatex-apa
  if entry.fields.howpublished then
    local howpublished = string.lower(entry.fields.howpublished)
    if howpublished == "advance online publication" then
      -- TODO: get_locale_term("advance online publication" )
      item.status = "Advance online publication"
    elseif howpublished == "manunpub" then
      -- biblatex-apa
      item.genre = "Unpublished manuscript"
    elseif howpublished == "maninprep" then
      -- biblatex-apa
      item.genre = "Manuscript in preparation"
    elseif howpublished == "mansub" then
      -- biblatex-apa
      item.genre = "Manuscript submitted for publication"
    end
  end
  if entry.fields.pubstate
      and string.lower(entry.fields.pubstate) == "inpress" then
    -- TODO: get_locale_term("advance online publication" )
    item.status = "in press"
  end
end


---@param entry BibtexEntry
function bibtex2csl.process_titles(entry)
  local fields = entry.fields
  -- title and subtitle
  if fields.subtitle then
    if fields.title then
      fields.title = util.join_title(fields.title, fields.subtitle)
      if not fields.shorttitle then
        fields.shorttitle = fields.title
      end
    else
      fields.title = fields.subtitle
    end
    fields.subtitle = nil
  end

  -- booktitle and booksubtitle
  if fields.booksubtitle then
    if not fields["container-title-short"] then
      fields["container-title-short"] = fields.booktitle
    end
    if fields.booktitle then
      fields.booktitle = util.join_title(fields.booktitle, fields.booksubtitle)
    else
      fields.booktitle = fields.booksubtitle
    end
    fields.booksubtitle = nil
  end

  -- mainsubtitle
  if fields.mainsubtitle then
    if fields.maintitle then
      fields.maintitle = util.join_title(fields.maintitle, fields.mainsubtitle)
    else
      fields.maintitle = fields.mainsubtitle
    end
  end

  -- maintitle
  if fields.maintitle then
    if entry.type == "audio" or entry.type == "video" then
      -- maintitle is the container-title
      fields["container-title"] = fields.maintitle
    elseif fields.booktitle then
      -- maintitle is with booktitle
      if not fields["volume-title"] then
        fields["volume-title"] = fields.booktitle
        fields.booktitle = fields.maintitle
      end
    else
      -- maintitle is with title
      if fields.title then
        if not fields["volume-title"] then
          fields["volume-title"] = fields.title
          fields.title = fields.maintitle
        end
      else
        -- This is unlikelu to happen.
        fields.title = fields.maintitle
      end
    end
  end

  if fields.journalsubtitle then
    if fields.journaltitle then
      fields.journaltitle = util.join_title(fields.journaltitle, fields.journalsubtitle)
    elseif fields.journal then
      fields.journal = util.join_title(fields.journal, fields.journal)
    end
    fields.journalsubtitle = nil
  end
  if fields.issuesubtitle then
    if fields.issuetitle then
      fields.issuetitle = util.join_title(fields.issuetitle, fields.issuesubtitle)
    else
      fields.issuetitle = fields.issuesubtitle
    end
    fields.issuesubtitle = nil
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

  if using_luatex then
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
    if string.match(value, "\\") then
      -- "{\noopsort{1973c}}1981"
      value = latex_parser.latex_to_pseudo_html(value, false, false)
    end
    -- "-3000~" should not be converted to "-3000 "
    csl_value = util.parse_edtf(value)

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


local arxiv_url_prefix = "https://arxiv.org/abs/"
local pubmed_url_prefix = "https://www.ncbi.nlm.nih.gov/pubmed/"
local pubmed_central_url_prefix = "https://www.ncbi.nlm.nih.gov/pmc/articles/"


---@param item CslItem
---@param entry BibtexEntry
function bibtex2csl.post_process_special_fields(item, entry, disable_journal_abbreviation)
  local bib_type = entry.type
  local bib_fields = entry.fields

  -- biblatex-apa
  if item.type == "article-journal" and entry.fields.entrysubtype == "nonacademic" then
    item.type = "article-magazine"
    item.genre = nil

  elseif item.type == "motion_picture" then
    if entry.fields.entrysubtype == "tvseries" then
      item.type = "broadcast"
      if item.genre == "tvseries" then
        item.genre = "TV series"
      end
    elseif entry.fields.entrysubtype == "tvepisode" then
      item.type = "broadcast"
      if item.genre == "tvepisode" then
        item.genre = "TV series episode"
      end
    end

  elseif item.type == "song" then
    if entry.fields.entrysubtype == "podcast" then
      item.type = "broadcast"
      if item.genre == "podcast" then
        item.genre = "Audio podcast"
      end

    elseif entry.fields.entrysubtype == "podcastepisode" then
      item.type = "broadcast"
      if item.genre == "podcastepisode" then
        item.genre = "Audio podcast episode"
      end

    elseif entry.fields.entrysubtype == "interview" then
      item.type = "interview"

    elseif entry.fields.entrysubtype == "speech" then
      item.type = "speech"

    end

  elseif item.type == "graphic" then
    item["archive-place"] = item["publisher-place"]

    if entry.fields.entrysubtype == "map" then
      item.type = "map"
    end

  elseif item.type == "webpage" then

    -- eprinttype is mapped to
    -- - `archive` for Google books;
    -- - `container-title` for twitter post;
    -- - `publisher` for arXiv preprint;

    local eprint_type_map = {
      facebook = "post",
      instagram = "post",
      reddit = "post",
      twitter = "post",
      arxiv = "preprint",
      psyarxiv = "preprint",
      pubmed = "preprint",
      ["pubmed central"] = "preprint",
    }

    -- Biblatex's `online` type can be mapped to `post`, `preprint`
    -- local eprinttype = entry.fields.eprinttype or entry.fields.archiveprefix
    if item.archive then
      local eprint_type = eprint_type_map[string.lower(item.archive)]
      if eprint_type then
        item.type = eprint_type
      elseif item.number then
        item.type = "preprint"
      elseif entry.fields.eprint then
        item.type = "preprint"
        item.numerb = entry.fields.eprint
      elseif item.DOI then
        item.type = "preprint"
      elseif item.URL then
        if util.startswith(item.URL, arxiv_url_prefix) then
          item.type = "preprint"
        elseif util.startswith(item.URL, pubmed_url_prefix) then
          item.type = "preprint"
        elseif util.startswith(item.URL, pubmed_central_url_prefix) then
          item.type = "preprint"
        end
      end
      if item.type == "preprint" then
        if not item.publisher then
          item.publisher = item.archive
          item.archive = nil
        end
        if not item.number then
          item.number = entry.fields.eprint
        end
      else
        if not item["container-title"] then
          item["container-title"] = item.archive
          item.archive = nil
        end
      end
    end

  end

  -- event-date
  if item["event-date"] and not item.issued then
    item.issued = util.deep_copy(item["event-date"])
  end

  -- event-title: for compatibility with CSL v1.0.1 and earlier versions
  if item["event-title"] then
    item.event = item["event-title"]
  end

  -- Jounal abbreviations
  if not disable_journal_abbreviation then
    if item.type == "article-journal" or item.type == "article-magazine"
        or item.type == "article-newspaper" then
      bibtex2csl.check_journal_abbreviations(item)
    end
  end

  if not item.genre then
    if bib_type == "phdthesis" then
      -- from APA
      item.genre = "Doctoral dissertation"
    elseif bib_type == "mastersthesis" then
      item.genre = "Master’s thesis"
    end
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
      item.number = string.gsub(bib_fields.number, "([^-])%-([^-])", "%1\\-%2")
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

  -- DOI
  if type(item.DOI) == "string" then
    item.DOI = util.remove_prefix(item.DOI, "https://doi.org/")
    item.DOI = util.remove_prefix(item.DOI, "doi.org/")
  end

  -- PMID
  if bib_fields.eprint and type(bib_fields.eprinttype) == "string" and
      string.lower(bib_fields.eprinttype) == "pubmed" and not item.PMID then
    item.PMID = bib_fields.eprint
  end

  if item.URL then
    if item.type == "preprint" and util.startswith(item.URL, arxiv_url_prefix) then
      if not item.publisher then
        item.publisher = "arXiv"
        item.archive = nil
      end
      if not item.number then
        item.number = util.remove_prefix(item.URL, pubmed_url_prefix)
      end
    end

    if util.startswith(item.URL, pubmed_url_prefix) then
      if not item.publisher then
        item.publisher = "PubMed"
        item.archive = nil
      end
      if not item.PMID then
        item.PMID = util.remove_prefix(item.URL, pubmed_url_prefix)
      end
    end

    if util.startswith(item.URL, pubmed_central_url_prefix) then
      if not item.publisher then
        item.publisher = "PubMed Central"
        item.archive = nil
      end
      if not item.PMCID then
        item.PMCID = util.remove_prefix(item.URL, pubmed_central_url_prefix)
      end
    end
  end

  -- `APA Education [@APAEducation], (2018, June 29). College students are forming menta/-health c/ubs-and they're making a difference @washingtonpost [Thumbnail with link attached]`
  -- The `[Thumbnail with link attached]` should not be italicized.
  -- if bib_fields.titleaddon and item.genre and item.genre ~= bib_fields.titleaddon then
  --   if item.title then
  --     item.title = string.format("%s [%s]", item.title, bib_fields.titleaddon)
  --   end
  -- end

end


function bibtex2csl.check_journal_abbreviations(item)
  if item["container-title"] and not item["container-title-short"] then
    if not journal_data then
      if using_luatex then
        journal_data = require("citeproc-journal-data")
      else
        journal_data = require("citeproc.journal-data")
      end
    end
    local key = unicode.casefold(string.gsub(item["container-title"], "%.", ""))
    local abbr = journal_data.abbrevs[key]
    if abbr then
      item["container-title-short"] = abbr
    else
      local full = journal_data.unabbrevs[key]
      if full then
        item["container-title-short"] = item["container-title"]
        item["container-title"] = full
      end
    end
  end
end


local original_field_dict = {
  author = "original-author",
  issued = "original-date",
  publisher = "original-publisher",
  ["publisher-place"] = "original-publisher-place",
  title = "original-title",
}

local reviewed_field_dict = {
  author = "reviewed-author",
  genre = "reviewed-genre",
  title = "reviewed-title",
}


---@param csl_item_dict table<string, CslItem>
---@param bib_entry_dict table<string, BibtexEntry>
function bibtex2csl.resolve_related(csl_item_dict, bib_entry_dict)
  for key, entry in pairs(bib_entry_dict) do
    local related_key = entry.fields.related
    local related_type = entry.fields.relatedtype
    if related_key then
      local related_bib_entry = bib_entry_dict[unicode.casefold(related_key)]
      if related_bib_entry then
        local csl_item = csl_item_dict[entry.key]
        local related_csl_item = csl_item_dict[related_bib_entry.key]
        if related_type == "reprintof" or related_type == "reprintfrom" then
          for original_field, new_field in pairs(original_field_dict) do
            if not csl_item[new_field] and related_csl_item[original_field] then
              csl_item[new_field] = util.deep_copy(related_csl_item[original_field])
            end
          end

        elseif related_type == "translationof" or related_type == "translationfrom" then
          for original_field, new_field in pairs(original_field_dict) do
            if not csl_item[new_field] and related_csl_item[original_field] then
              csl_item[new_field] = util.deep_copy(related_csl_item[original_field])
            end
          end

        elseif related_type == "reviewof" then
          for reviewed_field, new_field in pairs(reviewed_field_dict) do
            if not csl_item[new_field] and related_csl_item[reviewed_field] then
              csl_item[new_field] = util.deep_copy(related_csl_item[reviewed_field])
            end
          end

        end
      else
        util.warning(string.format('Related entry "%s" of "%s" not found.', related_key, entry.key))
      end
    end
  end
end


return bibtex2csl
