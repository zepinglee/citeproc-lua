#!/usr/bin/env texlua
kpse.set_program_name("luatex")

require("lualibs")
local dom = require("luaxml-domobject")
local lfs = require("lfs")
local inspect = require("inspect")

-- local CiteProc = require(kpse.lookup("cbustediteproc.lua", {path = "./citeproc/"}))
local CiteProc = require("citeproc.citeproc")


local function read_file(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local content = file:read("*a")
  file:close()
  return content
end

local function startswith(str, prefix)
  return string.sub(str, 1, #prefix) == prefix
end

local function endswith(str, suffix)
  return string.sub(str, -#suffix) == suffix
end

local function listdir(path, prefix)
  local files = {}
  for file in lfs.dir(path) do
    if file ~= "." and file ~= ".." and endswith(file, ".txt") then
      if not prefix or startswith(file, prefix) then
        table.insert(files, string.sub(file, 1, -5))
      end
    end
  end
  table.sort(files)
  return files
end


local function run_test(fixture, protected)
  local bib = {}
  for i, item in ipairs(fixture.input) do
    if item.id == nil then
      item.id = "item-" .. tostring(i)
    end
    bib[item.id] = item
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

  local citeproc = CiteProc:new(citeproc_sys, style)

  local test_func
  if fixture.mode == "citation" then
    if fixture.citation then
      -- TODO
      return nil
    else
      local citation_items = fixture.citation_items
      if not citation_items then
        citation_items = {{}}
        for _, item in ipairs(fixture.input) do
          table.insert(citation_items[1], {id = item.id})
        end
      end

      test_func = function ()
        local output = {}
        for _, items in ipairs(citation_items) do
          local res = citeproc:makeCitationCluster(items)
          -- Some hacks to pass the test-suite
          res = string.gsub(res, "^ibid", "Ibid")
          table.insert(output, res)
        end
        return table.concat(output, "\n")
      end
    end

  elseif fixture.mode == "bibliography" then
    local bibentries = fixture.bibentries
    if not bibentries then
      bibentries = {{}}
      for _, item in ipairs(fixture.input) do
        table.insert(bibentries[1], item.id)
      end
    end

    if fixture.bibsection then
      -- TODO
      return nil
    end

    test_func = function ()
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
  end

  local status, result
  if protected then
    status, result = pcall(test_func)
  else
    result = test_func()
    status = result ~= nil
  end

  if not status then
    result = "ERROR: " .. result
  end

  return result
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



local function main ()

  local test_dir = "./test/test-suite/processor-tests/humans"
  local files = listdir(test_dir, arg[1])
  local num_passed_tests = 0
  local failing_tests = {}
  local prefixes = {}
  local prefix_num_tests = {}
  local prefix_num_passed_tests = {}

  if #files == 0 then
    print(string.format("Test %s* not found.", arg[1]))
  end

  for i, file in ipairs(files) do
    print(string.format("Test %03d/%03d: %s", i, #files, file))
    local path = test_dir .. "/" .. file .. ".txt"
    local fixture = parse_fixture(path)

    local result = run_test(fixture, #files > 1)

    local sucessed = (result == fixture.result)

    if #files == 1 then
      print("RESULT  : ", inspect(result))
      print("EXPECTED: ", inspect(fixture.result))
      if sucessed then
        print("Passed")
      else
        print("Failed")
      end
    end

    local prefix = string.match(file, "^[^_]+")
    if prefix_num_tests[prefix] then
      prefix_num_tests[prefix] = prefix_num_tests[prefix] + 1
    else
      table.insert(prefixes, prefix)
      prefix_num_tests[prefix] = 1
      prefix_num_passed_tests[prefix] = 0
    end

    if sucessed then
      num_passed_tests = num_passed_tests + 1
      prefix_num_passed_tests[prefix] = prefix_num_passed_tests[prefix] + 1
    else
      local test_type = "citation-items"
      if fixture.citations then
        test_type = "citations"
      elseif fixture.mode == "bibliography" then
        test_type = "bibliography"
        if fixture.bibentries  then
          test_type = "bibentries"
        elseif fixture.bibsection then
          test_type = "bibsection"
        end

      end
      table.insert(failing_tests, file .. " [" .. test_type .. "]")
    end
  end

  if #prefixes > 1 then
    print("Prefixes:")
    for _, prefix in ipairs(prefixes) do
      print(string.format("%-13s: %d/%d", prefix, prefix_num_passed_tests[prefix], prefix_num_tests[prefix]))
    end
  end

  if #files > 1 then
    print(string.format("Passed: %d/%d", num_passed_tests, #files))
  end

  local previous_prefix = nil
  if not arg[1] then
    local file = io.open("test/failing_tests.txt", "w")
      for _, test in ipairs(failing_tests) do
        local prefix = string.match(test, "^[^_]+")
        if prefix ~= previous_prefix then
          if previous_prefix then
            file:write("\n")
          end
          previous_prefix = prefix
        end
        file:write(test, "\n")
      end
    file:close()
  end
end


main()
