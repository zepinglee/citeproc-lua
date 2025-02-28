--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local unicode = {}

local uni_utf8
local uni_algos_words
local uni_algos_case
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  -- Load `slnunicode` if in LuaTeX
  uni_utf8 = require("unicode").utf8
  local ok
  ok, uni_algos_words = pcall(require, "lua-uni-words")
  if not ok then
    ok, uni_algos_words = pcall(require, "citeproc-lua-uni-words")
  end
  uni_algos_case = require("lua-uni-case")
  util = require("citeproc-util")
else
  uni_utf8 = require("lua-utf8")
  if not utf8 then
    -- Lua < 5.3
    utf8 = uni_utf8
  end
  uni_algos_words = require("citeproc.lua-uni-algos.words")
  uni_algos_case = require("citeproc.lua-uni-algos.case")
  util = require("citeproc.util")
end


---@param str any
---@return integer
function unicode.len(str)
  return uni_utf8.len(str)
end


---Return a copy of the string with its first character capitalized and the rest lowercased.
---@param str string
---@param locale string?
---@return string
function unicode.capitalize(str, locale)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'capitalize' (string expected, got %s)", type(str)))
  end
  -- TODO: locale and unicode titlecase Lt
  str = unicode.lower(str, locale)
  str = uni_utf8.gsub(str, ".", uni_utf8.upper, 1)
  return str
end


---Return a casefolded copy of the string. Casefolded strings may be used for caseless matching.
---@param str string
---@param locale string?
---@return string
function unicode.casefold(str, locale)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'casefold' (string expected, got %s)", type(str)))
  end
  local enable_special = false
  if locale and string.match(locale, "^tr") then
    enable_special = true
  end
  return uni_algos_case.casefold(str, true, enable_special)
end


