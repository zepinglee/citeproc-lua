local markup
local util

local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  kpse.set_program_name("luatex")
  local kpse_searcher = package.searchers[2]
  ---@diagnostic disable-next-line: duplicate-set-field
  package.searchers[2] = function (pkg_name)
    local pkg_file = package.searchpath(pkg_name, package.path)
    if pkg_file then
      return loadfile(pkg_file)
    end
    return kpse_searcher(pkg_name)
  end
  markup = require("citeproc-output")
  util = require("citeproc-util")
else
  markup = require("citeproc.output")
  util = require("citeproc.util")
end

InlineElement = markup.InlineElement
OutputFormat = markup.OutputFormat


describe("Inline elements", function ()

  describe("parsing", function ()

    it("italic", function ()
      -- flipflop_ItalicsSimple.txt
      local text = ""
      local expected = {}
      assert.same(expected, InlineElement:parse(text))
    end)

    it("italic", function ()
      -- flipflop_ItalicsSimple.txt
      local text = "One TwoA <i>Three Four</i> Five!"
      local expected = {
        markup.PlainText:new("One TwoA "),
        markup.Formatted:new({
          markup.PlainText:new("Three Four"),
        }, {["font-style"] = "italic"}),
        markup.PlainText:new(" Five!"),
      }
      assert.same(expected, InlineElement:parse(text))
    end)

    it("small caps 1", function ()
      -- flipflop_SmallCaps.txt
      local text = 'His <span style="font-variant:small-caps;">Anonymous</span> Life'
      local expected = {
        markup.PlainText:new("His "),
        markup.Formatted:new({
          markup.PlainText:new("Anonymous"),
        }, {["font-variant"] = "small-caps"}),
        markup.PlainText:new(" Life"),
      }
      assert.same(expected, InlineElement:parse(text))
    end)

    it("small caps 2", function ()
      -- textcase_ImplicitNocase.txt
      local text = "My <sc>small caps phrase</sc> in a title"
      local expected = {
        markup.PlainText:new("My "),
        markup.Formatted:new({
          markup.PlainText:new("small caps phrase"),
        }, {["font-variant"] = "small-caps"}),
        markup.PlainText:new(" in a title"),
      }
      assert.same(expected, InlineElement:parse(text))
    end)

    it("no case", function ()
      -- textcase_CapitalizeAll.txt
      local text = 'This IS a Pen that is a <span class="nocase">SMITH</span> Pencil'
      local expected = {
        markup.PlainText:new("This IS a Pen that is a "),
        markup.NoCase:new({markup.PlainText:new("SMITH")}),
        markup.PlainText:new(" Pencil"),
      }
      assert.same(expected, InlineElement:parse(text))
    end)

  end)

  describe("title case", function ()
    local plain_text_format = markup.PlainTextWriter:new()

    describe("APA", function ()
      -- From <https://apastyle.apa.org/style-grammar-guidelines/capitalization/title-case>

      it("1", function ()
        local inlines = InlineElement:parse(
          "Train your mind for peak performance: A science-based approach for achieving your goals", nil)
        plain_text_format:apply_text_case(inlines, "title", true)
        local res = plain_text_format:write_inlines(inlines, nil)
        -- assert.equal("Mnemonics That Work Are Better Than Rules That Do Not", res)
        assert.equal("Train Your Mind for Peak Performance: A Science-Based Approach for Achieving Your Goals", res)
      end)

      -- -- APA does not capitalize the words of four letters or more like "down".
      -- it("2", function ()
      --   local inlines = InlineElement:parse("Turning frowns (and smiles) upside down: A multilevel examination of surface acting positive and negative emotions on well-being", nil)
      --   plain_text_format:apply_text_case(inlines, "title", true)
      --   local res = plain_text_format:write_inlines(inlines, nil)
      --   assert.equal("Turning Frowns (and Smiles) Upside Down: A Multilevel Examination of Surface Acting Positive and Negative Emotions on Well-Being", res)
      -- end)

    end)

  end)

end)
