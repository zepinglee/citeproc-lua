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
  -- TODO: map bib entry type to CSL-JSON type
  item.type = bib_type
  item.id = id

  local field_patterns = {
    "^(%w+)%s*=%s*(%b{}),?%s*(.-)$",
    '^(%w+)%s*=%s*"([^"]*)",?%s*(.-)$',
    "^(%w+)%s*=%s*(%w+),?%s*(.-)$",
  }

  while #contents > 0 do
    local bib_field, value, rest
    -- This pattern may fail in the case of `title = {foo\}bar}`.
    for i, pattern in ipairs(field_patterns) do
      bib_field, value, rest = string.match(contents, pattern)
      if value then
        if i == 1 then
          value = string.sub(value, 2, -2)
        end
        -- TODO: map bib field to CSL-JSON field
        local field = bib_field
        -- TODO: text escaping
        value = bibtex.parse_field(bib_field, value)
        item[field] = value
        contents = rest
        break
      end
    end
    if not value then
      bib_field = string.match(contents, "^%s*%w+")
      error(string.format('Invalid %s in "%s".', bib_field, id))
      return {}
    end
  end

  return item
end

function bibtex.parse_field(bib_field, value)
  local field_data = bibtex.bib_data.fields[bib_field]
  if not field_data then
    return nil
  end
  local field_type = field_data.type
  if field_type == "name" then
    return bibtex.parse_names(value)
  elseif field_type == "date" then
    return bibtex.parse_date(value)
  else
    return value
  end
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
