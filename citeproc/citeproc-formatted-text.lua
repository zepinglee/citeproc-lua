local dom = require("luaxml-domobject")

local inspect = require("inspect")


local FormattedText = {
  contents = nil,
  formats = nil,
  _tag_formats = {
    ["i"] = {["font-style"] = "italic"},
    ["b"] = {["font-weight"] = "bold"},
    ["sup"] = {["vertical-align"] = "sup"},
    ["sub"] = {["vertical-align"] = "sub"},
    ['span style="font-variant: small-caps;"'] = {["font-variant"] = "normal"},
    ['span style="nocase"'] = {["style"] = "nocase"},
  },
  _format_sequence = {
    "font-style",
    "font-variant",
    "font-weight",
    "text-decoration",
    "vertical-align",
    "quotes",
  },
  _flip_flop_formats = {
    ["font-style"] = "italic",
    ["font-weight"] = "bold",
    ["quotes"] = "true"
  },
  _type = "FormattedText",
}

function FormattedText:render(formatter, context, punctuation_in_quote)
  local res = ""

  self:merge_punctuations()

  if context then
    punctuation_in_quote = context.style:get_locale_option("punctuation-in-quote")
  end
  if punctuation_in_quote then
    self:move_punctuation_in_quote()
  end

  for _, text in ipairs(self.contents) do
    if type(text) == "string" then
      res = res .. formatter.text_escape(text)
    else  -- FormattedText
      res = res .. text:render(formatter, context)
    end
  end
  for _, attr in ipairs(self._format_sequence) do
    local value = self.formats[attr]
    if value then
      local key = string.format("@%s/%s", attr, value)
      local format = formatter[key]
      if type(format) == "string" then
        res = string.gsub(format, "%%%%STRING%%%%", res)
      elseif type(format) == "function" then
        res = format(res, context)
      end
    end
  end
  return res
end

-- https://github.com/Juris-M/citeproc-js/blob/aa2683f48fe23be459f4ed3be3960e2bb56203f0/src/queue.js#L724
-- Also merge duplicate punctuations.
FormattedText.punctuation_map = {
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

FormattedText.in_quote_punctuations = {
  [","] = true,
  ["."] = true,
  ["?"] = true,
  ["!"] = true,
}

function FormattedText:merge_punctuations(contents, index)
  for i, text in ipairs(self.contents) do
    if text._type == "FormattedText" then
      contents, index = text:merge_punctuations(contents, index)
    elseif type(text) == "string" then
      if contents and index then
        local previous_string = contents[index]
        local last_char = string.sub(previous_string, -1)
        local right_punct_map = self.punctuation_map[last_char]
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

function FormattedText:move_punctuation_in_quote()
  local i = 1
  while i < #self.contents do
    local text = self.contents[i]
    if text._type == "FormattedText" then
      text:move_punctuation_in_quote()
      if text.formats["quotes"] then

        local contents = self.contents
        local last_string = text
        while last_string._type == "FormattedText" do
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
              if self.in_quote_punctuations[first_char] then
                done = false
                local right_punct_map = self.punctuation_map[last_char]
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

function FormattedText.concat(str1, str2)
  assert(str1 and str2)
  if str1._type ~= "FormattedText" then
    str1 = FormattedText.new(str1)
  end
  local res = nil
  if next(str1.formats) == nil or str2 == "" then
    res = str1
  else
    res = FormattedText.new()
    res.contents = {str1}
  end
  if str2._type == "FormattedText" then
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

function FormattedText.concat_list(list, delimiter)
  -- Strings in the list may be nil.
  -- The delimiter may be nil.
  local res = nil
  for _, text in ipairs(list) do
    if text and text ~= "" then
      if res then
        if delimiter and delimiter ~= "" then
          res = FormattedText.concat(res, delimiter)
        end
        res = FormattedText.concat(res, text)
      else
        if type(text) == "string" then
          text = FormattedText.new(text)
        end
        res = text
      end
    end
  end
  return res
end

function FormattedText:strip_periods()
  local last_string = self
  local contents = self.contents
  while last_string._type == "FormattedText" do
    contents = last_string.contents
    last_string = contents[#contents]
  end
  if string.sub(last_string, -1) == "." then
    contents[#contents] = string.sub(last_string, 1, -2)
  end
end

function FormattedText:add_format(attr, value)
  self.formats[attr] = value
  if self._flip_flop_formats[attr] == value then
    for _, text in ipairs(self.contents) do
      if text._type == "FormattedText" then
        text:flip_flop(attr)
      end
    end
  end
end

function FormattedText:flip_flop(attr)
  if attr == "font-style" then
    local value = self.formats[attr]
    if value == "italic" then
      self.formats[attr] = "normal"
    elseif value == "normal" then
      self.formats[attr] = "italic"
    end

  elseif attr == "font-weight" then
    local value = self.formats[attr]
    if value == "bold" then
      self.formats[attr] = "normal"
    elseif value == "normal" then
      self.formats[attr] = "bold"
    end
  end
  for _, text in ipairs(self.contents) do
    if text._type == "FormattedText" then
      text:flip_flop(attr)
    end
  end
end

local FormattedText_mt = {
  __index = FormattedText,
  __concat = FormattedText.concat,
}

function FormattedText.new(text, formats)
  local res = {
    contents = {},
    formats = {},
  }

  setmetatable(res, FormattedText_mt)

  if not text then
    return res
  end

  if type(text) == "string" then
    local status, dom_object = pcall(dom.parse, "<p>"..text.."</p>")
    if status then
      return FormattedText.new(dom_object:get_path("p")[1])
    else
      res.contents = {text}
      return res
    end

  else
    if text:is_text() then
      res = text:get_text()
      return res

    elseif text:is_element() then
      res.contents = {}
      for _, child in ipairs(text:get_children()) do
        table.insert(res.contents, FormattedText.new(child))
      end

      local tag = text:get_element_name()
      local value = FormattedText._tag_formats[tag]
      if value then
        res.formats = value
      elseif tag == "span" then
        local style = text.get_attribute("style")
        if style == "font-variant: small-caps;" then
          res.formats = FormattedText._tag_formats['span style="font-variant: small-caps;"']
        elseif style == "nocase" then
          res.formats = FormattedText._tag_formats['span style="nocase"']
        end
      end
      return res
    end
  end
  return nil
end


return FormattedText
