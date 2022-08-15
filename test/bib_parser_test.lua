require("busted.runner")()

kpse.set_program_name("luatex")

local kpse_searcher = package.searchers[2]
package.searchers[2] = function(name)
  local file, err = package.searchpath(name, package.path)
  if not err then
    return loadfile(file)
  end
  return kpse_searcher(name)
end


local bib = require("citeproc-bib")
local util = require("citeproc-util")


describe("BibParser", function()

  it("bib entry", function()
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
    local res = bib.parse(contents)
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
        title = "One ``two'' “three” `four' ‘five’",
        type = "article-journal"
      }
    }
    assert.same(expected, res)
  end)

  describe("parse single name", function()
    -- http://maverick.inria.fr/~Xavier.Decoret/resources/xdkbibtex/bibtex_summary.html

    describe("non-reversed name", function()

      it("Testing simple case with no von.", function()
        local res = bib.parse_single_name("AA BB")
        local expected = {
          given = "AA",
          family = "BB",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function()
        local res = bib.parse_single_name("AA")
        local expected = {
          family = "AA",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function()
        local res = bib.parse_single_name("AA bb")
        local expected = {
          given = "AA",
          family = "bb",
        }
        assert.same(expected, res)
      end)

      it("Testing that Last cannot be empty.", function()
        local res = bib.parse_single_name("aa")
        local expected = {
          family = "aa",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von.", function()
        local res = bib.parse_single_name("AA bb CC")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von (with inner uppercase words)", function()
        local res = bib.parse_single_name("AA bb CC dd EE")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb CC dd",
          family = "EE",
        }
      end)

      it("Testing that digits are caseless (B fixes the case of 1B to uppercase).", function()
        local res = bib.parse_single_name("AA 1B cc dd")
        local expected = {
          given = "AA 1B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that digits are caseless (b fixes the case of 1b to lowercase)", function()
        local res = bib.parse_single_name("AA 1b cc dd")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "1b cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that pseudo letters are caseless.", function()
        local res = bib.parse_single_name("AA {b}B cc dd")
        local expected = {
          given = "AA {b}B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that pseudo letters are caseless.", function()
        local res = bib.parse_single_name("AA {b}b cc dd")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "{b}b cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that pseudo letters are caseless.", function()
        local res = bib.parse_single_name("AA {B}b cc dd")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "{B}b cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that pseudo letters are caseless.", function()
        local res = bib.parse_single_name("AA {B}B cc dd")
        local expected = {
          given = "AA {B}B",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that non letters are case less (in particular show how latex command are considered).", function()
        local res = bib.parse_single_name("AA \\BB{b} cc dd")
        local expected = {
          given = "AA \\BB{b}",
          ["non-dropping-particle"] = "cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that non letters are case less (in particular show how latex command are considered).", function()
        local res = bib.parse_single_name("AA \\bb{b} cc dd")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "\\bb{b} cc",
          family = "dd",
        }
        assert.same(expected, res)
      end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
        local res = bib.parse_single_name("AA {bb} cc DD")
        local expected = {
          given = "AA {bb}",
          ["non-dropping-particle"] = "cc",
          family = "DD",
        }
        assert.same(expected, res)
      end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
        local res = bib.parse_single_name("AA bb {cc} DD")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "{cc} DD",
        }
        assert.same(expected, res)
      end)

      it("Testing that caseless words are grouped with First primilarily and then with Last.", function()
        local res = bib.parse_single_name("AA {bb} CC")
        local expected = {
          given = "AA {bb}",
          family = "CC",
        }
        assert.same(expected, res)
      end)

    end)

    describe("reversed name", function()

      it("Simple case. Case do not matter for First.", function()
        local res = bib.parse_single_name("bb CC, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Simple case. Case do not matter for First.", function()
        local res = bib.parse_single_name("bb CC, aa")
        local expected = {
          given = "aa",
          ["non-dropping-particle"] = "bb",
          family = "CC",
        }
        assert.same(expected, res)
      end)

      it("Testing simple von (with inner uppercase).", function()
        local res = bib.parse_single_name("bb CC dd EE, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb CC dd",
          family = "EE",
        }
        assert.same(expected, res)
      end)

      it("Testing that the Last part cannot be empty.", function()
        local res = bib.parse_single_name("bb, AA")
        local expected = {
          given = "AA",
          family = "bb",
        }
        assert.same(expected, res)
      end)

      it("Testing that first can be empty after coma", function()
        local res = bib.parse_single_name("BB,")
        local expected = {
          family = "BB",
        }
        assert.same(expected, res)
      end)

      it("Simple Jr. Case do not matter for it.", function()
        local res = bib.parse_single_name("bb CC,XX, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
          suffix = "XX",
        }
        assert.same(expected, res)
      end)

      it("Simple Jr. Case do not matter for it.", function()
        local res = bib.parse_single_name("bb CC,xx, AA")
        local expected = {
          given = "AA",
          ["non-dropping-particle"] = "bb",
          family = "CC",
          suffix = "xx",
        }
        assert.same(expected, res)
      end)

      it("Testing that jr can be empty in between comas.", function()
        local res = bib.parse_single_name("BB,, AA")
        local expected = {
          given = "AA",
          family = "BB",
        }
        assert.same(expected, res)
      end)

    end)

  end)


  describe("parse date", function()

    it("single date", function()
      local res = bib.parse_date("1992-08-11")
      local expected = {
        ["date-parts"] = {
          { 1992, 8, 11 },
        }
      }
      assert.same(expected, res)
    end)

    it("year", function()
      local res = bib.parse_date("1992")
      local expected = {
        ["date-parts"] = {
          { 1992 },
        }
      }
      assert.same(expected, res)
    end)

    it("date range", function()
      local res = bib.parse_date("1997-07-01/2017-07-01")
      local expected = {
        ["date-parts"] = {
          { 1997, 7, 1 },
          { 2017, 7, 1 },
        }
      }
      assert.same(expected, res)
    end)

    it("literal date", function()
      local res = bib.parse_date("2003c")
      local expected = { literal = "2003c" }
      assert.same(expected, res)
    end)

    it("too many range parts", function()
      local res = bib.parse_date("1992/08/11")
      local expected = { literal = "1992/08/11" }
      assert.same(expected, res)
    end)

  end)

end)
