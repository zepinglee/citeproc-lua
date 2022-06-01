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
local dom = require("luaxml-domobject")

local Text = require("citeproc-node-text").Text
local util = require("citeproc-util")


describe("Text", function()

  it("build with variable attribute", function()
    local xml_str = '<text variable="title"/>'
    local node = dom.parse(xml_str):get_path("text")[1]
    local text = Text:from_node(node)
    assert.truthy(text)

    local expected = Text:new()
    expected.variable = "title"

    assert.same(expected, text)
  end)

end)
