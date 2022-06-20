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

local richtext = require("citeproc-richtext")
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
  if not o.name then
    o.name = Name:new()
  end
  if not o.et_al then
    o.et_al = EtAl:new()
  end

  o:get_delimiter_attribute(node)
  o:set_affixes_attributes(node)
  o:set_display_attribute(node)
  o:set_formatting_attributes(node)
  o:set_text_case_attribute(node)
  return o
end

function Names:build_ir(engine, state, context)
  -- local names_inheritance = state.name_override.inherited_names_options(context.names_inheritance, self)
  local names_inheritance = Names:new()
  names_inheritance.delimiter = context.name_inheritance.names_delimiter
  for key, value in pairs(self) do
    names_inheritance[key] = value
  end
  names_inheritance.name = util.clone(context.name_inheritance)
  for key, value in pairs(self.name) do
    names_inheritance.name[key] = value
  end

  local irs = {}
  local num_names = 0
  -- util.debug(self.name)
  for _, variable in ipairs(util.split(self.variable)) do
    local name_ir = names_inheritance.name:build_ir(variable, self.et_al, self.label, engine, state, context)
    if type(name_ir) == "number" then
      num_names = num_names + name_ir
    end
    table.insert(irs, name_ir)
  end

  if names_inheritance.name.form == "count" then
    return Rendered:new({PlainText:new(tostring(num_names))})
  end

  local ir = SeqIr:new(irs, self)
  if #irs == 0 then
    ir.group_var = "missing"
    return
  end

  ir.group_var = "important"

  ir.delimiter = names_inheritance.delimiter
  ir.formatting = util.clone(names_inheritance.formatting)
  ir.affixes = util.clone(names_inheritance.affixes)
  ir.display = names_inheritance.display
  return ir
end


