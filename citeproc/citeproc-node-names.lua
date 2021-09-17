local unicode = require("unicode")

local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Name = Element:new()

Name.default_options = {
  ["delimiter"] = ", ",
  ["delimiter-precedes-et-al"] = "contextual",
  ["delimiter-precedes-last"] = "contextual",
  ["et-al-min"] = 0,
  ["et-al-use-first"] = 0,
  ["et-al-subsequent-min"] = 0,
  ["et-al-subsequent-use-first "] = 0,
  ["et-al-use-last"] = false,
  ["form"] = "long",
  ["initialize"] = true,
  ["initialize-with"] = false,
  ["name-as-sort-order"] = false,
  ["sort-separator"] = ", ",
  ["prefix"] = "",
  ["suffix"] = "",
}

function Name:render (names, context)
  self:debug_info(context)
  context = self:process_context(context)

  local and_ = context.options["and"]
  local delimiter = context.options["delimiter"]
  local delimiter_precedes_et_al = context.options["delimiter-precedes-et-al"]
  local delimiter_precedes_last = context.options["delimiter-precedes-last"]
  local et_al_min = context.options["et-al-min"]
  local et_al_use_first = context.options["et-al-use-first"]
  local et_al_subsequent_min = context.options["et-al-subsequent-min"]
  local et_al_subsequent_use_first = context.options["et-al-subsequent-use-first "]
  local et_al_use_last = context.options["et-al-use-last"]

  local form = context.options["form"]
  local name_as_sort_order = context.options["name-as-sort-order"]

  local et_al_truncate = et_al_min > 0 and et_al_use_first > 0 and #names >= et_al_min
  local et_al_last = et_al_use_last and et_al_use_first <= et_al_min - 2

  if form == "count" then
    if et_al_truncate then
      return et_al_use_first
    else
      return #names
    end
  end

  local output = ""

  local res = nil
  local inverted = false

  for i, name in ipairs(names) do
    if et_al_truncate and i > et_al_use_first then
      if et_al_last then
        if i == #names then
          output = self:_concat(output, delimiter, context)
          output = output .. util.unicode["horizontal ellipsis"]
          if delimiter_precedes_last == "never" then
            output = output .. " "
          else
            output = self:_concat(output, delimiter, context)
          end
          res = self:render_single_name(name, i, context)
          output = output .. res
        end
      else
        if not self:_check_delimiter(delimiter_precedes_et_al, i, inverted) then
          delimiter = " "
        end
        output = self:_concat_list({output, context.et_al:render(context)}, delimiter, context)
        break
      end
    else
      if i > 1 then
        if i == #names and context.options["and"] then
          if self:_check_delimiter(delimiter_precedes_last, i, inverted) then
            output = self:_concat(output, delimiter, context)
          else
            output = output .. " "
          end
          local and_term = ""
          if context.options["and"] == "text" then
            and_term = self:get_term("and"):render(context)
          elseif context.options["and"] == "symbol" then
            and_term = self:escape("&")
          end
          output = output .. and_term .. " "
        else
          output = self:_concat(output, delimiter, context)
        end
      end
      res, inverted = self:render_single_name(name, i, context)
      if res and res ~= "" then
        output = output .. res
      end
    end
  end

  local ret = self:wrap(output, context)
  ret = self:format(ret, context)
  return ret
end

function Name:_check_delimiter (delimiter_attribute, index, inverted)
  -- `delimiter-precedes-et-al` and `delimiter-precedes-last`
  if delimiter_attribute == "always" then
    return true
  elseif delimiter_attribute == "never" then
    return false
  elseif delimiter_attribute == "contextual" then
    if index > 2 then
      return true
    else
      return false
    end
  elseif delimiter_attribute == "after-inverted-name" then
    if inverted then
      return true
    else
      return false
    end
  end
  return false
end

