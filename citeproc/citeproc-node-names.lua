local Element = require("citeproc.citeproc-node-element")
local util = require("citeproc.citeproc-util")


local Name = Element:new()

Name:set_default_options({
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
})

function Name:render (names, context)
  self:debug_info(context)
  context = self:process_context(context)
  local and_ = context["and"]
  local delimiter = context["delimiter"]
  local delimiter_precedes_et_al = context["delimiter-precedes-et-al"]
  local delimiter_precedes_last = context["delimiter-precedes-last"]
  local et_al_min = context["et-al-min"]
  local et_al_use_first = context["et-al-use-first"]
  local et_al_subsequent_min = context["et-al-subsequent-min"]
  local et_al_subsequent_use_first = context["et-al-subsequent-use-first "]
  local et_al_use_last = context["et-al-use-last"]

  local form = context["form"]
  local name_as_sort_order = context["name-as-sort-order"]

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
        output = self:_concat_list({output, context.et_al}, delimiter, context)
        break
      end
    else
      if i > 1 then
        if i == #names and context["and"] then
          if self:_check_delimiter(delimiter_precedes_last, i, inverted) then
            output = self:_concat(output, delimiter, context)
          else
            output = output .. " "
          end
          local and_term = ""
          if context["and"] == "text" then
            and_term = self:get_term("and"):render(context)
          elseif context["and"] == "symbol" then
            and_term = self:get_engine().formatter.text_escape("&")
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

  local ret = string.gsub(output, "(%a)'(%a)", "%1" .. util.unicode["apostrophe"] .. "%2")

  ret = self:wrap(ret, context)
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
  local form = context["form"]
  local initialize = context["initialize"]
  local initialize_with = context["initialize-with"]
  local name_as_sort_order = context["name-as-sort-order"]
  local sort_separator = context["sort-separator"]

  local demote_non_dropping_particle = context["demote-non-dropping-particle"]
  local name_sorting = context.name_sorting

  local family = name["family"] or ""
  local given = name["given"] or ""
  local dp = name["dropping-particle"] or ""
  local ndp = name["non-dropping-particle"] or ""
  local suffix = name["suffix"] or ""

  if family == "" and given == "" then
    if name["literal"] then
      return name["literal"]
    else
      error("Name not avaliable")
    end
  end

  if initialize and initialize_with then
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
      local hyphen_splits = util.split(family, "%-", 1)
      if #hyphen_splits > 1 then
        local particle
        particle, family = table.unpack(hyphen_splits)
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
      order = {family, given}
      inverted = true
    else
      given = util.concat({given, dp}, " ")
      family = util.concat({ndp, family}, " ")
      family, given = self:format_name_parts(family, given, context)
      order = {given, family}
      sort_separator = " "
      if name["comma-suffix"] then
        suffix_separator = ", "
      else
        suffix_separator = " "
      end
    end
    res = self:_concat_list(order, sort_separator, context)
    res = self:_concat_list({res, suffix}, suffix_separator, context)
  elseif form == "short" then
    family = util.concat({ndp, family}, " ")
    family, _ = self:format_name_parts(family, _, context)
    res = family
  else
    error(string.format('Invalid attribute form="%s" of "name".', form))
  end
  return res, inverted
end

function Name:initialize (given, mark, context)
  if not context["initialize-with-hyphen"] then
    given = string.gsub(given, "-", " ")
  end
  given = string.gsub(given, "%.", " ")
  given = util.strip(given)
  local res = ""
  for _, word in ipairs(util.split(given)) do
    local parts = {}
    for _, part in ipairs(util.split(word, "%-")) do
      if part ~= "" then
        local first_letter = utf8.char(utf8.codepoint(part))
        if util.is_upper(first_letter) then
          table.insert(parts, first_letter)
        end
      end
    end
    word = util.concat(parts, util.rstrip(mark) .. "-")
    if word ~= "" then
      res = res .. word .. mark
    end
  end
  res = util.rstrip(res)
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
  local context = self:process_context(context)
  local name = context["name"]

  if name == "family" then
    family = self:case(family, context)
    family = self:wrap(family, context)
    family = self:format(family, context)
  elseif name == "given" then
    given = self:case(given, context)
    given = self:format(given, context)
    given = self:wrap(given, context)
  end
  return family, given
end


local EtAl = Element:new()

EtAl:set_default_options({
  term = "et-al",
})

EtAl.render = function (self, item, context)
  context = self:process_context(context)
  local res = self:get_term(context["term"]):render(context)
  res = self:format(res, context)
  return res
end


local Substitute = Element:new()

function Substitute:render (item, context)
  self:debug_info(context)
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

  local et_al = self:get_child("et-al")
  if et_al == nil then
    et_al = self:create_element("et-al", {}, self)
    EtAl:set_base_class(et_al)
  end
  context.et_al = et_al:render(item, context)

  local name = self:get_child("name")
  if name == nil then
    name = self:create_element("name", {}, self)
    Name:set_base_class(name)
  end

  local label = self:get_child("label")

  local output = {}
  local num_names = 0
  for _, role in ipairs(util.split(context["variable"])) do
    local names = item[role]

    table.insert(context.variable_attempt, names ~= nil)

    if names then
      local res = name:render(names, context)
      if res then
        if type(res) == "number" then  -- name[form="count"]
          num_names = num_names + res
        elseif label then
          local label_result = label:render(item, context)
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
