--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

--[[
  A naive implementation of a Bib(La)TeX dateabase (.bib) parser
  References:
  - http://mirrors.ctan.org/biblio/bibtex/base/btxdoc.pdf
  - http://mirrors.ctan.org/info/bibtex/tamethebeast/ttb_en.pdf
  - https://github.com/brechtm/citeproc-py/blob/master/citeproc/source/bibtex/bibparse.py
  - http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html
  - https://github.com/pcooksey/bibtex-js/blob/master/src/bibtex_js.js
--]]

local bib = {}

local unicode = require("unicode")
bib.bib_data = require("citeproc-bib-data")

local util = require("citeproc-util")


function bib.parse(contents)
  local items = {}
  for item_contents in string.gmatch(contents, "(@%w+%b{})") do
    local item = bib.parse_item(item_contents)
    table.insert(items, item)
  end
  return items
end

function bib.parse_item(contents)
  contents = string.gsub(contents, "%s*\r?\n%s*", " ")
  local bib_type, id
  bib_type, id, contents = string.match(contents, "^@(%w+){([^%s,]+),%s*(.*)}$")
  if not id then
    return nil
  end

  local item = {id = id, ["citation-key"] = id}

  bib_type = string.lower(bib_type)
  local type_data = bib.bib_data.types[bib_type]
  if type_data and type_data.csl then
    item.type = type_data.csl
  else
    item.type = "document"
  end

  local bib_fields = bib.parse_fields(contents)
  -- util.debug(bib_fields)

  for bib_field, value in pairs(bib_fields) do
    local csl_field, csl_value = bib.convert_field(bib_field, value)

    if csl_field and not item[csl_field] then
      item[csl_field] = csl_value
    end
  end

  bib.process_special_fields(item, bib_fields)

  return item
end

function bib.parse_fields(contents)
  local fields = {}
  local field_patterns = {
    "^(%w+)%s*=%s*(%b{}),?%s*(.-)$",
    '^(%w+)%s*=%s*"([^"]*)",?%s*(.-)$',
    "^(%w+)%s*=%s*(%w+),?%s*(.-)$",
  }

  while #contents > 0 do
    local field, value, rest
    -- This pattern may fail in the case of `title = {foo\}bar}`.
    for pattern_index, pattern in ipairs(field_patterns) do
      field, value, rest = string.match(contents, pattern)
      if value then
        if pattern_index == 1 then
          -- Strip braces "{}"
          value = string.sub(value, 2, -2)
        elseif pattern_index == 3 then
          if not string.match(value, "^%d+$") then
            local string_name = value
            local macro = bib.bib_data.macros[string_name]
            if macro then
              value = macro.value
            else
              util.warning(string.format('String name "%s" is undefined', string_name))
            end
          end
        end
        fields[field] = value
        contents = rest
        break
      end
    end
  end
  return fields
end

function bib.convert_field(bib_field, value)
  local field_data = bib.bib_data.fields[bib_field]
  if not field_data then
    return nil, nil
  end
  local csl_field = field_data.csl
  if not csl_field then
    return nil, nil
  end

  value = bib.unescape(bib_field, value)

  local field_type = field_data.type
  if field_type == "name" then
    value = bib.parse_names(value)
  elseif field_type == "date" then
    value = bib.parse_date(value)
  end

  if bib_field == "title" or bib_field == "booktitle" then
    -- TODO: check if the original title is in sentence case
    value = bib.convert_sentence_case(value)
  end

  if bib_field == "volume" or bib_field == "pages" then
    value = string.gsub(value, util.unicode["en dash"], "-")
  end

  return csl_field, value
end

function bib.unescape(field, str)
  str = string.gsub(str, "%-%-%-", util.unicode["em dash"])
  str = string.gsub(str, "%-%-", util.unicode["en dash"])
  str = string.gsub(str, "``", util.unicode["left double quotation mark"])
  str = string.gsub(str, "''", util.unicode["right double quotation mark"])
  str = string.gsub(str, "`", util.unicode["left single quotation mark"])
  str = string.gsub(str, "'", util.unicode["right single quotation mark"])
  -- TODO: unicode chars like \"{o}
  str = string.gsub(str, "\\#", "#")
  str = string.gsub(str, "\\%$", "$")
  str = string.gsub(str, "\\%%", "%")
  str = string.gsub(str, "\\&", "&")
  str = string.gsub(str, "\\{", "{")
  str = string.gsub(str, "\\}", "}")
  str = string.gsub(str, "\\_", "_")
  if field ~= "url" then
    str = string.gsub(str, "~", util.unicode["no-break space"])
  end
  str = string.gsub(str, "\\quad%s+", util.unicode["em space"])
  return str