function Name:render_single_name (name, index, context)
  local form = context.options["form"]
  local initialize = context.options["initialize"]
  local initialize_with = context.options["initialize-with"]
  local name_as_sort_order = context.options["name-as-sort-order"]
  local sort_separator = context.options["sort-separator"]

  local demote_non_dropping_particle = context.options["demote-non-dropping-particle"]
  local name_sorting = context.name_sorting

  -- TODO: make it a module
  local function _strip_quotes(str)
    if str then
      str = string.gsub(str, '"', "")
      str = string.gsub(str, "'", util.unicode["apostrophe"])
    end
    return str
  end

  local family = _strip_quotes(name["family"]) or ""
  local given = _strip_quotes(name["given"]) or ""
  local dp = _strip_quotes(name["dropping-particle"]) or ""
  local ndp = _strip_quotes(name["non-dropping-particle"]) or ""
  local suffix = _strip_quotes(name["suffix"]) or ""
  local literal = _strip_quotes(name["literal"]) or ""

  if family == "" then
    family = literal
    if family == "" then
      family = given
    end
    if family ~= "" then
      family, _ = self:format_name_parts(family, nil, context)
      return family
    else
      error("Name not avaliable")
    end
  end

  if initialize_with then
    given = self:initialize(given, initialize_with, context)
  end

  local demote_ndp = false  -- only active when form == "long"
  if demote_non_dropping_particle == "display-and-sort" or
  demote_non_dropping_particle == "sort-only" and name_sorting then
    demote_ndp = true
  else  -- demote_non_dropping_particle == "never"
    demote_ndp = false
  end

  local res = nil
  local inverted = false
  if form == "long" then
    local order
    local suffix_separator = sort_separator
    if not util.is_romanesque(name["family"]) then
      order = {family, given}
      inverted = true
      sort_separator = ""
    elseif name_as_sort_order == "all" or (name_as_sort_order == "first" and index == 1) then

      -- "Alan al-One"
      local hyphen_parts = util.split(family, "%-", 1)
      if #hyphen_parts > 1 then
        local particle
        particle, family = table.unpack(hyphen_parts)
        particle = particle .. "-"
        ndp = self._concat(ndp, particle)
      end

      if demote_ndp then
        given = util.concat({given, dp, ndp}, " ")
      else
        family = util.concat({ndp, family}, " ")
        given = util.concat({given, dp}, " ")
      end
      family, given = self:format_name_parts(family, given, context)
      order = {family, given, suffix}
      inverted = true
    else
      family = util.concat({dp, ndp, family}, " ")
      if name["comma-suffix"] then
        suffix_separator = ", "
      else
        suffix_separator = " "
      end
      family = self:_concat_list({family, suffix}, suffix_separator, context)
      family, given = self:format_name_parts(family, given, context)
      order = {given, family}
      sort_separator = " "
    end
    res = self:_concat_list(order, sort_separator, context)
  elseif form == "short" then
    family = util.concat({ndp, family}, " ")
    family, _ = self:format_name_parts(family, _, context)
    res = family
  else
    error(string.format('Invalid attribute form="%s" of "name".', form))
  end
  return res, inverted
end

function Name:initialize (given, terminator, context)
  if not given or given == "" then
    return ""
  end

  local initialize = context.options["initialize"]
  if context.options["initialize-with-hyphen"] == false then
    given = string.gsub(given, "-", " ")
  end

  -- Split the given name to name_list (e.g., {"John", "M." "E"})
  -- Compound names are splitted too but are marked in punc_list.
  local name_list = {}
  local punct_list = {}
  local last_position = 1
  for name, pos in string.gmatch(given, "([^-.%s]+[-.%s]+)()") do
    table.insert(name_list, string.match(name, "^[^-%s]+"))
    if string.match(name, "%-") then
      table.insert(punct_list, "-")
    else
      table.insert(punct_list, "")
    end
    last_position = pos
  end
  if last_position <= #given then
    table.insert(name_list, util.strip(string.sub(given, last_position)))
    table.insert(punct_list, "")
  end

  for i, name in ipairs(name_list) do
    local is_particle = false
    local is_abbreviation = false

    local first_letter = utf8.char(utf8.codepoint(name))
    if util.is_lower(first_letter) then
        is_particle = true
    elseif #name == 1 then
      is_abbreviation = true
    else
      local abbreviation = string.match(name, "^([^.]+)%.$")
      if abbreviation then
        is_abbreviation = true
        name = abbreviation
      end
    end

    if is_particle then
      name_list[i] = name .. " "
      if i > 1 and not string.match(name_list[i-1], "%s$") then
        name_list[i-1] = name_list[i-1] .. " "
      end
    elseif is_abbreviation then
      name_list[i] = name .. terminator
    else
      if initialize then
        if util.is_upper(name) then
          name = first_letter
        else
          -- Long abbreviation: "TSerendorjiin" -> "Ts."
          local abbreviation = ""
          for _, c in utf8.codes(name) do
            local char = utf8.char(c)
            local lower = unicode.utf8.lower(char)
            if lower == char then
              break
            end
            if abbreviation == "" then
              abbreviation = char
            else
              abbreviation = abbreviation .. lower
            end
          end
          name = abbreviation
        end
        name_list[i] = name .. terminator
      else
        name_list[i] = name .. " "
      end
    end

    -- Handle the compound names
    if i > 1 and punct_list[i-1] == "-" then
      if is_particle then  -- special case "Guo-ping"
        name_list[i] = ""
      else
        name_list[i-1] = util.rstrip(name_list[i-1])
        name_list[i] = "-" .. name_list[i]
      end
    end
  end

  local res = util.concat(name_list, "")
  res = util.strip(res)
  return res

