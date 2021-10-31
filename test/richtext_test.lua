require("busted.runner")()

kpse.set_program_name("luatex")

local richtext = require("citeproc-richtext")
local util = require("citeproc-util")



describe("RichText", function()

  local formatter = {
    ["text_escape"] = function (text)
      text = string.gsub(text, "%&", "&#38;")
      text = string.gsub(text, "<", "&#60;")
      text = string.gsub(text, ">", "&#62;")
      return text
    end,
    ["@font-style/italic"] = "<i>%%STRING%%</i>",
    ["@font-style/oblique"] = "<em>%%STRING%%</em>",
    ["@font-style/normal"] = '<span style="font-style:normal;">%%STRING%%</span>',
    ["@font-variant/small-caps"] = '<span style="font-variant:small-caps;">%%STRING%%</span>',
    ["@font-variant/normal"] = '<span style="font-variant:normal;">%%STRING%%</span>',
    ["@font-weight/bold"] = "<b>%%STRING%%</b>",
    ["@font-weight/normal"] = '<span style="font-weight:normal;">%%STRING%%</span>',
    ["@font-weight/light"] = false,
    ["@text-decoration/none"] = '<span style="text-decoration:none;">%%STRING%%</span>',
    ["@text-decoration/underline"] = '<span style="text-decoration:underline;">%%STRING%%</span>',
    ["@vertical-align/sup"] = "<sup>%%STRING%%</sup>",
    ["@vertical-align/sub"] = "<sub>%%STRING%%</sub>",
    ["@vertical-align/baseline"] = '<span style="baseline">%%STRING%%</span>',
    ["@quotes/true"] = function (str, context)
      local open_quote = '“'
      local close_quote = '”'
      return open_quote .. str .. close_quote
    end,
    ["@quotes/inner"] = function (str, context)
      local open_quote = "‘"
      local close_quote = "’"
      return open_quote .. str .. close_quote
    end,
    ["@bibliography/entry"] = function (res, context)
      return '<div class="csl-entry">' .. res .. "</div>"
    end
  }

  describe("initilization", function()
    it("simple", function()
      local text = richtext.new("foo")
      local expected = {
        contents = {"foo"},
        formats = {},
      }
      assert.same(expected, text)
    end)

    it("space", function()
      local text = richtext.new(" ")
      local expected = {
        contents = {" "},
        formats = {},
      }
      assert.same(expected, text)
    end)

    it("with tags", function()
      local text = richtext.new("foo <i>bar</i> baz")
      local expected = {
        contents = {
          "foo ",
          {
            contents = {"bar"},
            formats = {["font-style"] = "italic"},
          },
          " baz",
        },
        formats = {},
      }
      assert.same(expected, text)
    end)

    it("with multiple tags", function()
      local text = richtext.new("<i>foo</i> bar <b>baz</b>")
      local expected = {
        contents = {
          {
            contents = {"foo"},
            formats = {["font-style"] = "italic"},
          },
          " bar ",
          {
            contents = {"baz"},
            formats = {["font-weight"] = "bold"},
          },
        },
        formats = {},
      }
      assert.same(expected, text)
    end)

    it("with hierarchical tags", function()
      local text = richtext.new("<i>foo <i>bar</i> baz</i>")
      local expected = {
        contents = {
          "foo ",
          {
            contents = {"bar"},
            formats = {["font-style"] = "italic"},
          },
          " baz",
        },
        formats = {["font-style"] = "italic"},
      }
      assert.same(expected, text)
    end)

    local quoted_text = {
      contents = {
        "foo ",
        {
          contents = {"bar"},
          formats = {["quotes"] = "true"},
        },
        " baz",
      },
      formats = {},
    }

    it("with double quotation mark", function()
      local text = richtext.new('foo “bar” baz')
      assert.same(quoted_text, text)
    end)

    it("with double straight quotation mark", function()
      local text = richtext.new('foo "bar" baz')
      assert.same(quoted_text, text)
    end)

    it("single quotation mark", function()
      local text = richtext.new("foo ‘bar’ baz")
      assert.same(quoted_text, text)
    end)

    it("single straight quotation mark", function()
      local text = richtext.new("foo 'bar' baz")
      assert.same(quoted_text, text)
    end)

    it("with apostrophe", function()
      local text = richtext.new("foo 'bar's' baz")
      local expected = {
        contents = {
          "foo ",
          {
            contents = {"bar’s"},
            formats = {["quotes"] = "true"},
          },
          " baz",
        },
        formats = {},
      }
      assert.same(expected, text)
    end)

    it("with ambiguous apostrophe", function()
      local text = richtext.new("'foo bars' baz'")
      local expected = {
        contents = {
          {
            contents = {"foo bars"},
            formats = {["quotes"] = "true"},
          },
          " baz’",
        },
        formats = {},
      }
      assert.same(expected, text)
    end)

  end)


  it("render text", function()
    local text = richtext.new("<b>foo</b>")
    assert.equal("<b>foo</b>", text:render(formatter, nil))
  end)

  it("merge punctuation", function()
    local text = richtext.new()
    text.contents = {"(", "ed.", ".)"}
    local res = text:render(formatter, nil)
    assert.equal("(ed.)", res)
  end)

  it("merge punctuation with formats", function()
    local text = richtext.new("<i>Foo.</i>. 1965")
    local res = text:render(formatter, nil)
    assert.equal("<i>Foo.</i> 1965", res)
  end)


  describe("formatting", function()

    it("add format", function()
      local text = richtext.new("foo")
      text:add_format("font-style", "italic")
      assert.equal("<i>foo</i>", text:render(formatter, nil))
    end)

    it("nodecor", function()
      local text = richtext.new('<i>foo <span class="nodecor">bar</span> baz</i>')
      local result = text:render(formatter, nil)
      local expected = '<i>foo <span style="font-style:normal;">bar</span> baz</i>'
      assert.equal(expected, result)
    end)

    it("clean format", function()
      local text = richtext.new("foo")
      text:add_format("font-style", "normal")
      local result = text:render(formatter, nil)
      assert.equal("foo", result)
    end)

    describe("flip-flop", function()

      it("simple", function()
        local text = richtext.new("foo<i>bar</i>baz")
        text:add_format("font-style", "italic")
        assert.equal('<i>foo<span style="font-style:normal;">bar</span>baz</i>', text:render(formatter, nil))
      end)

      it("hierarchical tags", function()
        local text = richtext.new("One <i>Two <i>Three</i> Four</i> Five!")
        text:add_format("font-style", "italic")
        local expected = '<i>One <span style="font-style:normal;">Two <i>Three</i> Four</span> Five!</i>'
        local result = text:render(formatter, nil)
        assert.equal(expected, result)
      end)

      it("quotes", function()
        local text = richtext.new('"foo \'bar\' baz"')
        local result = text:render(formatter, nil)
        local expected = '“foo ‘bar’ baz”'
        assert.equal(expected, result)
      end)

    end)

  end)


  describe("quotes", function()

    it("move punctuation in quotes", function()
      local quoted = richtext.new()
      quoted.contents = {"comma"}
      quoted:add_format("quotes", "true")
      local res = richtext.new()
      res.contents = {quoted, ",", ". ", "period"}
      res = res:render(formatter, nil, true)
      assert.equal("“comma,.” period", res)
    end)

  end)


  it("strip periods", function()
    local text = richtext.new("eds.")
    text:strip_periods()
    local res = text:render(formatter, nil)
    assert.equal("eds", res)
  end)


  describe("text case", function()

    it("lowercase", function()
      local text = richtext.new("Foo <i>Bar</i>")
      text:add_format("text-case", "lowercase")
      local res = text:render(formatter, nil)
      assert.equal("foo <i>bar</i>", res)
    end)

    it("uppercase", function()
      local text = richtext.new("Foo <i>Bar</i>")
      text:add_format("text-case", "uppercase")
      local res = text:render(formatter, nil)
      assert.equal("FOO <i>BAR</i>", res)
    end)

    describe("capitalize-first", function()
      it("lower", function()
        local text = richtext.new("foo <i>bar</i>")
        text:add_format("text-case", "capitalize-first")
        local res = text:render(formatter, nil)
        assert.equal("Foo <i>bar</i>", res)
      end)

      it("mixied", function()
        local text = richtext.new("fOO <i>bAR</i>")
        text:add_format("text-case", "capitalize-first")
        local res = text:render(formatter, nil)
        assert.equal("fOO <i>bAR</i>", res)
      end)
    end)

    describe("capitalize-all", function()
      it("lower", function()
        local text = richtext.new("foo <i>bar</i>")
        text:add_format("text-case", "capitalize-all")
        local res = text:render(formatter, nil)
        assert.equal("Foo <i>Bar</i>", res)
      end)

      it("mixed", function()
        local text = richtext.new("fOO <i>bAR</i>")
        text:add_format("text-case", "capitalize-all")
        local res = text:render(formatter, nil)
        assert.equal("fOO <i>bAR</i>", res)
      end)

    end)

    describe("sentence", function()
      it("uppercase", function()
        local text = richtext.new("FOO <i>BAR</i>")
        text:add_format("text-case", "sentence")
        local res = text:render(formatter, nil)
        assert.equal("Foo <i>bar</i>", res)
      end)

      it("mixed", function()
        local text = richtext.new("fOO <i>BAR</i>")
        text:add_format("text-case", "sentence")
        local res = text:render(formatter, nil)
        assert.equal("fOO <i>BAR</i>", res)
      end)
    end)

    describe("title", function()
      it("uppercase", function()
        local text = richtext.new("FOO <i>BAR</i>")
        text:add_format("text-case", "title")
        local res = text:render(formatter, nil)
        assert.equal("Foo <i>Bar</i>", res)
      end)

      it("mixed", function()
        local text = richtext.new("fOO <i>bar</i> bAZ")
        text:add_format("text-case", "title")
        local res = text:render(formatter, nil)
        assert.equal("fOO <i>Bar</i> bAZ", res)
      end)

      it("stop word first", function()
        local text = richtext.new("THE FOO <i>BAR</i>")
        text:add_format("text-case", "title")
        local res = text:render(formatter, nil)
        assert.equal("The Foo <i>Bar</i>", res)
      end)

      it("stop word last", function()
        local text = richtext.new("the foo: On <i>tHE bAR</i> Down")
        text:add_format("text-case", "title")
        local res = text:render(formatter, nil)
        -- TODO
        pending("Stop words are not lowercased if they are the last word in the string.")
        assert.equal("The Foo: On <i>the bAR</i> Down", res)
      end)

      it("suppl", function()
        local text = richtext.new("Supplément aux annales du Service des Antiquités de l'Égypte, Cahier")
        text:add_format("text-case", "title")
        local res = text:render(formatter, nil)
        assert.equal("Supplément Aux Annales Du Service Des Antiquités de l’Égypte, Cahier", res)
      end)

    end)

    it("nodecor", function()
      local text = richtext.new('foo <span class="nodecor">bar</span> baz')
      text:add_format("text-case", "capitalize-all")
      local res = text:render(formatter, nil)
      assert.equal("Foo bar Baz", res)
    end)

    it("small-caps", function()
      local text = richtext.new('foo bar baz')
      text:add_format("text-case", "capitalize-all")
      text:add_format("font-variant", "small-caps")
      local res = text:render(formatter, nil)
      local expected = '<span style="font-variant:small-caps;">Foo Bar Baz</span>'
      assert.equal(expected, res)
    end)

  end)

  describe("concatenation", function()
    it("concat text", function()
      local text = richtext.new("foo")
      local bar = richtext.new("bar")
      local res = richtext.concat(text, bar)
      res = res:render(formatter, nil)
      assert.equal("foobar", res)
    end)

    it("concat string", function()
      local text = richtext.new("foo")
      local bar = "bar"
      local res = richtext.concat(text, bar)
      res = res:render(formatter, nil)
      assert.equal("foobar", res)
    end)

    it("concat two strings", function()
      local text = "foo"
      local bar = "bar"
      local res = richtext.concat(text, bar)
      res = res:render(formatter, nil)
      assert.equal("foobar", res)
    end)

    it("concat text of space", function()
      local text = richtext.new("foo")
      local bar = richtext.new(" ")
      local res = richtext.concat(text, bar)
      res = res:render(formatter, nil)
      assert.equal("foo ", res)
    end)

    it("concat string of space", function()
      local text = richtext.new("foo")
      local bar = " "
      local res = richtext.concat(text, bar)
      res = res:render(formatter, nil)
      assert.equal("foo ", res)
    end)

    it("concat list of strings", function()
      local list = {"foo", "bar"}
      local res = richtext.concat_list(list, " ")
      res = res:render(formatter, nil)
      assert.equal("foo bar", res)
    end)

  end)

end)
