require("busted.runner")()

kpse.set_program_name("luatex")

local FormattedText = require("citeproc.citeproc-formatted-text")

local inspect = require("inspect")


describe("FormattedText", function()

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
      local open_quote = "“"
      local close_quote = "”"
      return open_quote .. str .. close_quote
    end,
    ["@bibliography/entry"] = function (res, context)
      return '<div class="csl-entry">' .. res .. "</div>"
    end
  }

  it("initialze", function()
    local foo = FormattedText.new("foo")
    assert.equal( "foo", foo:render(formatter, nil))
  end)

  it("render text", function()
    local foo = FormattedText.new("<b>foo</b>")
    assert.equal("<b>foo</b>", foo:render(formatter, nil))
  end)

  it("initialze", function()
    local foo = FormattedText.new()
    foo.contents = {"foo"}
    local res = foo:render(formatter, nil)
    assert.equal("foo", res)
  end)

  it("initialize with tags", function()
    local foo = FormattedText.new("<b>foo</b>")
    assert.equal("<b>foo</b>", foo:render(formatter, nil))
  end)

  it("initialize with tags", function()
    local foo = FormattedText.new("<b>foo<i>bar</i>baz</b>")
    assert.equal("<b>foo<i>bar</i>baz</b>", foo:render(formatter, nil))
  end)

  it("initialize with quotes", function()
    local foo = FormattedText.new('foo "bar" baz')
    assert.equal('foo “bar” baz', foo:render(formatter, nil))
  end)

  it("merge punctuation", function()
    local foo = FormattedText.new()
    foo.contents = {"(", "ed.", ".)"}
    local res = foo:render(formatter, nil)
    assert.equal("(ed.)", res)
  end)

  it("merge punctuation with formats", function()
    local foo = FormattedText.new("<i>Foo.</i>. 1965")
    local res = foo:render(formatter, nil)
    assert.equal("<i>Foo.</i> 1965", res)
  end)

  it("move punctuation in quotes", function()
    local quoted = FormattedText.new()
    quoted.contents = {"comma"}
    quoted:add_format("quotes", "true")
    local res = FormattedText.new()
    res.contents = {quoted, ",", ". ", "period"}
    res = res:render(formatter, nil, true)
    assert.equal("“comma,.” period", res)
  end)

  describe("text case", function()
    it("lowercase", function()
      local foo = FormattedText.new("Foo <i>Bar</i>")
      foo:add_format("text-case", "lowercase")
      local res = foo:render(formatter, nil)
      assert.equal("foo <i>bar</i>", res)
    end)

    it("uppercase", function()
      local foo = FormattedText.new("Foo <i>Bar</i>")
      foo:add_format("text-case", "uppercase")
      local res = foo:render(formatter, nil)
      assert.equal("FOO <i>BAR</i>", res)
    end)

    describe("capitalize-first", function()
      it("lower", function()
        local foo = FormattedText.new("foo <i>bar</i>")
        foo:add_format("text-case", "capitalize-first")
        local res = foo:render(formatter, nil)
        assert.equal("Foo <i>bar</i>", res)
      end)

      it("mixied", function()
        local foo = FormattedText.new("fOO <i>bAR</i>")
        foo:add_format("text-case", "capitalize-first")
        local res = foo:render(formatter, nil)
        assert.equal("fOO <i>bAR</i>", res)
      end)
    end)

    describe("capitalize-all", function()
      it("lower", function()
        local foo = FormattedText.new("foo <i>bar</i>")
        foo:add_format("text-case", "capitalize-all")
        local res = foo:render(formatter, nil)
        assert.equal("Foo <i>Bar</i>", res)
      end)

      it("mixed", function()
        local foo = FormattedText.new("fOO <i>bAR</i>")
        foo:add_format("text-case", "capitalize-all")
        local res = foo:render(formatter, nil)
        assert.equal("fOO <i>bAR</i>", res)
      end)
    end)

    describe("sentence", function()
      it("uppercase", function()
        local foo = FormattedText.new("FOO <i>BAR</i>")
        foo:add_format("text-case", "sentence")
        local res = foo:render(formatter, nil)
        assert.equal("Foo <i>bar</i>", res)
      end)

      it("mixed", function()
        local foo = FormattedText.new("fOO <i>BAR</i>")
        foo:add_format("text-case", "sentence")
        local res = foo:render(formatter, nil)
        assert.equal("fOO <i>BAR</i>", res)
      end)
    end)

    describe("title", function()
      it("uppercase", function()
        local foo = FormattedText.new("FOO <i>BAR</i>")
        foo:add_format("text-case", "title")
        local res = foo:render(formatter, nil)
        assert.equal("Foo <i>Bar</i>", res)
      end)

      it("mixed", function()
        local foo = FormattedText.new("fOO <i>bar</i> bAZ")
        foo:add_format("text-case", "title")
        local res = foo:render(formatter, nil)
        assert.equal("fOO <i>Bar</i> bAZ", res)
      end)

      it("stop word first", function()
        local foo = FormattedText.new("THE FOO <i>BAR</i>")
        foo:add_format("text-case", "title")
        local res = foo:render(formatter, nil)
        assert.equal("The Foo <i>Bar</i>", res)
      end)

      it("stop word first", function()
        local foo = FormattedText.new("the foo: On <i>tHE bAR</i> Down")
        foo:add_format("text-case", "title")
        local res = foo:render(formatter, nil)
        assert.equal("The Foo: On <i>the bAR</i> Down", res)
      end)

      it("suppl", function()
        local foo = FormattedText.new("Supplément aux annales du Service des Antiquités de l'Égypte, Cahier")
        foo:add_format("text-case", "title")
        local res = foo:render(formatter, nil)
        assert.equal("Supplément Aux Annales Du Service Des Antiquités de l’Égypte, Cahier", res)
      end)

    end)

  end)

  it("concat text", function()
    local foo = FormattedText.new("foo")
    local bar = FormattedText.new("bar")
    local res = FormattedText.concat(foo, bar)
    res = res:render(formatter, nil)
    assert.equal("foobar", res)
  end)

  it("concat string", function()
    local foo = FormattedText.new("foo")
    local bar = "bar"
    local res = FormattedText.concat(foo, bar)
    res = res:render(formatter, nil)
    assert.equal("foobar", res)
  end)

  it("concat two strings", function()
    local foo = "foo"
    local bar = "bar"
    local res = FormattedText.concat(foo, bar)
    res = res:render(formatter, nil)
    assert.equal("foobar", res)
  end)

  it("concat text of space", function()
    local foo = FormattedText.new("foo")
    local bar = FormattedText.new(" ")
    local res = FormattedText.concat(foo, bar)
    res = res:render(formatter, nil)
    assert.equal("foo ", res)
  end)

  it("concat string of space", function()
    local foo = FormattedText.new("foo")
    local bar = " "
    local res = FormattedText.concat(foo, bar)
    res = res:render(formatter, nil)
    assert.equal("foo ", res)
  end)

  it("concat list of strings", function()
    local list = {"foo", "bar"}
    local res = FormattedText.concat_list(list, " ")
    res = res:render(formatter, nil)
    assert.equal("foo bar", res)
  end)

  it("strip periods", function()
    local foo = FormattedText.new("eds.")
    foo:strip_periods()
    local res = foo:render(formatter, nil)
    assert.equal("eds", res)
  end)

  it("add format", function()
    local foo = FormattedText.new("foo")
    foo:add_format("font-style", "italic")
    assert.equal("<i>foo</i>", foo:render(formatter, nil))
  end)

  it("flip-flop", function()
    local foo = FormattedText.new("foo<i>bar</i>baz")
    foo:add_format("font-style", "italic")
    assert.equal('<i>foo<span style="font-style:normal;">bar</span>baz</i>', foo:render(formatter, nil))
  end)

end)
