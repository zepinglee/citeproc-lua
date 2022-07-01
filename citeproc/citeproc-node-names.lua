--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local names_module = {}

local unicode = require("unicode")

local IrNode = require("citeproc-ir-node").IrNode
local NameIr = require("citeproc-ir-node").NameIr
local SeqIr = require("citeproc-ir-node").SeqIr
local Rendered = require("citeproc-ir-node").Rendered
local InlineElement = require("citeproc-output").InlineElement
local PlainText = require("citeproc-output").PlainText

local Element = require("citeproc-element").Element
local util = require("citeproc-util")


local Names = Element:derive("names")
local Name = Element:derive("name", {
  delimiter = ", ",
  delimiter_precedes_et_al = "contextual",
  delimiter_precedes_last = "contextual",
  et_al_use_last = false,
  form = "long",
  initialize = true,
  sort_separator = ", ",
})
local NamePart = Element:derive("name-part")
local EtAl = Element:derive("et-al")
local Substitute = Element:derive("substitute")


-- [Names](https://docs.citationstyles.org/en/stable/specification.html#names)
function Names:new()
  local o = Element.new(self)
  o.name = nil
  o.et_al = nil
  o.substitute = nil
  o.label = nil
  return o
end

function Names:from_node(node)
  local o = Names:new()
  o:set_attribute(node, "variable")
  o.name = nil
  o.et_al = nil
  o.substitute = nil
  o.label = nil
  o.children = {}
  o:process_children_nodes(node)
  for _, child in ipairs(o.children) do
    local element_name = child.element_name
    if element_name == "name" then
      o.name = child
    elseif element_name == "et-al" then
      o.et_al = child
    elseif element_name == "substitute" then
      o.substitute = child
    elseif element_name == "label" then
      o.label = child
      if o.name then
        child.after_name = true
      end
    else
      util.warning(string.format('Unkown element "{}".', element_name))
    end
  end
  o:get_delimiter_attribute(node)
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  return o
end

function Names:build_ir(engine, state, context)
  -- names_inheritance: names and name attributes inherited from cs:style
  --   and cs:citaiton or cs:bibliography
  -- name_override: names, name, et-al, label elements inherited in substitute element
  local names_inheritance = Names:new()
  names_inheritance.delimiter = context.name_inheritance.names_delimiter
  names_inheritance.name = util.clone(context.name_inheritance)
  if state.name_override then
    for key, value in pairs(state.name_override) do
      if key == "name" and not self.name then
        for k, v in pairs(state.name_override.name) do
          names_inheritance.name[k] = util.clone(v)
        end
      else
        names_inheritance[key] = util.clone(value)
      end
    end
  else
    if not self.name then
      self.name = Name:new()
    end
    if not self.et_al then
      self.et_al = EtAl:new()
    end
  end

  for key, value in pairs(self) do
    if key == "name" then
      for k, v in pairs(self.name) do
        names_inheritance.name[k] = util.clone(v)
      end
    else
      names_inheritance[key] = util.clone(value)
    end
  end

  if context.cite and context.cite.position and context.cite.position >= util.position_map["subsequent"] then
    if names_inheritance.name.et_al_subsequent_min then
      names_inheritance.name.et_al_min = names_inheritance.name.et_al_subsequent_min
    end
    if names_inheritance.name.et_al_subsequent_use_first then
      names_inheritance.name.et_al_use_first = names_inheritance.name.et_al_subsequent_use_first
    end
  end

  -- util.debug(names_inheritance)
  -- util.debug(context.reference.id)
  -- util.debug(names_inheritance.variable)
  -- util.debug(names_inheritance.name.form)

  local irs = {}
  local num_names = 0
  -- util.debug(self.name)

  -- The names element may not hold a variable attribute.
  -- substitute_SubstituteOnlyOnceString.txt
  if names_inheritance.variable then
    for _, variable in ipairs(util.split(names_inheritance.variable)) do
      local name_ir = names_inheritance.name:build_ir(variable, names_inheritance.et_al, names_inheritance.label, engine, state, context)
      if name_ir and names_inheritance.name.form == "count" then
        num_names = num_names + name_ir.name_count
      end
      table.insert(irs, name_ir)
    end
  end

  if names_inheritance.name.form == "count" then
    if num_names > 0 then
      local ir = Rendered:new({PlainText:new(tostring(num_names))})
      ir.name_count = num_names
      ir.group_var = "important"
      -- util.debug(ir)
      return ir
    end
  else
    if #irs > 0 then
      local ir = SeqIr:new(irs, self)
      ir.group_var = "important"
      ir.delimiter = names_inheritance.delimiter
      ir.formatting = util.clone(names_inheritance.formatting)
      ir.affixes = util.clone(names_inheritance.affixes)
      ir.display = names_inheritance.display
      return ir
    end
  end

  if self.substitute then
    state.name_override = names_inheritance
    for _, substitute_names in ipairs(self.substitute.children) do
      local ir = substitute_names:build_ir(engine, state, context)
      if ir and ir.group_var ~= "missing" then
        state.name_override = nil
        return ir
      end
    end
    state.name_override = nil
  end

  local ir = Rendered:new()
  ir.group_var = "missing"
  ir.name_count = 0
  return ir

end


function Names:substitute_single_field(result, context)
  if not result then
    return nil
  end
  if context.build.first_rendered_names and #context.build.first_rendered_names == 0 then
    context.build.first_rendered_names[1] = result
  end
  result = self:substitute_names(result, context)
  return result
end

function Names:substitute_names(result, context)
  if not context.build.first_rendered_names then
     return result
  end
  local name_strings = {}
  local match_all

  if #context.build.first_rendered_names > 0 then
    match_all = true
  else
    match_all = false
  end
  for i, text in ipairs(context.build.first_rendered_names) do
    local str = text:render(context.engine.formatter, context)
    name_strings[i] = str
    if context.build.preceding_first_rendered_names and str ~= context.build.preceding_first_rendered_names[i] then
      match_all = false
    end
  end

  if context.build.preceding_first_rendered_names then
    local sub_str = context.options["subsequent-author-substitute"]
    local sub_rule = context.options["subsequent-author-substitute-rule"]

    if sub_rule == "complete-all" then
      if match_all then
        if sub_str == "" then
          result = nil
        else
          result.contents = {sub_str}
        end
      end

    elseif sub_rule == "complete-each" then
      -- In-place substitution
      if match_all then
        for _, text in ipairs(context.build.first_rendered_names) do
          text.contents = {sub_str}
        end
        result = self:concat(context.build.first_rendered_names, context)
      end

    elseif sub_rule == "partial-each" then
      for i, text in ipairs(context.build.first_rendered_names) do
        if name_strings[i] == context.build.preceding_first_rendered_names[i] then
          text.contents = {sub_str}
        else
          break
        end
      end
      result = self:concat(context.build.first_rendered_names, context)

    elseif sub_rule == "partial-first" then
      if name_strings[1] == context.build.preceding_first_rendered_names[1] then
        context.build.first_rendered_names[1].contents = {sub_str}
      end
      result = self:concat(context.build.first_rendered_names, context)
    end
  end

  if #context.build.first_rendered_names > 0 then
    context.build.first_rendered_names = nil
  end
  context.build.preceding_first_rendered_names = name_strings
  return result
end

-- [Name](https://docs.citationstyles.org/en/stable/specification.html#name)
function Name:new()
  local o = Element.new(self, "name")

  o.family = NamePart:new("family")
  o.given = NamePart:new("given")
  return o
end

function Name:from_node(node)
  local o = Name:new()
  o:set_attribute(node, "and")
  o:get_delimiter_attribute(node)
  o:set_attribute(node, "delimiter-precedes-et-al")
  o:set_attribute(node, "delimiter-precedes-last")
  o:set_number_attribute(node, "et-al-min")
  o:set_number_attribute(node, "et-al-use-first")
  o:set_number_attribute(node, "et-al-subsequent-min")
  o:set_number_attribute(node, "et-al-subsequent-use-first")
  o:set_bool_attribute(node, "et-al-use-last")
  o:set_attribute(node, "form")
  o:set_bool_attribute(node, "initialize")
  o:set_attribute(node, "initialize-with")
  o:set_attribute(node, "name-as-sort-order")
  o:set_attribute(node, "sort-separator")
  o:set_affixes_attributes(node)
  o:set_formatting_attributes(node)
  o:process_children_nodes(node)
  for _, child in ipairs(o.children) do
    if child.name == "family" then
      o.family = child
    elseif child.name == "given" then
      o.given = child
    end
  end
  if not o.family then
    o.family = NamePart:new()
    o.family.name = "family"
  end
  if not o.given then
    o.given = NamePart:new()
    o.family.name = "given"
  end
  return o
end


function Name:build_ir(variable, et_al, label, engine, state, context)
  -- Returns NameIR
  local names
  if not state.suppressed[variable] then
    names = context:get_variable(variable)
  end
  if not names then
    return nil
  end

  if context.sort_key then
    self.delimiter = "   "
    self.name_as_sort_order = "all"
    if context.sort_key.names_min then
      self.et_al_min = context.sort_key.names_min
    end
    if context.sort_key.names_use_first then
      self.et_al_use_first = context.sort_key.names_use_first
    end
    if context.sort_key.names_use_last then
      self.et_al_use_last = context.sort_key.names_use_last
    end
    et_al = nil
    label = nil
  end

  local et_al_truncate = self.et_al_min and self.et_al_use_first and #names >= self.et_al_min
  local et_al_last = et_al_truncate and self.et_al_use_last and self.et_al_use_first <= self.et_al_min - 2

  if self.form == "count" then
    local count
    if et_al_truncate then
      count = self.et_al_use_first
    else
      count = #names
    end
    local ir = Rendered:new({PlainText:new(tostring(count))})
    ir.name_count = count
    ir.group_var = "important"
    return ir
  end

  local truncated_names = names
  if et_al_truncate then
    truncated_names = util.slice(names, 1, self.et_al_use_first)
  end

  local inlines = {}

  for i, name in ipairs(truncated_names) do
    if i > 1 then
      if i == #names and self["and"] then
        local inverted = self:check_inverted(names, i-1)
        if self:_check_delimiter(self.delimiter_precedes_last, i, inverted) then
          table.insert(inlines, PlainText:new(self.delimiter))
        else
          table.insert(inlines, PlainText:new(" "))
        end
        local and_term
        if self["and"] == "text" then
          and_term = context.locale:get_simple_term("and")
        elseif self["and"] == "symbol" then
          and_term = "&"
        end
        table.insert(inlines, PlainText:new(and_term .. " "))
      else
        table.insert(inlines, PlainText:new(self.delimiter))
      end
    end
    util.extend(inlines, self:render_person_name(name, i > 1, context))
  end

  if et_al_truncate then
    if et_al_last then
      local punctuation = self.delimiter .. util.unicode["horizontal ellipsis"] .. " "
      table.insert(inlines, PlainText:new(punctuation))
      util.extend(inlines, self:render_person_name(names[#names], self.et_al_use_first > 1, context))
    elseif self.et_al_use_first > 0 and et_al then
      local et_al_inlines = et_al:render_term(context)
      if #et_al_inlines > 0 then
        if self:_check_delimiter(self.delimiter_precedes_et_al, self.et_al_use_first + 1) then
          table.insert(inlines, PlainText:new(self.delimiter))
        else
          table.insert(inlines, PlainText:new(" "))
        end
        util.extend(inlines, et_al:render_term(context))
      end
    end
  end

  if #inlines == 0 then
    -- local ir = Rendered:new()
    -- ir.group_var = "missing"
    -- return ir
    return nil
  end

  local output_format = context.format
  inlines = output_format:with_format(inlines, self.formatting)
  inlines = output_format:affixed(inlines, self.affixes)

  local irs = {Rendered:new(inlines)}

  if label then
    local is_plural = (label.plural == "always" or (label.plural == "contextual" and #names > 1))
    local label_term = context.locale:get_simple_term(variable, label.form, is_plural)
    if label_term and label_term ~= "" then
      local inlines = label:render_text_inlines(label_term, context)
      local label_ir = Rendered:new(inlines)
      if label.after_name then
        table.insert(irs, label_ir)
      else
        table.insert(irs, 1, label_ir)
      end
    end
  end

  local ir = NameIr:new(irs, self)

  -- Suppress substituted name variable
  if state.name_override and not context.sort_key then
    state.suppressed[variable] = true
  end

  -- ir = self:apply_formatting(ir)
  -- ir = self:apply_affixes(ir)
  return ir
end


function Name:render_person_name(name, seen_one, context)
  -- Return: inlines
  local is_latin = util.has_romanesque_char(name.family)
  local is_reversed = (self.name_as_sort_order == "all" or
    (self.name_as_sort_order == "first" and not seen_one) or not is_latin)
  -- TODO
  local is_sort = context.sort_key
  local demote_ndp = (context.style.demote_non_dropping_particle == "display-and-sort" or
    (is_sort and context.style.demote_non_dropping_particle == "sort-only"))

  local name_part_tokens = self:get_display_order(name, self.form, is_latin, is_sort, is_reversed, demote_ndp)
  -- util.debug(name)
  -- util.debug(name_part_tokens)

  local inlines = {}
  for i, token in ipairs(name_part_tokens) do
    if token == "family" or token == "ndp-family" or token == "dp-ndp-family-suffix" then
      local family_inlines = self:render_family(name, token, context)
      util.extend(inlines, family_inlines)

    elseif token == "given" or token == "given-dp" or token == "given-dp-ndp" then
      local given_inlines = self:render_given(name, token, context)
      util.extend(inlines, given_inlines)

    elseif token == "dp-ndp" then
      local particle_inlines = self:render_particle(name, token, context)
      util.extend(inlines, particle_inlines)

    elseif token == "suffix" then
      local text = name.suffix or ""
      util.extend(inlines, InlineElement:parse(text, context))

    elseif token == "literal" then
    local literal_inlines = self.family:format_text_case(name.literal, context)
      util.extend(inlines, literal_inlines)

    elseif token == "space" then
      table.insert(inlines, PlainText:new(" "))

    elseif token == "wide-space" then
      table.insert(inlines, PlainText:new("   "))

    elseif token == "sort-separator" then
      table.insert(inlines, PlainText:new(self.sort_separator))
    end
  end
  -- util.debug(inlines)
  return inlines
end

-- Name-part Order
-- https://docs.citationstyles.org/en/stable/specification.html#name-part-order
function Name:get_display_order(name, form, is_latin, is_sort, is_reversed, demote_ndp)
  if not name.family then
    if name.literal then
      return {"literal"}
    else
      util.error("Invalid name")
    end
  end

  local name_part_tokens = {"family"}

  if not is_latin then
    if form == "long" and name.given then
      return {"family", "given"}
    else
      return {"family"}
    end
  end

  if is_sort then
    if demote_ndp then
      return {"family", "wide-space", "dp-ndp", "wide-space", "given", "wide-space", "suffix"}
    else
      return {"ndp-family", "wide-space", "dp", "wide-space", "given", "wide-space", "suffix"}
    end
  end

  if form == "short" then
    return {"ndp-family"}
  end

  local ndp = name["non-dropping-particle"]
  local dp = name["dropping-particle"]

  if name.given then
    if is_reversed then
      if demote_ndp then
        name_part_tokens = {"family", "sort-separator", "given-dp-ndp"}
      else
        name_part_tokens = {"ndp-family", "sort-separator", "given-dp"}
      end
    else
      name_part_tokens = {"given", "space", "dp-ndp-family-suffix"}
    end
  else
    if is_reversed then
      if demote_ndp then
        if ndp or dp then
          name_part_tokens = {"family", "sort-separator", "dp-ndp"}
        else
          name_part_tokens = {"family"}
        end
      else
        name_part_tokens = {"ndp-family"}
      end
    else
      name_part_tokens = {"dp-ndp-family-suffix"}
    end
  end

  if name.suffix and is_reversed then
    if is_reversed or name["comma-suffix"] then
      table.insert(name_part_tokens, "sort-separator")
      table.insert(name_part_tokens, "suffix")
    elseif string.match(name.suffix, "^%p") then
      table.insert(name_part_tokens, "sort-separator")
      table.insert(name_part_tokens, "suffix")
    else
      table.insert(name_part_tokens, "space")
      table.insert(name_part_tokens, "suffix")
    end
  end

  return name_part_tokens
end

function Name:render_family(name, token, context)
  local inlines = {}
  local name_part

  if token == "dp-ndp-family-suffix" then
    local dp_part = name["dropping-particle"]
    if dp_part then
      name_part = dp_part
      local dp_inlines = self.given:format_text_case(dp_part, context)
      util.extend(inlines, dp_inlines)
    end
  end

  if token == "dp-ndp-family-suffix" or token == "ndp-family" then
    local ndp_part = name["non-dropping-particle"]
    if ndp_part then
      if #inlines > 0 then
        table.insert(inlines, PlainText:new(" "))
      end
      name_part = ndp_part
      local ndp_inlines = self.family:format_text_case(ndp_part, context)
      util.extend(inlines, ndp_inlines)
    end
  end

  local family = name.family
  if context.sort_key then
    -- Remove brackets for sorting: sort_NameVariable.txt
    family = string.gsub(family, "[%[%]]", "")
    -- Remove leading apostrophe: sort_LeadingApostropheOnNameParticle.txt
    family = string.gsub(family, "^'", "")
    family = string.gsub(family, "^’", "")
  end

  local family_inlines = self.family:format_text_case(family, context)
  if #inlines > 0 then
    if not string.match(name_part, "['-]$") and not util.endswith(name_part, "’") then
      table.insert(inlines, PlainText:new(" "))
    end
  end
  util.extend(inlines, family_inlines)

  if token == "dp-ndp-family-suffix" then
    local suffix_part = name.suffix
    if suffix_part then
      if name["comma-suffix"] or util.startswith(suffix_part, "!") then
        -- force use sort-separator exclamation prefix: magic_NameSuffixWithComma.txt
        -- "! Jr." => "Jr."
        table.insert(inlines, PlainText:new(self.sort_separator))
        suffix_part = string.gsub(suffix_part, "^%p%s*", "")
      else
        table.insert(inlines, PlainText:new(" "))
      end
      table.insert(inlines, PlainText:new(suffix_part))
    end
  end

  inlines = self.family:affixed(inlines)
  return inlines
end

function Name:render_given(name, token, context)
  local given = name.given

  if context.sort_key then
    -- The empty given name is needed for evaluate the sort key.
    if not given then
      return {PlainText:new("")}
    end
    -- Remove brackets for sorting: sort_NameVariable.txt
    given = string.gsub(given, "[%[%]]", "")
  end

  if self.initialize_with then
    given = self:initialize_name(given, self.initialize_with, context.style.initialize_with_hyphen)
  end
  local inlines = self.given:format_text_case(given, context)

  if token == "given-dp" or token == "given-dp-ndp" then
    local name_part = name["dropping-particle"]
    if name_part then
      table.insert(inlines, PlainText:new(" "))
      local dp_inlines = self.given:format_text_case(name_part, context)
      util.extend(inlines, dp_inlines)
    end
  end

  if token == "given-dp-ndp" then
    local name_part = name["non-dropping-particle"]
    if name_part then
      table.insert(inlines, PlainText:new(" "))
      local ndp_inlines = self.family:format_text_case(name_part, context)
      util.extend(inlines, ndp_inlines)
    end
  end

  inlines = self.given:affixed(inlines)
  return inlines
end

function Name:render_particle(name, token, context)
  local inlines = {}

  local dp_part = name["dropping-particle"]
  if dp_part then
    local dp_inlines = self.given:format_text_case(dp_part, context)
    util.extend(inlines, dp_inlines)
  end

  local ndp_part = name["non-dropping-particle"]
  if ndp_part then
    if #inlines > 0 then
      table.insert(inlines, PlainText:new(" "))
    end
    local ndp_inlines = self.family:format_text_case(ndp_part, context)
    util.extend(inlines, ndp_inlines)
  end

  return inlines
end

function Name:check_inverted(names, index)
  if index < 1 then
    return false
  end
  if not names[index].family then
    return false
  end
  if self.name_as_sort_order == "all" then
    return true
  elseif self.name_as_sort_order == "first" and index == 1 then
    return true
  else
    return false
  end
end

function Name:_check_delimiter(delimiter_attribute, index, inverted)
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

-- TODO: initialize name with markups
--   name_InTextMarkupInitialize.txt
--   name_InTextMarkupNormalizeInitials.txt
function Name:initialize_name(given, with, initialize_with_hyphen)
  if not given or given == "" then
    return ""
  end

  if initialize_with_hyphen == false then
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
      name_list[i] = name .. with
    else
      if self.initialize then
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
        name_list[i] = name .. with
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


-- [Name-part](https://docs.citationstyles.org/en/stable/specification.html#name-part-formatting)
function NamePart:new(name)
  local o = Element.new(self)
  o.name = name
  return o
end

function NamePart:from_node(node)
  local o = NamePart:new()
  o:set_attribute(node, "name")
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  o:set_affixes_attributes(node)
  return o
end

function NamePart:format_text_case(text, context)
  local output_format = context.format
  local inlines = InlineElement:parse(text, context)
  local is_english = context:is_english()
  if not output_format then
    print(debug.traceback())
  end
  output_format:apply_text_case(inlines, self.text_case, is_english)

  inlines = output_format:with_format(inlines, self.formatting)
  return inlines
end

function NamePart:affixed(inlines)
  if self.affixes then
    if self.affixes.prefix then
      table.insert(inlines, 1, PlainText:new(self.affixes.prefix))
    end
    if self.affixes.suffix then
      table.insert(inlines, PlainText:new(self.affixes.suffix))
    end
  end
  return inlines
end


-- [Et-al](https://docs.citationstyles.org/en/stable/specification.html#et-al)
EtAl.term = "et-al"

function EtAl:from_node(node)
  local o = EtAl:new()
  o:set_attribute(node, "term")
  o:set_formatting_attributes(node)
  return o
end

function EtAl:render_term(context)
  local term = context.locale:get_simple_term(self.term)
  local inlines= InlineElement:parse(term, context)
  inlines = context.format:with_format(inlines, self.formatting)
  return inlines
end

function Substitute:from_node(node)
  local o = Substitute:new()
  o:process_children_nodes(node)
  return o
end


names_module.Names = Names
names_module.Name = Name
names_module.NamePart = NamePart
names_module.EtAl = EtAl
names_module.Substitute = Substitute

return names_module
