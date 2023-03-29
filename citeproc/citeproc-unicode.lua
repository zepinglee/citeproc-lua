--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local unicode = {}

local sln = require("unicode")
local uni_case = require("lua-uni-case")
local uni_words = nil
if kpse.find_file("lua-uni-words", "lua") then
  uni_words = require("lua-uni-words")
end

local util = require("citeproc-util")


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
  str = sln.grapheme.gsub(str, ".", sln.grapheme.upper, 1)
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
  return uni_case.casefold(str, true, enable_special)
end


---Return True if all characters in the string are alphanumeric and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isalnum(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isalnum' (string expected, got %s)", type(str)))
  end
  return sln.grapheme.match(str, "^%w+$") ~= nil
end


---Return True if all characters in the string are alphabetic and there is at least one character, False otherwise.
---@param str string
---@return boolean
function unicode.isalpha(str)
  if type(str) ~= "string" then
    error(string.format("bad argument #1 to 'isalpha' (string expected, got %s)", type(str)))
  end
  return sln.grapheme.match(str, "^%a+$") ~= nil
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
  return sln.grapheme.find(str, "%l") and not sln.grapheme.find(str, "%u")
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
  return sln.grapheme.find(str, "%u") and not sln.grapheme.find(str, "%l")
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
  return sln.grapheme.lower(str)
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
  return sln.grapheme.lower(str)
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
  if uni_words then
    for _, _, segment in uni_words.word_boundaries(str) do
      if unicode.isalnum(segment) then
        table.insert(words, segment)
      end
    end

  else
    -- A naive implementation
    local state = CharState.Other
    local last_idx = 1
    for idx, char in sln.grapheme.gmatch(str, "()(.)") do
      local new_state = CharState.Other
      if sln.grapheme.match(char, "%w") or char == "'" or char == "’" or char == "`" then
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
  local segments = {}
  if uni_words then
    for _, _, segment in uni_words.word_boundaries(str) do
      table.insert(segments, segment)
    end

  else
    -- A naive implementation
    local state = CharState.Other
    local last_idx = 1
    for idx, char in sln.grapheme.gmatch(str, "()(.)") do
      local new_state = CharState.Other
      if sln.grapheme.match(char, "%w") or char == "'" or char == "’" or char == "`" then
        new_state = CharState.Word
      elseif sln.grapheme.match(char, "%p") then
        new_state = CharState.Punctuation
      elseif sln.grapheme.match(char, "%s") then
        new_state = CharState.Space
      else
        new_state = CharState.Other
      end
      if new_state ~= state then
        if idx > 1 then
          local segment = string.sub(str, last_idx, idx - 1)
          table.insert(segments, segment)
        end
        state = new_state
        last_idx = idx
      end
    end

    local segment = string.sub(str, last_idx, #str)
    table.insert(segments, segment)
  end

  return segments
end

return unicode
