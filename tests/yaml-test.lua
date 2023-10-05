local lfs = require("lfs")
local yaml
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
  yaml = require("citeproc-yaml")
  require("lualibs")
  json_decode = utilities.json.tolua
  util = require("citeproc-util")
else
  yaml = require("citeproc.yaml")
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


describe("CSL-YAML file", function ()
  local test_dir = "./tests/yaml"
  for _, file in ipairs(listdir(test_dir)) do
    if string.match(file, "%.yaml$") then
      it(file, function ()
        local yaml_path = test_dir .. "/" .. file
        local yaml_contents = util.read_file(yaml_path)
        local converted = yaml.parse(yaml_contents)

        local json_path = test_dir .. "/" .. string.gsub(file, "%.yaml$", ".json")
        local json_contents = util.read_file(json_path)
        local expected = json_decode(json_contents)
        assert.same(expected, converted)
      end)
    end
  end
end)
