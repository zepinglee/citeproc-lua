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
  util = require("citeproc-util")
else
  util = require("citeproc.util")
end


-- The tests are taken from <https://www.loc.gov/standards/datetime/>.

describe("EDTF", function ()
  describe("Level 0", function ()
    describe("Date", function ()
      it("complete representation", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4, 12},
          },
        }, util.parse_edtf("1985-04-12"))
      end)

      it("reduced precision for year and month", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4},
          },
        }, util.parse_edtf("1985-04"))
      end)

      it("reduced precision for year", function ()
        assert.same({
          ["date-parts"] = {
            {1985},
          },
        }, util.parse_edtf("1985"))
      end)
    end)

    describe("Date and Time", function ()
      it("Complete representations for calendar date and (local) time of day", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4, 12},
          },
        }, util.parse_edtf("1985-04-12T23:20:30"))
      end)

      it("Complete representations for calendar date and UTC time of day", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4, 12},
          },
        }, util.parse_edtf("1985-04-12T23:20:30Z"))
      end)

      it("Date and time with timeshift in hours (only)", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4, 12},
          },
        }, util.parse_edtf("1985-04-12T23:20:30-04"))
      end)

      it("Date and time with timeshift in hours and minutes", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4, 12},
          },
        }, util.parse_edtf("1985-04-12T23:20:30+04:30"))
      end)
    end)

    describe("Time Interval", function ()
      it("interval with calendar year precision", function ()
        assert.same({
          ["date-parts"] = {
            {1964},
            {2008},
          },
        }, util.parse_edtf("1964/2008"))
      end)

      it("time interval with calendar month precision", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 6},
            {2006, 8},
          },
        }, util.parse_edtf("2004-06/2006-08"))
      end)

      it("time interval with calendar day precision", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 2, 1},
            {2005, 2, 8},
          },
        }, util.parse_edtf("2004-02-01/2005-02-08"))
      end)

      it("time interval", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 2, 1},
            {2005, 2},
          },
        }, util.parse_edtf("2004-02-01/2005-02"))
      end)

      it("time interval", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 2, 1},
            {2005},
          },
        }, util.parse_edtf("2004-02-01/2005"))
      end)

      it("time interval", function ()
        assert.same({
          ["date-parts"] = {
            {2005},
            {2006, 2},
          },
        }, util.parse_edtf("2005/2006-02"))
      end)
    end)
  end)

  describe("Level 1", function ()
    it("Letter-prefixed calendar year", function ()
      assert.same({
        ["date-parts"] = {
          {170000002},
        },
      }, util.parse_edtf("Y170000002"))

      assert.same({
        ["date-parts"] = {
          {-170000003},
        },
      }, util.parse_edtf("Y-170000002"))
    end)

    it("Seasons", function ()
      assert.same({
        ["date-parts"] = {
          {2001, 21},
        },
      }, util.parse_edtf("2001-21"))
    end)

    describe("Qualification of a date (complete)", function ()
      it("year uncertain (possibly the year 1984, but not definitely)", function ()
        assert.same({
          ["date-parts"] = {
            {1984},
          },
          circa = true,
        }, util.parse_edtf("1984?"))
      end)

      it("year-month approximate", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 6},
          },
          circa = true,
        }, util.parse_edtf("2004-06~"))
      end)

      it("entire date (year-month-day) uncertain and approximate", function ()
        assert.same({
          ["date-parts"] = {
            {2004, 6, 11},
          },
          circa = true,
        }, util.parse_edtf("2004-06-11%"))
      end)
    end)

    describe("Unspecified digit(s) from the right", function ()
      it("A year with one or two (rightmost) unspecified digits in a year-only expression (year precision)", function ()
        assert.same({
          ["date-parts"] = {
            {2010},
          },
          circa = true,
        }, util.parse_edtf("201X"))

        assert.same({
          ["date-parts"] = {
            {2000},
          },
          circa = true,
        }, util.parse_edtf("20XX"))
      end)

      it("Year specified, month unspecified in a year-month expression (month precision)", function ()
        assert.same({
          ["date-parts"] = {
            {2004},
          },
          circa = true,
        }, util.parse_edtf("2004-XX"))
      end)

      it("Year and month specified, day unspecified in a year-month-day expression (day precision)", function ()
        assert.same({
          ["date-parts"] = {
            {1985, 4},
          },
          circa = true,
        }, util.parse_edtf("1985-04-XX"))
      end)

      it("Year specified, day and month unspecified in a year-month-day expression  (day precision)", function ()
        assert.same({
          ["date-parts"] = {
            {1985},
          },
          circa = true,
        }, util.parse_edtf("1985-XX-XX"))
      end)

      -- biblatex-apap-test-references.bib 10.2:36
      it("AD", function ()
        assert.same({
          ["date-parts"] = {
            {-350},
          },
          circa = true,
        }, util.parse_edtf("-0349~"))
      end)
    end)
  end)
end)
