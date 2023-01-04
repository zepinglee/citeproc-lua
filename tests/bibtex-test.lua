kpse.set_program_name("luatex")

local kpse_searcher = package.searchers[2]
package.searchers[2] = function (name)
  local file, err = package.searchpath(name, package.path)
  if not err then
    return loadfile(file)
  end
  return kpse_searcher(name)
end


local bibtex = require("citeproc-bibtex")
require("lualibs")
local util = require("citeproc-util")


local function listdir(path)
  local files = {}
  for file in lfs.dir(path) do
    if not string.match(file, "^%.") then
      table.insert(files, file)
    end
  end
  table.sort(files)
  return files
end


describe("BibTeX entry", function ()
  local bibtex_dir = "./tests/bibtex"
  for _, file in ipairs(listdir(bibtex_dir)) do
    if string.match(file, "%.bib$") then
      it(file, function ()
        local bib_path = bibtex_dir .. "/" .. file
        local bib_contents = util.read_file(bib_path)
        local converted = bibtex.parse(bib_contents)

        local json_path = bibtex_dir .. "/" .. string.gsub(file, "%.bib$", ".json")
        local json_contents = util.read_file(json_path)
        local expencted = utilities.json.tolua(json_contents)
        assert.same(expencted, converted)
      end)
    end
  end
end)
