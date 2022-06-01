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
local inspect = require("inspect")

local Style = require("citeproc-node-style").Style
local util = require("citeproc-util")


local remove_all_metatables = function(item, path)
  if path[#path] ~= inspect.METATABLE then return item end
end


describe("Style", function()

  local str = util.read_file("../styles/apa.csl")

  it("parses from xml", function()
    local style = Style:parse(str)
    assert.truthy(style)
    print(inspect(style.citation, {process = remove_all_metatables}))
  end)

end)
