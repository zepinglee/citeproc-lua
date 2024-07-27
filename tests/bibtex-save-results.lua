local bibtex2csl
local json_encode
local lfs = require("lfs")
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
  bibtex2csl = require("citeproc.citeproc-bibtex2csl")
  require("lualibs")
  json_encode = utilities.json.tojson
  util = require("citeproc.citeproc-util")
else
  bibtex2csl = require("citeproc.bibtex2csl")
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


---@param bib_contents string
---@param json_path string
---@param protect_case boolean
---@param sentence_case_title boolean
---@param check_sentence_case boolean
local function save_csl_json(bib_contents, json_path, protect_case, sentence_case_title, check_sentence_case)
  -- print(json_path)
  local csl_items, exceptions = bibtex2csl.parse_bibtex_to_csl(bib_contents, true, protect_case, sentence_case_title, check_sentence_case)
  if not csl_items then
    for _, exception in ipairs(exceptions) do
      util.debug(exception)
    end
    util.error("Cannot convert to CSL-JSON")
    csl_items = {}
  end

  local fh = io.open(json_path, "w")
  if fh then
    fh:write(json_encode(csl_items))
    fh:close()
  else
    error("Cannot write file.")
  end

  local cmd = string.format('python3 scripts/normalize_csl_json.py "%s"', json_path)
  -- print(cmd)
  os.execute(cmd)

end


local function main()
  local bib_dir = "./tests/bibtex"
  for _, file in ipairs(listdir(bib_dir)) do
    if string.match(file, "%.bib$") then
      local bib_path = bib_dir .. "/" .. file
      local bib_contents = util.read_file(bib_path)
      if not bib_contents then
        error(string.format('File not found: "%s"', bib_path))
      end

      local sentence_case_options = {"on+guess", "on", "off"}
      -- TODO: "as-needed" not implemented
      local case_protection_options = {"as-needed", "strict", "off"}

      for _, sentence_case in ipairs(sentence_case_options) do
        for _, case_protection in ipairs(case_protection_options) do
          local config = string.format("sentencecase=%s^caseprotection=%s", sentence_case, case_protection)
          local result_dir = string.format("./tests/bibtex/results/%s", config)
          if not lfs.attributes(result_dir) then
            lfs.mkdir(result_dir)
          end
          local json_path = string.format("%s/%s", result_dir, file:gsub("%.bib$", ".json"))

          local sentence_case_title = (sentence_case ~= "off")
          local protect_case = (case_protection ~= "off")
          local check_sentence_case = (sentence_case == "on+guess")

          save_csl_json(bib_contents, json_path, protect_case, sentence_case_title, check_sentence_case)

        end
      end
    end
  end
end


main()
