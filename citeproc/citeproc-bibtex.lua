--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

--[[
  A PEG-based implementation of a Bib(La)TeX dateabase (.bib) parser
  References notes: scripts/bibtex-parser-notes.md
--]]

local bibtex = {}

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

bibtex.strings = {}  -- Stores all the @STRINGs
for key, value in pairs(bibtex_data.macros) do
  bibtex.strings[key] = value.value
end


-- Parse BibTeX content and convert to CSL-JSON
function bibtex.parse(str)
  local bibliography = bibtex.parse_bibtex(str, bibtex.strings)
  local csl_json_items = bibtex.convert_csl_json(bibliography)
  return csl_json_items
end


-- The case-insensitivity trick is taken from <http://boston.conman.org/2020/06/05.1>.
local function ignore_case(str)
  local char = R("AZ", "az") / function (c) return P(c:lower()) + P(c:upper()) end
               + P(1) / function (c) return P(c) end
  return Cf(char^1, function (a, b) return a * b end):match(str)
end

  local function normalize_white_space(str)
    local res = string.gsub(str, "%s+", " ")
    return res
  end

-- Based on the grammar described at <https://github.com/aclements/biblib>.
function bibtex.get_bibtex_grammar()
  local comment = (1 - P"@")^0
  local space = S(" \t\r\n")^0
  local comment_cmd = ignore_case("comment")
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
  local value = Ct(piece * (space * P"#" * space * piece)^0)

  local string_body = Cg(ident / string.lower, "name") * space * P"=" * space * Cg(value, "contents")
  local string_cmd = Ct(Cg(Cc"string", "category") * ignore_case("string") * space * (
    P"{" * space * string_body * space * P"}"
    + P"(" * space * string_body * space * P")"
  ))

  local preamble_body = Cg(value, "contents")
  local preamble_cmd = Ct(Cg(Cc"preamble", "category") * ignore_case("preamble") * space * (
    P"{" * space * preamble_body * space * P"}"
    + P"(" * space * preamble_body * space * P")"
  ))

  local key = (1 - S", \t}\r\n")^0
  local key_paren = (1 - S", \t\r\n")^0
  local field_value_pair = (ident / string.lower) * space * P"=" * space * value  -- * record_success_position()

  local entry_body = Cf(Ct"" * (P"," * space * Cg(field_value_pair))^0 * (P",")^-1, rawset)
  local entry = Ct(Cg(Cc"entry", "category") * Cg(ident / string.lower, "type") * space * (
    P"{" * space * Cg(key, "key") * space * Cg(entry_body, "fields")^-1 * space * (P"}")
    + P"(" * space * Cg(key_paren, "key") * space * Cg(entry_body, "fields")^-1 * space * (P")")
  ))

  local command_or_entry = P"@" * space * (comment_cmd + preamble_cmd + string_cmd + entry)

  -- The P(-1) causes nil parsing result in case of error.
  local bibtex_grammar = Ct(comment * (command_or_entry * comment)^0) * P(-1)

  return bibtex_grammar
end


bibtex.bibtex_grammar = bibtex.get_bibtex_grammar()


-- Return a list of entries, strings, preamble
function bibtex.parse_bibtex_objects(str)
  return bibtex.bibtex_grammar:match(str)
end


local function concat_strings(pieces, strings)
  local value = ""
  for _, piece in ipairs(pieces) do
    if type(piece) == "string" then
      value = value .. piece
    elseif type(piece) == "table" and piece.category == "string" then
      local piece_str = strings[piece.name]
      if piece_str then
        value = value .. piece_str
      else
        util.warning(string.format('String name "%s" is undefined."', piece.name))
      end
    end
  end
  value = normalize_white_space(value)
  return value
end


