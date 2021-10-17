--[[
  A naive implementation of a Bib(La)TeX dateabase (.bib) parser
  References:
  - http://mirrors.ctan.org/biblio/bibtex/base/btxdoc.pdf
  - http://mirrors.ctan.org/info/bibtex/tamethebeast/ttb_en.pdf
  - https://github.com/brechtm/citeproc-py/blob/master/citeproc/source/bibtex/bibparse.py
  - http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html
  - https://github.com/pcooksey/bibtex-js/blob/master/src/bibtex_js.js
--]]

require("lualibs")

local util = require("citeproc.citeproc-util")


local bibtex = {}

bibtex.bib_data = utilities.json.tolua(util.read_file("citeproc/citeproc-bib-data.json"))


function bibtex.parse(contents)
  local items = {}
  for item_contents in string.gmatch(contents, "(@%w+%b{})") do
    local item = bibtex.parse_item(item_contents)
    table.insert(items, item)
  end
  return items
end

function bibtex.parse_item(contents)
  contents = string.gsub(contents, "%s*\r?\n%s*", " ")
  local bib_type, id
  bib_type, id, contents = string.match(contents, "^@(%w+){([^%s,]+),%s*(.*)}$")
  if not id then
    return nil
  end

  local item = {}
  local type_data = bibtex.bib_data.types[bib_type]
  if not type_data then
    return nil
  end
  item.id = id
  item.type = type_data.csl

  local bib_fields = bibtex.parse_fields(contents)
  -- util.debug(bib_fields)

  for bib_field, value in pairs(bib_fields) do
    local csl_field, csl_value = bibtex.convert_field(bib_field, value)

    if bib_field == "year" and item.issued then
      csl_field = nil
    end
    if csl_field and csl_value then
      item[csl_field] = csl_value
    end
  end

  -- Special types and fields
  if item.type == "misc"then
    if bib_fields.url then
      item.type = "webpage"
    end
  end

  if bib_type == "article-journal" and bib_fields.eprint then
    item.type = "article"
  end

  return item
end

function bibtex.parse_fields(contents)
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
            local macro = bibtex.bib_data.macros[string_name]
            if macro then
              value = macro.value
            else
              util.warning(string.format('String name "%s" is undefined', string_name))
            end
          end
        end
        -- TODO: text unescaping
        -- value = bibtex.unescape(value)
        fields[field] = value
        contents = rest
        break
      end
    end
  end
  return fields
end

function bibtex.convert_field(bib_field, value)
  local field_data = bibtex.bib_data.fields[bib_field]
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
  end
  return csl_field, value
end

function bibtex.parse_names(str)
  local names = {}
  for _, name_str in ipairs(util.split(str, "%s+and%s+")) do
    local name = bibtex.parse_single_name(name_str)
    table.insert(names, name)
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

return bibtex
