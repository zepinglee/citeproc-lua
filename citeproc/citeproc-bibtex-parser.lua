--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

--[[
  A PEG-based implementation of a Bib(La)TeX database (.bib) parser
  References notes: scripts/bibtex-parser-notes.md
--]]


-- @module bibtex_parser
local bibtex_parser = {}

local unicode
local bibtex_data
local util
local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  unicode = require("citeproc-unicode")
  bibtex_data = require("citeproc-bibtex-data")
  util = require("citeproc-util")
else
  unicode = require("citeproc.unicode")
  bibtex_data = require("citeproc.bibtex-data")
  util = require("citeproc.util")
end

local lpeg = require("lpeg")
local latex_parser = nil  -- load as needed


local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local C = lpeg.C
local Cc = lpeg.Cc
local Cf = lpeg.Cf
local Cg = lpeg.Cg
local Ct = lpeg.Ct
local V = lpeg.V


---@diagnostic disable codestyle-check
-- Learned from <http://boston.conman.org/2020/06/05.1>.
local function case_insensitive_pattern(str)
  local char = R("AZ", "az") / function (c) return P(c:lower()) + P(c:upper()) end
               + P(1) / function (c) return P(c) end
  return Cf(char^1, function (a, b) return a * b end):match(str)
end

-- Merge multiple white spaces to one
local function normalize_white_space(str)
  local res = string.gsub(str, "%s+", " ")
  return res
end


-- Based on the grammar described at <https://github.com/aclements/biblib>.
local function get_bibtex_grammar()
  local inline_comment = P"%" * (1-P"\n")^0 * P"\n"
  local comment = (inline_comment + 1 - P"@")^0
  -- local ws = S(" \t\r\n")^0
  local ws = (S" \t\r\n" + inline_comment)^0
  local comment_cmd = case_insensitive_pattern("comment")
  local balanced = P{ "{" * V(1)^0 * "}" + (1 - S"{}") }
  local ident = (- R"09") * (R"\x20\x7F" - S" \t\"#%'(),={}")^1

  local piece = (P"{" * (balanced^0 / normalize_white_space) * P"}")
                + (P'"' * ((balanced - P'"')^0 / normalize_white_space) * P'"')
                + C(R("09")^1)
                + C(ident) / function (name)
                  return {
                    category = "string",
                    name = string.lower(name),
                  }
                end
  local value = Ct(piece * (ws * P"#" * ws * piece)^0)

  local string_body = Cg(ident / string.lower, "name") * ws * P"=" * ws * Cg(value, "contents")
  local string_cmd = Ct(Cg(Cc"string", "category") * case_insensitive_pattern("string") * ws * (
    P"{" * ws * string_body * ws * P"}"
    + P"(" * ws * string_body * ws * P")"
  ))

  local preamble_body = Cg(value, "contents")
  local preamble_cmd = Ct(Cg(Cc"preamble", "category") * case_insensitive_pattern("preamble") * ws * (
    P"{" * ws * preamble_body * ws * P"}"
    + P"(" * ws * preamble_body * ws * P")"
  ))

  local key = (1 - S", \t}\r\n")^0
  local key_paren = (1 - S", \t\r\n")^0
  local field_value_pair = (ident / string.lower) * ws * P"=" * ws * value  -- * record_success_position()

  local entry_body = Cf(Ct"" * (P"," * ws * Cg(field_value_pair))^0 * (P",")^-1, rawset)
  local entry = Ct(Cg(Cc"entry", "category") * Cg(ident / string.lower, "type") * ws * (
    P"{" * ws * Cg(key, "key") * ws * Cg(entry_body, "fields")^-1 * ws * (P"}")
    + P"(" * ws * Cg(key_paren, "key") * ws * Cg(entry_body, "fields")^-1 * ws * (P")")
  ))

  local command_or_entry = P"@" * ws * (comment_cmd + preamble_cmd + string_cmd + entry)

  -- The P(-1) causes nil parsing result in case of error.
  local bibtex_grammar = Ct(comment * (command_or_entry * comment)^0) * P(-1)

  return bibtex_grammar
end
---@diagnostic enable codestyle-check


local function concat_strings(pieces, strings)
  local value = ""
  for _, piece in ipairs(pieces) do
    if type(piece) == "string" then
      value = value .. piece
    elseif type(piece) == "table" and piece.category == "string" then
      local piece_str = strings[bibtex_parser.normalize_key(piece.name)]
      if piece_str then
        value = value .. piece_str
      else
        util.warning(string.format("String name '%s' is undefined.", piece.name))
      end
    end
  end
  value = normalize_white_space(value)
  return value
end


-- The parser class
---@class BibtexParser
local BibtexParser = {
  grammar = get_bibtex_grammar(),
  -- config
  strings = {},
  options = {
    -- allow_escaped_braces = true,
    convert_to_unicode = false,
    -- common_strings = false,
    -- split_names = false,
    -- split_name_parts = false,
  },
  -- variables
  name_fields = {},
}

