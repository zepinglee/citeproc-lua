local bibtex2csl
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
  bibtex2csl = require("citeproc-bibtex2csl")
  util = require("citeproc-util")
else
  bibtex2csl = require("citeproc.bibtex2csl")
  util = require("citeproc.util")
end


describe("BibTeX data to CSL converter", function ()

  describe("name", function ()

    it("suffix", function ()
      local name = "Bennett, Jr., Frank G."
      local _, csl_name = bibtex2csl.convert_field("author", name, true, true, true, "en-US", true)
      local expected = {
        {
          family = "Bennett",
          given = "Frank G.",
          suffix = "Jr.",
        },
      }
      assert.same(expected, csl_name)
    end)

    it("literal", function ()
      local name = "{World Health Organization}"
      local _, csl_name = bibtex2csl.convert_field("author", name, true, true, true, "en-US", true)
      local expected = {
        {
          literal = "World Health Organization",
        },
      }
      assert.same(expected, csl_name)
    end)

  end)

  describe("title", function ()

    it("math", function ()
      local title = "A study of the excited {1$\\Sigma$g+} states in {Na2}"
      local _, csl_title = bibtex2csl.convert_field("title", title, true, true, true, "en-US", true)
      local expected = 'A study of the excited <span class="nocase">1<math-tex>\\Sigma</math-tex>g+</span> states in <span class="nocase">Na2</span>'
      assert.same(expected, csl_title)
    end)

  end)

  it("entry", function ()
    local contents = [[
      @book{lamport86,
        author    = "Leslie Lamport",
        title     = "LaTeX: A Document
                     Preparation System",
        publisher = {Addison-Wesley},
        year      = 1986
      }
    ]]
    local res = bibtex2csl.parse_bibtex_to_csl(contents, true, true, true, true)
    local expected = {
      {
        id = "lamport86",
        type = "book",
        author = {
          {
            family = "Lamport",
            given  = "Leslie",
          },
        },
        issued = {
          ["date-parts"] = {
            { 1986 },
          },
        },
        publisher = "Addison-Wesley",
        title = "LaTeX: A document preparation system",
      },
    }
    assert.same(expected, res)
  end)
end)
