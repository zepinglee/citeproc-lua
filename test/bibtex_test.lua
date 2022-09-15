require("busted.runner")()

kpse.set_program_name("luatex")

local kpse_searcher = package.searchers[2]
package.searchers[2] = function (name)
  local file, err = package.searchpath(name, package.path)
  if not err then
    return loadfile(file)
  end
  return kpse_searcher(name)
end


local bibtex = require("citeproc-bibtex")
local util = require("citeproc-util")


describe("Parsing AST", function ()

  it("entry", function ()
    local contents = [[
      @book{lamport86,
        author    = "Leslie Lamport",
        title     = "{\LaTeX{}} A Document
                     Preparation system",
        publisher = {Addison-Wesley},
        year      = 1986
      }
    ]]
    local res = bibtex.parse_bibtex_objects(contents)
    local expected = {
      {
        category = "entry",
        type = "book",
        key = "lamport86",
        fields = {
          author    = {"Leslie Lamport"},
          title     = {"{\\LaTeX{}} A Document Preparation system"},
          publisher = {"Addison-Wesley"},
          year      = {"1986"}
        },
      },
    }
    assert.same(expected, res)
  end)

  it("string command", function ()
    -- btxdoc.pdf, p. 2
    local contents = [[
      @STRING( WGA = " World Gnus Almanac" )
    ]]
    local res = bibtex.parse_bibtex_objects(contents)
    local expected = {
      {
        category = "string",
        name = "wga",
        contents = {
          " World Gnus Almanac",
        },
      },
    }
    assert.same(expected, res)
  end)

  it("string in field value", function ()
    -- btxdoc.pdf, p. 2
    local contents = [[
      @BOOK(almanac-66,
        title = 1966 # WGA,
      )
    ]]
    local res = bibtex.parse_bibtex_objects(contents)
    local expected = {
      {
        category = "entry",
        type = "book",
        key = "almanac-66",
        fields = {
          title = {
            "1966",
            {
              category = "string",
              name = "wga"
            },
          },
        },
      }
    }
    assert.same(expected, res)
  end)

  it("preamble command", function ()
    -- btxdoc.pdf, p. 4
    local contents = [[
      @PREAMBLE{ "\newcommand{\noopsort}[1]{} "
               # "\newcommand{\singleletter}[1]{#1} " }
    ]]
    local res = bibtex.parse_bibtex_objects(contents)
    local expected = {
      {
        category = "preamble",
        contents = {
          "\\newcommand{\\noopsort}[1]{} ",
          "\\newcommand{\\singleletter}[1]{#1} ",
        }
      }
    }
    assert.same(expected, res)
  end)

  -- describe("error report", function ()

  --   it("should throw an error", function ()
  --     local str = "@book{test\n foo=foo}"
  --     assert.has_error(function () bibtex.parse_bibtex_objects(str) end)
  --   end)

  -- end)

end)


describe("Parsing BibTeX data", function ()

  it("BibTeX entry", function ()
    local contents = [[
      @book{entry-key,
        Author = {Foo, Bar},
        title  = "Title",
        year   = 1984,
      }
    ]]
    local res = bibtex.parse_bibtex(contents)
    -- util.debug(res.entries[1])
    local expected = {
      preamble = "",
      strings = {},
      entries = {
        {
          type = "book",
          key = "entry-key",
          fields = {
            author = "Foo, Bar",
            title = "Title",
            year = "1984"
          },
        }
      }
    }
    assert.same(expected, res)
  end)

  it("spaces in field value", function ()
    local contents = [[
      @book{entry-key,
        title = {Foo  Bar},
        booktitle = {Foo
                     Bar},
      }
    ]]
    local res = bibtex.parse_bibtex(contents)
    local expected = {
      {
        type = "book",
        key = "entry-key",
        fields = {
          title = "Foo Bar",
          booktitle = "Foo Bar"
        },
      }
    }
    assert.same(expected, res.entries)
  end)

  it("string command", function ()
    -- btxdoc.pdf, p. 4
    local contents = [[
      @STRING( WGA = " World Gnus Almanac" )
    ]]
    local res = bibtex.parse_bibtex(contents)
    local expected = {
      preamble = "",
      entries = {},
      strings = {
        wga = " World Gnus Almanac"
      },
    }
    assert.same(expected, res)
  end)

  it("preamble command", function ()
    -- btxdoc.pdf, p. 4
    local contents = [[
      @PREAMBLE{ "\newcommand{\noopsort}[1]{} "
               # "\newcommand{\singleletter}[1]{#1} " }
    ]]
    local res = bibtex.parse_bibtex(contents)
    local expected = {
      preamble = "\\newcommand{\\noopsort}[1]{} \\newcommand{\\singleletter}[1]{#1} ",
      entries = {},
      strings = {},
    }
    assert.same(expected, res)
  end)

  it("string concatenation", function ()
    local contents = [[
      @STRING{STOC = " Symposium on the Theory of Computing"}
      @INPROCEEDINGS{inproceedings-full,
        booktitle = "Proc. Fifteenth Annual ACM" # STOC,
        month = mar # ", " # 1,
      }
    ]]
    local res = bibtex.parse_bibtex(contents)
    local expected = {
      {
        type = "inproceedings",
        key = "inproceedings-full",
        fields = {
          booktitle = "Proc. Fifteenth Annual ACM Symposium on the Theory of Computing",
          month = "3, 1",
        }
      },
    }
    assert.same(expected, res.entries)
  end)


  describe("convert LaTeX formats to HTML", function ()

    it("textbf", function ()
      local str = "foo \\textbf{bar} baz"
      local expected = 'foo <b><span class="nocase">bar</span></b> baz'
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("em", function ()
      local str = "foo {\\em bar} baz"
      local expected = "foo <i>bar</i> baz"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

  end)

  describe("converts to unicode", function ()

    it("with single symbol", function ()
      local str = "\\textexclamdown "
      local expected = "¡"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\`A "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\`{A} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\` A "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\` {A} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "{\\`A} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "{\\`{A}} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "{\\` A} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "{\\` {A}} "
      local expected = "À "
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\`\\i "
      local expected = "ì"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\` \\i "
      local expected = "ì"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\r ABC"
      local expected = "ÅBC"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with accented letter", function ()
      local str = "\\r{A}BC"
      local expected = "ÅBC"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with dot above", function ()
      local str = "\\.{}"
      local expected = "˙"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

    it("with dot above", function ()
      local str = "\\. {}"
      local expected = "˙"
      local res = bibtex.to_unicode(str)
      assert.same(expected, res)
    end)

  end)


  describe("error report", function ()

    it("should throw an error", function ()
      local str = "@book{test\n foo=foo}"
      assert.has_error(function () bibtex.parse(str) end)
    end)

  end)

end)


describe("CSL-JSON conversion", function ()

  describe("name parsing", function ()
    -- http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html

    describe("non-reversed name", function ()

      it("Testing simple case with no von.", function ()
        local res = bibtex.parse_single_name("AA BB")
        local expected = {
          given = "AA",
          family = "BB",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function ()
        local res = bibtex.parse_single_name("AA")
        local expected = {
          family = "AA",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function ()
        local res = bibtex.parse_single_name("AA bb")
        local expected = {
          given = "AA",
          family = "bb",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function ()
        local res = bibtex.parse_single_name("aa")
        local expected = {
          family = "aa",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von.", function ()
        local res = bibtex.parse_single_name("AA bb CC")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von (with inner uppercase words)", function ()
        local res = bibtex.parse_single_name("AA bb CC dd EE")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb CC dd",
          family = "EE",
        }
      end)

      it("Testing that digits are caseless (B fixes the case of 1B to uppercase).", function ()
        local res = bibtex.parse_single_name("AA 1B cc dd")
        local expected = {
          given = "AA 1B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      -- it("Testing that digits are caseless (b fixes the case of 1b to lowercase)", function ()
      --   local res = bibtex.parse_single_name("AA 1b cc dd")
      --   local expected = {
      --     given = "AA",
      --     ["non-dropping-particle"] = "1b cc",
      --     family = "dd",
      --   }
      --   assert.same(expected, res)
      -- end)

      it("Testing that pseudo letters are caseless.", function ()
        local res = bibtex.parse_single_name("AA {b}B cc dd")
        local expected = {
          given = "AA {b}B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      -- it("Testing that pseudo letters are caseless.", function ()
      --   local res = bibtex.parse_single_name("AA {b}b cc dd")
      --   local expected = {
      --     given = "AA",
      --     ["non-dropping-particle"] = "{b}b cc",
      --     family = "dd",
      --   }
      --   assert.same(expected, res)
      -- end)

      -- it("Testing that pseudo letters are caseless.", function ()
      --   local res = bibtex.parse_single_name("AA {B}b cc dd")
      --   local expected = {
      --     given = "AA",
      --     ["non-dropping-particle"] = "{B}b cc",
      --     family = "dd",
      --   }
      --   assert.same(expected, res)
      -- end)

      it("Testing that pseudo letters are caseless.", function ()
        local res = bibtex.parse_single_name("AA {B}B cc dd")
        local expected = {
          given = "AA {B}B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that non letters are case less (in particular show how latex command are considered).", function ()
        local res = bibtex.parse_single_name("AA \\BB{b} cc dd")
        local expected = {
          given = "AA \\BB{b}",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      -- it("Testing that non letters are case less (in particular show how latex command are considered).", function ()
      --   local res = bibtex.parse_single_name("AA \\bb{b} cc dd")
      --   local expected = {
      --     given = "AA",
      --     ["non-dropping-particle"] = "\\bb{b} cc",
      --     family = "dd",
      --   }
      --   assert.same(expected, res)
      -- end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
        local res = bibtex.parse_single_name("AA {bb} cc DD")
        local expected = {
          given = "AA {bb}",
          ["non-dropping-particle"] = "cc",
          family = "DD",
        }
        assert.same(expected, res)
      end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
        local res = bibtex.parse_single_name("AA bb {cc} DD")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "{cc} DD",
        }
        assert.same(expected, res)
      end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function ()
        local res = bibtex.parse_single_name("AA {bb} CC")
        local expected = {
          given = "AA {bb}",
          family = "CC",
        }
        assert.same(expected, res)
      end)

    end)


    describe("reversed name", function ()

      it("Simple case. Case do not matter for First.", function ()
        local res = bibtex.parse_single_name("bb CC, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Simple case. Case do not matter for First.", function ()
        local res = bibtex.parse_single_name("bb CC, aa")
        local expected = {
          given = "aa",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von (with inner uppercase).", function ()
        local res = bibtex.parse_single_name("bb CC dd EE, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb CC dd",
          family = "EE",
        }
        assert.same(expected, res)
      end)

      it("Testing that the Last part cannot be empty.", function ()
        local res = bibtex.parse_single_name("bb, AA")
        local expected = {
          given = "AA",
          family = "bb",
        }
        assert.same(expected, res)
      end)

      it("Testing that first can be empty after coma", function ()
        local res = bibtex.parse_single_name("BB,")
        local expected = {
          family = "BB",
        }
        assert.same(expected, res)
      end)

      it("Simple Jr. Case do not matter for it.", function ()
        local res = bibtex.parse_single_name("bb CC,XX, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
          suffix = "XX",
        }
        assert.same(expected, res)
      end)

      it("Simple Jr. Case do not matter for it.", function ()
        local res = bibtex.parse_single_name("bb CC,xx, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
          suffix = "xx",
        }
        assert.same(expected, res)
      end)

      it("Testing that jr can be empty in between comas.", function ()
        local res = bibtex.parse_single_name("BB,, AA")
        local expected = {
          given = "AA",
          family = "BB",
        }
        assert.same(expected, res)
      end)

    end)

  end)

  describe("date parsing", function ()

    it("single date", function ()
      local res = bibtex.parse_date("1992-08-11")
      local expected = {
        ["date-parts"] = {
          { 1992, 8, 11 },
        }
      }
      assert.same(expected, res)
    end)

    it("year", function ()
      local res = bibtex.parse_date("1992")
      local expected = {
        ["date-parts"] = {
          { 1992 },
        }
      }
      assert.same(expected, res)
    end)

    it("date range", function ()
      local res = bibtex.parse_date("1997-07-01/2017-07-01")
      local expected = {
        ["date-parts"] = {
          { 1997, 7, 1 },
          { 2017, 7, 1 },
        }
      }
      assert.same(expected, res)
    end)

    it("literal date", function ()
      local res = bibtex.parse_date("2003c")
      local expected = { literal = "2003c" }
      assert.same(expected, res)
    end)

    it("too many range parts", function ()
      local res = bibtex.parse_date("1992/08/11")
      local expected = { literal = "1992/08/11" }
      assert.same(expected, res)
    end)

  end)


end)


describe("Full BibTeX to CSL-JSON conversion", function ()

  it("full entry", function ()
    local contents = [[
      @article{key,
        author = {von Last, First and von Last, First, Jr},
        editor = {First de la Last and First de la Von Last},
        title = {One ``two'' “three” `four' ‘five’},
        date = {1999-01-01/2000-12-11},
        year = 1999,
        month = jul,
      }
    ]]
    local res = bibtex.parse(contents)
    local expected = {
      {
        author = {
          {
            family = "Last",
            given = "First",
            ["non-dropping-particle"] = "von"
          }, {
            family = "Last",
            given = "Jr",
            ["non-dropping-particle"] = "von",
            suffix = "First"
          }
        },
        editor = {
          {
            family = "Last",
            given = "First",
            ["non-dropping-particle"] = "de la"
          }, {
            family = "Von Last",
            given = "First",
            ["non-dropping-particle"] = "de la"
          }
        },
        id = "key",
        issued = {
          ["date-parts"] = { { 1999, 1, 1 }, { 2000, 12, 11 } }
        },
        title = "One “two” “three” ‘four’ ‘five’",
        type = "article-journal"
      }
    }
    assert.same(expected, res)
  end)

  it("hyphen in field name", function ()
    -- https://github.com/zepinglee/citeproc-lua/issues/18
    local contents = [[
      @article{Chen2008,
        abstract = {The myocardial tissue lacks significant intrinsic regenerative capability to replace the lost cells. Therefore, the heart is a major target of research within the field of tissue engineering, which aims to replace infarcted myocardium and enhance cardiac function. The primary objective of this work was to develop a biocompatible, degradable and superelastic heart patch from poly(glycerol sebacate) (PGS). PGS was synthesised at 110, 120 and 130 °C by polycondensation of glycerol and sebacic acid with a mole ratio of 1:1. The investigation was focused on the mechanical and biodegrading behaviours of the developed PGS. PGS materials synthesised at 110, 120 and 130 °C have Young's moduli of 0.056, 0.22 and 1.2 MPa, respectively, which satisfy the mechanical requirements on the materials applied for the heart patch and 3D myocardial tissue engineering construction. Degradation assessment in phosphate buffered saline and Knockout™ DMEM culture medium has demonstrated that the PGS has a wide range of degradability, from being degradable in a couple of weeks to being nearly inert. The matching of physical characteristics to those of the heart, the ability to fine tune degradation rates in biologically relevant media and initial data showing biocompatibility indicate that this material has promise for cardiac tissue engineering applications. {\textcopyright} 2007 Elsevier Ltd. All rights reserved.},
        author = {Chen, Qi-Zhi and Bismarck, Alexander and Hansen, Ulrich and Junaid, Sarah and Tran, Michael Q. and Harding, Si{\^{a}}n E. and Ali, Nadire N. and Boccaccini, Aldo R.},
        doi = {10.1016/j.biomaterials.2007.09.010},
        file = {::},
        isbn = {0142-9612},
        issn = {01429612},
        journal = {Biomaterials},
        keywords = {Biocompatibility,Degradation,Heart patch,Mechanical property,Myocardial tissue engineering,Poly(glycerol sebacate),human,rat},
        mendeley-tags = {human,rat},
        month = {jan},
        number = {1},
        pages = {47--57},
        pmid = {17915309},
        title = {{Characterisation of a soft elastomer poly(glycerol sebacate) designed to match the mechanical properties of myocardial tissue}},
        url = {http://linkinghub.elsevier.com/retrieve/pii/S0142961207007156},
        volume = {29},
        year = {2008}
      }
    ]]
    local res = bibtex.parse(contents)
    local expected = {
      {
        id = "Chen2008",
        type = "article-journal",
        DOI = "10.1016/j.biomaterials.2007.09.010",
        ISBN = "0142-9612",
        ISSN = "01429612",
        URL = "http://linkinghub.elsevier.com/retrieve/pii/S0142961207007156",
        abstract = "The myocardial tissue lacks significant intrinsic regenerative capability to replace the lost cells. Therefore, the heart is a major target of research within the field of tissue engineering, which aims to replace infarcted myocardium and enhance cardiac function. The primary objective of this work was to develop a biocompatible, degradable and superelastic heart patch from poly(glycerol sebacate) (PGS). PGS was synthesised at 110, 120 and 130 °C by polycondensation of glycerol and sebacic acid with a mole ratio of 1:1. The investigation was focused on the mechanical and biodegrading behaviours of the developed PGS. PGS materials synthesised at 110, 120 and 130 °C have Young’s moduli of 0.056, 0.22 and 1.2 MPa, respectively, which satisfy the mechanical requirements on the materials applied for the heart patch and 3D myocardial tissue engineering construction. Degradation assessment in phosphate buffered saline and Knockout™ DMEM culture medium has demonstrated that the PGS has a wide range of degradability, from being degradable in a couple of weeks to being nearly inert. The matching of physical characteristics to those of the heart, the ability to fine tune degradation rates in biologically relevant media and initial data showing biocompatibility indicate that this material has promise for cardiac tissue engineering applications. © 2007 Elsevier Ltd. All rights reserved.",
        author = { {
            family = "Chen",
            given = "Qi-Zhi"
          }, {
            family = "Bismarck",
            given = "Alexander"
          }, {
            family = "Hansen",
            given = "Ulrich"
          }, {
            family = "Junaid",
            given = "Sarah"
          }, {
            family = "Tran",
            given = "Michael Q."
          }, {
            family = "Harding",
            given = "Siân E."
          }, {
            family = "Ali",
            given = "Nadire N."
          }, {
            family = "Boccaccini",
            given = "Aldo R."
          } },
        ["container-title"] = "Biomaterials",
        issue = "1",
        issued = {
          ["date-parts"] = { { 2008 } }
        },
        page = "47-57",
        title = '<span class="nocase">Characterisation of a soft elastomer poly(glycerol sebacate) designed to match the mechanical properties of myocardial tissue</span>',
        volume = "29"
      }
    }
    assert.same(expected, res)
  end)

  it("underscore in field name", function ()
    -- https://github.com/zepinglee/citeproc-lua/issues/22
    local contents = [[
      @incollection{haltest,
        TITLE={{A tale of two funerary traditons: the predynastic cemetery at Kom el-Khilgan (eastern delta)}},
        AUTHOR={Buchez, N. and Midant-Reynes, B.},
        URL={https://hal.archives-ouvertes.fr/hal-03186401},
        BOOKTITLE={{Egypt and its Origins 3. Proceedings of the Third International Conference ''Origin of the State. Predynastic and Early Dynastic Egypt'', London, 27th July-1st August 2008}},
        EDITOR={Ren{\'e}e F. Friedman and Peter N. Fiske},
        PUBLISHER={{Peeters}},
        SERIES={Orientalia Lovaniensia Analecta},
        VOLUME={205},
        PAGES={831--858},
        YEAR={2011},
        HAL_ID={hal-03186401},
        HAL_VERSION={v1},
      }
    ]]
    local res = bibtex.parse(contents)
    local expected = {
      {
        URL = "https://hal.archives-ouvertes.fr/hal-03186401",
        author = { {
            family = "Buchez",
            given = "N."
          }, {
            family = "Midant-Reynes",
            given = "B."
          } },
        ["collection-title"] = "Orientalia Lovaniensia Analecta",
        ["container-title"] = '<span class="nocase">Egypt and its Origins 3. Proceedings of the Third International Conference ”Origin of the State. Predynastic and Early Dynastic Egypt”, London, 27th July-1st August 2008</span>',
        editor = { {
            family = "Friedman",
            given = "Renée F."
          }, {
            family = "Fiske",
            given = "Peter N."
          } },
        id = "haltest",
        issued = {
          ["date-parts"] = { { 2011 } }
        },
        page = "831-858",
        publisher = '<span class="nocase">Peeters</span>',
        title = '<span class="nocase">A tale of two funerary traditons: the predynastic cemetery at Kom el-Khilgan (eastern delta)</span>',
        type = "chapter",
        volume = "205"
      }
    }
    assert.same(expected, res)
  end)

end)
