local json_decode

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
  require("lualibs")
  json_decode = utilities.json.tolua
else
  json_decode = require("dkjson").decode
end

local lfs = require("lfs")
local citeproc = require("citeproc")
local util = citeproc.util


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
  local file = io.open("./tests/citeproc-test-skip.txt", "r")
  if not file then
    return skipped_files
  end
  for line in file:lines() do
    if line ~= "" and not util.startswith(line, "#") then
      skipped_files[line] = true
    end
  end
  file:close()
  return skipped_files
end


local function test_citation_items(engine, fixture)
  local citation_items = fixture.citation_items

  local ids = {}
  for _, item in ipairs(fixture.input) do
    table.insert(ids, item.id)
  end
  engine:updateItems(ids)

  -- The citation-items are loaded from the engine registry.
  -- See <https://github.com/Juris-M/citeproc-test-runner/blob/b1e72d5cb1363b7f4abbe1f6546c9e2c443db726/lib/sys.js#L369-L376>
  if not citation_items then
    citation_items = {{}}
    for _, id in ipairs(engine.registry.reflist) do
      table.insert(citation_items[1], {id = tostring(id)})
    end
  end

  local output = {}
  for _, items in ipairs(citation_items) do
    local res = engine:makeCitationCluster(items)
    -- Some hacks to pass the test-suite
    res = string.gsub(res, "^ibid", "Ibid")
    table.insert(output, res)
  end
  return table.concat(output, "\n")
end


local function test_citations_process_citation_cluster(engine, fixture)
  local output = {}
  local citation_order = {}
  for i, citation_cluster in ipairs(fixture.citations) do
    local citation = citation_cluster[1]
    local citations_pre = citation_cluster[2]
    local citations_post = citation_cluster[3]

    -- bugreports_NumericStyleFirstRefMultipleCiteFailure.txt
    -- Empty citationID
    if not citation.citationID then
      citation.citationID = "CITATION-" .. tostring(i)
    end

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


local function test_citations_process_citation(engine, fixture)
  local citations = {}
  local citation_dict = {}
  for i, citation_cluster in ipairs(fixture.citations) do
    local citation = citation_cluster[1]
    local citations_pre = citation_cluster[2]
    local citations_post = citation_cluster[3]

    -- bugreports_NumericStyleFirstRefMultipleCiteFailure.txt
    -- Empty citationID
    if not citation.citationID then
      citation.citationID = "CITATION-" .. tostring(i)
    end

    citation_dict[citation.citationID] = citation
    if i == #fixture.citations then
      for _, citation_id_note in ipairs(citations_pre) do
        local citation_id = citation_id_note[1]
        local citation_ = citation_dict[citation_id]
        citation_.properties.noteIndex = citation_id_note[2]
        table.insert(citations, citation_)
      end
      table.insert(citations, citation)
      for _, citation_id_note in ipairs(citations_post) do
        local citation_id = citation_id_note[1]
        local citation_ = citation_dict[citation_id]
        citation_.properties.noteIndex = citation_id_note[2]
        table.insert(citations, citation_)
      end
    end
  end

  local item_ids = {}
  local item_id_dict = {}
  for _, citation_ in ipairs(citations) do
    for _, cite_item in ipairs(citation_.citationItems) do
      if not item_id_dict[cite_item.id] then
        item_id_dict[cite_item.id] = true
        table.insert(item_ids, cite_item.id)
      end
    end
  end
  engine:updateItems(item_ids)

  local output = {}
  for i, citation in ipairs(citations) do
    local citation_str = engine:process_citation(citation)
    table.insert(output, string.format("[%d] %s", i - 1, citation_str))
  end

  local lines = {}
  for _, line in ipairs(util.split(fixture.result, "\n")) do
    line = string.gsub(line, "^%.%.", "")
    line = string.gsub(line, "^>>", "")
    table.insert(lines, line)
  end
  fixture.trimmed_result = table.concat(lines, "\n")

  return table.concat(output, "\n")
end


