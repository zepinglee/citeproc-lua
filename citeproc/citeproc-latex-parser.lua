--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local latex_parser = {}

local lpeg = require("lpeg")
local latex_data = require("citeproc-latex-data")
local markup = require("citeproc-output")
local util = require("citeproc-util")


-- Convert LaTeX string to Unicode string
function latex_parser.latex_to_unicode(str)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_ast_to_unicode(ast)
  local res = latex_parser.to_string(ast)
  return res
end


-- Convert LaTeX string to InlineElements
function latex_parser.latex_to_inlines(str, strict, case_protection)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_ast_to_unicode(ast)
  local inlines = latex_parser.convert_tokens_to_inlines(ast, strict, case_protection)
  return inlines
end


-- Convert LaTeX string to string with HTML-like tags
function latex_parser.latex_to_pseudo_html(str, strict, case_protection)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_ast_to_unicode(ast)
  local inlines = latex_parser.convert_tokens_to_inlines(ast, strict, case_protection)
  -- util.debug(inlines)
  local pseudo_html_format = markup.PseudoHtml:new()
  local res = pseudo_html_format:write_inlines(inlines, {})
  return res
end


-- strict: preserve unkown LaTeX commands
-- case_protection: BibTEX case protection with curly braces


---comment
---@param str string
---@param keep_unknown_commands boolean?
---@param case_protection boolean?
---@param check_sentence_case boolean?
---@return string
function latex_parser.latex_to_sentence_case_pseudo_html(str, keep_unknown_commands, case_protection, check_sentence_case)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_ast_to_unicode(ast)
  local inlines = latex_parser.convert_tokens_to_inlines(ast, keep_unknown_commands, case_protection)
  local pseudo_html_format = markup.PseudoHtml:new()
  pseudo_html_format:convert_sentence_case(inlines, check_sentence_case)
  local res = pseudo_html_format:write_inlines(inlines, {})
  return res
end


-- Convert LaTeX string to CSL rich-text
function latex_parser.latex_to_rich_text(str)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_ast_to_unicode(ast)
  local res = latex_parser.convert_ast_to_rich_text(ast)
  return res
end


