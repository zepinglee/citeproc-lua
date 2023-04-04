local markup 
local util 

if kpse then
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

  describe("title case", function ()
    local plain_text_format = markup.PlainTextWriter:new()

    describe("APA", function ()
      -- From <https://apastyle.apa.org/style-grammar-guidelines/capitalization/title-case>

      it("1", function ()
        local inlines = InlineElement:parse("Train your mind for peak performance: A science-based approach for achieving your goals", nil)
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