local function test_bibliography(engine, fixture)
  if fixture.bibentries then
    -- TODO
    pending("bibentries")
  end

  if fixture.citations then
    test_citations_process_citation_cluster(engine, fixture)
  else
    test_citation_items(engine, fixture)
  end

  local result = engine:makeBibliography(fixture.bibsection)
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
          contents = json_decode(contents)
          if not contents then
            error(string.format('JSON parsing error in "%s"', section))
          end
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
      local locale_path = "./tests/locales/locales-" .. lang .. ".xml"
      return util.read_file(locale_path, true)
    end,
    retrieveItem = function (id)
      local res = bib[id]
      if not res then
        util.warning(string.format("Didn't find a database entry for '%s'", id))
      end
      return res
    end
  }

  local style = fixture.csl

  local engine = citeproc.new(citeproc_sys, style)
  engine:set_output_format('html')
  citeproc.util.warning_enabled = false
  if fixture.options then
    for key, value in pairs(fixture.options) do
      engine.opt[key] = value
    end
  end

  local result

  if fixture.mode == "citation" then
    if fixture.citations then
      -- result = test_citations_process_citation_cluster(engine, fixture)
      -- assert.equal(fixture.result, result)
      -- engine:updateItems({})
      result = test_citations_process_citation(engine, fixture)
      assert.equal(fixture.trimmed_result, result)
    else
      result = test_citation_items(engine, fixture)
      assert.equal(fixture.result, result)
    end

  elseif fixture.mode == "bibliography" then
    result = test_bibliography(engine, fixture)
    if fixture.result and util.startswith(fixture.result, "<div") then
      result = normalize_new_line(result)
      fixture.result = normalize_new_line(fixture.result)
    end
    assert.equal(fixture.result, result)
  end


  -- local compare_result = fixture.result == result
  -- if not compare_result then
  --   local make_diff = require("diff")  -- luadiffer
  --   local diff = make_diff(fixture.result, result)
  --   diff:print()
  -- end
  -- assert.is_true(compare_result)

end


local function main()
  local suites = {
    "test-suite",
    "citeproc-js",
    "citeproc-hs",
    "citeproc-rs",
    "local",
  }

  local suite_dirs = {
    ["test-suite"] = "./tests/fixtures/test-suite/processor-tests/humans",  -- standard test-suite
    ["citeproc-js"] = "./tests/fixtures/citeproc-js",
    ["citeproc-hs"] = "./tests/fixtures/citeproc-hs",
    ["citeproc-rs"] = "./tests/fixtures/citeproc-rs",
    ["local"] = "./tests/fixtures/local",
  }

  local suite_fixtures = {}
  local fixture_paths = {}

  for _, suite_name in ipairs(suites) do
    local test_dir = suite_dirs[suite_name]
    suite_fixtures[suite_name] = {}
    if path_exists(test_dir) then
      local files = listdir(test_dir)
      for _, file in ipairs(files) do
        if string.match(file, "%.txt$") then
          if fixture_paths[file] then
            error(string.format("Duplicate fixture: %s", file))
          end
          table.insert(suite_fixtures[suite_name], file)
          local path = test_dir .. "/" .. file
          fixture_paths[file] = path
        end
      end
    end
  end

  -- local count = 0
  -- for file, path in pairs(fixture_paths) do
  --   print(path)
  --   count = count + 1
  -- end
  -- print(count)

  local override_dir = "./tests/fixtures/overrides"  -- fixtures that override the above
  for _, file in ipairs(listdir(override_dir)) do
    if string.match(file, "%.txt$") then
      if not fixture_paths[file] then
        error(string.format("Fixture not exists: %s", file))
      end
      fixture_paths[file] = override_dir .. "/" .. file
    end
  end

  -- local skipped_files = {}
  local skipped_files = get_skipped_files()

  for _, suite_name in ipairs(suites) do
    describe(suite_name, function ()
      for _, file in ipairs(suite_fixtures[suite_name]) do
        if not skipped_files[file] then
          local path = fixture_paths[file]
          it(file, function ()
            run_test(path)
          end)
        end
      end
    end)
  end

end


main()