end

function Name:format_name_parts (family, given, context)
  for _, child in ipairs(self:get_children()) do
    if child:is_element() and child:get_element_name() == "name-part" then
      family, given = child:format_parts(family, given, context)
    end
  end
  return family, given
end

local NamePart = Element:new()

NamePart.format_parts = function (self, family, given, context)
  context = self:process_context(context)
  local name = context.options["name"]

  if name == "family" and family then
    family = self:case(family, context)
    family = self:wrap(family, context)
    family = self:format(family, context)
  elseif name == "given" and given then
    given = self:case(given, context)
    given = self:format(given, context)
    given = self:wrap(given, context)
  end
  return family, given
end


local EtAl = Element:new()

EtAl.default_options = {
  term = "et-al",
}

EtAl.render = function (self, context)
  self:debug_info(context)
  context = self:process_context(context)
  local res = self:get_term(context.options["term"]):render(context)
  res = self:format(res, context)
  return res
end


local Substitute = Element:new()

function Substitute:render (item, context)
  self:debug_info(context)

  if context.suppressed_variables then
    -- true in layout, not in sort
    context.suppress_subsequent_variables = true
  end

  for i, child in ipairs(self:get_children()) do
    if child:is_element() then
      local result = child:render(item, context)
      if result and result ~= "" then
        return result
      end
    end
  end
  return nil
end


local Names = Element:new()

function Names:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local names_delimiter = context.options["names-delimiter"]
  if names_delimiter then
    context.options["delimiter"] = names_delimiter
  end

  -- Inherit attributes of parent `names` element
  local names = context.names_element
  if names then
    for key, value in pairs(names._attr) do
      context.options[key] = value
    end
    for key, value in pairs(self._attr) do
      context.options[key] = value
    end
  else
    context.names_element = self
    context.variable = context.options["variable"]
  end
  local variable_names = context.options["variable"] or context.variable

  local name = self:get_child("name")
  if not name then
    name = context.name_element
  end
  if not name then
    name = self:create_element("name", {}, self)
    Name:set_base_class(name)
  end
  context.name_element = name

  local et_al = self:get_child("et-al")
  if not et_al then
    et_al = context.et_al
  end
  if not et_al then
    et_al = self:create_element("et-al", {}, self)
    EtAl:set_base_class(et_al)
  end
  context.et_al = et_al

  local label = self:get_child("label")
  if label then
    context.label = label
  else
    label = context.label
  end

  local output = {}
  local num_names = 0
  for _, role in ipairs(util.split(variable_names)) do
    local names = self:get_variable(item, role, context)

    table.insert(context.variable_attempt, names ~= nil)

    if names then
      local res = name:render(names, context)
      if res then
        if type(res) == "number" then  -- name[form="count"]
          num_names = num_names + res
        elseif label then
          local label_result = label:render(role, context)
          if label_result then
            res = res .. label_result
          end
        end
      end
      table.insert(output, res)
    end
  end

  local ret = nil
  if num_names > 0 then
    ret = num_names
  else
    ret = self:concat(output, context)
  end

  table.insert(context.rendered_quoted_text, false)

  if ret then
    ret = self:format(ret, context)
    ret = self:wrap(ret, context)
    return ret
  else
    local substitute = self:get_child("substitute")
    if substitute then
      return substitute:render(item, context)
    else
      return nil
    end
  end
end



return {
  names = Names,
  name = Name,
  ["name-part"] = NamePart,
  ["et-al"] = EtAl,
  substitute = Substitute,
}
