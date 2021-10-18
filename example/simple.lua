#!/usr/bin/env texlua
kpse.set_program_name("luatex")

require("lualibs")
local dom = require("luaxml-domobject")
local inspect = require("inspect")

local citeproc = require("citeproc.citeproc")


local function read_file(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end


local function main ()

    local style = read_file("example/simple.csl")

    local bib = {}
    local items = utilities.json.tolua(read_file("example/simple.json"))
    for _, item in ipairs(items) do
        bib[item["id"]] = item
    end

    local citeproc_sys = {
        retrieveLocale = function (self, lang)
            local content = read_file("example/locales-" .. lang .. ".xml")
            if content then
                return dom.parse(content)
            else
                return nil
            end
        end,
        retrieveItem = function (self, id)
            return bib[id]
        end
    }

    local engine = citeproc.new(citeproc_sys, style)

    local cite_items = {
        {id = "ITEM-1"},
        {id = "ITEM-2"},
    }

    local result = engine:makeCitationCluster(cite_items)
    print(inspect(result))

    local params, bibliography = engine:makeBibliography()
    print(inspect(params))
    print(inspect(bibliography))
end


main()
