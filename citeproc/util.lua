--[[
  Copyright (C) 2021 Zeping Lee
--]]

local util = {}

function util.to_ordinal(n)
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

function util.split(str, pat)
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

function util.slice(t, start, stop)
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

function util.join_non_empty(t, sep)
  local t_non_empty = {}
  for _, item in ipairs(t) do
    if item and item ~= "" then
      table.insert(t_non_empty, item)
    end
  end
  if next(t_non_empty) == nil then
    return nil
  end
  return table.concat(t_non_empty, sep)
end

function util.rstrip(str)
  if not str then
    return nil
  end
  local res = string.gsub(str, "%s*$", "")
  return res
end

function util.startswith(str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

function util.endswith(str, suffix)
  -- print(string.sub(str, -#suffix))
  return string.sub(str, -#suffix) == suffix
end

function util.initialize(given, mark)
  local parts = util.split(given)
  local output = {}
  for _, part in ipairs(parts) do
    local first_letter = string.sub(part, 1, 1)
    table.insert(output, first_letter .. mark)
  end
  output = table.concat(output)
  return table.concat(util.split(output), ' ')
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
}


-- Text-case

function util.is_lower(str)
  return string.match(str, "%u") == nil
end

function util.is_upper(str)
  return string.match(str, "%l") == nil
end

function util.capitalize(str)
  str = string.lower(str)
  local res = string.gsub(str, "%w", string.upper, 1)
  return res
end

function util.capitalize_first(str)
  local output = {}
  for i, word in ipairs(util.split(str)) do
    if i == 1 and util.is_lower(word) then
      word = util.capitalize(word)
    end
    table.insert(output, word)
  end
  return table.concat(output, " ")
end

function util.capitalize_all(str)
  local output = {}
  for _, word in ipairs(util.split(str)) do
    if util.is_lower(word) then
      word = util.capitalize(word)
    end
    table.insert(output, word)
  end
  return table.concat(output, " ")
end

function util.sentence(str)
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

function util.title(str)
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

function util.all(t)
  for _, item in ipairs(t) do
    if not item then
      return false
    end
  end
  return true
end

function util.any(t)
  for _, item in ipairs(t) do
    if item then
      return true
    end
  end
  return false
end


return util
