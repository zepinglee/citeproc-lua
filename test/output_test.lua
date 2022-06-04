kpse.set_program_name("luatex")

local kpse_searcher = package.searchers[2]
package.searchers[2] = function(name)
  local file, err = package.searchpath(name, package.path)
  if not err then
    return loadfile(file)
  end
  return kpse_searcher(name)
end


require("busted.runner")()

local InlineElement = require("citeproc-output").InlineElement
local PlainText = require("citeproc-output").PlainText
local Formatted = require("citeproc-output").Formatted
local Quoted = require("citeproc-output").Quoted
local util = require("citeproc-util")


describe("Oputput", function()

  it("parses string", function()
    local str = "foo bar"
    local el = InlineElement:parse(str)

    local expected = PlainText:new("foo bar")
    assert.same(expected, el)
  end)

  it("with tags", function()
    local str = "foo <i>bar</i> baz"
    local el = InlineElement:parse(str)
    local expected = InlineElement:new({
      PlainText:new("foo "),
      Formatted:new({
        PlainText:new("bar"),
      }, {["font-style"] = "italic"}),
      PlainText:new(" baz"),
    })
    assert.same(expected, el)
  end)

  it("quotes", function()
    local str = "'quote', "
    local el = InlineElement:parse(str)

    local expected = {
      Quoted:new({PlainText:new("quote")}),
      PlainText:new(", "),
    }
    assert.same(expected, el)
  end)

  it("french apostrophe", function()
    local str = "Life's 'Little' Surprises"
    local el = InlineElement:parse(str)
    assert.truthy(el)
    util.debug(el)

    -- local expected = InlineElement:new({
    --   Quoted:new({PlainText:new("quote")}),
    --   PlainText:new(", "),
    -- })

    -- assert.same(expected, el)
  end)

end)