---Create a new BibtexParser instance.
---@return BibtexParser
function BibtexParser:new()
  local obj = {}

  obj.options = util.clone(self.options)

  for field, info in ipairs(bibtex_data.fields) do
    if info.type == "name" then
      obj.name_fields[field] = true
    end
  end

  setmetatable(obj, self)
  self.__index = self
  return obj
end


---@alias BibtexEntry { key: string, type: string, fields: table<string, string> }
---@class BibtexData
---@field entries BibtexEntry[]
---@field entries_by_id table<string, BibtexEntry>
---@field strings table<string, string>
---@field preamble string?

---@alias Exception table

---@param bib_str string
---@param strings table<string, string>?
---@return BibtexData?
---@return Exception[]
function BibtexParser:parse(bib_str, strings)
  if strings then
    strings = setmetatable({}, {__index = strings})
  else
    strings = setmetatable({}, {__index = self.strings})
  end
  if type(bib_str) ~= "string" then
    util.error("Invalid string")
  end
  local bib_objects = self.grammar:match(bib_str)
  if not bib_objects then
    local error = {
      type = "error",
      message = "BibTeX parser error.",
    }
    return nil, {error}
  end

  ---@type BibtexData
  local res = {
    ---@type BibtexEntry[]
    entries = {},
    ---@type table<string, BibtexEntry>
    entries_by_id = {},
    strings = {},
    preamble = nil,
  }
  ---@type Exception[]
  local exceptions = {}

  for _, object in ipairs(bib_objects) do
    if object.category == "entry" then
      local entry = self:_make_entry(object, strings)
      table.insert(res.entries, entry)
      res.entries_by_id[entry.key] = entry

    elseif object.category == "string" then
      local string_value = concat_strings(object.contents, strings)
      local normalized_name = bibtex_parser.normalize_key(object.name)
      strings[normalized_name] = string_value
      res.strings[normalized_name] = string_value

    elseif object.category == "preamble" then
      local value = concat_strings(object.contents, strings)
      if res.preamble then
        res.preamble = res.preamble .. "\n" .. value
      else
        res.preamble = value
      end

      -- elseif object.category == "comment" then
      -- Is this really needed?

    elseif object.category == "exception" then
      -- TODO

    end
  end

  return res, exceptions
end


function BibtexParser:_make_entry(object, strings)
  object.category = nil
  for field, value in pairs(object.fields) do
    value = concat_strings(value, strings)

    if self.options.convert_to_unicode then
      if using_luatex then
        latex_parser = latex_parser or require("citeproc-latex-parser")
      else
        latex_parser = latex_parser or require("citeproc.latex-parser")
      end
      value = latex_parser.latex_to_unicode(value)
    end

    -- if self.name_fields[field] then
    --   if self.options.split_names then
    --     local value = bibtex_parser.split_names(value)
    --     value = {}
    --     if self.options.split_name_parts then
    --       for i, name in ipairs(value) do
    --         value[i] = bibtex_parser.split_name_parts(name)
    --       end
    --     end
    --   end
    -- end

    object.fields[field] = value
  end
  return object
end

---@diagnostic disable codestyle-check
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
---@diagnostic enable codestyle-check


---@alias NameDict table<string, string>
---@alias NameStr string

---Split BibTeX names
---@param str NameStr name field value
---@return NameStr[]
function bibtex_parser.split_names(str)
  ---@diagnostic disable codestyle-check
  local delimiter_and = ignore_case("and") * (space + -1)
  local name = (balanced - space * delimiter_and)^1
  local names = Ct(((white_space * delimiter_and) + C(name))^0)
  ---@diagnostic enable codestyle-check
  return names:match(str)
end

---Split BibTeX name parts
---@param str NameStr single name string
---@return NameDict
function bibtex_parser.split_name_parts(str)
  str = util.strip(str)
  if string.match(str, ",$") then
    util.warning(string.format("Name '%s' has has a comma at the end.", str))
    str = string.gsub(str, ",$", "")
  end

  ---@diagnostic disable codestyle-check
  local comma = P","
  local comma_part = (balanced - comma)^0
  local comma_parts = Ct(C(comma_part) * (comma * white_space * C(comma_part))^0)
  ---@diagnostic enable codestyle-check
  local parts = comma_parts:match(str)

  local is_biblatex_extended_format = false
  if #parts > 0 and (string.match(parts[1], "^[a-zA-Z]+%-?i?%s*=")
        or string.match(parts[1], '^"[a-zA-Z]+%-?i?%s*=.*"$')) then
    is_biblatex_extended_format = true
  end

  local name = {}
  if is_biblatex_extended_format then
    name = bibtex_parser._split_extended_name_format(parts)
  elseif #parts == 1 then
    name = bibtex_parser._split_first_von_last_parts(parts[1])
  elseif #parts == 2 then
    name = bibtex_parser._split_von_last_parts(parts[1])
    if parts[2] ~= "" then
      name.first = parts[2]
    end
  elseif #parts == 3 then
    name = bibtex_parser._split_last_jr_first_parts(parts)
  elseif #parts > 3 then
    util.error(string.format("Too many commas in name '%s'", str))
    name = bibtex_parser._split_last_jr_first_parts(util.slice(parts, 1, 3))
  end

  return name
