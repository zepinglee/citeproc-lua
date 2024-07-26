--
-- Copyright (c) 2021-2024 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local util = {}

local uni_utf8
if kpse then
  uni_utf8 = require("unicode").grapheme
else
  uni_utf8 = require("lua-utf8")
end


local inspect  -- only load it when debugging
local journal_data = nil  -- load as needed


-- Deep copy
function util.deep_copy(obj)
  local res
  if type(obj) == "table" then
    res = {}
    local meta_table = getmetatable(obj)
    if meta_table then
      setmetatable(res, meta_table)
    end
    for key, value in pairs(obj) do
      res[key] = util.deep_copy(value)
    end
  else
    res = obj
  end
  return res
end

-- Shallow copy
function util.clone(obj)
  if type(obj) == "table" then
    local res = {}
    for key, value in pairs(obj) do
      res[key] = value
    end
    return setmetatable(res, getmetatable(obj))
  else
    return obj
  end
end

---Limitation: Hierarchical or multiple inheritance is not supported.
---@param obj table
---@param class table
---@return boolean
function util.is_instance(obj, class)
  return (type(obj) == "table" and obj._type == class._type)
end

function util.join(list, delimiter)
  -- Why not return table.concat(list, delimiter)?
  local res = {}
  for i, item in ipairs(list) do
    if i > 1 then
      table.insert(res, delimiter)
    end
    table.insert(res, item)
  end
  return res
end

function util.to_boolean(str)
  if not str then
    return false
  end
  if str == "true" then
    return true
  elseif str == "false" then
    return false
  else
    util.warning(string.format('Invalid boolean string "%s"', str))
    return false
  end
end

function util.to_list(str)
  if not str then
    return nil
  end
  return util.split(str)
end


--- Concat with CJK or western colon
---@param main_title string
---@param substitle string
function util.join_title(main_title, substitle)
  local code_point = utf8.codepoint(main_title, utf8.len(main_title))
  if util.is_cjk_char(code_point) then
    return main_title .. "：" .. substitle
  else
    code_point = utf8.codepoint(substitle, 1)
    if util.is_cjk_char(code_point) then
      return main_title .. "：" .. substitle
    else
      return main_title .. ": " .. substitle
    end
  end
end


function util.to_ordinal (n)
  -- assert(type(n) == "number")
  local last_digit = n % 10
  if last_digit == 1 and n ~= 11
    then return tostring(n) .. "st"
  elseif last_digit == 2 and n ~= 12
    then return tostring(n) .. "nd"
  elseif last_digit == 3 and n ~= 13
    then return tostring(n) .. "rd"
  else
    return tostring(n) .. "th"
  end
end


util.quiet_mode = false

-- A file handle to usually a `.blg` file.
util.logging_file = nil


function util.set_logging_file(path)
  util.logging_file = io.open(path, "w")
  if not util.logging_file then
    util.error(string.format('Cannot write to "%s".', path))
  end
  util.logging_file = io.open(path, 'a')
end


function util.close_logging_file()
  if util.logging_file then
    util.logging_file:close()
  end
end


util.num_errors = 0
util.num_warnings = 0


function util.error(message)
  util.num_errors = util.num_errors + 1
  if luatexbase then
    -- The luatexbase.module_error() prints the traceback, which causes panic
    -- luatexbase.module_error("citeproc", message)

    -- TODO: Enhance the error output. Make it like `\msg_error`.
    texio.write_nl("term", "\n")
    tex.error("Module citeproc Error: " .. message)

    -- tex.print(string.format("\\PackageError{citation-style-language}{%s}{}", message))

  else
    message  = "Error: " .. message
    print(message)
    if util.logging_file then
      util.logging_file:write(message .. "\n")
    end
  end
end

util.warning_enabled = true

function util.warning(message)
  util.num_warnings = util.num_warnings + 1
  if luatexbase then
    texio.write_nl("term", "\n")
    luatexbase.module_warning("citeproc", message)

    -- tex.print(string.format("\\PackageWarning{citation-style-language}{%s}{}", message))

  else
    message = "Warning: " .. message
    if util.logging_file then
      util.logging_file:write(message .. "\n")
    end
    if util.warning_enabled then
      io.stderr:write(message, "\n")
    end
  end
end

---@param message string
function util.info(message)
  if not luatexbase and not util.quiet_mode then
    print(message)
  end
  if util.logging_file then
    util.logging_file:write(message .. "\n")
  end
end


local remove_all_metatables = nil

