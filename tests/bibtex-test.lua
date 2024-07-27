local bibtex2csl
local json_decode
local lfs = require("lfs")
local util
local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
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

        local sentence_case_options = {"on+guess", "on", "off"}
        -- local case_protection_options = {"as-needed", "strict", "off"}
        local case_protection_options = {"strict", "off"}  -- TODO: "as-needed" not implemented

        for _, sentence_case in ipairs(sentence_case_options) do
          for _, case_protection in ipairs(case_protection_options) do
            local sentence_case_title = (sentence_case ~= "off")
            local protect_case = (case_protection ~= "off")
            local check_sentence_case = (sentence_case == "on+guess")

            local config = string.format("sentencecase=%s^caseprotection=%s", sentence_case, case_protection)
            local result_dir = string.format("./tests/bibtex/results/%s", config)
            local json_path = string.format("%s/%s", result_dir, file:gsub("%.bib$", ".json"))

            describe(json_path, function ()
              local csl_items, exceptions = bibtex2csl.parse_bibtex_to_csl(bib_contents, true, protect_case, sentence_case_title, check_sentence_case)

              if not csl_items then
                error("Cannot parse bib to CSL-JSON.")
              end

              local json_contents = util.read_file(json_path)
              local expected = json_decode(json_contents)
              if not expected then
                error('Cannot load json baseline.')
              end

              for i, expected_item in ipairs(expected) do
                it(tostring(expected_item.id), function ()
                  assert.same(expected_item, csl_items[i])
                end)
              end
            end)
          end
        end

      end)
    end
  end
end)
