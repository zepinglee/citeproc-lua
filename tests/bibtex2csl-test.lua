kpse.set_program_name("texlua")

local kpse_searcher = package.searchers[2]
---@diagnostic disable-next-line: duplicate-set-field
package.searchers[2] = function (pkg_name)
  local pkg_file = package.searchpath(pkg_name, package.path)
  if pkg_file then
    return loadfile(pkg_file)
  end
  return kpse_searcher(pkg_name)
end


require("busted.runner")()

local bibtex2csl = require("citeproc-bibtex2csl")
local util = require("citeproc-util")


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
