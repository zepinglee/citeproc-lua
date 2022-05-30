kpse.set_program_name("luatex")

local kpse_lua_searcher = package.searchers[2]

local function lua_searcher(name)
  local file, err = package.searchpath(name, package.path)
  if err then
    return string.format("[lua searcher]: module not found: '%s'%s", name, err)
  else
    return loadfile(file)
  end
end

package.searchers[2] = function(name)
  local loader1 = lua_searcher(name)
  if type(loader1) ~= "string" then
    return loader1
  end
  local loader2 = kpse_lua_searcher(name)
  if type(loader2) ~= "string" then
    return loader2
  end
  return string.format("%s\n\t%s", loader1, loader2)
end


require("busted.runner")()

local Style = require("citeproc-node-style").Style
local inspect = require("inspect")
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