function Names:render (item, context)
  self:debug_info(context)
  context = self:process_context(context)

  local names_delimiter = context.options["names-delimiter"]
  if names_delimiter then
    context.options["delimiter"] = names_delimiter
  end

  -- Inherit attributes of parent `names` element
  local names_element = context.names_element
  if names_element then
    for key, value in pairs(names_element._attr) do
      context.options[key] = value
    end
    for key, value in pairs(self._attr) do
      context.options[key] = value
    end
  else
    context.names_element = self
    context.variable = context.options["variable"]
  end

  local name, et_al, label
  -- The position of cs:label relative to cs:name determines the order of
  -- the name and label in the rendered text.
  local label_position = nil
  for _, child in ipairs(self:get_children()) do
    if child:is_element() then
      local element_name = child:get_element_name()
      if element_name == "name" then
        name = child
        if label then
          label_position = "before"
        end
      elseif element_name == "et-al" then
        et_al = child
      elseif element_name == "label" then
        label = child
        if name then
          label_position = "after"
        end
      end
    end
  end
  if label_position then
    context.label_position = label_position
  else
    label_position = context.label_position or "after"
  end

  -- local name = self:get_child("name")
  if not name then
    name = context.name_element
  end
  if not name then
    name = self:create_element("name", {}, self)
    Name:set_base_class(name)
  end
  context.name_element = name

  -- local et_al = self:get_child("et-al")
  if not et_al then
    et_al = context.et_al
  end
  if not et_al then
    et_al = self:create_element("et-al", {}, self)
    EtAl:set_base_class(et_al)
  end
  context.et_al = et_al

  -- local label = self:get_child("label")
  if label then
    context.label = label
  else
    label = context.label
  end

  local sub_str = nil
  if context.mode == "bibliography" and not context.sorting then
    sub_str = context.options["subsequent-author-substitute"]
  --   if sub_str and #context.build.preceding_first_rendered_names == 0 then
  --     context.rendered_names = {}
  --   else
  --     sub_str = nil
  --     context.rendered_names = nil
  --   end
  end

  local variable_names = context.options["variable"] or context.variable
  local ret = nil

  if variable_names then
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
          elseif label and not context.sorting then
            -- drop name label in sorting
            local label_result = label:render(role, context)
            if label_result then
              if label_position == "before" then
                res = richtext.concat(label_result, res)
              else
                res = richtext.concat(res, label_result)
              end
            end
          end
        end
        table.insert(output, res)
      end
    end

    if num_names > 0 then
      ret = tostring(num_names)
    else
      ret = self:concat(output, context)
      if ret and sub_str and context.build.first_rendered_names then
        ret = self:substitute_names(ret, context)
      end
    end
  end

  if ret then
    ret = self:_apply_format(ret, context)
    ret = self:_apply_affixes(ret, context)
    ret = self:_apply_display(ret, context)
    return ret
  else
    local substitute = self:get_child("substitute")
    if substitute then
      ret = substitute:render(item, context)
    end
    if ret and sub_str then
      ret = self:substitute_single_field(ret, context)
    end
    return ret
  end
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
  local names = context:get_variable(variable)
  if not names then
    return nil
  end

  local et_al_truncate = self.et_al_min and self.et_al_use_first and #names >= self.et_al_min
  local et_al_last = et_al_truncate and self.et_al_use_last and self.et_al_use_first <= self.et_al_min - 2

  if self.form == "count" then
    if et_al_truncate then
      return self.et_al_use_first
    else
      return #names
    end
  end

  local irs = {}

  for i, name in ipairs(names) do
    if et_al_truncate and i > self.et_al_use_first then
      if et_al_last then
        if i == #names then
          local punctuation = self.delimiter .. util.unicode["horizontal ellipsis"] .. " "
          table.insert(irs, Rendered:new({PlainText:new(punctuation)}))
          local inlines = self:render_person_name(name, i > 1, context)
          table.insert(irs, Rendered:new(inlines, self))
        end
      else
        if self:_check_delimiter(self.delimiter_precedes_et_al, i) then
          table.insert(irs, Rendered:new({PlainText:new(self.delimiter)}))
        else
          table.insert(irs, Rendered:new({PlainText:new(" ")}))
        end
        table.insert(irs, et_al:build_ir(engine, state, context))
      end
      break
    end
    if i > 1 then
      if i == #names and self["and"] then
        if self:_check_delimiter(self.delimiter_precedes_last, i) then
          table.insert(irs, Rendered:new({PlainText:new(self.delimiter)}))
        else
          table.insert(irs, Rendered:new({PlainText:new(" ")}))
        end
        local and_term
        if self["and"] == "text" then
          and_term = context.locale:get_simple_term("and")
        elseif self["and"] == "symbol" then
          and_term = "&"
        end
        table.insert(irs, Rendered:new({PlainText:new(and_term .. " ")}))
      else
        table.insert(irs, Rendered:new({PlainText:new(self.delimiter)}))
      end
    end
    local inlines = self:render_person_name(name, i > 1, context)
    local rendered = Rendered:new(inlines, self)
    -- util.debug(rendered)
    table.insert(irs, rendered)
  end

  local ir = NameIr:new(irs, self)

  -- ir = self:apply_formatting(ir)
  -- ir = self:apply_affixes(ir)
  return ir
end


function Name:render_person_name(person_name, seen_one, context)
  -- Return: inlines
  local is_romanesque = util.has_romanesque_char(person_name.family)
  local is_reversed = (self.name_as_sort_order == "all" or
    (self.name_as_sort_order == "first" and not seen_one) or not is_romanesque)
  local demote_ndp = context.style.demote_non_dropping_particle

  local name_part_tokens = self:get_display_order(person_name, seen_one)
  local inlines = {}
  for i, name_part_token in ipairs(name_part_tokens) do
    if name_part_token == "family" then
      local text = person_name.family
      if person_name["non-dropping-particle"] and is_romanesque and not (is_reversed and demote_ndp) then
        text = person_name["non-dropping-particle"] .. " " .. text
      end
      for _, inline in ipairs(InlineElement:parse(text)) do
        table.insert(inlines, inline)
      end
    elseif name_part_token == "given" then
      local text = person_name.given
      if self.initialize_with then
        text = self:initialize_name(text, self.initialize_with, context.style.initialize_with_hyphen)
      end
      if person_name["dropping-particle"] then
        text = text .. " " .. person_name["dropping-particle"]
      end
      if person_name["non-dropping-particle"] and is_romanesque and (is_reversed and demote_ndp) then
        text = text .. " " .. person_name["non-dropping-particle"]
      end
      for _, inline in ipairs(InlineElement:parse(text)) do
        table.insert(inlines, inline)
      end
    elseif name_part_token == "suffix" then
      for _, inline in ipairs(InlineElement:parse(person_name.suffix)) do
        table.insert(inlines, inline)
      end
    elseif name_part_token == "literal" then
      for _, inline in ipairs(InlineElement:parse(person_name.literal)) do
        table.insert(inlines, inline)
      end
    elseif name_part_token == "space" then
      table.insert(inlines, PlainText:new(" "))
    elseif name_part_token == "sort-separator" then
      table.insert(inlines, PlainText:new(self.sort_separator))
    end
  end
  -- util.debug(inlines)
  return inlines
