--[[
  Copyright (C) 2021 Zeping Lee
--]]

-- load `slnunicode` from LuaTeX
local unicode = require("unicode")


local util = {}

function util.to_ordinal (n)
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


util.error = function (message)
  error(message, 2)
end


util.warning = function (message)
  if message == nil then
    message = ""
  else
    message = tostring(message)
  end
  io.stderr:write("Warning: " .. message .. "\n")
end


util.debug = function (message)
  io.stderr:write("Debug: " .. tostring(message) .. "\n")
end

function util.split (str, pat)
  if pat == nil then
    pat = "%s+"
  end
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
    if s ~= 1 or cap ~= "" then
     table.insert(t, cap)
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
    cap = str:sub(last_end)
    table.insert(t, cap)
   end
   return t
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
  for _, s in ipairs(list) do
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

function util.lstrip (str)
  if not str then
    return nil
  end
  local res = string.gsub(str, "^%s+", "")
  return res
end

function util.rstrip (str)
  if not str then
    return nil
  end
  local res = string.gsub(str, "%s+$", "")
  return res
end

function util.strip (str)
  return util.lstrip(util.rstrip(str))
end

function util.startswith (str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

function util.endswith (str, suffix)
  return string.sub(str, -#suffix) == suffix
end

function util.is_numeric (str)
  if str == nil or str == "" then
    return false
  end
  local res = true
  for w in string.gmatch(str, "%w+") do
    if string.match(w, "^[a-zA-Z]*%d+[a-zA-Z]*$") == nil then
      res = false
      break
    end
  end
  for w in string.gmatch(str, "%W+") do
    if string.match(w, "^%s*[,&-]+%s*$") == nil then
      res = false
      break
    end
  end
  return res
end

function util.is_uncertain_date (variable)
  if variable == nil then
    return false
  end
  local value = variable["circa"]
  return value ~= nil and value ~= ""
end

util.variable_types = {}

util.variables = {}

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
  ["en dash"] = "\u{2013}",
  ["em dash"] = "\u{2014}",
  ["left single quotation mark"] = "\u{2018}",
  ["right single quotation mark"] = "\u{2019}",
  ["apostrophe"] = "\u{2019}",
  ["left double quotation mark"] = "\u{201C}",
  ["right double quotation mark"] = "\u{201D}",
  ["horizontal ellipsis"] = "\u{2026}"
}


-- Text-case

function util.is_lower (str)
  return unicode.utf8.lower(str) == str
end

function util.is_upper (str)
  return unicode.utf8.upper(str) == str
end

function util.capitalize (str)
  str = string.lower(str)
  local res = string.gsub(str, "%w", unicode.utf8.upper, 1)
  return res
end

function util.capitalize_first (str)
  local output = {}
  for i, word in ipairs(util.split(str)) do
    if i == 1 and util.is_lower(word) then
      word = util.capitalize(word)
    end
    table.insert(output, word)
  end
  return table.concat(output, " ")
end

function util.capitalize_all (str)
  local output = {}
  for _, word in ipairs(util.split(str)) do
    if util.is_lower(word) then
      word = util.capitalize(word)
    end
    table.insert(output, word)
  end
  return table.concat(output, " ")
end

function util.sentence (str)
  if util.is_upper(str) then
    return util.capitalize(str)
  else
    local output = {}
    for i, word in ipairs(util.split(str)) do
      if i == 1 and util.is_lower(word) then
        table.insert(output, util.capitalize(word))
      else
        table.insert(output, word)
      end
    end
    return table.concat(output, " ")
  end
end

util.stop_words = {
  ["a"] = true,
  ["an"] = true,
  ["and"] = true,
  ["as"] = true,
  ["at"] = true,
  ["but"] = true,
  ["by"] = true,
  ["down"] = true,
  ["for"] = true,
  ["from"] = true,
  ["in"] = true,
  ["into"] = true,
  ["nor"] = true,
  ["of"] = true,
  ["on"] = true,
  ["onto"] = true,
  ["or"] = true,
  ["over"] = true,
  ["so"] = true,
  ["the"] = true,
  ["till"] = true,
  ["to"] = true,
  ["up"] = true,
  ["via"] = true,
  ["with"] = true,
  ["yet"] = true,
}

function util.title (str)
  local output = {}
  local previous = ":"
  for i, word in ipairs(util.split(str)) do
    local lower = string.lower(word)
    if previous ~= ":" and util.stop_words[string.match(lower, "%w+")] then
      table.insert(output, lower)
    elseif util.is_lower(word) or util.is_upper(word) then
      table.insert(output, util.capitalize(word))
    else
      table.insert(output, word)
    end
  end
  local res = table.concat(output, " ")
  return res
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
  {0x0E01, 0x0E5B},
  {0x00C0, 0x017F},
  {0x0370, 0x03FF},
  {0x0400, 0x052F},
  {0x0590, 0x05D4},
  {0x05D6, 0x05FF},
  {0x1F00, 0x1FFF},
  {0x0600, 0x06FF},
  {0x202A, 0x202E},
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

util.romanesque_chars = {
  0x200c,
  0x200d,
  0x200e,
  0x0218,
  0x0219,
  0x021a,
  0x021b,
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

function util.is_romanesque (s)
  -- has romanesque char but not necessarily pure romanesque
  if not s then
    return false
  end
  local res = false
  if string.match(s, "%a") then
    res = true
  else
    for _, codepoint in utf8.codes(s) do
      local char_is_romanesque = string.match(utf8.char(codepoint), "[-%w]") or
        util.in_list(codepoint, util.romanesque_chars) or
        util.in_ranges(codepoint, util.romanesque_ranges)
      if char_is_romanesque then
        res = true
        break
      end
    end
  end
  return res
end


return util