end

function bib.convert_sentence_case(str)
  local res = ""
  local to_lower = false
  local brace_level = 0
  for _, code_point in utf8.codes(str) do
    local char = utf8.char(code_point)
    if to_lower and brace_level == 0 then
      char = unicode.utf8.lower(char)
    end
    if string.match(char, "%S") then
      to_lower = true
    end
    if char == "{" then
      brace_level = brace_level + 1
      char = ""
    elseif char == "}" then
      brace_level = brace_level - 1
      char = ""
    elseif char == ":" then
      to_lower = false
    end
    res = res .. char
  end
  return res
end

function bib.parse_names(str)
   -- "{International Federation of Library Association and Institutions}"
  local names = {}
  local brace_level = 0
  local name = ""
  local last_word = ""
  for i = 1, #str do
    local char = string.sub(str, i, i)
    if char == " " then
      if brace_level == 0 and last_word == "and" then
        table.insert(names, name)
        name = ""
      else
        if name ~= "" then
          name = name .. " "
        end
        name = name .. last_word
      end
      last_word = ""
    else
      last_word = last_word .. char
      if char == "{" then
        brace_level = brace_level + 1
      elseif char == "}" then
        brace_level = brace_level - 1
      end
    end
  end

  if name ~= "" then
    name = name .. " "
  end
  name = name .. last_word
  table.insert(names, name)

  for i, name in ipairs(names) do
    names[i] = bib.parse_single_name(name)
  end
  return names
end

function bib.parse_single_name(str)
  local literal = string.match(str, "^{(.*)}$")
  if literal then
    return {
      literal = literal,
    }
  end

  local name_parts = util.split(str, ",%s*")
  if #name_parts > 1 then
    return bib.parse_revesed_name(name_parts)
  else
    return bib.parse_non_revesed_name(str)
  end
end

function bib.parse_revesed_name(name_parts)
  local name = {}
  local von, last, jr, first
  if #name_parts == 2 then
    first = name_parts[2]
  elseif #name_parts >= 3 then
    jr = name_parts[2]
    first = name_parts[3]
  end
  if first and first ~= "" then
    name.given = first
  end
  if jr and jr ~= "" then
    name.suffix = jr
  end

  last = name_parts[1]
  local words = util.split(last)
  local index = #words - 1
  while index > 0 and string.match(words[index], "^%L") do
    index = index - 1
  end
  name.family = util.concat(util.slice(words, index + 1), " ")
  if index >= 1 then
    von = util.concat(util.slice(words, 1, index), " ")
    name["non-dropping-particle"] = von
  end
  return name
end

function bib.parse_non_revesed_name(str)
  local name = {}
  local words = util.split(str)

  local index = 1
  -- TODO: case determination for pseudo-characters (e.g., "\bb{BB}")
  while index < #words and string.match(words[index], "^%L") do
    index = index + 1
  end
  if index > 1 then
    name.given = util.concat(util.slice(words, 1, index - 1), " ")
  end

  local particle_start_index = index
  index = #words - 1
  while index >= particle_start_index and string.match(words[index], "^%L") do
    index = index - 1
  end
  if index >= particle_start_index then
    local particles = util.slice(words, particle_start_index, index)
    -- TODO: distiguish dropping and non-dropping particles
    name["non-dropping-particle"] = util.concat(particles, " ")
  end
  name.family = util.concat(util.slice(words, index + 1), " ")

  return name
end

function bib.parse_date(str)
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
    local date_ = bib.parse_single_date(date_part)
    if not date_ then
      return literal
    end
    table.insert(date["date-parts"], date_)
  end
  return date
end

function bib.parse_single_date(str)
  local date = {}
  for _, date_part in ipairs(util.split(str, "%-")) do
    if not string.match(date_part, "^%d+$") then
      return nil
    end
    table.insert(date, tonumber(date_part))
  end
  return date
end


