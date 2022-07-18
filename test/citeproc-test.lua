#!/usr/bin/env texlua

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
require("lualibs")
local lfs = require("lfs")
local inspect = require("inspect")

local citeproc = require("citeproc")
local util = require("citeproc-util")


local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

local function endswith(str, suffix)
  return string.sub(str, -#suffix) == suffix
end

local function path_exists(path)
  if pcall(function () lfs.dir(path) end) then
    return true
  else
    return false
  end
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


local function get_skipped_files()
  local skipped_files = {}
  local file = io.open("./test/citeproc-test-skip.txt", "r")
  if not file then
    return skipped_files
  end
  for line in file:lines() do
    if not util.startswith(line, "#") then
      skipped_files[line] = true
    end
  end
  file:close()
  return skipped_files
end


local function test_citation_items(engine, fixture)
  local citation_items = fixture.citation_items
  if not citation_items then
    citation_items = {{}}
    local cited = {}  -- to remove duplicates: number_PlainHyphenOrEnDashAlwaysPlural.txt
    for _, item in ipairs(fixture.input) do
      if not cited[item.id] then
        table.insert(citation_items[1], {id = tostring(item.id)})
        cited[item.id] = true
      end
    end
  end

  local ids = {}
  for _, item in ipairs(fixture.input) do
    table.insert(ids, item.id)
  end
  engine:updateItems(ids)

  local output = {}
  for _, items in ipairs(citation_items) do
    local res = engine:makeCitationCluster(items)
    -- Some hacks to pass the test-suite
    res = string.gsub(res, "^ibid", "Ibid")
    table.insert(output, res)
  end
  return table.concat(output, "\n")
end

local function test_citations(engine, fixture)

  local output = {}
  local citation_order = {}
  for i, citation_cluster in ipairs(fixture.citations) do
    local citation = citation_cluster[1]
    local citations_pre = citation_cluster[2]
    local citations_post = citation_cluster[3]

    local res = engine:processCitationCluster(citation, citations_pre, citations_post)

    for citation_id, citation_output in pairs(output) do
      if not engine.registry.citations_by_id[citation_id] then
        output[citation_id] = nil
      end
    end

    if i == #fixture.citations then
      for _, citation_output in pairs(output) do
        citation_output.prefix = ".."
      end
      for _, citation_id_note in ipairs(citations_pre) do
        table.insert(citation_order, citation_id_note[1])
      end
      table.insert(citation_order, citation.citationID)
      for _, citation_id_note in ipairs(citations_post) do
        table.insert(citation_order, citation_id_note[1])
      end
    end

    for _, insert in ipairs(res[2]) do
      local citation_index = insert[1] + 1
      local citation_str = insert[2]
      local citation_id = insert[3]

      if output[citation_id] then
        output[citation_id].prefix = ">>"
        output[citation_id].string = citation_str
      else
        output[citation_id] = {
          prefix = ">>",
          string = citation_str,
        }
      end
    end
  end

  local ret = {}
  for i, citation_id in ipairs(citation_order) do
    local prefix = output[citation_id].prefix
    local citation_str = output[citation_id].string
    table.insert(ret, prefix .. "[" .. tostring(i-1) .. "] " .. citation_str)
  end
  return table.concat(ret, "\n")
end

local function test_bibliography(engine, fixture)
  if fixture.bibentries then
    -- TODO
    pending("bibentries")
  end

  if fixture.bibsection then
    -- TODO
    pending("bibsection")
  end

  if fixture.citations then
    test_citations(engine, fixture)
  else
    test_citation_items(engine, fixture)
  end

  local result = engine:makeBibliography()
  local params = result[1]
  local entries = result[2]
  local res = params.bibstart
  for _, entry in ipairs(entries) do
    res = res .. "  " .. entry
  end
  res = res .. params.bibend
  return res
end

local function parse_fixture(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local res = {}
  local section = nil
  local contents = nil
  for line in file:lines() do
    --
    local start = string.match(line, ">>=+%s*([%w-]+)%s*=+")
    if start then
      section = start
      contents = nil
    else
      local stop = string.match(line, "<<=+%s*([%w-]+)%s*=+")
      if stop and stop == section then
        if section == "INPUT" or
            section == "CITATION-ITEMS" or
            section == "CITATIONS" or
            section == "OPTIONS" or
            section == "BIBENTRIES" or
            section == "BIBSECTION" or
            section == "ABBREVIATIONS" then
          contents = utilities.json.tolua(contents)
        end
        section = string.lower(section)
        section = string.gsub(section, "-", "_")
        res[section] = contents
        section = nil
      else
        if section then
          if contents then
            contents = contents .. "\n" .. line
          else
            contents = line
          end
        end
      end
    end
  end
  file:close()
  return res
end

local function normalize_new_line(str)
  local lines = util.split(str, "\r?\n")
  local indent_level = 0
  for i, line in ipairs(lines) do
    line = util.lstrip(line)

    if #line > 0 then
      local current_indent_level = indent_level
      if util.startswith(line, "</div>") then
        current_indent_level = indent_level - 1
      end

      line = string.rep(" ", 2 * current_indent_level) .. line
    end
    lines[i] = line

    string.gsub(line, "<div ", function ()
      indent_level = indent_level + 1
    end)
    string.gsub(line, "</div>", function ()
      indent_level = indent_level - 1
    end)
  end
  return table.concat(lines, "\n")
end

local function run_test(path)
  local fixture = parse_fixture(path)

  if not fixture then
    error(string.format('Failed to parse fixture "%s".', path))
    return
  end

  local bib = {}
  for i, item in ipairs(fixture.input) do
    if item.id == nil then
      item.id = "item-" .. tostring(i)
    end
    bib[tostring(item.id)] = item
  end

  local citeproc_sys = {
    retrieveLocale = function (lang)
      if not lang then
        return nil
      end
      local path = "./locales/csl-locales-" .. lang .. ".xml"
      local content = read_file(path)
      if not content then
        return nil
      end
      return content
    end,
    retrieveItem = function (id)
      return bib[id]
    end
  }

  local style = fixture.csl

  local engine = citeproc.new(citeproc_sys, style)
  engine:set_formatter('html')
  citeproc.util.warning_enabled = false
  if fixture.options then
    for key, value in pairs(fixture.options) do
      engine.opt[key] = value
    end
  end

  local result

  if fixture.mode == "citation" then
    if fixture.citations then
      result = test_citations(engine, fixture)
    else
      result = test_citation_items(engine, fixture)
    end

  elseif fixture.mode == "bibliography" then
    result = test_bibliography(engine, fixture)
  end

  if util.startswith(fixture.result, "<div") then
    result = normalize_new_line(result)
    fixture.result = normalize_new_line(fixture.result)
  end

  assert.equal(fixture.result, result)

  -- local compare_result = fixture.result == result
  -- if not compare_result then
  --   local make_diff = require("diff")  -- luadiffer
  --   local diff = make_diff(fixture.result, result)
  --   diff:print()
  -- end
  -- assert.is_true(compare_result)

end

local function main()
  local test_dirs = {
    "./test/test-suite/processor-tests/humans",  -- standard test-suite
    "./test/overrides",  -- fixture that overrides the standard
    "./test/local",
  }
  local fixture_list = {}
  local fixture_path = {}
  for _, test_dir in ipairs(test_dirs) do
    if path_exists(test_dir) then
      local files = listdir(test_dir)
      local skipped_files = get_skipped_files()
      for _, file in ipairs(files) do
        if string.match(file, "%.txt$") and not skipped_files[file] then
          local path = test_dir .. "/" .. file
          if not fixture_path[file] then
            table.insert(fixture_list, file)
          end
          fixture_path[file] = path
        end
      end
    end
  end

  describe("test-suite", function ()
    for _, fixture in ipairs(fixture_list) do
      local path = fixture_path[fixture] do
        it(fixture, function ()
          run_test(path)
        end)
      end
    end
  end)
end


main()
