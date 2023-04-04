local bibtex2csl 
local json_decode
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
  bibtex2csl = require("citeproc-bibtex2csl")
  require("lualibs")
  json_decode = utilities.json.tolua
  util = require("citeproc-util")
else
  bibtex2csl = require("citeproc.bibtex2csl")
  json_decode = require("dkjson").decode
  util = require("citeproc.util")
end


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


describe("BibTeX data", function ()
  local bibtex_dir = "./tests/bibtex"
  for _, file in ipairs(listdir(bibtex_dir)) do
    if string.match(file, "%.bib$") then
      describe(file, function ()
        local bib_path = bibtex_dir .. "/" .. file
        local bib_contents = util.read_file(bib_path)
        if not bib_contents then
          error(string.format('File not found: "%s"', bib_path))
        end
        local csl_data = bibtex2csl.parse_bibtex_to_csl(bib_contents, true, true, true, true)

        local json_path = bibtex_dir .. "/" .. string.gsub(file, "%.bib$", ".json")
        local json_contents = util.read_file(json_path)
        local expected = json_decode(json_contents)
        for i, item in ipairs(csl_data) do
          it(item.id, function ()
            assert.same(expected[i], item)
          end)
        end
      end)
    end
  end
end)
