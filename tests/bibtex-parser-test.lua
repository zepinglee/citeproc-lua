local bibtex_parser
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
  bibtex_parser = require("citeproc-bibtex-parser")
  util = require("citeproc-util")
else
  bibtex_parser = require("citeproc.bibtex-parser")
  util = require("citeproc.util")
end


describe("BibTeX parser", function ()

  describe("parse entries", function ()

    it("entry", function ()
      local bib = [[
        @book{lamport86,
          author    = "Leslie Lamport",
          title     = "{\LaTeX{}} A Document
                      Preparation system",
          publisher = {Addison-Wesley},
          year      = 1986
        }
      ]]
      local res = bibtex_parser.parse(bib)
      local expected = {
        {
          type = "book",
          key = "lamport86",
          fields = {
            author    = "Leslie Lamport",
            title     = "{\\LaTeX{}} A Document Preparation system",
            publisher = "Addison-Wesley",
            year      = "1986"
          },
        },
      }
      assert.same(expected, res.entries)
    end)

    it("with string concatenation", function ()
      local contents = [[
        @STRING( WGA = " World Gnus Almanac" )
        @BOOK(almanac-66,
          title = 1966 # WGA,
        )
      ]]
      local res = bibtex_parser.parse(contents)
      local expected = {
        {
          type = "book",
          key = "almanac-66",
          fields = {
            title = "1966 World Gnus Almanac",
          },
        }
      }
      assert.same(expected, res.entries)
    end)

  end)

  describe("parse @string commands", function ()

    it("string command", function ()
      -- btxdoc.pdf, p. 2
      local bib = [[
        @STRING( WGA = " World Gnus Almanac" )
      ]]
      local res = bibtex_parser.parse(bib)
      local expected = {
        wga = " World Gnus Almanac",
      }
      assert.same(expected, res.strings)
    end)

  end)

  describe("parse @preamble commands", function ()

    it("preamble command", function ()
      -- btxdoc.pdf, p. 4
      local contents = [[
        @PREAMBLE{ "\newcommand{\noopsort}[1]{} "
                # "\newcommand{\singleletter}[1]{#1} " }
      ]]
      local res = bibtex_parser.parse(contents)
      local expected = "\\newcommand{\\noopsort}[1]{} \\newcommand{\\singleletter}[1]{#1} "
      assert.same(expected, res.preamble)
    end)

  end)

  describe("splits names", function ()

    it("", function ()
      assert.same(
        {
          "Goossens, Michel",
          "Mittelbach, Franck",
          "Samarin, Alexander",
        },
        bibtex_parser.split_names("Goossens, Michel and Mittelbach, Franck and Samarin, Alexander")
      )
    end)

    it("with braces", function ()
      assert.same(
        {
          "Foo",
          "{Bar and Baz}"
        },
        bibtex_parser.split_names("Foo and {Bar and Baz}")
      )
    end)

    it("empty", function ()
      assert.same(
        {},
        bibtex_parser.split_names("")
      )
    end)

    it("with and- prefix", function ()
      assert.same(
        {
          "Foo Andes",
        },
        bibtex_parser.split_names("Foo Andes")
      )
    end)

    it("starting with and", function ()
      assert.same(
        {
          "Foo",
        },
        bibtex_parser.split_names("and Foo")
      )
    end)

    it("starting with and", function ()
      assert.same(
        {
          "Foo",
        },
        bibtex_parser.split_names(" and Foo")
      )
    end)

    it("ending with and", function ()
      -- BibTeX actually produces {"and"}
      assert.same(
        {
          "Foo",
        },
        bibtex_parser.split_names("Foo and")
      )
    end)

    it("ending with and", function ()
      assert.same(
        {
          "Foo",
        },
        bibtex_parser.split_names("Foo and ")
      )
    end)

    it("ending with and", function ()
      assert.same(
        {
          "Foo,",
          "Bar",
        },
        bibtex_parser.split_names("Foo, and Bar")
      )
    end)

  end)

  describe("splits name parts", function ()

    it("with first form", function ()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
        },
        bibtex_parser.split_name_parts("First von Last")
      )
    end)

    it("with second form", function ()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
        },
        bibtex_parser.split_name_parts("von Last, First")
      )
    end)

    it("with third form", function ()
      assert.same(
        {
          first = "First",
          von = "von",
          last = "Last",
          jr = "Jr",
        },
        bibtex_parser.split_name_parts("von Last, Jr, First")
      )
    end)

    it("literal", function ()
      assert.same(
        {
          last = "{World Health Organization}",
        },
        bibtex_parser.split_name_parts("{World Health Organization}")
      )
    end)

    it("example 1", function ()
      assert.same(
        {
          first = "Per",
          last = "Brinch Hansen",
        },
        bibtex_parser.split_name_parts("Brinch Hansen, Per")
      )
    end)

    it("example 1 mistake", function ()
      assert.same(
        {
          first = "Per Brinch",
          last = "Hansen",
        },
        bibtex_parser.split_name_parts("Per Brinch Hansen")
      )
    end)

    it("example 2", function ()
      assert.same(
        {
          first = "Charles Louis Xavier Joseph",
          von = "de la",
          last = "Vall{\\'e}e Poussin",
        },
        bibtex_parser.split_name_parts("Charles Louis Xavier Joseph de la Vall{\\'e}e Poussin")
      )
    end)

    it("with hyphen in last name", function ()
      assert.same(
        {
          first = "F. Phidias",
          last = "Phony-Baloney",
        },
        bibtex_parser.split_name_parts("F. Phidias Phony-Baloney")
      )
    end)

    it('with conbinations of format "First von Last" in sec. 11 of ttb', function ()

      assert.same(
        {
          von = "jean de la",
          last = "fontaine",
        },
        bibtex_parser.split_name_parts("jean de la fontaine")
      )

      assert.same(
        {
          first = "Jean",
          von = "de la",
          last = "fontaine",
        },
        bibtex_parser.split_name_parts("Jean de la fontaine")
      )

      assert.same(
        {
          first = "Jean {de}",
          von = "la",
          last = "fontaine",
        },
        bibtex_parser.split_name_parts("Jean {de} la fontaine")
      )

      assert.same(
        {
          von = "jean",
          last = "{de} {la} fontaine",
        },
        bibtex_parser.split_name_parts("jean {de} {la} fontaine")
      )

      assert.same(
        {
          first = "Jean {de} {la}",
          last = "fontaine",
        },
        bibtex_parser.split_name_parts("Jean {de} {la} fontaine")
      )

      assert.same(
        {
          first = "Jean De La",
          last = "Fontaine",
        },
        bibtex_parser.split_name_parts("Jean De La Fontaine")
      )

      assert.same(
        {
          von = "jean De la",
          last = "Fontaine",
        },
        bibtex_parser.split_name_parts("jean De la Fontaine")
      )

      assert.same(
        {
          first = "Jean",
          von = "de",
          last = "La Fontaine",
        },
        bibtex_parser.split_name_parts("Jean de La Fontaine")
      )

    end)

    -- http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html
    describe("in test suite", function ()

      describe("for the first name specification form First von Last", function ()

        it("Testing simple case with no von.", function ()
          assert.same(
            {
              first = "AA",
              last = "BB",
            },
            bibtex_parser.split_name_parts("AA BB")
          )
        end)

        it("Testing that Last cannot be empty.", function ()
          assert.same(
            {
              last = "AA",
            },
            bibtex_parser.split_name_parts("AA")
          )
        end)

        it("Testing that Last cannot be empty.", function ()
          assert.same(
            {
              first = "AA",
              last = "bb",
            },
            bibtex_parser.split_name_parts("AA bb")
          )
        end)

        it("Testing that Last cannot be empty.", function ()
          assert.same(
            {
              last = "aa",
            },
            bibtex_parser.split_name_parts("aa")
          )
        end)

        it("Testing simple von.", function ()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
            },
            bibtex_parser.split_name_parts("AA bb CC")
          )
        end)

        it("Testing simple von (with inner uppercase words)", function ()
          assert.same(
            {
              first = "AA",
              von = "bb CC dd",
              last = "EE",
            },
            bibtex_parser.split_name_parts("AA bb CC dd EE")
          )
        end)

        it("Testing that digits are caseless (B fixes the case of 1B to uppercase).", function ()
          assert.same(
            {
              first = "AA 1B",
              von = "cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA 1B cc dd")
          )
        end)

        it("Testing that digits are caseless (b fixes the case of 1b to lowercase)", function ()
          assert.same(
            {
              first = "AA",
              von = "1b cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA 1b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function ()
          assert.same(
            {
              first = "AA {b}B",
              von = "cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA {b}B cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function ()
          assert.same(
            {
              first = "AA",
              von = "{b}b cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA {b}b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function ()
          assert.same(
            {
              first = "AA",
              von = "{B}b cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA {B}b cc dd")
          )
        end)

        it("Testing that pseudo letters are caseless.", function ()
          assert.same(
            {
              first = "AA {B}B",
              von = "cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA {B}B cc dd")
          )
        end)

        it("Testing that non letters are case less (in particular show how latex command are considered).", function ()
          assert.same(
            {
              first = "AA \\BB{b}",
              von = "cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA \\BB{b} cc dd")
          )
        end)

        it("Testing that non letters are case less (in particular show how latex command are considered).", function ()
          assert.same(
            {
              first = "AA",
              von = "\\bb{b} cc",
              last = "dd",
            },
            bibtex_parser.split_name_parts("AA \\bb{b} cc dd")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
          assert.same(
            {
              first = "AA {bb}",
              von = "cc",
              last = "DD",
            },
            bibtex_parser.split_name_parts("AA {bb} cc DD")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "{cc} DD",
            },
            bibtex_parser.split_name_parts("AA bb {cc} DD")
          )
        end)

        it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
          assert.same(
            {
              first = "AA {bb}",
              last = "CC",
            },
            bibtex_parser.split_name_parts("AA {bb} CC")
          )
        end)

      end)


      describe("for the second,third specification form von Last First", function ()

        it("Simple case. Case do not matter for First.", function ()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
            },
            bibtex_parser.split_name_parts("bb CC, AA")
          )
        end)

        it("Simple case. Case do not matter for First.", function ()
          assert.same(
            {
              first = "aa",
              von = "bb",
              last = "CC",
            },
            bibtex_parser.split_name_parts("bb CC, aa")
          )
        end)

        it("Testing simple von (with inner uppercase).", function ()
          assert.same(
            {
              first = "AA",
              von = "bb CC dd",
              last = "EE",
            },
            bibtex_parser.split_name_parts("bb CC dd EE, AA")
          )
        end)

        it("Testing that the Last part cannot be empty.", function ()
          assert.same(
            {
              first = "AA",
              last = "bb",
            },
            bibtex_parser.split_name_parts("bb, AA")
          )
        end)

        it("Testing that first can be empty after coma", function ()
          assert.same(
            {
              last = "BB",
            },
            bibtex_parser.split_name_parts("BB,")
          )
        end)

        it("Simple Jr. Case do not matter for it.", function ()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
              jr = "XX",
            },
            bibtex_parser.split_name_parts("bb CC,XX, AA")
          )
        end)

        it("Simple Jr. Case do not matter for it.", function ()
          assert.same(
            {
              first = "AA",
              von = "bb",
              last = "CC",
              jr = "xx",
            },
            bibtex_parser.split_name_parts("bb CC,xx, AA")
          )
        end)

        it("Testing that jr can be empty in between comas.", function ()
          assert.same(
            {
              first = "AA",
              last = "BB",
            },
            bibtex_parser.split_name_parts("BB, , AA")
          )
        end)

      end)

      it("further remarks", function ()

        assert.same(
          {
            first = "Paul \\'Emile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Paul \\'Emile Victor")
        )

        assert.same(
          {
            first = "Paul {\\'E}mile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Paul {\\'E}mile Victor")
        )

        assert.same(
          {
            first = "Paul",
            von = "\\'emile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Paul \\'emile Victor")
        )

        assert.same(
          {
            first = "Paul",
            von = "{\\'e}mile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Paul {\\'e}mile Victor")
        )

        assert.same(
          {
            first = "Paul \\'Emile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Victor, Paul \\'Emile")
        )

        assert.same(
          {
            first = "Paul {\\'E}mile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Victor, Paul {\\'E}mile")
        )

        assert.same(
          {
            first = "Paul \\'emile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Victor, Paul \\'emile")
        )

        assert.same(
          {
            first = "Paul {\\'e}mile",
            last = "Victor",
          },
          bibtex_parser.split_name_parts("Victor, Paul {\\'e}mile")
        )

        assert.same(
          {
            first = "Dominique Galouzeau",
            von = "de",
            last = "Villepin",
          },
          bibtex_parser.split_name_parts("Dominique Galouzeau de Villepin")
        )

        assert.same(
          {
            first = "Dominique",
            von = "{G}alouzeau de",
            last = "Villepin",
          },
          bibtex_parser.split_name_parts("Dominique {G}alouzeau de Villepin")
        )

        assert.same(
          {
            first = "Dominique",
            von = "Galouzeau de",
            last = "Villepin",
          },
          bibtex_parser.split_name_parts("Galouzeau de Villepin, Dominique")
        )

      end)

    end)

    describe("biblatex extended name format", function ()
      local names = {
        {
          "given=Hans, family=Harman and given=Simon, prefix=de, family=Beumont",
          {
            {
              last = "Harman",
              first = "Hans",
            },
            {
              last = "Beumont",
              first = "Simon",
              von = "de",
            },
          },
        },
        {
          "given=Jean, prefix=de la, prefix-i=d, family=Rousse",
          {
            {
              last = "Rousse",
              first = "Jean",
              von = "de la",
              ["von-i"] = "d"
            }
          }
        },
        {
          "given={Jean Pierre Simon}, given-i=JPS",
          {
            {
              first = "Jean Pierre Simon",
              ["first-i"] = "JPS"
            }
          }
        },
        {
          '"family={Robert and Sons, Inc.}"',
          {
            {
              last = "Robert and Sons, Inc.",
            }
          }
        },
        {
          "Hans Harman and given=Simon, prefix=de, family=Beumont",
          {
            {
              last = "Harman",
              first = "Hans",
            },
            {
              last = "Beumont",
              first = "Simon",
              von = "de",
            },
          }
        },
      }
      for _, name_str_pair in ipairs(names) do
        local name_str, name_list = table.unpack(name_str_pair)
        it(name_str, function ()
          local parsed_names = bibtex_parser.split_names(name_str)
          local parsed_name_parts = {}
          for i, parsed_name in ipairs(parsed_names) do
            parsed_name_parts[i] = bibtex_parser.split_name_parts(parsed_name)
          end
          assert.same(name_list, parsed_name_parts)
        end)
      end
    end)

  end)

end)
