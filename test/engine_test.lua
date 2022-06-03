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

local Style = require("citeproc-node-style").Style
local util = require("citeproc-util")


describe("Style", function()

  local str = util.read_file("../styles/apa.csl")

  it("parses from xml", function()
    local style = Style:parse(str)
    assert.truthy(style)
    util.debug(style.citation)
  end)

end)
