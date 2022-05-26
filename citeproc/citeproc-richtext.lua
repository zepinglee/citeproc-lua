--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local richtext = {}

local unicode = require("unicode")

local util = require("citeproc-util")


local RichText = {
  contents = nil,
  formats = nil,
  _type = "RichText",
}

function RichText:shallow_copy()
  local res = richtext.new()
  for _, text in ipairs(self.contents) do
    table.insert(res.contents, text)
  end
  for key, value in pairs(self.formats) do
    res.formats[key] = value
  end
  return res
end

function RichText:render(formatter, context, punctuation_in_quote)
  self:merge_punctuations()

  if punctuation_in_quote == nil and context then
    punctuation_in_quote = context.style:get_locale_option("punctuation-in-quote")
  end
  if punctuation_in_quote then
    self:move_punctuation_in_quote()
  end

  self:change_case()

  self:flip_flop()

  self:clean_formats()

  return self:_render(formatter, context)
end

function RichText:_render(formatter, context)
  local res = ""
  for _, text in ipairs(self.contents) do
    local str
    if type(text) == "string" then
      if formatter and formatter.text_escape then
        str = formatter.text_escape(text)
      else
        str = text
      end
    else  -- RichText
      str = text:_render(formatter, context)
    end
    -- Remove leading spaces
    if string.sub(res, -1) == " " and string.sub(str, 1, 1) == " " then
      str = string.gsub(str, "^%s+", "")
    end
    res = res .. str
  end
  for _, attr in ipairs(richtext.format_sequence) do
    local value = self.formats[attr]
    if value then
      local key = string.format("@%s/%s", attr, value)
      if formatter then
        local format = formatter[key]
        if type(format) == "string" then
          res = string.format(format, res)
        elseif type(format) == "function" then
          res = format(res, context)
        end
      end
    end
  end
  return res
end

function RichText:merge_punctuations(contents, index)
  for i, text in ipairs(self.contents) do
    if text._type == "RichText" then
      contents, index = text:merge_punctuations(contents, index)
    elseif type(text) == "string" then
      if contents and index then
        local previous_string = contents[index]
        local last_char = string.sub(previous_string, -1)
        local right_punct_map = richtext.punctuation_map[last_char]
        if right_punct_map then
          local first_char = string.sub(text, 1, 1)
          local new_punctuations = nil
          if first_char == last_char then
            new_punctuations = last_char
          elseif contents == self.contents then
            new_punctuations = right_punct_map[first_char]
          end
          if new_punctuations then
            if #text == 1 then
              table.remove(self.contents, i)
            else
              self.contents[i] = string.sub(text, 2)
            end
            contents[index] = string.sub(previous_string, 1, -2) .. new_punctuations
          end
        end
      end
      contents = self.contents
      index = i
    end
  end
  return contents, index
end