function latex_parser.get_latex_grammar()
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

  local space = S(" \t\r\n")^0
  local specials = P"~" / util.unicode["no-break space"]
                  --  + P"\\$" / "$"
                  --  + P"\\%" / "%"
                  --  + P"\\&" / "&"
                  --  + P"\\#" / "#"
                  --  + P"\\_" / "_"
                  --  + P"\\{" / "{"
                  --  + P"\\}" / "}"
  local control_sequence = C(P"\\" * (R("AZ", "az")^1 * space + (1 - R("AZ", "az")))) / function (cs)
    return {
      type = "control_sequence",
      name = util.rstrip(cs),
      raw = cs,
    }
  end
  local math = P"$" * C((P"\\$" + 1 - S"$")^0) * P"$" / function (math_text)
    return {
      type = "math",
      text = math_text,
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


latex_parser.latex_grammar = latex_parser.get_latex_grammar()


local format_commands_with_argment = {
  ["\\textbf"] = "bold",
  ["\\textit"] = "italic",
  ["\\textsl"] = "italic",
  ["\\emph"] = "italic",
  ["\\enquote"] = "quote",
  ["\\textsc"] = "sc",
  ["\\sout"] = "strike",  -- from ulem package
  ["\\st"] = "strike", -- from soul package
  ["\\textsuperscript"] = "sup",
  ["\\textsubscript"] = "sub",
}

local format_commands_without_argment = {
  ["\\bf"] = "bold",
  ["\\bfseries"] = "bold",
  ["\\it"] = "italic",
  ["\\itshape"] = "italic",
  ["\\sl"] = "italic",
  ["\\slshape"] = "italic",
  ["\\em"] = "italic",
  ["\\scshape"] = "sc",
  ["\\sc"] = "sc",
}



function latex_parser.to_string(ast)
  local res = ""
  for i, token in ipairs(ast) do
    if type(token) == "string" then
      res = res .. token
    elseif type(token) == "table" then
      if token.type == "control_sequence" then
        res = res .. token.raw
      elseif token.type == "math" then
        res = res .. token.text
      elseif token.type == "group" then
        res = res .. "{" .. latex_parser.to_string(token.contents) .. "}"
      end
    end
  end
  return res
end


local function _remove_braces_of_diacritic(tokens, i, orig_first_token)
  -- Remove braces in "{\'A}"
  local token = tokens[i]
  if #token.contents == 1 then
    local first_token = token.contents[1]
    local prev_token = tokens[i - 1]
    if orig_first_token and type(orig_first_token) == "table"
        and orig_first_token.type == "control_sequence"
        and not (type(prev_token) == "table" and prev_token.type == "control_sequence")
        and type(first_token) == "string" then
      tokens[i] = first_token
    end
  end
end

local function _replace_diacritic_with_unicode(tokens, i, code_point)
  local unicode_char
  if type(code_point) == "string" then
    unicode_char = utf8.char(tonumber(code_point, 16))
    tokens[i] = unicode_char

  elseif type(code_point) == "table" then
    -- The command takes an argument (\"{o})
    local arg
    local j = i + 1
    while j <= #tokens and tokens[j] == " " do
      j = j + 1
    end
    if j <= #tokens then
      local next_token = tokens[j]
      if type(next_token) == "string" then
        arg = next_token
      elseif type(next_token) == "table" then
        if next_token.type == "control_sequence" then
          arg = next_token.name
        elseif next_token.type == "group" then
          if #next_token.contents == 0 then
            arg = "{}"
          elseif #next_token.contents == 1 then
            next_token = next_token.contents[1]
            if type(next_token) == "string" then
              arg = next_token
            elseif type(next_token) == "table" then
              arg = next_token.name
            end
          end
        end
      end
    end
    if arg and code_point[arg] then
      unicode_char = utf8.char(tonumber(code_point[arg], 16))
      tokens[i] = unicode_char
      for k = j, i + 1, -1 do
        table.remove(tokens, k)
      end
    end
  end
end

function latex_parser.convert_ast_to_unicode(tokens)
  local res = ""
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    if type(token) == "table" then
      if token.type == "group" then
        local orig_first_token = token.contents[1]
        latex_parser.convert_ast_to_unicode(token.contents)
        _remove_braces_of_diacritic(tokens, i, orig_first_token)

      elseif token.type == "control_sequence" then
        local cs = token
        local code_point = latex_data.unicode_commands[cs.name]
        if code_point then
          _replace_diacritic_with_unicode(tokens, i, code_point)
        end
      end
    end
    i = i + 1
  end
  return res
end


-- Also return the index to last token read by the cs
function latex_parser.convert_cs_to_inlines(tokens, i, strict, case_protection)
  local token = tokens[i]
  local inlines = {}

  local command_info = latex_data.commands[token.name]
  if command_info then
    local inline_type = command_info.inline_type
    if inline_type then
      local arg_inlines
      if command_info.num_args == 1 then
        local next_token = tokens[i+1]
        if type(next_token) == "table" and next_token.type == "group" then
          arg_inlines = latex_parser.convert_tokens_to_inlines(next_token.contents, strict, false)
          if case_protection then
            arg_inlines = {markup.NoCase:new(arg_inlines)}
          end
        else
          arg_inlines = latex_parser.convert_tokens_to_inlines({next_token}, strict, case_protection)
        end
        i = i + 1
      else  -- command_info.num_args == 0
        if command_info.inline_type then
          local arg_tokens = util.slice(tokens, i+1, #tokens)
          i = #tokens
          arg_inlines = latex_parser.convert_tokens_to_inlines(arg_tokens, strict, case_protection)
        end
      end

      if inline_type == "Formatted" then
        local inline = markup.Formatted:new(arg_inlines,
          {[command_info.formatting_key] = command_info.formatting_value})
        table.insert(inlines, inline)
      elseif inline_type == "Quoted" then
        table.insert(inlines, markup.Quoted:new(arg_inlines))
      elseif inline_type == "NoCase" then
        if not case_protection then
          arg_inlines = {markup.NoCase:new(arg_inlines)}
        end
        util.extend(inlines, arg_inlines)
      else
        -- NoCase
        table.insert(inlines, markup[inline_type]:new(arg_inlines))
      end
    end

  else
    -- Unrecognized command
    if strict then
      table.insert(inlines, markup.Code:new(token.raw))
    else
      -- Gobble following groupsas pandoc does:
      -- "Foo \unrecognized{bar}{baz} quz" -> "Foo  quz"
      for j = i + 1, #tokens do
        if type(tokens[j]) == "table" and tokens[j].type == "group" then
          i = j
        else
          break
        end
      end
    end
  end

  return inlines, i
end

function latex_parser.convert_group_to_inlines(token, strict, case_protection)
  if case_protection then
    local first_token = token.contents[1]
    if type(first_token) == "table" and first_token.type == "control_sequence" then
      -- BibTeX's "special character" like "{\'E}nd""
      case_protection = false
    end
  end
  local inlines = latex_parser.convert_tokens_to_inlines(token.contents, strict, false)
  if case_protection then
    inlines = {markup.NoCase:new(inlines)}
  end
  if strict then
    local has_command = false
    for _, inline in ipairs(inlines) do
      if inline._type == "Code" and util.startswith(inline.value, "\\") then
        has_command = true
        break
      end
    end
    if has_command then
      table.insert(inlines, 1, markup.Code:new("{"))
      table.insert(inlines, markup.Code:new("}"))
    end
  end
  return inlines
end


---comment
---@param tokens table
---@param strict boolean? Convert unrecognized LaTeX command to Code element
---@param case_protection boolean? Protect case with BibTeX's rules
---@return table
function latex_parser.convert_tokens_to_inlines(tokens, strict, case_protection)
  local inlines = {}

  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    if type(token) == "string" then
      -- The merge following string tokens
      for j = i + 1, #tokens do
        if type(tokens[j]) == "string" then
          token = token .. tokens[j]
          i = j
        else
          break
        end
      end
      table.insert(inlines, markup.PlainText:new(token))

    elseif type(token) == "table" then
      if token.type == "control_sequence" then
        local cs_inlines
        cs_inlines, i = latex_parser.convert_cs_to_inlines(tokens, i, strict, case_protection)
        util.extend(inlines, cs_inlines)

      elseif token.type == "group" then
        util.extend(inlines, latex_parser.convert_group_to_inlines(token, strict, case_protection))

      elseif token.type == "math" then
        table.insert(inlines, markup.MathTeX:new(token.text))
      end

    end
    i = i + 1
  end

  -- Merge adjacent Code inlines.
  for i = #inlines, 1, -1 do
    if i > 1 then
      local inline = inlines[i]
      local prev = inlines[i-1]
      if type(inline) == "table" and inline._type == "Code" and
          type(prev) == "table" and prev._type == "Code" then
        prev.value = prev.value .. inline.value
        table.remove(inlines, i)
      end
    end
  end

  return inlines
end



function latex_parser.convert_ast_to_rich_text(tokens)
  local res = {}

  local tmp_str = ""
  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    if type(token) == "string" then
      tmp_str = tmp_str .. token
    elseif type(token) == "table" then
      if tmp_str ~= "" then
        table.insert(res, tmp_str)
        tmp_str = ""
      end
      if token.type == "control_sequence" then
        local format_with_argment = format_commands_with_argment[token.name]
        local format_without_argment = format_commands_without_argment[token.name]
        if format_with_argment then
          if i < #tokens then
            local next_token = tokens[i + 1]
            local rich_text
            if type(next_token) == "string" then
              rich_text = {[format_with_argment] = next_token}
            elseif type(next_token) == "table" then
              if next_token.type == "control_sequence" then
                local content = {code = next_token.raw}
                rich_text = {[format_with_argment] = {content}}
              elseif next_token.type == "group" then
                rich_text = {[format_with_argment] = latex_parser.convert_ast_to_rich_text(next_token.contents)}
              elseif next_token.type == "math" then
                local content = latex_parser.convert_ast_to_rich_text(next_token.contents)
                rich_text = {[format_with_argment] = {{["math-tex"] = content}}}
              end
            end
            if rich_text then
              table.insert(res, rich_text)
              i = i + 1
            end
          else
            table.insert(res, {code = token.raw})
          end

        elseif format_without_argment then
          local rest_tokens = {}
          for j = i + 1, #tokens do
            table.insert(rest_tokens, tokens[j])
          end
          local rich_text = {[format_without_argment] = latex_parser.convert_ast_to_rich_text(rest_tokens)}
          table.insert(res, rich_text)
          i = #tokens

        else
          local rich_text = {code = token.raw}
          table.insert(res, rich_text)

        end

      elseif token.type == "group" then
        table.insert(res, {code = "{"})
        for _, rich_text in ipairs(latex_parser.convert_ast_to_rich_text(token.contents)) do
          table.insert(res, rich_text)
        end
        table.insert(res, {code = "}"})

      elseif token.type == "math" then
        table.insert(res, {["math-tex"] = token.text})
      end

    end
    i = i + 1
  end

  if tmp_str ~= "" then
    table.insert(res, tmp_str)
  end

  -- Merge tokens
  for i = #res - 1, 1, -1 do
    local token = res[i]
    local next_token = res[i + 1]
    local token_type = type(token)
    local next_token_type = type(next_token)
    if token_type == "string" and next_token_type == "string" then
      res[i] = token .. next_token
      table.remove(res, i + 1)
    elseif token_type == "table" and token.code and
        next_token_type == "table" and next_token.code then
      token.code = token.code .. next_token.code
      table.remove(res, i + 1)
    end
  end

  if #res == 1 and type(res[1]) == "string" then
    res = res[1]
  end

  return res
end


function latex_parser.parse_seq(str)
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

  local balanced = P{"{" * V(1) ^ 0 * "}" + (P"\\{" + P"\\}" + 1 - S"{}")}
  local item = P"{" * C(balanced^0) * P"}" + C((balanced - P",")^1)
  local seq = Ct((item * P(",")^-1)^0)

  return seq:match(str)
end

function latex_parser.parse_prop(str)
  local P = lpeg.P
  local R = lpeg.R
  local S = lpeg.S
  local C = lpeg.C
  local Cf = lpeg.Cf
  local Cg = lpeg.Cg
  local Ct = lpeg.Ct
  local V = lpeg.V

  local balanced = P{"{" * V(1)^0 * "}" + (P"\\{" + P"\\}" + 1 - S"{}")}
  local key = (R"09" + R"AZ" + R"az" + S"-_./")^1
  local value = (P"{" * C(balanced^0) * P"}" + C((balanced - S",=")^0)) / function (s)
    if s == "true" then
      return true
    elseif s == "false" then
      return false
    else
      return s
    end
  end
  local space = S(" \t\r\n")^0
  local pair = C(key) * space * P"=" * space * value * (P(",") * space)^-1
  local prop = Cf(Ct"" * space * Cg(pair)^0, rawset)

  -- if not str then
  --   print(debug.traceback())
  -- end
  return prop:match(str)
end


return latex_parser