end

local function is_lower_word(word)
  -- Word is a list of tokens
  for _, token in ipairs(word) do
    if string.match(token, "^{") then
      if string.match(token, "^{\\") then
        -- Special characters, level 0
        local token_content
        if string.match(token, "^{\\%w+") then
          token_content = string.gsub(token, "^{\\%w+%s*", "")
        else
          token_content = string.gsub(token, "^{\\.%s*", "")
        end
        token_content = string.gsub(token, "}%s*$", "")
        for i = 1, #token_content do
          local char = string.sub(token_content, i, i)
          if unicode.islower(char) then
            return true
          elseif unicode.isupper(char) then
            return false
          end
        end
      end
    else
      if unicode.islower(token) then
        return true
      elseif unicode.isupper(token) then
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


---@param parts string[]
---@return table<string, string>
function bibtex_parser._split_extended_name_format(parts)
  local name = {}
  for _, part in ipairs(parts) do
    local key, value = string.match(part, "^([a-zA-Z]+%-?i?)%s*=%s*(.-)%s*$")
    if not key then
      key, value = string.match(part, '^"([a-zA-Z]+%-?i?)%s*=%s*(.-)%s*"%s*$')
    end
    if not key then
      util.error(string.format("Invalid extended name part '%s'", part))
    end

    if key == "given" then
      key = "first"
    elseif key == "given-i" then
      key = "first-i"
    elseif key == "prefix" then
      key = "von"
    elseif key == "prefix-i" then
      key = "von-i"
    elseif key == "family" then
      key = "last"
    elseif key == "family-i" then
      key = "last-i"
    elseif key == "suffix" then
      key = "jr"
    elseif key == "suffix-i" then
      key = "jr-i"
    end

    ---@diagnostic disable codestyle-check
    local braced_pattern = P"{" * C(balanced^0) * P"}" * P(-1)
    local stripped = braced_pattern:match(value)
    ---@diagnostic enable codestyle-check
    if stripped then
      value = stripped
    end

    name[key] = value
  end
  return name
end

function bibtex_parser._split_first_von_last_parts(str)
  ---@diagnostic disable codestyle-check
  local word_sep = P" " + P"~" + P(util.unicode['no-break space'])
  local word_tokens = Ct(C(utf8_balanced - space_char - word_sep)^0)
  local words_and_seps = Ct(word_tokens * (C(space + word_sep) * word_tokens)^0)
  local pieces = words_and_seps:match(str)
  ---@diagnostic enable codestyle-check

  local words = {}
  local seps = {""}

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

function bibtex_parser._split_von_last_parts(str)
  ---@diagnostic disable codestyle-check
  local word_sep = P"-" + P"~" + P(util.unicode['no-break space'])
  local word_tokens = Ct(C(utf8_balanced - space_char - word_sep)^0)
  local words_and_seps = Ct(word_tokens * (C(space + word_sep) * word_tokens)^0)
  ---@diagnostic enable codestyle-check
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

---@param parts string[]
---@return NameDict
function bibtex_parser._split_last_jr_first_parts(parts)
  local name = bibtex_parser._split_von_last_parts(parts[1])
  if parts[2] ~= "" then
    name.jr = parts[2]
  end
  if parts[3] ~= "" then
    name.first = parts[3]
  end
  return name
end


function bibtex_parser.normalize_key(entry_key)
  local normalized_key = unicode.NFC(entry_key)
  normalized_key = unicode.casefold(normalized_key)
  return normalized_key
end


--- Note that BibTeX find crossref in a case-insensitive manner (see
--- `article-crossref` in `xampl.bib`) which is unlike biber/biblatex.
--- This function is case-sensitive.
---@param entry_list BibtexEntry[]
---@param entry_dict table<string, BibtexEntry>?
function bibtex_parser.resolve_crossrefs(entry_list, entry_dict)
  if not entry_dict then
    entry_dict = {}
    for _, entry in ipairs(entry_list) do
      entry_dict[bibtex_parser.normalize_key(entry.key)] = entry
    end
  end
  for _, entry in ipairs(entry_list) do
    local ref_entry = entry
    ---@type string?
    local ref_key = entry.fields.crossref
    while ref_key do
      local crossref_entry = entry_dict[bibtex_parser.normalize_key(ref_key)]
      if crossref_entry then
        ref_entry = crossref_entry
        for field, value in pairs(ref_entry.fields) do
          if not entry.fields[field] then
            entry.fields[field] = value
          end
        end
        ref_key = ref_entry.fields.crossref
      else
        util.warning(string.format("Didn't find a database entry for crossref '%s' in entry '%s'.", ref_key,
          ref_entry.key))
        ref_entry.fields.crossref = nil
        ref_key = nil
      end
    end
  end
end


bibtex_parser._default_parser = BibtexParser:new()


---@param bib_str string input string
---@param strings table<string, string>? strings
---@return BibtexData?, Exception[]
function bibtex_parser.parse(bib_str, strings)
  return bibtex_parser._default_parser:parse(bib_str, strings)
end


bibtex_parser.BibtexParser = BibtexParser


return bibtex_parser