function RichText:move_punctuation_in_quote()
  local i = 1
  while i <= #self.contents do
    local text = self.contents[i]
    if type(text) == "table" and text._type == "RichText" then
      text:move_punctuation_in_quote()

      if text.formats["quotes"] then
        local contents = self.contents
        local last_string = text
        while type(last_string) == "table" and last_string._type == "RichText" do
          contents = last_string.contents
          last_string = contents[#contents]
        end

        local done = false
        while not done do
          done = true
          last_string = contents[#contents]
          local last_char = string.sub(last_string, -1)
          if i < #self.contents then
            local next_text = self.contents[i + 1]
            if type(next_text) == "string" then
              local first_char = string.sub(next_text, 1, 1)
              if richtext.in_quote_punctuations[first_char] then
                done = false
                local right_punct_map = richtext.punctuation_map[last_char]
                if right_punct_map then
                  first_char  = right_punct_map[first_char]
                  last_string = string.sub(last_string, 1, -2)
                end
                contents[#contents] = last_string .. first_char
                if #next_text == 1 then
                  table.remove(self.contents, i + 1)
                else
                  self.contents[i + 1] = string.sub(next_text, 2)
                end
              end
            end
          end
        end
      end
    end
    i = i + 1
  end
end

function RichText:change_case()
  for _, text in ipairs(self.contents) do
    if type(text) == "table" and text._type == "RichText" then
      text:change_case()
    end
  end
  local text_case = self.formats["text-case"]
  if text_case then
    if text_case == "lowercase" then
      self:lowercase()
    elseif text_case == "uppercase" then
      self:uppercase()
    elseif text_case == "capitalize-first" then
      self:capitalize_first()
    elseif text_case == "capitalize-all" then
      self:capitalize_all()
    elseif text_case == "sentence" then
      self:sentence()
    elseif text_case == "title" then
      self:title()
    end
  end
end

function RichText:_change_word_case(state, word_transform, first_tranform, is_phrase)
  if self.formats["text-case"] == "nocase" then
    return
  end
  if is_phrase and (self.formats["vertical-align"] == "sup" or
      self.formats["vertical-align"] == "sub" or
      self.formats["font-variant"] == "small-caps") then
    return
  end
  state = state or "after-sentence"
  word_transform = word_transform or function (x) return x end
  first_tranform = first_tranform or word_transform
  for i, text in ipairs(self.contents) do
    if type(text) == "string" then

      local res = ""
      local word_seps = {
        " ",
        "%-",
        "/",
        util.unicode["no-break space"],
        util.unicode["en dash"],
        util.unicode["em dash"],
      }
      for _, tuple in ipairs(util.split(text, word_seps, nil, true)) do
        local word, punctuation = table.unpack(tuple)
        if state == "after-sentence" then
          res = res .. first_tranform(word)
          if string.match(word, "%w") then
            state = "after-word"
          end
        else
          res = res .. word_transform(word, punctuation)
        end
        res = res .. punctuation
        if string.match(word, "[.!?:]%s*$") then
          state = "after-sentence"
        end
      end

      -- local word_index = 0
      -- local res = string.gsub(text, "%w+", function (word)
      --   word_index = word_index + 1
      --   if word_index == 1 then
      --     return first_tranform(word)
      --   else
      --     return word_transform(word)
      --   end
      -- end)
      -- if string.match(res, "[.!?:]%s*$") then
      --   state = "after-sentence"
      -- end

      self.contents[i] = res
    else
      state = text:_change_word_case(state, word_transform, first_tranform, true)
    end
  end
  return state
end

function RichText:lowercase()
  local word_transform = unicode.utf8.lower
  self:_change_word_case("after-sentence", word_transform)
end

function RichText:uppercase()
  local word_transform = unicode.utf8.upper
  self:_change_word_case("after-sentence", word_transform)
end

local function capitalize(str)
  local res = string.gsub(str, utf8.charpattern, unicode.utf8.upper, 1)
  return res
end

local function capitalize_if_lower(word)
  if util.is_lower(word) then
    return capitalize(word)
  else
    return word
  end
end

function RichText:capitalize_first(state)
  local first_tranform = capitalize_if_lower
  self:_change_word_case("after-sentence", nil, first_tranform)
end

function RichText:capitalize_all()
  local word_transform = capitalize_if_lower
  self:_change_word_case("after-sentence", word_transform)
end

function RichText:is_upper()
  for _, text in ipairs(self.contents) do
    if type(text) == "string" then
      if not util.is_upper(text) then
        return false
      end
    else
      local res = text:is_upper()
      if not res then
        return false
      end
    end
  end
  return true
end

function RichText:sentence()
  if self:is_upper() then
    local first_tranform = function(word)
      return capitalize(unicode.utf8.lower(word))
    end
    local word_transform = unicode.utf8.lower
    self:_change_word_case("after-sentence", word_transform, first_tranform)
  else
    local first_tranform = capitalize_if_lower
    self:_change_word_case("after-sentence", nil, first_tranform)
  end
end

function RichText:title()
  if self:is_upper() then
    local first_tranform = function(word)
      return capitalize(unicode.utf8.lower(word))
    end
    local word_transform = function(word, sep)
      local res = unicode.utf8.lower(word)
      if not util.stop_words[res] then
        res = capitalize(res)
      end
      return res
    end
    self:_change_word_case("after-sentence", word_transform, first_tranform)
  else
    local first_tranform = capitalize_if_lower
    local word_transform = function(word, sep)
      local lower = unicode.utf8.lower(word)
      -- Stop word before hyphen is treated as a normal word.
      if util.stop_words[lower] and sep ~= "-" then
        return lower
      elseif word == lower then
        return capitalize(word)
      else
        return word
      end
    end
    self:_change_word_case("after-sentence", word_transform, first_tranform)
  end
end

function richtext.concat(str1, str2)
  assert(str1 and str2)

  if type(str1) == "string" then
    str1 = richtext.new(str1)
  end

  local res
  if next(str1.formats) == nil or str2 == "" then
    -- shallow copy
    res = str1
  else
    res = richtext.new()
    res.contents = {str1}
  end

  if str2._type == "RichText" then
    if next(str2.formats) == nil then
      for _, text in ipairs(str2.contents) do
        table.insert(res.contents, text)
      end
    else
      table.insert(res.contents, str2)
    end
  elseif str2 ~= "" then
    table.insert(res.contents, str2)
  end
  return res
end

function richtext.concat_list(list, delimiter)
  -- Strings in the list may be nil thus ipairs() should be avoided.
  -- The delimiter may be nil.
  local res = nil
  for i = 1, #list do
    local text = list[i]
    if text and text ~= "" then
      if res then
        if delimiter and delimiter ~= "" then
          res = richtext.concat(res, delimiter)
        end
        res = richtext.concat(res, text)
      else
        if type(text) == "string" then
          text = richtext.new(text)
        end
        res = text
      end
    end
  end
  return res
end

function RichText:apply_strip_periods()
  local last_string = self
  local contents = self.contents
  while last_string._type == "RichText" do
    contents = last_string.contents
    last_string = contents[#contents]
  end
  if string.sub(last_string, -1) == "." then
    contents[#contents] = string.sub(last_string, 1, -2)
  end
end

function RichText:add_format(attr, value)
  self.formats[attr] = value
end

function RichText:flip_flop(attr, value)
  if not attr then
    for attr, _ in pairs(richtext.flip_flop_formats) do
      self:flip_flop(attr)
    end
    return
  end

  local default_value = richtext.default_formats[attr]

  if value and value ~= default_value and self.formats[attr] == value then
    self.formats[attr] = richtext.flip_flop_values[attr][value]
  end
  if self.formats[attr] then
    value = self.formats[attr]
  end

  for _, text in ipairs(self.contents) do
    if type(text) == "table" and text._type == "RichText" then
      text:flip_flop(attr, value)
    end
  end
end

function RichText:clean_formats(format)
  -- Remove the formats that are default values
  if not format then
    for format, _ in pairs(richtext.default_formats) do
      self:clean_formats(format)
    end
    return
  end
  if self.formats[format] then
    if self.formats[format] == richtext.default_formats[format] then
      self.formats[format] = nil
    else
      return
    end
  end
  for _, text in ipairs(self.contents) do
    if type(text) == "table" and text._type == "RichText" then
      text:clean_formats(format)
    end
  end
end

local RichText_mt = {
  __index = RichText,
  __concat = richtext.concat,
}

local function table_update(t, new_t)
  for key, value in pairs(new_t) do
    t[key] = value
  end
  return t
end

function RichText._split_tags(str)
  -- Normalize markup
  str = string.gsub(str, '<span%s+style="font%-variant:%s*small%-caps;?">', '<span style="font-variant:small-caps;">')
  str = string.gsub(str, '<span%s+class="nocase">', '<span class="nocase">')
  str = string.gsub(str, '<span%s+class="nodecor">', '<span class="nodecor">')

  local strings = {}

  local start_index = 1
  local i = 1

  while i <= #str do
    local substr = string.sub(str, i)
    local starts_with_tag = false
    for tag, _ in pairs(richtext.tags) do
      if util.startswith(substr, tag) then
        if start_index <= i - 1 then
          table.insert(strings, string.sub(str, start_index, i-1))
        end
        table.insert(strings, tag)
        i = i + #tag
        start_index = i
        starts_with_tag = true
        break
      end
    end
    if not starts_with_tag then
      i = i + 1
    end
  end
  if start_index <= #str then
    table.insert(strings, string.sub(str, start_index))
  end

  for i = 1, #strings do
    str = strings[i]
    if str == "'" or str == util.unicode["apostrophe"] then
      local previous_str = strings[i - 1]
      local next_str = strings[i + 1]
      if previous_str and next_str then
        local previous_code_point = nil
        for _, code_point in utf8.codes(previous_str) do
          previous_code_point = code_point
        end
        local next_code_point = utf8.codepoint(next_str)
        if util.is_romanesque(previous_code_point) and util.is_romanesque(next_code_point) then
          -- An apostrophe
          strings[i-1] = strings[i-1] .. util.unicode["apostrophe"] .. strings[i+1]
          table.remove(strings, i+1)
          table.remove(strings, i)
        end
      end
    end
  end

  return strings
end

function richtext.new(text, formats)
  local res = {
    contents = {},
    formats = formats or {},
  }

  setmetatable(res, RichText_mt)

  if not text then
    return res
  end

  if type(text) == "string" then

    local strings = RichText._split_tags(text)
    local contents = {}
    for _, str in ipairs(strings) do
      table.insert(contents, str)

      local end_tag = nil
      if str == '"' then
        local last_text = contents[#contents - 1]
        if last_text and type(last_text) == "string" and string.match(last_text, "%s$") then
          end_tag = nil
        else
          end_tag = str
        end
      elseif richtext.end_tags[str] then
        end_tag = str
      end

      if end_tag then
        for i = #contents - 1, 1, -1 do
          local start_tag = contents[i]
          if type(start_tag) == "string" and richtext.tag_pairs[start_tag] == end_tag then
            local subtext = richtext.new()
            -- subtext.contents = util.slice(contents, i + 1, #contents - 1)
            if start_tag == "'" and end_tag == "'" and i == #contents - 1 then
              contents[i] = util.unicode["apostrophe"]
              contents[#contents] = util.unicode["apostrophe"]
              break
            end

            for j = i + 1, #contents - 1 do
              local substr = contents[j]
              if substr == "'" then
                substr = util.unicode["apostrophe"]
              end
              local last_text = subtext.contents[#subtext.contents]
              if type(substr) == "string" and type(last_text) == "string" then
                subtext.contents[#subtext.contents] = last_text .. substr
              else
                table.insert(subtext.contents, substr)
              end
            end

            if start_tag == '<span class="nodecor">' then
              for attr, value in pairs(richtext.default_formats) do
                subtext.formats[attr] = value
              end
              subtext.formats["text-case"] = "nocase"
            else
              for attr, value in pairs(richtext.tag_formats[start_tag]) do
                subtext.formats[attr] = value
              end
            end

            for j = #contents, i, -1 do
              table.remove(contents, j)
            end
            table.insert(contents, subtext)
            break
          end
        end
      end
    end

    for i = #contents, 1, -1 do
      if contents[i] == "'" then
        contents[i] = util.unicode["apostrophe"]
      end
      if type(contents[i]) == "string" and type(contents[i+1]) == "string" then
        contents[i] = contents[i] .. contents[i+1]
        table.remove(contents, i+1)
      end
    end

    if #contents == 1 and type(contents[1]) == "table" then
      res = contents[1]
    else
      res.contents = contents
    end

    return res

  elseif type(text) == "table" and text._type == "RichText" then
    return text

  elseif type(text) == "table" then
    return text
  end
  return nil
end

richtext.tag_formats = {
  ["<i>"] = {["font-style"] = "italic"},
  ["<b>"] = {["font-weight"] = "bold"},
  ["<sup>"] = {["vertical-align"] = "sup"},
  ["<sub>"] = {["vertical-align"] = "sub"},
  ["<sc>"] = {["font-variant"] = "small-caps"},
  ['<span style="font-variant:small-caps;">'] = {["font-variant"] = "small-caps"},
  ['<span class="nocase">'] = {["text-case"] = "nocase"},
  ['"'] = {["quotes"] = "true"},
  [util.unicode['left double quotation mark']] = {["quotes"] = "true"},
  ["'"] = {["quotes"] = "true"},
  [util.unicode['left single quotation mark']] = {["quotes"] = "true"},
}

richtext.default_formats = {
  ["URL"] = "false",
  ["DOI"] = "false",
  ["PMID"] = "false",
  ["PMCID"] = "false",
  ["font-style"] = "normal",
  ["font-variant"] = "normal",
  ["font-weight"] = "normal",
  ["text-decoration"] = "none",
  ["vertical-align"] = "baseline",
  ["quotes"] = "false",
}

richtext.format_sequence = {
  "URL",
  "DOI",
  "PMID",
  "PMCID",
  "font-style",
  "font-variant",
  "font-weight",
  "text-decoration",
  "vertical-align",
  "quotes",
  "display",
}

richtext.flip_flop_formats = {
  ["font-style"] = true,
  ["font-weight"] = true,
  ["font-variant"] = true,
  ["quotes"] = true,
}

richtext.flip_flop_values = {
  ["font-style"] = {
    italic = "normal",
    normal = "italic",
  },
  ["font-weight"] = {
    bold = "normal",
    normal = "bold",
  },
  ["font-variant"] = {
    ["small-caps"] = "normal",
    normal = "small-caps",
  },
  ["quotes"] = {
    ["true"] = "inner",
    inner = "true",
  },
}

-- https://github.com/Juris-M/citeproc-js/blob/aa2683f48fe23be459f4ed3be3960e2bb56203f0/src/queue.js#L724
-- Also merge duplicate punctuations.
richtext.punctuation_map = {
  ["!"] = {
    ["."] = "!",
    ["?"] = "!?",
    [":"] = "!",
    [","] = "!,",
    [";"] = "!;",
  },
  ["?"] = {
    ["!"] = "?!",
    ["."] = "?",
    [":"] = "?",
    [","] = "?,",
    [";"] = "?;",
  },
  ["."] = {
    ["!"] = ".!",
    ["?"] = ".?",
    [":"] = ".:",
    [","] = ".,",
    [";"] = ".;",
  },
  [":"] = {
    ["!"] = "!",
    ["?"] = "?",
    ["."] = ":",
    [","] = ":,",
    [";"] = ":;",
  },
  [","] = {
    ["!"] = ",!",
    ["?"] = ",?",
    [":"] = ",:",
    ["."] = ",.",
    [";"] = ",;",
  },
  [";"] = {
    ["!"] = "!",
    ["?"] = "?",
    [":"] = ";",
    [","] = ";,",
    ["."] = ";",
  }
}

richtext.in_quote_punctuations = {
  [","] = true,
  ["."] = true,
  ["?"] = true,
  ["!"] = true,
}

richtext.tag_pairs = {
  ["<i>"] = "</i>",
  ["<b>"] = "</b>",
  ["<sup>"] = "</sup>",
  ["<sub>"] = "</sub>",
  ["<sc>"] = "</sc>",
  ['<span style="font-variant:small-caps;">'] = "</span>",
  ['<span class="nocase">'] = "</span>",
  ['<span class="nodecor">'] = "</span>",
  ['"'] = '"',
  [util.unicode['left double quotation mark']] = util.unicode['right double quotation mark'],
  ["'"] = "'",
  [util.unicode['left single quotation mark']] = util.unicode['right single quotation mark'],
}

richtext.tags = {}

richtext.end_tags = {}

for start_tag, end_tag in pairs(richtext.tag_pairs) do
  richtext.tags[start_tag] = true
  richtext.tags[end_tag] = true
  richtext.end_tags[end_tag] = true
end

return richtext
