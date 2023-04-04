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
  util = require("citeproc-util")
else
  util = require("citeproc.util")
end


describe("String splitter", function ()
  local split = util.split
  it("empty sep", function ()
    -- assert.has_error(split("abc", ""))
  end)

  -- it("empty string", function ()
  --   assert.same(split("", ","), {})
  -- end)

  it("empty string", function ()
    assert.same(split("abc"), {"abc"})
  end)

  it("sep not exists", function ()
    assert.same(split("abc", ","), {"abc"})
  end)

  it("sep", function ()
    assert.same(split("a,b,c", ","), {"a", "b", "c"})
  end)

  it("empty last", function ()
    assert.same(split("a,b,c,", ","), {"a", "b", "c", ""})
  end)

  it("empty first", function ()
    assert.same(split(",a,b,c", ","), {"", "a", "b", "c"})
  end)

  it("sequent sep", function ()
    assert.same(split("x,,,y", ","), {"x", "", "", "y"})
  end)

  it("sequent sep", function ()
    assert.same(split(",,,", ","), {"", "", "", ""})
  end)

  it("max splits", function ()
    assert.same(split("a,b,c,d", ",", 3), {"a", "b", "c", "d"})
  end)

  -- it("less splits", function ()
  --   assert.same(split("a,b,c,d", ",", 2), {"a", "b", "c,d"})
  -- end)

  -- it("one split", function ()
  --   assert.same(split("a,b,c,d", ",", 1), {"a", "b,c,d"})
  -- end)

  -- it("zero split", function ()
  --   assert.same(split("a,b,c,d", ",", 0), {"a,b,c,d"})
  -- end)

  it("sep not exits with max split", function ()
    assert.same(split("a,b,c,d", "%.", 2), {"a,b,c,d"})
  end)

  it("escaped hyphen", function ()
    assert.same(split("en-US", "%-"), {"en", "US"})
  end)

  it("unescaped hyphen", function ()
    assert.same(split("en-US", "-"), {"en", "US"})
  end)

  -- it("unescaped hyphen", function ()
  --   assert.same(split("en-US", "n-"), {"", "", "", "", "", "", ""})
  -- end)

end)