end

function Name:get_display_order(person_name, seen_one)
  if not person_name.family and not person_name.given then
    if person_name.literal then
      return {"literal"}
    else
      util.error("Invalid name")
    end
  end
  if not person_name.family then
    -- name_OnlyGivenname.txt
    person_name.family = person_name.given
    person_name.given = nil
    return {"family"}
  end

  local name_part_tokens = {"family"}

  if self.form == "short" then
    return name_part_tokens
  end

  -- TODO: use is_romanesque
  local is_romanesque = util.has_romanesque_char(person_name.family)
  local is_reversed = (self.name_as_sort_order == "all" or
    (self.name_as_sort_order == "first" and not seen_one) or not is_romanesque)

  if person_name.given then
    if is_reversed then
      if is_romanesque then
        name_part_tokens = {"family", "sort-separator", "given"}
      else
        name_part_tokens = {"family", "given"}
      end
    else
      name_part_tokens = {"given", "space", "family"}
    end
  end

  if person_name.suffix then
    if is_reversed or person_name["comma-suffix"] then
      table.insert(name_part_tokens, "sort-separator")
      table.insert(name_part_tokens, "suffix")
    else
      table.insert(name_part_tokens, "space")
      table.insert(name_part_tokens, "suffix")
    end
  end

  return name_part_tokens
