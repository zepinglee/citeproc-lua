
--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local cli = {}


require("lualibs")
local citeproc = require("citeproc")
local bibtex  -- = require("citeproc-bibtex")  -- load on demand
local util = require("citeproc-util")
local core = require("citeproc-latex-core")


local function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    else
      if tab.file then
        error(string.format('Invalid argument "%s"', v))
      end
      tab.file = v
    end

  end
  return tab
end


local function print_version()
  io.write(string.format("citeproc-lua %s\n", citeproc.__VERSION__))
end


local function print_help()
  io.write("Usage: citeproc-lua [options] auxname[.aux]\n")
  io.write("Options:\n")
  io.write("  -h, --help          Print this message and exit.\n")
  io.write("  -V, --version       Print the version number and exit.\n")
end


local function convert_bib(path, output_path)
  local contents = util.read_file(path)
  bibtex = bibtex or require("citeproc-bibtex")
  local data = bibtex.parse(contents)
  if not output_path then
    output_path = string.gsub(path, "%.bib$", ".json")
  end
  local file = io.open(output_path, "w")
  if not file then
    util.error(string.format('Cannot write "%s".', output_path))
    return
  end
  file:write(utilities.json.tojson(data) .. "\n")
  file:close()
end



local function read_aux_file(aux_file)
  local bib_style = nil
  local bib_files = {}
  local citations = {}
  local csl_options = {}

  local file = io.open(aux_file, "r")
  if not file then
    error(string.format('Cannot read "%s"', aux_file))
    return
  end
  for line in file:lines() do
    local match
    match = string.match(line, "^\\bibstyle%s*(%b{})")
    if match then
      bib_style = string.sub(match, 2, -2)
    else
      match = string.match(line, "^\\csl@data%s*(%b{})")
      if match then
        for _, bib in ipairs(util.split(string.sub(match, 2, -2), "%s*,%s*")) do
          table.insert(bib_files, bib)
        end
      else
        match = string.match(line, "^\\citation%s*(%b{})")
        if match then
          local citation = core.make_citation(string.sub(match, 2, -2))
          table.insert(citations, citation)
        else
          match = string.match(line, "^\\csloptions%s*(%b{})")
          if match then
            for key, value in string.gmatch(match, "([%w-]+)=(%w+)") do
              csl_options[key] = value
            end
          end
        end
      end
    end
  end
  file:close()

  return bib_style, bib_files, citations, csl_options
end


local function process_aux_file(aux_file)
  if not util.endswith(aux_file, ".aux") then
    aux_file = aux_file .. ".aux"
  end

  local style_name, bib_files, citations, csl_options = read_aux_file(aux_file)

  local lang = csl_options.locale

  local engine = core.init(style_name, bib_files, lang)
  if csl_options.linking == "true" then
    engine:enable_linking()
  end
  local style_class = engine:get_style_class()

  local citation_strings = core.process_citations(engine, citations)

  -- util.debug(citation_strings)

  local output_string = ""

  for _, citation in ipairs(citations) do
    local citation_id = citation.citationID
    if citation_id ~= "@nocite" then
      local citation_str = citation_strings[citation_id]
      output_string = output_string .. string.format("\\cslcite{%s}{{%s}{%s}}\n", citation_id, style_class, citation_str)
    end
  end

  output_string = output_string .. "\n"

  local result = core.make_bibliography(engine)
  output_string = output_string .. result

  local output_path = string.gsub(aux_file, "%.aux$", ".bbl")
  local bbl_file = io.open(output_path, "w")
  bbl_file:write(output_string)
  bbl_file:close()
end


function cli.main()
  local args = getopt(arg, "o")

  -- for k, v in pairs(args) do
  --   print( k, v )
  -- end

  if args.V or args.version then
    print_version()
    return
  elseif args.h or args.help then
    print_help()
    return
  end

  if not args.file then
    error("citeproc: Need exactly one file argument.\n")
  end

  local path = args.file

  local output_path = args.o or args.output
  if util.endswith(path, ".bib") then
    convert_bib(path, output_path)
  else
    process_aux_file(path)
  end

end


return cli
