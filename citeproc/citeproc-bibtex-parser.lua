--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

--[[
  A PEG-based implementation of a Bib(La)TeX dateabase (.bib) parser
  References notes: scripts/bibtex-parser-notes.md
--]]

local bibtex_parser = {}

local lpeg = require("lpeg")
local unicode = require("unicode")
local bibtex_data = require("citeproc-bibtex-data")
local util = require("citeproc-util")

local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local C = lpeg.C
local Cc = lpeg.Cc
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Cp = lpeg.Cp
local Ct = lpeg.Ct
local V = lpeg.V


-- The parser class
local BibtexParser = {}

function BibtexParser:new()
  local obj = {
    convert_to_unicode = false,
    common_strings = false,
    split_names = false,
    split_name_parts = false,
    name_variables = {},
  }

  setmetatable(obj, self)
  self.__index = self
  return obj
end

-- continuation byte
local utf8_cont = lpeg.R("\128\191")

local utf8_char = lpeg.R("\0\127")
                  + lpeg.R("\194\223") * utf8_cont
                  + lpeg.R("\224\239") * utf8_cont * utf8_cont
                  + lpeg.R("\240\244") * utf8_cont * utf8_cont * utf8_cont

local space_char = S(" \t\r\n")
local space = space_char^1
local white_space = space_char^0
local balanced = P { "{" * V(1) ^ 0 * "}" + (P "\\{" + P "\\}" + 1 - S "{}") }
local utf8_balanced = P { "{" * V(1) ^ 0 * "}" + (P "\\{" + P "\\}" + utf8_char - S "{}") }

-- The case-insensitivity trick is taken from <http://boston.conman.org/2020/06/05.1>.
local function ignore_case(str)
  local char = R("AZ", "az") / function (c) return P(c:lower()) + P(c:upper()) end
               + P(1) / function (c) return P(c) end
  return Cf(char^1, function (a, b) return a * b end):match(str)
end

function BibtexParser:parse(str, strings)
end

function BibtexParser:_split_names(str)
  local delimiter_and = ignore_case("and") * (space + -1)
  local name = (balanced - space * delimiter_and)^1
  local names = Ct(((white_space * delimiter_and) + C(name))^0)
  return names:match(str)
end

function BibtexParser:_split_name_parts(str)
  str = util.strip(str)
  if string.match(str, ",$") then
    util.warning(string.format('Name "%s" has has a comma at the end.', str))
    str = string.gsub(str, ",$", '')
  end

  local comma = P","
  local comma_part = (balanced - comma)^0
  local comma_parts = Ct(C(comma_part) * (comma * white_space * C(comma_part))^0)
  local parts = comma_parts:match(str)

  local name = {}
  if #parts == 1 then
    name = self:_split_first_von_last_parts(parts[1])
  elseif #parts == 2 then
    name = self:_split_von_last_parts(parts[1])
    if parts[2] ~= "" then
      name.first = parts[2]
    end
  elseif #parts == 3 then
    name = self:_split_von_last_parts(parts[1])
    if parts[2] ~= "" then
      name.jr = parts[2]
    end
    if parts[3] ~= "" then
      name.first = parts[3]
    end
  elseif #parts > 3 then
    util.warning()
    name = self:_split_last_jr_fist_parts(util.slice(parts, 1, 3))
  else
    util.warning()
  end

  return name
end

local function is_upper_letter(char)
  return unicode.utf8.upper(char) == char and unicode.utf8.lower(char) ~= char
end

local function is_lower_letter(char)
  return unicode.utf8.lower(char) == char and unicode.utf8.upper(char) ~= char
end

local function is_lower_word(word)
  -- Word is a list of tokens
  for _, token in ipairs(word) do
    if not string.match(token, "^{") then
      if is_lower_letter(token) then
        return true
      elseif is_upper_letter(token) then
        return false
      end
    end
  end
  return false
end

local function join_words_and_seps(words, seps, start, stop)
  local tokens = {}
  for i = start, stop do
    if i > start then
      table.insert(tokens, seps[i])
    end
    for _, token in ipairs(words[i]) do
      table.insert(tokens, token)
    end
  end
  local res = table.concat(tokens, "")
  if res == "" then
    return nil
  end
  return res
end

function BibtexParser:_split_first_von_last_parts(str)
  local word_sep = P"-" + P"~" + P(util.unicode['no-break space'])
  local word_tokens = Ct(C(utf8_balanced - space_char - word_sep)^0)
  local words_and_seps = Ct(word_tokens * (C(space + word_sep) * word_tokens)^0)
  local pieces = words_and_seps:match(str)

  local words = {}
  local seps = { "" }

  for _, piece in ipairs(pieces) do
    if type(piece) == "table" then
      table.insert(words, piece)
    else
      table.insert(seps, piece)
    end
  end

  local von_start = 0
  local von_stop = 0

  local first_stop = #words - 1
  local last_start = #words

  -- for i, word_or_sep in ipairs(part) do
  for i = 1, #words - 1 do
    local word = words[i]
    if is_lower_word(word) then
      if von_start == 0 then
        von_start = i
      end
      von_stop = i
    end
  end

  -- util.debug(von_start)
  -- util.debug(von_stop)

  local name = {}

  if von_stop > 0 then
    name.von = join_words_and_seps(words, seps, von_start, von_stop)
    last_start = von_stop + 1
    first_stop = von_start - 1
  end

  name.last = join_words_and_seps(words, seps, last_start, #words)

  if first_stop > 0 then
    name.first = join_words_and_seps(words, seps, 1, first_stop)
  end

  return name
end

function BibtexParser:_split_von_last_parts(str)
  local word_sep = P"-" + P"~" + P(util.unicode['no-break space'])
  local word_tokens = Ct(C(utf8_balanced - space_char - word_sep)^0)
  local words_and_seps = Ct(word_tokens * (C(space + word_sep) * word_tokens)^0)
  local pieces = words_and_seps:match(str)

  local words = {}
  local seps = {""}

  for _, piece in ipairs(pieces) do
    if type(piece) == "table" then
      table.insert(words, piece)
    else
      table.insert(seps, piece)
    end
  end

  local von_stop = 0
  local last_start = 1

  -- for i, word_or_sep in ipairs(part) do
  for i = #words - 1, 1, -1 do
    local word = words[i]
    if is_lower_word(word) then
      von_stop = i
      break
    end
  end

  local name = {}

  if von_stop > 0 then
    name.von = join_words_and_seps(words, seps, 1, von_stop)
    last_start = von_stop + 1
  end
  name.last = join_words_and_seps(words, seps, last_start, #words)

  return name
end

bibtex_parser.BibtexParser = BibtexParser
local _default_parser = BibtexParser:new()


function bibtex_parser.parse(strings, parser)
  if not strings then
    strings = {}
  end
  if not parser then
    parser = _default_parser
  end
end

return bibtex_parser