---Return True if all characters in the string are alphanumeric and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isalnum(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isalnum' (string expected, got %s)", type(str)))
  end
  return uni_utf8.match(str, "^%w+$") ~= nil
end


---Return True if all characters in the string are alphabetic and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isalpha(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isalpha' (string expected, got %s)", type(str)))
  end
  return uni_utf8.match(str, "^%a+$") ~= nil
end


---Return True if the string is empty or all characters in the string are ASCII, False otherwise.
---@param str string
---@return boolean
function unicode.isascii(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isascii' (string expected, got %s)", type(str)))
  end
  return string.match(str, "^[\0-\x7F]+$") ~= nil
end


---Return True if all characters in the string are digits and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isdigit(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isdigit' (string expected, got %s)", type(str)))
  end
  return string.match(str, "^%d+$") ~= nil
end


---Return True if all cased characters in the string are lowercase and there is at least one cased character, False otherwise.
---@param str string
---@return boolean
function unicode.islower(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'islower' (string expected, got %s)", type(str)))
  end
  --TODO: No titlecased letters
  return uni_utf8.find(str, "%l") and not uni_utf8.find(str, "%u")
end


---Return True if all characters in the string are numeric characters, and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isnumeric(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isnumeric' (string expected, got %s)", type(str)))
  end
  return string.match(str, "^%n+$") ~= nil
end


---@param str string
---@return boolean
function unicode.ispunct(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isnumeric' (string expected, got %s)", type(str)))
  end
  return uni_utf8.match(str, "^%p+$") ~= nil
end


-- ---Return True if the string is a titlecased string and there is at least one character, for example uppercase characters may only follow uncased characters and lowercase characters only cased ones. Return False otherwise.
-- ---@param str string
-- ---@return boolean
-- function unicode.istitle(str)
--   if type(str) ~= "string" then
--     error(string.format("bad argument #1 to 'istitle' (string expected, got %s)", type(str)))
--   end
--   error("Not implemented")
--   return false
-- end


---Return True if all cased characters in the string are uppercase and there is at least one cased character, False otherwise.
---@param str string
---@return boolean
function unicode.isupper(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isupper' (string expected, got %s)", type(str)))
  end
  --TODO: No titlecased letters
  return uni_utf8.find(str, "%u") and not uni_utf8.find(str, "%l")
end


---Return a copy of the string with all the cased characters converted to lowercase.
---@param str string
---@param locale string?
---@return string
function unicode.lower(str, locale)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'lower' (string expected, got %s)", type(str)))
  end
  -- TODO: locale
  return uni_utf8.lower(str)
end


-- ---Return a titlecased version of the string where words start with an uppercase character and the remaining characters are lowercase.
-- ---@param str string
-- ---@param locale string?
-- ---@return string
-- function unicode.title(str, locale)
--   if type(str) ~= "string" then
--     error(string.format("bad argument #1 to 'title' (string expected, got %s)", type(str)))
--   end
--   error("Not implemented")
-- end


---Return a copy of the string with all the cased characters converted to uppercase.
---@param str string
---@param locale string?
---@return string
function unicode.upper(str, locale)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'upper' (string expected, got %s)", type(str)))
  end
  -- TODO: locale
  return uni_utf8.upper(str)
end


---@enum CharState
local CharState = {
  Other = 0,
  Word = 1,
  Punctuation = 2,
  Space = 3,
}


---@param str string
---@return string[]
function unicode.words(str)
  local words = {}
  if uni_algos_words then
    for _, _, segment in uni_algos_words.word_boundaries(str) do
      if unicode.isalnum(segment) then
        table.insert(words, segment)
      end
    end

  else
    -- A naive implementation
    local state = CharState.Other
    local last_idx = 1
    for idx, char in uni_utf8.gmatch(str, "()(.)") do
      local new_state = CharState.Other
      if uni_utf8.match(char, "%w") or char == "'" or char == "’" or char == "`" then
        new_state = CharState.Word
      else
        new_state = CharState.Other
      end
      if new_state ~= state then
        if idx > 1 and state == CharState.Word then
          local segment = string.sub(str, last_idx, idx - 1)
          table.insert(words, segment)
        end
        state = new_state
        last_idx = idx
      end
    end

    if state == CharState.Word then
      local segment = string.sub(str, last_idx, #str)
      table.insert(words, segment)
    end
  end

  return words

end


---@param str string
---@return string[]
function unicode.split_word_bounds(str)
  -- util.debug(str)
  local segments = {}
  if uni_algos_words then
    -- util.debug("uni_algos_words")
    for _, _, segment in uni_algos_words.word_boundaries(str) do
      table.insert(segments, segment)
    end
    -- textcase_NoSpaceBeforeApostrophe.txt: "Marcus Shafi`" -> ["Marcus" "Shafi`"]
    for i = #segments, 1, -1 do
      local segment = segments[i]
      if segment == "`" then
        if i < #segments and not uni_utf8.match(segments[i+1], "^%s") then
          segments[i] = segment .. segments[i+1]
          table.remove(segments, i+1)
        end
        if i > 1 and not uni_utf8.match(segments[i-1], "%s") then
          segments[i-1] = segments[i-1] .. segments[i]
          table.remove(segments, i)
        end
      end
    end

  else
    -- util.debug("no uni_algos_words")
    -- A naive implementation
    local state = CharState.Other
    local segment = ""
    for idx, code_point in utf8.codes(str) do
      local char = utf8.char(code_point)
      local new_state = CharState.Other
      if uni_utf8.match(char, "%w") or char == "'" or char == "’" or char == "`" then
        new_state = CharState.Word
      elseif uni_utf8.match(char, "%p") then
        new_state = CharState.Punctuation
      elseif uni_utf8.match(char, "%s") then
        new_state = CharState.Space
      else
        new_state = CharState.Other
      end
      if new_state ~= state then
        if segment ~= "" then
          table.insert(segments, segment)
          segment = ""
        end
        state = new_state
      end
      segment = segment .. char
    end

    table.insert(segments, segment)
  end

  -- util.debug(segments)
  return segments
end

return unicode