end

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

  -- sorting
  if context.options["names-min"] then
    et_al_min = context.options["names-min"]
  end
  if context.options["names-use-first"] then
    et_al_use_first = context.options["names-use-first"]
  end
  if context.options["names-use-last"] ~= nil then
    et_al_use_last = context.options["names-use-last"]
  end

  local form = context.options["form"]

  local et_al_truncate = et_al_min and et_al_use_first and #names >= et_al_min
  local et_al_last = et_al_use_last and et_al_use_first <= et_al_min - 2

  if form == "count" then
    if et_al_truncate then
      return et_al_use_first
    else
      return #names
    end
  end

  local output = nil

  local res = nil
  local inverted = false

  for i, name in ipairs(names) do
    if et_al_truncate and i > et_al_use_first then
      if et_al_last then
        if i == #names then
          output = richtext.concat(output, delimiter)
          output = output .. util.unicode["horizontal ellipsis"]
          output = output .. " "
          res = self:render_single_name(name, i, context)
          output = output .. res
        end
      else
        if not self:_check_delimiter(delimiter_precedes_et_al, i, inverted) then
          delimiter = " "
        end
        if output then
          output = richtext.concat_list({output, context.et_al:render(context)}, delimiter)
        end
        break
      end
    else
      if i > 1 then
        if i == #names and context.options["and"] then
          if self:_check_delimiter(delimiter_precedes_last, i, inverted) then
            output = richtext.concat(output, delimiter)
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
          output = richtext.concat(output, delimiter)
        end
      end
      res, inverted = self:render_single_name(name, i, context)

      if res and res ~= "" then
        res = richtext.new(res)
        if context.build.first_rendered_names then
          table.insert(context.build.first_rendered_names, res)
        end

        if output then
          output = richtext.concat(output, res)
        else
          output = res
        end
      end
    end
  end

  local ret = self:_apply_format(output, context)
  ret = self:_apply_affixes(ret, context)
  return ret
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
    inverted = self.name_as_sort_order == "all" or (self.name_as_sort_order == "first" and index == 2)
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
  if context.sorting then
    name_as_sort_order = "all"
  end
  local sort_separator = context.options["sort-separator"]

  local demote_non_dropping_particle = context.options["demote-non-dropping-particle"]

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
      given = ""
    end
    if family ~= "" then
      return family
    else
      error("Name not avaliable")
    end
  end

  if initialize_with then
    given = self:initialize_name(given, initialize_with, context)
  end

  local demote_ndp = false  -- only active when form == "long"
  if demote_non_dropping_particle == "display-and-sort" or
  demote_non_dropping_particle == "sort-only" and context.sorting then
    demote_ndp = true
  else  -- demote_non_dropping_particle == "never"
    demote_ndp = false
  end

  local family_name_part = nil
  local given_name_part = nil
  for _, child in ipairs(self:get_children()) do
    if child:is_element() and child:get_element_name() == "name-part" then
      local name_part = child:get_attribute("name")
      if name_part == "family" then
        family_name_part = child
      elseif name_part == "given" then
        given_name_part = child
      end
    end
  end

  local res = nil
  local inverted = false
  if form == "long" then
    local order
    local suffix_separator = sort_separator
    if not util.has_romanesque_char(name["family"]) then
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
        ndp = richtext.concat(ndp, particle)
      end

      if family_name_part then
        family = family_name_part:format_name_part(family, context)
        ndp = family_name_part:format_name_part(ndp, context)
      end
      if given_name_part then
        given = given_name_part:format_name_part(given, context)
        dp = family_name_part:format_name_part(dp, context)
      end

      if demote_ndp then
        given = richtext.concat_list({given, dp, ndp}, " ")
      else
        family = richtext.concat_list({ndp, family}, " ")
        given = richtext.concat_list({given, dp}, " ")
      end

      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
      if given_name_part then
        given = given_name_part:wrap_name_part(given, context)
      end

      order = {family, given, suffix}
      inverted = true
    else
      if family_name_part then
        family = family_name_part:format_name_part(family, context)
        ndp = family_name_part:format_name_part(ndp, context)
      end
      if given_name_part then
        given = given_name_part:format_name_part(given, context)
        dp = family_name_part:format_name_part(dp, context)
      end

      family = richtext.concat_list({dp, ndp, family}, " ")
      if name["comma-suffix"] then
        suffix_separator = ", "
      else
        suffix_separator = " "
      end
      family = richtext.concat_list({family, suffix}, suffix_separator)

      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
      if given_name_part then
        given = given_name_part:wrap_name_part(given, context)
      end

      order = {given, family}
      sort_separator = " "
    end
    res = richtext.concat_list(order, sort_separator)

  elseif form == "short" then
    if family_name_part then
      family = family_name_part:format_name_part(family, context)
      ndp = family_name_part:format_name_part(ndp, context)
    end
    family = util.concat({ndp, family}, " ")
      if family_name_part then
        family = family_name_part:wrap_name_part(family, context)
      end
    res = family
  else
    error(string.format('Invalid attribute form="%s" of "name".', form))
  end
  return res, inverted
end

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
  o:set_affixes_attributes(node)
  o:set_text_case_attribute(node)
  return o
end

function NamePart:format_name_part(name_part, context)
  context = self:process_context(context)
  local res = self:_apply_case(name_part, context)
  res = self:_apply_format(res, context)
  return res
end

function NamePart:wrap_name_part(name_part, context)
  context = self:process_context(context)
  local res = self:_apply_affixes(name_part, context)
  return res
end


-- [Et-al](https://docs.citationstyles.org/en/stable/specification.html#et-al)
EtAl.term = "et-al"

function EtAl:from_node(node)
  local o = EtAl:new()
  o:set_attribute(node, "term")
  o:set_formatting_attributes(node)
  return o
end

function EtAl:build_ir(engine, state, context)
  local term = context.locale:get_simple_term(self.term)
  local ir = Rendered:new({PlainText:new(term)})
  ir.formatting = util.clone(self.formatting)
  return ir
end


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


names_module.Names = Names
names_module.Name = Name
names_module.NamePart = NamePart
names_module.EtAl = EtAl
names_module.Substitute = Substitute

return names_module