function util.debug(obj)
  local text
  if type(obj) == "table" and (obj._debug or (obj[1] and obj[1]._debug)) then
    if obj._debug then
      text = obj:_debug()
    else
      text = ""
      for _, child in ipairs(obj) do
        text = text .. child:_debug()
      end
    end
  else
    if not inspect then
      inspect = require("inspect")
      remove_all_metatables = function (item, path)
        if path[#path] ~= inspect.METATABLE then
          return item
        end
      end
    end
    text = inspect(obj, {process = remove_all_metatables})
  end
  io.stderr:write("[")
  io.stderr:write(debug.getinfo(2, "S").source:sub(2))
  io.stderr:write(":")
  io.stderr:write(debug.getinfo(2, "l").currentline)
  io.stderr:write("] ")
  io.stderr:write(text)
  io.stderr:write("\n")
end

-- Similar to re.split() in Python
---comment
---@param str string
---@param sep string?
---@param maxsplit integer?
---@return string[]
function util.split(str, sep, maxsplit)
  if type(str) ~= "string" then
    util.error("Invalid string")
  end
  sep = sep or "%s+"
  if sep == "" then
    util.error("Empty separator")
  end
  if string.find(str, sep) == nil then
    return { str }
  end

  if maxsplit == nil or maxsplit < 0 then
    maxsplit = -1    -- No limit
  end
  local result = {}
  local pattern = "(.-)" .. sep .. "()"
  local num_splits = 0
  local lastPos = 1
  for part, pos in string.gmatch(str, pattern) do
    if num_splits == maxsplit then
      break
    end
    num_splits = num_splits + 1
    result[num_splits] = part
    lastPos = pos
  end
  -- Handle the last field
  result[num_splits + 1] = string.sub(str, lastPos)
  return result
end

function util.split_multiple(str, seps, include_sep)
  seps = seps or "%s+"
  if seps == "" then
    error("Empty separator")
  end
  if type(seps) == "string" then
    seps = {seps}
  end

  local splits = {}
  for _, sep_pattern in ipairs(seps) do
    for start, sep, stop in string.gmatch(str, "()(" .. sep_pattern .. ")()") do
      table.insert(splits, {start, sep, stop})
    end
  end

  if #seps > 1 then
    table.sort(splits, function (a, b) return a[1] < b[1] end)
  end

  local res = {}
  local previous = 1
  for _, sep_tuple in ipairs(splits) do
    local start, sep, stop = table.unpack(sep_tuple)
    local item = string.sub(str, previous, start - 1)
    if include_sep then
      table.insert(res, {item, sep})
    else
      table.insert(res, item)
    end
    previous = stop
  end
  local item = string.sub(str, previous, #str)
  if include_sep then
    table.insert(res, {item, ""})
  else
    table.insert(res, item)
  end
  return res
end

function util.slice (t, start, stop)
  start = start or 1
  stop = stop or #t
  if start < 0 then
    start = start + #t + 1
  end
  if stop < 0 then
    stop = stop + #t + 1
  end
  local new = {}
  for i, item in ipairs(t) do
    if i >= start and i <= stop then
      table.insert(new, item)
    end
  end
  return new
end

function util.concat (list, sep)
  -- This helper function omits empty strings in list, which is different from table.concat
  -- This function always returns a string, even empty.
  local res = ""
  for i = 1, #list do
    local s = list[i]
    if s and s~= "" then
      if res == "" then
        res = s
      else
        res = res .. sep .. s
      end
    end
  end
  return res
end

-- Python list.extend()
function util.extend(first, second)
  -- if not second then
  --   print(debug.traceback())
  -- end
  local l = #first
  for i, element in ipairs(second) do
    first[l + i] = element
  end
  return first
end

-- Concat two lists in place
function util.concat_list(first, second)
  local res
  for i, element in ipairs(first) do
    res[i] = element
  end
  local i = #res
  for j, element in ipairs(second) do
    res[i + j] = element
  end
  return res
end

---@param str string
---@return string
function util.lstrip (str)
  if not str then
    error("Invalid input")
  end
  local res = string.gsub(str, "^%s*", "")
  return res
end

---@param str string
---@return string
function util.rstrip (str)
  if not str then
    error("Invalid input")
  end
  local res = string.gsub(str, "%s*$", "")
  return res
end

---@param str string
---@return string
function util.strip (str)
  return util.lstrip(util.rstrip(str))
end

function util.startswith(str, prefix)
  if type(str) ~= "string" then
    util.error(string.format('\n%s\n"%s" is not a string.', debug.traceback(), str))
  end
  return string.sub(str, 1, #prefix) == prefix
end

function util.endswith(str, suffix)
  -- if not str or type(str) ~= "string" then
  --   print(debug.traceback())
  -- end
  return string.sub(str, -#suffix) == suffix
end

---@param str string | number
---@return boolean
function util.is_numeric(str)
  if str == nil or str == "" then
    return false
  end
  str = string.gsub(str, util.unicode["en dash"], "-")
  local res = true
  for w in string.gmatch(str, "%w+") do
    if not string.match(w, "^%w*%d+%a*$") and
        not string.match(w, "^and$") and
        not string.match(w, "^et$") and
        not string.match(w, "^[MDCLXVI]+$") and
        not string.match(w, "^[mdclxvi]+$") then
      -- Roman number without validation
      return false
    end
  end
  for w in string.gmatch(str, "%W+") do
    if not string.match(w, "^%s*[,&-]+%s*$")
        and not string.match(str, "%s+") then
      res = false
      break
    end
  end
  return res
end

util.variable_types = {}

-- schema/schemas/styles/csl-variables.rnc
util.variables = {}

-- -- Standard variables
-- util.variables.standard = {
--   "abstract",
--   "annote",
--   "archive",
--   "archive_collection",
--   "archive_location",
--   "archive-place",
--   "authority",
--   "call-number",
--   "citation-key",
--   "citation-label",
--   "collection-title",
--   "container-title",
--   "container-title-short",
--   "dimensions",
--   "division",
--   "DOI",
--   "event",
--   "event-title",
--   "event-place",
--   "genre",
--   "ISBN",
--   "ISSN",
--   "jurisdiction",
--   "keyword",
--   "language",
--   "license",
--   "medium",
--   "note",
--   "original-publisher",
--   "original-publisher-place",
--   "original-title",
--   "part-title",
--   "PMCID",
--   "PMID",
--   "publisher",
--   "publisher-place",
--   "references",
--   "reviewed-genre",
--   "reviewed-title",
--   "scale",
--   "source",
--   "status",
--   "title",
--   "title-short",
--   "URL",
--   "volume-title",
--   "year-suffix",
-- }

-- Number variables
util.variables.number = {
  "chapter-number",
  "citation-number",
  "collection-number",
  "edition",
  "first-reference-note-number",
  "issue",
  "locator",
  "number",
  "number-of-pages",
  "number-of-volumes",
  "page",
  "page-first",
  "part-number",
  "printing-number",
  "section",
  "supplement-number",
  "version",
  "volume",
}

-- Date variables
util.variables.date = {
  "accessed",
  "available-date",
  "event-date",
  "issued",
  "original-date",
  "submitted",
}

-- Name variables
util.variables.name = {
  "author",
  "chair",
  "collection-editor",
  "compiler",
  "composer",
  "container-author",
  "contributor",
  "curator",
  "director",
  "editor",
  "editor-translator",
  "editorial-director",
  "executive-producer",
  "guest",
  "host",
  "illustrator",
  "interviewer",
  "narrator",
  "organizer",
  "original-author",
  "performer",
  "producer",
  "recipient",
  "reviewed-author",
  "script-writer",
  "series-creator",
  "translator",
}

util.variable_types = {}

for type, variables in pairs(util.variables) do
  for _, variable in ipairs(variables) do
    util.variable_types[variable] = type
  end
end

util.primary_dialects = {
  af= "af-ZA",
  ar= "ar",
  bg= "bg-BG",
  ca= "ca-AD",
  cs= "cs-CZ",
  cy= "cy-GB",
  da= "da-DK",
  de= "de-DE",
  el= "el-GR",
  en= "en-US",
  es= "es-ES",
  et= "et-EE",
  eu= "eu",
  fa= "fa-IR",
  fi= "fi-FI",
  fr= "fr-FR",
  he= "he-IL",
  hi= "hi-IN",
  hr= "hr-HR",
  hu= "hu-HU",
  id= "id-ID",
  is= "is-IS",
  it= "it-IT",
  ja= "ja-JP",
  km= "km-KH",
  ko= "ko-KR",
  la= "la",
  lt= "lt-LT",
  lv= "lv-LV",
  mn= "mn-MN",
  nb= "nb-NO",
  nl= "nl-NL",
  nn= "nn-NO",
  pl= "pl-PL",
  pt= "pt-PT",
  ro= "ro-RO",
  ru= "ru-RU",
  sk= "sk-SK",
  sl= "sl-SI",
  sr= "sr-RS",
  sv= "sv-SE",
  th= "th-TH",
  tr= "tr-TR",
  uk= "uk-UA",
  vi= "vi-VN",
  zh= "zh-CN"
}



-- Range delimiter

util.unicode = {
  ["no-break space"] = "\u{00A0}",
  ["em space"] = "\u{2003}",
  ["en dash"] = "\u{2013}",
  ["em dash"] = "\u{2014}",
  ["left single quotation mark"] = "\u{2018}",
  ["right single quotation mark"] = "\u{2019}",
  ["apostrophe"] = "\u{2019}",
  ["left double quotation mark"] = "\u{201C}",
  ["right double quotation mark"] = "\u{201D}",
  ["left-pointing double angle quotation mark"] = "\u{00AB}",
  ["right-pointing double angle quotation mark"] = "\u{00BB}",
  ["horizontal ellipsis"] = "\u{2026}",
  ["narrow no-break space"] = "\u{202F}",
}

util.word_boundaries = {
  ":",
  " ",
  "%-",
  "/",
  util.unicode["no-break space"],
  util.unicode["en dash"],
  util.unicode["em dash"],
}


-- TODO: process multiple words
util.stop_words = {
  ["a"] = true,
  ["according to"] = true,
  ["across"] = true,
  ["afore"] = true,
  ["after"] = true,
  ["against"] = true,
  ["ahead of"] = true,
  ["along"] = true,
  ["alongside"] = true,
  ["amid"] = true,
  ["amidst"] = true,
  ["among"] = true,
  ["amongst"] = true,
  ["an"] = true,
  ["and"] = true,
  ["anenst"] = true,
  ["apart from"] = true,
  ["apropos"] = true,
  ["apud"] = true,
  ["around"] = true,
  ["as"] = true,
  ["as regards"] = true,
  ["aside"] = true,
  ["astride"] = true,
  ["at"] = true,
  ["athwart"] = true,
  ["atop"] = true,
  ["back to"] = true,
  ["barring"] = true,
  ["because of"] = true,
  ["before"] = true,
  ["behind"] = true,
  ["below"] = true,
  ["beneath"] = true,
  ["beside"] = true,
  ["besides"] = true,
  ["between"] = true,
  ["beyond"] = true,
  ["but"] = true,
  ["by"] = true,
  ["c"] = true,
  ["ca"] = true,
  ["circa"] = true,
  ["close to"] = true,
  ["d'"] = true,
  ["de"] = true,
  ["despite"] = true,
  ["down"] = true,
  ["due to"] = true,
  ["during"] = true,
  ["et"] = true,
  ["except"] = true,
  ["far from"] = true,
  ["for"] = true,
  ["forenenst"] = true,
  ["from"] = true,
  ["given"] = true,
  ["in"] = true,
  ["inside"] = true,
  ["instead of"] = true,
  ["into"] = true,
  ["lest"] = true,
  ["like"] = true,
  ["modulo"] = true,
  ["near"] = true,
  ["next"] = true,
  ["nor"] = true,
  ["notwithstanding"] = true,
  ["of"] = true,
  ["off"] = true,
  ["on"] = true,
  ["onto"] = true,
  ["or"] = true,
  ["out"] = true,
  ["outside of"] = true,
  ["over"] = true,
  ["per"] = true,
  ["plus"] = true,
  ["prior to"] = true,
  ["pro"] = true,
  ["pursuant to"] = true,
  ["qua"] = true,
  ["rather than"] = true,
  ["regardless of"] = true,
  ["sans"] = true,
  ["since"] = true,
  ["so"] = true,
  ["such as"] = true,
  ["than"] = true,
  ["that of"] = true,
  ["the"] = true,
  ["through"] = true,
  ["throughout"] = true,
  ["thru"] = true,
  ["thruout"] = true,
  ["till"] = true,
  ["to"] = true,
  ["toward"] = true,
  ["towards"] = true,
  ["under"] = true,
  ["underneath"] = true,
  ["until"] = true,
  ["unto"] = true,
  ["up"] = true,
  ["upon"] = true,
  ["v."] = true,
  ["van"] = true,
  ["versus"] = true,
  ["via"] = true,
  ["vis-à-vis"] = true,
  ["von"] = true,
  ["vs."] = true,
  ["where as"] = true,
  ["with"] = true,
  ["within"] = true,
  ["without"] = true,
  ["yet"] = true,
}

-- <https://github.com/Juris-M/citeproc-js/blob/73bc1b44bc7d54d0bfec4e070fd27f5efe024ff9/src/load.js#L1052C2-L1052C2>
local citeproc_js_addition_stop_words = {
  ["about"] = true,
  ["above"] = true,
  ["al"] = true,
  ["as for"] = true,
  ["as of"] = true,
  ["as per"] = true,
  ["aside from"] = true,
  ["except for"] = true,
  ["inside of"] = true,
  ["near to"] = true,
  ["next to"] = true,
  ["on to"] = true,
  ["out from"] = true,
  ["out of"] = true,
  ["up to"] = true,
  ["v"] = true,
  ["vs"] = true,
}

for word, _ in pairs(citeproc_js_addition_stop_words) do
  util.stop_words[word] = true
end

function util.all (t)
  for _, item in ipairs(t) do
    if not item then
      return false
    end
  end
  return true
end

function util.any (t)
  for _, item in ipairs(t) do
    if item then
      return true
    end
  end
  return false
end

-- ROMANESQUE_REGEXP = "-0-9a-zA-Z\u0e01-\u0e5b\u00c0-\u017f\u0370-\u03ff\u0400-\u052f\u0590-\u05d4\u05d6-\u05ff\u1f00-\u1fff\u0600-\u06ff\u200c\u200d\u200e\u0218\u0219\u021a\u021b\u202a-\u202e"

util.romanesque_ranges = {
  {0x0030, 0x0039},  -- 0-9
  {0x0041, 0x005A},  -- A-Z
  {0x0061, 0x007A},  -- a-z
  {0x0E01, 0x0E5B},  -- Thai
  {0x0E01, 0x0E5B},  -- Thai
  {0x00C0, 0x017F},  -- Latin-1 Supplement
  {0x0370, 0x03FF},  -- Greek and Coptic
  {0x0400, 0x052F},  -- Cyrillic
  {0x0590, 0x05D4},  -- Hebrew
  {0x05D6, 0x05FF},  -- Hebrew
  {0x1F00, 0x1FFF},  -- Greek Extended
  {0x0600, 0x06FF},  -- Arabic
  {0x202A, 0x202E},  -- Writing directions in General Punctuation
}

util.romanesque_chars = {
  0x200c,
  0x200d,
  0x200e,
  0x0218,
  0x0219,
  0x021a,
  0x021b,
}

util.CJK_ranges = {
  {0x4E00, 0x9FFF},  -- CJK Unified Ideographs
  {0x3400, 0x4DBF},  -- CJK Unified Ideographs Extension A
  {0x3040, 0x309F},  -- Hiragana
  {0x30A0, 0x30FF},  -- Katakana
  {0xF900, 0xFAFF},  -- CJK Compatibility Ideographs
  {0x20000, 0x2A6DF},  -- CJK Unified Ideographs Extension B
  {0x2A700, 0x2B73F},  -- CJK Unified Ideographs Extension C
  {0x2B740, 0x2B81F},  -- CJK Unified Ideographs Extension D
  {0x2B820, 0x2CEAF},  -- CJK Unified Ideographs Extension E
  {0x2CEB0, 0x2EBEF},  -- CJK Unified Ideographs Extension F
  {0x30000, 0x3134F},  -- CJK Unified Ideographs Extension G
  {0x2F800, 0x2FA1F},  -- CJK Compatibility Ideographs Supplement
}

function util.in_list (value, list)
  for _, v in ipairs(list) do
    if value == v then
      return true
    end
  end
  return false
end

function util.in_ranges (value, ranges)
  for _, range in ipairs(ranges) do
    if value >= range[1] and value <= range[2] then
      return true
    end
  end
  return false
end

function util.is_romanesque(code_point)
  if not code_point then
    return false
  end
  if util.in_ranges(code_point, util.romanesque_ranges) then
    return true
  end
  if util.in_list(code_point, util.romanesque_chars) then
    return true
  end
  return false
end

function util.has_romanesque_char(s)
  -- has romanesque char but not necessarily pure romanesque
  if not s then
    return false
  end
  for _, code_point in utf8.codes(s) do
    if util.is_romanesque(code_point) then
      return true
    end
  end
  return false
end

function util.is_cjk_char(code_point)
  if not code_point then
    return false
  end
  if util.in_ranges(code_point, util.CJK_ranges) then
    return true
  end
  return false
end

function util.has_cjk_char(s)
  -- has romanesque char but not necessarily pure romanesque
  if not s then
    return false
  end
  for _, code_point in utf8.codes(s) do
    if util.is_cjk_char(code_point) then
      return true
    end
  end
  return false
end


---@param ordinal string
---@return string
function util.convert_ordinal_to_arabic(ordinal)
  -- "1st", "2nd"
  local numeral, suffix = string.match(ordinal, "^(%d+)(%a+)$")
  if numeral then
    return numeral
  end
  local arabic = util.ordinal_to_arabic_map[string.lower(ordinal)]
  if arabic then
    return arabic
  else
    return ordinal
  end
end

util.ordinal_to_arabic_map = {
  first              = "1",
  second             = "2",
  third              = "3",
  fourth             = "4",
  fifth              = "5",
  sixth              = "6",
  seventh            = "7",
  eighth             = "8",
  ninth              = "9",
  tenth              = "10",
  eleventh           = "11",
  twelfth            = "12",
  thirteenth         = "13",
  fourteenth         = "14",
  fifteenth          = "15",
  sixteenth          = "16",
  seventeenth        = "17",
  eighteenth         = "18",
  nineteenth         = "19",
  twentieth          = "20",
  ["twenty-first"]   = "21",
  ["twenty-second"]  = "22",
  ["twenty-third"]   = "23",
  ["twenty-fourth"]  = "24",
  ["twenty-fifth"]   = "25",
  ["twenty-sixth"]   = "26",
  ["twenty-seventh"] = "27",
  ["twenty-eighth"]  = "28",
  ["twenty-ninth"]   = "29",
  thirtieth          = "30",
}


function util.convert_roman (number)
  -- assert(type(number) == "number")
  local output = {}
  for _, tuple in ipairs(util.roman_numerals) do
    local letter, value = table.unpack(tuple)
    table.insert(output, string.rep(letter, math.floor(number / value)))
    number = number % value
  end
  return table.concat(output, "")
end

util.roman_numerals = {
  {"m",  1000},
  {"cm", 900},
  {"d",  500},
  {"cd", 400},
  {"c",  100},
  {"xc", 90},
  {"l",  50},
  {"xl", 40},
  {"x",  10},
  {"ix", 9},
  {"v",  5},
  {"iv", 4},
  {"i",  1},
};


-- Choose

---@enum Postion
local Position = {
  First = 0,
  Subsequent = 1,
  Ibid = 2,
  IbidWithLocator = 3,
}
util.Position = Position

util.position_map = {
  ["first"] = Position.First,
  ["subsequent"] = Position.Subsequent,
  ["ibid"] = Position.Ibid,
  ["ibid-with-locator"] = Position.IbidWithLocator,
  ["container-subsequent"] = 4,
}


-- Output

util.superscripts = {
  ["\u{00AA}"] = "\u{0061}",
  ["\u{00B2}"] = "\u{0032}",
  ["\u{00B3}"] = "\u{0033}",
  ["\u{00B9}"] = "\u{0031}",
  ["\u{00BA}"] = "\u{006F}",
  ["\u{02B0}"] = "\u{0068}",
  ["\u{02B1}"] = "\u{0266}",
  ["\u{02B2}"] = "\u{006A}",
  ["\u{02B3}"] = "\u{0072}",
  ["\u{02B4}"] = "\u{0279}",
  ["\u{02B5}"] = "\u{027B}",
  ["\u{02B6}"] = "\u{0281}",
  ["\u{02B7}"] = "\u{0077}",
  ["\u{02B8}"] = "\u{0079}",
  ["\u{02E0}"] = "\u{0263}",
  ["\u{02E1}"] = "\u{006C}",
  ["\u{02E2}"] = "\u{0073}",
  ["\u{02E3}"] = "\u{0078}",
  ["\u{02E4}"] = "\u{0295}",
  ["\u{1D2C}"] = "\u{0041}",
  ["\u{1D2D}"] = "\u{00C6}",
  ["\u{1D2E}"] = "\u{0042}",
  ["\u{1D30}"] = "\u{0044}",
  ["\u{1D31}"] = "\u{0045}",
  ["\u{1D32}"] = "\u{018E}",
  ["\u{1D33}"] = "\u{0047}",
  ["\u{1D34}"] = "\u{0048}",
  ["\u{1D35}"] = "\u{0049}",
  ["\u{1D36}"] = "\u{004A}",
  ["\u{1D37}"] = "\u{004B}",
  ["\u{1D38}"] = "\u{004C}",
  ["\u{1D39}"] = "\u{004D}",
  ["\u{1D3A}"] = "\u{004E}",
  ["\u{1D3C}"] = "\u{004F}",
  ["\u{1D3D}"] = "\u{0222}",
  ["\u{1D3E}"] = "\u{0050}",
  ["\u{1D3F}"] = "\u{0052}",
  ["\u{1D40}"] = "\u{0054}",
  ["\u{1D41}"] = "\u{0055}",
  ["\u{1D42}"] = "\u{0057}",
  ["\u{1D43}"] = "\u{0061}",
  ["\u{1D44}"] = "\u{0250}",
  ["\u{1D45}"] = "\u{0251}",
  ["\u{1D46}"] = "\u{1D02}",
  ["\u{1D47}"] = "\u{0062}",
  ["\u{1D48}"] = "\u{0064}",
  ["\u{1D49}"] = "\u{0065}",
  ["\u{1D4A}"] = "\u{0259}",
  ["\u{1D4B}"] = "\u{025B}",
  ["\u{1D4C}"] = "\u{025C}",
  ["\u{1D4D}"] = "\u{0067}",
  ["\u{1D4F}"] = "\u{006B}",
  ["\u{1D50}"] = "\u{006D}",
  ["\u{1D51}"] = "\u{014B}",
  ["\u{1D52}"] = "\u{006F}",
  ["\u{1D53}"] = "\u{0254}",
  ["\u{1D54}"] = "\u{1D16}",
  ["\u{1D55}"] = "\u{1D17}",
  ["\u{1D56}"] = "\u{0070}",
  ["\u{1D57}"] = "\u{0074}",
  ["\u{1D58}"] = "\u{0075}",
  ["\u{1D59}"] = "\u{1D1D}",
  ["\u{1D5A}"] = "\u{026F}",
  ["\u{1D5B}"] = "\u{0076}",
  ["\u{1D5C}"] = "\u{1D25}",
  ["\u{1D5D}"] = "\u{03B2}",
  ["\u{1D5E}"] = "\u{03B3}",
  ["\u{1D5F}"] = "\u{03B4}",
  ["\u{1D60}"] = "\u{03C6}",
  ["\u{1D61}"] = "\u{03C7}",
  ["\u{2070}"] = "\u{0030}",
  ["\u{2071}"] = "\u{0069}",
  ["\u{2074}"] = "\u{0034}",
  ["\u{2075}"] = "\u{0035}",
  ["\u{2076}"] = "\u{0036}",
  ["\u{2077}"] = "\u{0037}",
  ["\u{2078}"] = "\u{0038}",
  ["\u{2079}"] = "\u{0039}",
  ["\u{207A}"] = "\u{002B}",
  ["\u{207B}"] = "\u{2212}",
  ["\u{207C}"] = "\u{003D}",
  ["\u{207D}"] = "\u{0028}",
  ["\u{207E}"] = "\u{0029}",
  ["\u{207F}"] = "\u{006E}",
  ["\u{2120}"] = "\u{0053}\u{004D}",
  ["\u{2122}"] = "\u{0054}\u{004D}",
  ["\u{3192}"] = "\u{4E00}",
  ["\u{3193}"] = "\u{4E8C}",
  ["\u{3194}"] = "\u{4E09}",
  ["\u{3195}"] = "\u{56DB}",
  ["\u{3196}"] = "\u{4E0A}",
  ["\u{3197}"] = "\u{4E2D}",
  ["\u{3198}"] = "\u{4E0B}",
  ["\u{3199}"] = "\u{7532}",
  ["\u{319A}"] = "\u{4E59}",
  ["\u{319B}"] = "\u{4E19}",
  ["\u{319C}"] = "\u{4E01}",
  ["\u{319D}"] = "\u{5929}",
  ["\u{319E}"] = "\u{5730}",
  ["\u{319F}"] = "\u{4EBA}",
  ["\u{02C0}"] = "\u{0294}",
  ["\u{02C1}"] = "\u{0295}",
  ["\u{06E5}"] = "\u{0648}",
  ["\u{06E6}"] = "\u{064A}",
}


-- File IO

function util.remove_bom(text)
  if type(text) == "string" then
    return string.gsub(text, "^\xEF\xBB\xBF", "")
  else
    return text
  end
end


---@param path string
---@return string?
function util.read_file(path, allowe_missing)
  if type(path) ~= "string" then
    error("Invalid path.")
  end
  local file = io.open(path, "r")
  if not file then
    if not allowe_missing then
      util.error(string.format('Cannot open file "%s".', path))
    end
    return nil
  end
  local content = file:read("*a")
  content = util.remove_bom(content)
  file:close()
  return content
end


---@param text string
---@param path string
function util.write_file(text, path)
  local file = io.open(path, "w")
  if not file then
    util.error(string.format('Cannot write to file "%s".', path))
    return
  end
  file:write(text)
  file:close()
end


function util.parse_edtf(str)
  local date = {["date-parts"] = {}}
  local range_parts = util.split(str, "/")
  for i, range_part in ipairs(range_parts) do
    if i > 2 then
      break
    end
    date["date-parts"][i] = {}
    local negative_year = false
    if string.match(range_part, "^Y%-") then
      negative_year = true
    end
    range_part = string.gsub(range_part, "^Y[+-]?", "")
    if string.match(range_part, "[?~%%]$") then
      date.circa = true
      range_part = string.gsub(range_part, "[?~%%]$", "")
    end
    range_part = string.gsub(range_part, "T.*$", "")
    for j, date_part in ipairs(util.split(range_part, "%-")) do
      if j > 3 then
        break
      end
      if string.match(date_part, "X") then
        date.circa = true
        date_part = string.gsub(date_part, "X", "0")
      end
      if string.match(date_part, "^%d+$") then
        date_part = tonumber(date_part)
        if date_part > 0 then
          date["date-parts"][i][j] = date_part
        else
          break
        end
      else
        return nil
      end
    end
    if negative_year then
      date["date-parts"][i][1] = - date["date-parts"][i][1]
    end
  end
  return date
end


function util.parse_extra_name(str)
  local name
  local name_parts = util.split(str, "%s*||%s*")
  if #name_parts == 2 then
    name = {
      family = name_parts[1],
      given = name_parts[2],
    }
  else
    name = {literal = str}
  end
  return name
end


function util.check_journal_abbreviations(item)
  if item["container-title"] and not item["container-title-short"] then
    if not journal_data then
      if kpse then
        journal_data = require("citeproc-journal-data")
      else
        journal_data = require("citeproc.journal-data")
      end
    end
    local key = uni_utf8.upper(string.gsub(item["container-title"], "%.", ""))
    local full = journal_data.unabbrevs[key]
    if full then
      item["container-title-short"] = item["container-title"]
      item["container-title"] = full
    else
      local abbr = journal_data.abbrevs[key]
      if abbr then
        item["container-title-short"] = abbr
      end
    end
  end
end


---CSL-M: `layout` extension
---Select the layout by
---@param element Citation | Bibliography
---@param engine CiteProc
---@param item any
---@return Layout
---@return string
function util.get_layout_by_language(element, engine, item)
  if not item then
    return element.layout, engine.lang
  end

  local entry_lang = item.language or ""
  local language = string.sub(entry_lang, 1, 2)
  local primary_dialect = util.primary_dialects[language] or ""

  local layouts = element.layouts_by_language
  local active_layout = layouts[entry_lang] or layouts[language] or layouts[primary_dialect]

  local context_lang
  if active_layout then
    context_lang = entry_lang
  else
    context_lang = engine.lang
    active_layout = element.layout
  end
  return active_layout, context_lang
end


util.trigraph = "Aaaa00:AaAa00:AaAA00:AAAA00"


---comment
---@param trigraph string
---@return { authors: integer[], year: integer }
function util.get_trigraph_param(trigraph)
  if not trigraph or string.sub(trigraph, 1, 1) ~= "A" then
    util.error(string.format('Bad trigraph definition: "%s"', trigraph))
  end
  local param = {
    authors = {},
    year = 0,
  }

  for i = 1, #trigraph do
    local char = string.sub(trigraph, i, i)
    if char == "A" then
      table.insert(param.authors, 1)
    elseif char == "a" then
      local len = #param.authors
      param.authors[len] =  param.authors[len] + 1
    elseif char == "0" then
      param.year = param.year + 1
    else
      util.error(string.format('Invalid character "%s" in trigraph definition "%s"', char, trigraph))
    end
  end
  return param
end


---comment
---@param item ItemData
---@return string
function util.get_citation_label(item)
  local label = ""
  local trigraph = util.split(util.trigraph, ":")
  local config = util.get_trigraph_param(trigraph[1])

  for _, name_variable in ipairs(util.variables.name) do
    local names = item[name_variable]
    if names then
      local param = trigraph[1]
      if #names > #trigraph then
        param = trigraph[#trigraph]
      else
        param = trigraph[#names]
      end
      config = util.get_trigraph_param(param)
      for i, name in ipairs(names) do
        if i > #config.authors then
          break
        end
        local name_label = ""
        if name and name.family then
          name_label = name.family
          name_label = string.gsub(name_label, "^[ 'a-z]+%s*", "")
          name_label = string.gsub(name_label, "^\u{2019}+%s*", "")
        elseif name and name.literal then
          name_label = name.literal
        end
        name_label = uni_utf8.lower(name_label)
        name_label = string.gsub(name_label, "^a%s+", "")
        name_label = string.gsub(name_label, "^an%s+", "")
        name_label = string.gsub(name_label, "^the%s+", "")
        -- TODO: Remove none reomanesque
        name_label = uni_utf8.sub(name_label, 1, config.authors[i])
        if #name_label > 1 then
          name_label = uni_utf8.upper(uni_utf8.sub(name_label, 1, 1)) .. uni_utf8.lower(uni_utf8.sub(name_label, 2))
        elseif #name_label == 1 then
          name_label = uni_utf8.upper(name_label)
        end
        label = label .. name_label
      end

      break
    end
  end

  if label == "" then
    -- TODO: try the title
  end

  local year = "0000"
  if item.issued and item.issued["date-parts"] then
    year = tostring(item.issued["date-parts"][1][1])
  end
  year = string.sub(year, -config.year)
  label = label .. year

  return label
end


return util