function bib.process_special_fields(item, bib_fields)
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
    item.issued = bib.parse_date(bib_fields.year)
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
    local language_code = bib.babel_locale_mapping[item.language]
    if language_code then
      item.language = language_code
    end
  end
  -- if not item.language then
  --   if util.has_cjk_char(item.title) then
  --     item.language = "zh"
  --   end
  -- end

  -- number
  if item.number then
    if item.type == "article-journal" or item.type == "article-magazine" or item.type == "article-newspaper" or item.type == "periodical" then
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


bib.babel_locale_mapping = {
  acadian         = "fr-CA",
  american        = "en-US",
  australian      = "en-AU",
  afrikaans       = "af-ZA",
  albanian        = "sq-AL",
  amharic         = "am-ET",
  arabic          = "ar",
  armenian        = "hy-AM",
  asturian        = "ast-ES",
  austrian        = "de-AT",
  bahasa          = "id-ID",
  bahasai         = "id-ID",
  bahasam         = "id-ID",
  basque          = "eu-ES",
  bengali         = "bn-BD",
  bgreek          = "el-GR",
  brazil          = "pt-BR",
  brazilian       = "pt-BR",
  breton          = "br-FR",
  british         = "en-GB",
  bulgarian       = "bg-BG",
  canadian        = "en-CA",
  canadien        = "fr-CA",
  catalan         = "ca-AD",
  coptic          = "cop",
  croatian        = "hr-HR",
  czech           = "cs-CZ",
  danish          = "da-DK",
  divehi          = "dv-MV",
  dutch           = "nl-NL",
  english         = "en-US",
  esperanto       = "eo-001",
  estonian        = "et-EE",
  ethiopia        = "am-ET",
  farsi           = "fa-IR",
  finnish         = "fi-FI",
  francais        = "fr-FR",
  french          = "fr-FR",
  frenchle        = "fr-FR",
  friulan         = "fur-IT",
  galician        = "gl-ES",
  german          = "de-DE",
  germanb         = "de-DE",
  greek           = "el-GR",
  hebrew          = "he-IL",
  hindi           = "hi-IN",
  ibygreek        = "el-CY",
  icelandic       = "is-IS",
  indon           = "id-ID",
  indonesia       = "id-ID",
  interlingua     = "ia-FR",
  irish           = "ga-IE",
  italian         = "it-IT",
  japanese        = "ja-JP",
  kannada         = "kn-IN",
  lao             = "lo-LA",
  latin           = "la-Latn",
  latvian         = "lv-LV",
  lithuanian      = "lt-LT",
  lowersorbian    = "dsb-DE",
  lsorbian        = "dsb-DE",
  magyar          = "hu-HU",
  malay           = "id-ID",
  malayalam       = "ml-IN",
  marathi         = "mr-IN",
  meyalu          = "id-ID",
  mongolian       = "mn-Cyrl",
  naustrian       = "de-AT",
  newzealand      = "en-NZ",
  ngerman         = "de-DE",
  nko             = "ha-NG",
  norsk           = "nb-NO",
  norwegian       = "nn-NO",
  nynorsk         = "nn-NO",
  occitan         = "oc-FR",
  piedmontese     = "pms-IT",
  pinyin          = "pny",
  polish          = "pl-PL",
  polutonikogreek = "el-GR",
  portuges        = "pt-PT",
  portuguese      = "pt-PT",
  romanian        = "ro-RO",
  romansh         = "rm-CH",
  russian         = "ru-RU",
  samin           = "se-NO",
  sanskrit        = "sa-IN",
  scottish        = "gd-GB",
  serbian         = "sr-Latn",
  serbianc        = "sr-Cyrl",
  slovak          = "sk-SK",
  slovene         = "sl-SI",
  slovenian       = "sl-SI",
  spanish         = "es-ES",
  swedish         = "sv-SE",
  swiss           = "de-CH",
  swissgerman     = "de-CH",
  nswissgerman    = "de-CH",
  syriac          = "syc",
  tamil           = "ta-IN",
  telugu          = "te-IN",
  thai            = "th-TH",
  thaicjk         = "th-TH",
  tibetan         = "bo-CN",
  turkish         = "tr-TR",
  turkmen         = "tk-TM",
  ukrainian       = "uk-UA",
  urdu            = "ur-IN",
  UKenglish       = "en-UK",
  uppersorbian    = "hsb-DE",
  USenglish       = "en-US",
  usorbian        = "hsb-DE",
  vietnamese      = "vi-VN",
  welsh           = "cy-GB",
}


return bib
