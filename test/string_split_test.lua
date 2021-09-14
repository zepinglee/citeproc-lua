require("busted.runner")()

local util = require("citeproc.citeproc-util")


describe("String split", function()
  local split = util.split
  it("empty sep", function()
    -- assert.has_error(split("abc", ""))
  end)

  it("empty string", function()
    assert.same(split("", ","), {})
  end)

  it("empty string", function()
    assert.same(split("abc"), {"abc"})
  end)

  it("sep not exists", function()
    assert.same(split("abc", ","), {"abc"})
  end)

  it("sep", function()
    assert.same(split("a,b,c", ","), {"a", "b", "c"})
  end)

  it("empty last", function()
    assert.same(split("a,b,c,", ","), {"a", "b", "c", ""})
  end)

  it("empty first", function()
    assert.same(split(",a,b,c", ","), {"", "a", "b", "c"})
  end)

  it("sequent sep", function()
    assert.same(split("x,,,y", ","), {"x", "", "", "y"})
  end)

  it("sequent sep", function()
    assert.same(split(",,,", ","), {"", "", "", ""})
  end)

  it("max splits", function()
    assert.same(split("a,b,c,d", ",", 3), {"a", "b", "c", "d"})
  end)

  it("less splits", function()
    assert.same(split("a,b,c,d", ",", 2), {"a", "b", "c,d"})
  end)

  it("one split", function()
    assert.same(split("a,b,c,d", ",", 1), {"a", "b,c,d"})
  end)

  it("zero split", function()
    assert.same(split("a,b,c,d", ",", 0), {"a,b,c,d"})
  end)

  it("sep not exits with max split", function()
    assert.same(split("a,b,c,d", "%.", 2), {"a,b,c,d"})
  end)

  it("escaped hyphen", function()
    assert.same(split("en-US", "%-"), {"en", "US"})
  end)

  it("unescaped hyphen", function()
    assert.same(split("en-US", "-"), {"en", "US"})
  end)

  it("unescaped hyphen", function()
    assert.same(split("en-US", "n-"), {"", "", "", "", "", "", ""})
  end)

end)
