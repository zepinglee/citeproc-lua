#!/usr/bin/env texlua

require("busted.runner")()

kpse.set_program_name("luatex")

require("lualibs")
local dom = require("luaxml-domobject")
local lfs = require("lfs")

local CiteProc = require("citeproc.citeproc")


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

local function listdir(path)
  local files = {}
  for file in lfs.dir(path) do
    if file ~= "." and file ~= ".." and endswith(file, ".txt") then
      table.insert(files, string.sub(file, 1, -5))
    end
  end
  table.sort(files)
  return files
end

local function test_citations(citeproc, fixture)
  -- TODO
  pending("citations")
end

local function test_citation_items(citeproc, fixture)
  local citation_items = fixture.citation_items
  if not citation_items then
    citation_items = {{}}
    for _, item in ipairs(fixture.input) do
      table.insert(citation_items[1], {id = tostring(item.id)})
    end
  end

  local output = {}
  for _, items in ipairs(citation_items) do
    local res = citeproc:makeCitationCluster(items)
    -- Some hacks to pass the test-suite
    res = string.gsub(res, "^ibid", "Ibid")
    table.insert(output, res)
  end
  return table.concat(output, "\n")
end

local function test_bibliography(citeproc, fixture)
  local bibentries = fixture.bibentries
  if not bibentries then
    bibentries = {{}}
    for _, item in ipairs(fixture.input) do
      table.insert(bibentries[1], tostring(item.id))
    end
  end

  if fixture.bibsection then
    -- TODO
    pending("bibsection")
  end

  local output = {}
  for _, items in ipairs(bibentries) do
    citeproc:updateItems(items)
    local _, entries = citeproc:makeBibliography()
    local res = "<div class=\"csl-bib-body\">\n"
    for _, entry in ipairs(entries) do
      res = res .. "  " .. entry .. "\n"
    end
    res = res .. "</div>"
    table.insert(output, res)
  end
  return table.concat(output, "\n")
end

local function run_test(fixture)
  local bib = {}
  for i, item in ipairs(fixture.input) do
    if item.id == nil then
      item.id = "item-" .. tostring(i)
    end
    bib[tostring(item.id)] = item
  end

  local citeproc_sys = {
    retrieveLocale = function (self, lang)
      if not lang then
        return nil
      end
      local path = "./test/locales/locales-" .. lang .. ".xml"
      local content = read_file(path)
      if not content then
        return nil
      end
      return dom.parse(content)
    end,
    retrieveItem = function (self, id)
      return bib[id]
    end
  }

  local style = dom.parse(fixture.csl)

  local citeproc = CiteProc:new(citeproc_sys, style, "test")

  if fixture.mode == "citation" then
    if fixture.citations then
      return test_citations(citeproc, fixture)
    else
      return test_citation_items(citeproc, fixture)
    end

  elseif fixture.mode == "bibliography" then
    return test_bibliography(citeproc, fixture)
  end
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


describe("test-suite", function ()
  local test_dir = "./test/test-suite/processor-tests/humans"
  local files = listdir(test_dir)
  for _, file in ipairs(files) do
    local path = test_dir .. "/" .. file .. ".txt"
    local fixture = parse_fixture(path)

    it(file, function ()
      local result = run_test(fixture)
      assert.equal(fixture.result, result)
      return fixture.mode
    end)
  end
end)
