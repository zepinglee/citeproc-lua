kpse.set_program_name("luatex")

local kpse_searcher = package.searchers[2]
---@diagnostic disable-next-line: duplicate-set-field
package.searchers[2] = function(name)
  local file, err = package.searchpath(name, package.path)
  if not err then
    return loadfile(file)
  end
  return kpse_searcher(name)
end


require("busted.runner")()
local bibtex_parser = require("citeproc-bibtex-parser")
local BibtexParser = bibtex_parser.BibtexParser
local util = require("citeproc-util")


describe("BibTeX-parser", function()
  -- http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html

  describe("splits names", function()

    it("", function()
      assert.same(
        {
          "Goossens, Michel",
          "Mittelbach, Franck",
          "Samarin, Alexander",
        },
        BibtexParser:_split_names("Goossens, Michel and Mittelbach, Franck and Samarin, Alexander")
      )
    end)

    it("with braces", function()
      assert.same(
        {
          "Foo",
          "{Bar and Baz}"
        },
        BibtexParser:_split_names("Foo and {Bar and Baz}")
      )
    end)

    it("empty", function()
      assert.same(
        {},
        BibtexParser:_split_names("")
      )
    end)

    it("with and- prefix", function()
      assert.same(
        {
          "Foo Andes",
        },
        BibtexParser:_split_names("Foo Andes")
      )
    end)

    it("starting with and", function()
      assert.same(
        {
          "Foo",
        },
        BibtexParser:_split_names("and Foo")
      )
    end)

    it("starting with and", function()
      assert.same(
        {
          "Foo",
        },
        BibtexParser:_split_names(" and Foo")
      )
    end)

    it("ending with and", function()
      -- BibTeX actually produces {"and"}
      assert.same(
        {
          "Foo",
        },
        BibtexParser:_split_names("Foo and")
      )
    end)

    it("ending with and", function()
      assert.same(
        {
          "Foo",
        },
        BibtexParser:_split_names("Foo and ")
      )
    end)

    it("ending with and", function()
      assert.same(
        {
          "Foo,",
          "Bar",
        },
        BibtexParser:_split_names("Foo, and Bar")
      )
    end)

  end)

  describe("splits name parts", function()

    it("with first form", function()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
        },
        BibtexParser:_split_name_parts("First von Last")
      )
    end)

    it("with second form", function()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
        },
        BibtexParser:_split_name_parts("von Last, First")
      )
    end)

    it("with third form", function()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
          jr = "Jr",
        },
        BibtexParser:_split_name_parts("von Last, Jr, First")
      )
    end)

    it("example 1", function()
      assert.same(
        {
          first = "Per",
          last = "Brinch Hansen",
        },
        BibtexParser:_split_name_parts("Brinch Hansen, Per")
      )
    end)

    it("example 1 mistake", function()
      assert.same(
        {
          first = "Per Brinch",
          last = "Hansen",
        },
        BibtexParser:_split_name_parts("Per Brinch Hansen")
      )
    end)

    it("example 2", function()
      assert.same(
        {
          first = "Charles Louis Xavier Joseph",
          von = "de la",
          last = "Vall{\\'e}e Poussin",
        },
        BibtexParser:_split_name_parts("Charles Louis Xavier Joseph de la Vall{\\'e}e Poussin")
      )
    end)

    it('with conbinations of format "First von Last" in sec. 11 of ttb', function()

      assert.same(
        {
          von = "jean de la",
          last = "fontaine",
        },
        BibtexParser:_split_name_parts("jean de la fontaine")
      )

      assert.same(
        {
          first = "Jean",
          von = "de la",
          last = "fontaine",
        },
        BibtexParser:_split_name_parts("Jean de la fontaine")
      )

      assert.same(
        {
          first = "Jean {de}",
          von = "la",
          last = "fontaine",
        },
        BibtexParser:_split_name_parts("Jean {de} la fontaine")
      )

      assert.same(
        {
          von = "jean",
          last = "{de} {la} fontaine",
        },
        BibtexParser:_split_name_parts("jean {de} {la} fontaine")
      )

      assert.same(
        {
          first = "Jean {de} {la}",
          last = "fontaine",
        },
        BibtexParser:_split_name_parts("Jean {de} {la} fontaine")
      )

      assert.same(
        {
          first = "Jean De La",
          last = "Fontaine",
        },
        BibtexParser:_split_name_parts("Jean De La Fontaine")
      )

      assert.same(
        {
          von = "jean De la",
          last = "Fontaine",
        },
        BibtexParser:_split_name_parts("jean De la Fontaine")
      )

      assert.same(
        {
          first = "Jean",
          von = "de",
          last = "La Fontaine",
        },
        BibtexParser:_split_name_parts("Jean de La Fontaine")
      )

    end)

    describe("in test suite", function()

      describe("for the first name specification form First von Last", function()

        it("Testing simple case with no von.", function()
          assert.same(
            {
              first = "AA",
              last = "BB",
            },
            BibtexParser:_split_name_parts("AA BB")
          )
        end)

        it("Testing that Last cannot be empty.", function()
          assert.same(
            {
              last = "AA",
            },
            BibtexParser:_split_name_parts("AA")
          )
        end)

        it("Testing that Last cannot be empty.", function()
          assert.same(
            {
              first = "AA",
              last = "bb",
            },
            BibtexParser:_split_name_parts("AA bb")
          )
        end)

        it("Testing that Last cannot be empty.", function()
          assert.same(
            {
              last = "aa",
            },
            BibtexParser:_split_name_parts("aa")
          )
        end)

        it("Testing simple von.", function()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
            },
            BibtexParser:_split_name_parts("AA bb CC")
          )
        end)

        it("Testing simple von (with inner uppercase words)", function()
          assert.same(
            {
              first = "AA",
              von = "bb CC dd",
              last = "EE",
            },
            BibtexParser:_split_name_parts("AA bb CC dd EE")
          )
        end)

        it("Testing that digits are caseless (B fixes the case of 1B to uppercase).", function()
          assert.same(
            {
              first = "AA 1B",
              von = "cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA 1B cc dd")
          )
        end)

        it("Testing that digits are caseless (b fixes the case of 1b to lowercase)", function()
          assert.same(
            {
              first = "AA",
              von = "1b cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA 1b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function()
          assert.same(
            {
              first = "AA {b}B",
              von = "cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA {b}B cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function()
          assert.same(
            {
              first = "AA",
              von = "{b}b cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA {b}b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function()
          assert.same(
            {
              first = "AA",
              von = "{B}b cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA {B}b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function()
          assert.same(
            {
              first = "AA {B}B",
              von = "cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA {B}B cc dd")
          )
        end)

        it("Testing that non letters are case less (in particular show how latex command are considered).", function()
          assert.same(
            {
              first = "AA \\BB{b}",
              von = "cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA \\BB{b} cc dd")
          )
        end)

        it("Testing that non letters are case less (in particular show how latex command are considered).", function()
          assert.same(
            {
              first = "AA",
              von = "\\bb{b} cc",
              last = "dd",
            },
            BibtexParser:_split_name_parts("AA \\bb{b} cc dd")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
          assert.same(
            {
              first = "AA {bb}",
              von = "cc",
              last = "DD",
            },
            BibtexParser:_split_name_parts("AA {bb} cc DD")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "{cc} DD",
            },
            BibtexParser:_split_name_parts("AA bb {cc} DD")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
          assert.same(
            {
              first = "AA {bb}",
              last = "CC",
            },
            BibtexParser:_split_name_parts("AA {bb} CC")
          )
        end)

      end)


      describe("for the second,third specification form von Last First", function()

        it("Simple case. Case do not matter for First.", function()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
            },
            BibtexParser:_split_name_parts("bb CC, AA")
          )
        end)

        it("Simple case. Case do not matter for First.", function()
          assert.same(
            {
              first = "aa",
              von = "bb",
              last = "CC",
            },
            BibtexParser:_split_name_parts("bb CC, aa")
          )
        end)

        it("Testing simple von (with inner uppercase).", function()
          assert.same(
            {
              first = "AA",
              von = "bb CC dd",
              last = "EE",
            },
            BibtexParser:_split_name_parts("bb CC dd EE, AA")
          )
        end)

        it("Testing that the Last part cannot be empty.", function()
          assert.same(
            {
              first = "AA",
              last = "bb",
            },
            BibtexParser:_split_name_parts("bb, AA")
          )
        end)

        it("Testing that first can be empty after coma", function()
          assert.same(
            {
              last = "BB",
            },
            BibtexParser:_split_name_parts("BB,")
          )
        end)

        it("Simple Jr. Case do not matter for it.", function()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
              jr = "XX",
            },
            BibtexParser:_split_name_parts("bb CC,XX, AA")
          )
        end)

        it("Simple Jr. Case do not matter for it.", function()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
              jr = "xx",
            },
            BibtexParser:_split_name_parts("bb CC,xx, AA")
          )
        end)

        it("Testing that jr can be empty in between comas.", function()
          assert.same(
            {
              first = "AA",
              last = "BB",
            },
            BibtexParser:_split_name_parts("BB, , AA")
          )
        end)

      end)

    end)

  end)

end)