function bibtex.parse_bibtex(content, strings)
  if strings then
    strings = setmetatable({}, {__index = strings})
  else
    strings = setmetatable({}, {__index = bibtex.strings})
  end
  local bib_objects = bibtex.parse_bibtex_objects(content)

  local res = {
    entries = {},
    strings = {},
    preamble = "",
  }
  local exceptions = {}
  for _, object in ipairs(bib_objects) do
    if object.category == "entry" then
      object.category = nil
      for field, value in pairs(object.fields) do
        local value_str = concat_strings(value, strings)
        if field ~= "url" then
          value_str = bibtex.to_unicode(value_str)
        end
        object.fields[field] = value_str
      end
      table.insert(res.entries, object)

    elseif object.category == "string" then
      local string_value = concat_strings(object.contents, strings)
      strings[object.name] = string_value
      res.strings[object.name] = string_value

    elseif object.category == "preamble" then
      res.preamble = res.preamble .. concat_strings(object.contents, strings)

    -- elseif object.category == "comment" then
    -- Is this really needed?

    elseif object.category == "exception" then
      -- TODO

    end
  end

  return res
end


local function get_line_number(str, position)
  local line_number = 1
  for i = 1, position do
    if string.sub(str, i, i) == "\n" then
      line_number = line_number + 1
    end
  end
  return line_number
end


function bibtex.get_latex_grammar()
  local space = S(" \t\r\n")^0
  local specials = P"\\$" / "$"
                   + P"\\%" / "%"
                   + P"\\&" / "&"
                   + P"\\#" / "#"
                   + P"\\_" / "_"
                   + P"\\{" / "{"
                   + P"\\}" / "}"
                   + P"~" / util.unicode["no-break space"]
  local control_sequence = C(P"\\" * (R("AZ", "az")^1 + 1) * space) / function (cs)
    return {
      type = "control_sequence",
      name = util.rstrip(cs),
      raw = cs,
    }
  end
  local math = P"$" * C((P"\\$" + 1 - S"$")^0) * P"$" / function (math_text)
    return {
      type = "math",
      contents = math_text,
    }
  end
  local ligatures = P"``" / util.unicode["left double quotation mark"]
                    + P"`" / util.unicode["left single quotation mark"]
                    + P"''" / util.unicode["right double quotation mark"]
                    + P"'" / util.unicode["right single quotation mark"]
                    + P"---" / util.unicode["em dash"]
                    + P"--" / util.unicode["en dash"]
  local plain_text = C(1 - S"{}$\\")
  local latex_grammar = P{
    "latex_text";
    latex_text = Ct((specials + control_sequence + math + ligatures + specials + V"group" + plain_text)^0),
    group = P"{" * V"latex_text" * P"}" / function (group_contents)
      return {
        type = "group",
        contents = group_contents,
      }
    end,
  }
  return latex_grammar
end

bibtex.latex_grammar = bibtex.get_latex_grammar()


function bibtex.to_unicode(str)
  local tokens = bibtex.latex_grammar:match(str)
  local res = bibtex.unescape_tokens(tokens, 0)
  return res
end

local format_commands_with_argment = {
  ["\\textrm"] = {'<span class="nodecor">', '</span>'},
  ["\\textbf"] = {'<b>', '</b>'},
  ["\\textit"] = {'<i>', '</i>'},
  ["\\textsl"] = {'<i>', '</i>'},
  ["\\emph"] = {'<i>', '</i>'},
  ["\\textsc"] = {'<span style="font-variant: small-caps;">', '</span>'},
  ["\\textsuperscript"] = {'<sup>', '</sup>'},
  ["\\textsubscript"] = {'<sub>', '</sub>'},
}

local format_commands_without_argment = {
  ["\\rm"] = {'<span class="nodecor">', '</span>'},
  ["\\upshape"] = {'<span class="nodecor">', '</span>'},
  ["\\bf"] = {'<b>', '</b>'},
  ["\\bfseries"] = {'<b>', '</b>'},
  ["\\it"] = {'<i>', '</i>'},
  ["\\itshape"] = {'<i>', '</i>'},
  ["\\sl"] = {'<i>', '</i>'},
  ["\\slshape"] = {'<i>', '</i>'},
  ["\\em"] = {'<i>', '</i>'},
  ["\\scshape"] = {'<span style="font-variant: small-caps;">', '</span>'},
  ["\\sc"] = {'<span style="font-variant: small-caps;">', '</span>'},
}


