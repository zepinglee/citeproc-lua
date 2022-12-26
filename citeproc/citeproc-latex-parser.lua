--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local latex_parser = {}

local lpeg = require("lpeg")
local unicode = require("unicode")
local bibtex_data = require("citeproc-bibtex-data")
local util = require("citeproc-util")


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


latex_parser.latex_grammar = latex_parser.get_latex_grammar()


function latex_parser.convert_latex_to_rich_text(str)
  local ast = latex_parser.latex_grammar:match(str)
  latex_parser.convert_accents_to_unicode(ast)
  local res = latex_parser.convert_ast_to_rich_text(ast)
  return res
end


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


function latex_parser.convert_accents_to_unicode(tokens)
  local res = ""
  local i = 1
  while i <= #tokens do
    if type(token) == "table" and token.type == "control_sequence" then
      local cs = token
      local code_point = bibtex_data.unicode_commands[cs.name]
      if code_point then
        local unicode_char
        if type(code_point) == "string" then
          unicode_char = utf8.char(tonumber(code_point, 16))
          tokens[i] = unicode_char

        elseif type(code_point) == "table" then
          -- The command takes an argument (\"{o})
          local arg
          if i < #tokens then
            local next_token = tokens[i + 1]
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
            table.remove(tokens, i + 1)
          end
        end
      end
    end
    i = i + 1
  end
  return res
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
        table.insert(res, {["math-tex"] = token.contents})
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

  return prop:match(str)
end


return latex_parser
