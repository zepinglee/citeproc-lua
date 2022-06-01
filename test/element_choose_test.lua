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

local choose = require("citeproc-node-choose")
local Context = require("citeproc-context").Context
local util = require("citeproc-util")


describe("Choose", function()

  it("build", function()
    local xml_str = [[
      <choose>
        <if variable="title-short">
          <text variable="true"/>
        </if>
        <else>
          <text variable="false"/>
        </else>
      </choose>
    ]]
    local node = dom.parse(xml_str):get_path("choose")[1]
    local element = choose.Choose:from_node(node)
    assert.truthy(element)

    util.debug(element)
  end)

  it("evaluate variable condition", function()
    local xml_str = [[
      <if variable="title-short">
        <text variable="true"/>
      </if>
    ]]
    local node = dom.parse(xml_str):get_path("if")[1]
    local element = choose.If:from_node(node)
    assert.truthy(element)
    util.debug(element)

    local engine
    local state
    local context = Context:new()
    context.reference = {
      id = "ITEM-1",
      title = "My Long Title 1",
    }
    assert.equal(false, element:evaluate_conditions(nil, state, context))

  end)

end)