function bibtex.unescape_tokens(tokens, brace_level)
  local res = ""
  local skip_token = false
  for i, token in ipairs(tokens) do
    if skip_token then
      skip_token = false
    else
      if type(token) == "string" then
        res = res .. token
      elseif type(token) == "table" then
        if token.type == "control_sequence" then
          local code_point = bibtex_data.unicode_commands[token.name]
          if code_point then
            local unicode_char
            if type(code_point) == "string" then
              unicode_char = utf8.char(tonumber(code_point, 16))
            elseif type(code_point) == "table" then
              -- The command takes an argument (\"{o})
              local arg
              if i < #tokens then
                local next_token = tokens[i + 1]
                if type(next_token) == "string" then
                  arg = next_token
                  skip_token = true
                elseif type(next_token) == "table" then
                  if next_token.type == "control_sequence" then
                    arg = next_token.name
                    skip_token = true
                  elseif next_token.type == "group" then
                    if #next_token.contents == 0 then
                      arg = "{}"
                      skip_token = true
                    elseif #next_token.contents == 1 then
                      next_token = next_token.contents[1]
                      if type(next_token) == "string" then
                        arg = next_token
                        skip_token = true
                      elseif type(next_token) == "table" then
                        arg = next_token.name
                        skip_token = true
                      end
                    end
                  end
                end
              end
              if arg and code_point[arg] then
                unicode_char = utf8.char(tonumber(code_point[arg], 16))
              end
            end
            if unicode_char then
              res = res .. unicode_char
            else
              res = res .. '<span class="nocase">' .. token.raw .. '</span>'
            end

          elseif format_commands_with_argment[token.name] then
            -- Commands like `\textbf`
            if i < #tokens then
              local next_token = tokens[i + 1]
              if type(next_token) == "table" and next_token.type == "group" then
                local tags = format_commands_with_argment[token.name]
                if brace_level == 0 then
                  res = res .. tags[1] .. '<span class="nocase">' .. bibtex.unescape_tokens(next_token.contents, brace_level + 1) .. '</span>' .. tags[2]
                else
                  res = res .. tags[1] .. bibtex.unescape_tokens(next_token.contents, brace_level + 1) .. tags[2]
                end
                skip_token = true
              else
                res = res .. '<span class="nocase">' .. token.raw .. '</span>'
              end
            else
              res = res .. '<span class="nocase">' .. token.raw .. '</span>'
            end

          else
            res = res .. '<span class="nocase">' .. token.raw .. '</span>'

          end

        elseif token.type == "math" then
          -- res = res .. "$" .. token .. "$"
          res = res .. '<span class="nocase">' .. token.raw .. '</span>'

        elseif token.type == "group" then
          local first_token = token.contents[1]
          if type(first_token) == "table" and first_token.type == "control_sequence" then
            local tags = format_commands_without_argment[first_token.name]
            if tags then
              table.remove(token.contents, 1)
              res = res .. tags[1] .. bibtex.unescape_tokens(token.contents, brace_level) .. tags[2]
            else
              res = res .. bibtex.unescape_tokens(token.contents, brace_level)
            end
          else
            if brace_level == 0 then
              res = res .. '<span class="nocase">' .. bibtex.unescape_tokens(token.contents, brace_level + 1) .. '</span>'
            else
              res = res .. '<span class="nocase">' .. bibtex.unescape_tokens(token.contents, brace_level + 1) .. '</span>'
            end
          end

        end
      end
    end
  end
  return res
end

-- function bibtex.format_syntanx_error(str, position, file_path)
--   local line_number = 1
--   local line_start = 1
--   local column_number = 0
--   for i = 1, position do
--     column_number = column_number + 1
--     if string.sub(str, i, i) == "\n" then
--       line_number = line_number + 1
--       line_start = i + 1
--       column_number = 0
--     end
--   end
--   -- return line_number, column_number

--   local res
--   if file_path then
--     res = string.format('File "%s", line %d\n', file_path, line_number)
--   else
--     res = string.format('Line %d\n', line_number)
--   end
--   local line_end = position
--   while line_end < #str + 1 and string.sub(str, line_end, line_end) ~= "\n" do
--     line_end = line_end + 1
--   end
--   res = res .. "  " .. string.sub(str, line_start, line_end - 1) .. "\n"
--   res = res .. "Syntax Error"
--   return res
-- end


function bibtex.convert_csl_json(bibliography)
  local csl_json_data = {}
  for _, entry in ipairs(bibliography.entries) do
    local item = {  -- CSL-JSON item
      id = entry.key,
      type = "document",
    }

    -- CSL types
    local type_data = bibtex_data.types[entry.type]
    if type_data and type_data.csl then
      item.type = type_data.csl
    end

    for field, value in pairs(entry.fields) do
      local csl_field, csl_value = bibtex.convert_field(field, value)

      if csl_field and csl_value and not item[csl_field] then
        item[csl_field] = csl_value
      end
    end

    bibtex.process_special_fields(item, entry.fields)

    table.insert(csl_json_data, item)
  end

  return csl_json_data
end


function bibtex.convert_field(bib_field, value)
  local field_data = bibtex_data.fields[bib_field]
  if not field_data then
    return nil, nil
  end
  local csl_field = field_data.csl
  if not csl_field then
    return nil, nil
  end

  local field_type = field_data.type
  if field_type == "name" then
    value = bibtex.parse_names(value)

  elseif field_type == "date" then
    value = bibtex.parse_date(value)

  -- elseif bib_field == "title" or bib_field == "booktitle" then
  --   value = bibtex.convert_sentence_case(value)

  elseif bib_field == "volume" or bib_field == "pages" then
    value = string.gsub(value, util.unicode["en dash"], "-")
  end

  return csl_field, value
end


function bibtex.parse_names(str)
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
    names[i] = bibtex.parse_single_name(name)
  end
  return names
end

function bibtex.parse_single_name(str)
  local literal = string.match(str, "^{(.*)}$")
  if literal then
    return {
      literal = literal,
    }
  end

  local name_parts = util.split(str, ",%s*")
  if #name_parts > 1 then
    return bibtex.parse_revesed_name(name_parts)
  else
    return bibtex.parse_non_revesed_name(str)
  end
end

function bibtex.parse_revesed_name(name_parts)
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

function bibtex.parse_non_revesed_name(str)
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

function bibtex.parse_date(str)
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
    local date_ = bibtex.parse_single_date(date_part)
    if not date_ then
      return literal
    end
    table.insert(date["date-parts"], date_)
  end
  return date
end

function bibtex.parse_single_date(str)
  local date = {}
  for _, date_part in ipairs(util.split(str, "%-")) do
    if not string.match(date_part, "^%d+$") then
      return nil
    end
    table.insert(date, tonumber(date_part))
  end
  return date
end


-- -- TODO: check if the original title is in sentence case
-- function bibtex.convert_sentence_case(str)
--   local res = ""
--   local to_lower = false
--   local brace_level = 0
--   for _, code_point in utf8.codes(str) do
--     local char = utf8.char(code_point)
--     if to_lower and brace_level == 0 then
--       char = string.lower(char)
--     end
--     if string.match(char, "%S") then
--       to_lower = true
--     end
--     if char == "{" then
--       brace_level = brace_level + 1
--       char = ""
--     elseif char == "}" then
--       brace_level = brace_level - 1
--       char = ""
--     elseif char == ":" then
--       to_lower = false
--     end
--     res = res .. char
--   end
--   return res
-- end



function bibtex.process_special_fields(item, bib_fields)
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
    item.issued = bibtex.parse_date(bib_fields.year)
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
    local language_code = bibtex_data.language_code_map[item.language]
    if language_code then
      item.language = language_code
    end
  end
  -- if not item.language then
  --   if util.has_cjk_char(item.title) then
  --     item.language = "zh"
  --   end
  -- end

  -- Jounal abbreviations
  if item.type == "article-journal" or item.type == "article-magazine"
      or item.type == "article-newspaper" then
    util.check_journal_abbreviations(item)
  end

  -- number
  if item.number then
    if item.type == "article-journal" or item.type == "article-magazine" or
        item.type == "article-newspaper" or item.type == "periodical" then
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


return bibtex
