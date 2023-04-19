
--
-- Copyright (c) 2021-2023 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local cli = {}


local lpeg = require("lpeg")

require("lualibs")
local citeproc = require("citeproc")
local bibtex2csl  -- = require("citeproc-bibtex-parser")  -- load on demand
local util = require("citeproc-util")
local core = require("citeproc-latex-core")
local latex_parser = require("citeproc-latex-parser")


-- http://lua-users.org/wiki/AlternativeGetOpt
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
  io.write("  -q, --quiet         Quiet mode: suppress the banner and progress reports.\n")
  io.write("  -V, --version       Print the version number and exit.\n")
end


local function convert_bib(path, output_path)
  local contents = util.read_file(path)
  bibtex2csl = bibtex2csl or require("citeproc-bibtex2csl")
  local csl_data = bibtex2csl.parse_bibtex_to_csl(contents, true, true, true, true)
  if not output_path then
    output_path = string.gsub(path, "%.bib$", ".json")
  end
  util.write_file(utilities.json.tojson(csl_data) .. "\n", output_path)
end


local balanced = lpeg.P{ "{" * lpeg.V(1)^0 * "}" + (1 - lpeg.S"{}") }


---@param text string
---@return string?
local function get_command_argument(text, command)
  if string.match(text, command) then
    local grammar = (lpeg.P(command) * lpeg.S(" \t\r\n")^0 * lpeg.C(balanced) + 1)^0
    local argument = grammar:match(text)
    if not argument then
      return nil
    end
    argument = string.sub(argument, 2, -2)
    return argument
  end
  return nil
end



---comment
---@param aux_file any
---@return string
---@return string[]
---@return Citation[]
---@return table<string, string>
---@return string[]
local function read_aux_file(aux_file)
  local csl_style = nil
  local csl_data_files = {}
  local csl_citations = {}
  local csl_options = {}
  local csl_bibliographies = {}

  local file = io.open(aux_file)
  if not file then
    util.error(string.format("Couldn't open file %s", aux_file))
    return csl_style, csl_data_files, csl_citations, csl_options, csl_bibliographies
  end
  for line in file:lines() do
    -- TODO: Use lpeg-based method and detect multiple lines
    local style = get_command_argument(line, "\\csl@aux@style")
    if style then
      csl_style = style
    else
      local data = get_command_argument(line, "\\csl@aux@data")
      if data then
        for _, bib_file in ipairs(latex_parser.parse_seq(data)) do
          table.insert(csl_data_files, bib_file)
        end
      else
        local cite = get_command_argument(line, "\\csl@aux@cite")
        if cite then
          local citation = core.make_citation(cite)
          table.insert(csl_citations, citation)
        else
          local options = get_command_argument(line, "\\csl@aux@options")
          if options then
            options = latex_parser.parse_prop(options)
            for key, value in pairs(options) do
              csl_options[key] = value
            end
          else
            local bib = get_command_argument(line, "\\csl@aux@bibliography")
            if bib then
              table.insert(csl_bibliographies, bib)
            else
              local sub_aux_file = get_command_argument(line, "\\@input")
              if sub_aux_file and util.endswith(sub_aux_file, ".aux") then
                local style_name, data_files, citations, opts, bibs = read_aux_file(sub_aux_file)
                if style_name then
                  csl_style = style_name
                end
                util.extend(csl_data_files, data_files)
                util.extend(csl_citations, citations)
                util.extend(csl_citations, citations)
                for key, value in pairs(opts) do
                  csl_options[key] = value
                end
                util.extend(csl_bibliographies, bibs)
              end
            end
          end
        end
      end
    end
  end
  file:close()

  return csl_style, csl_data_files, csl_citations, csl_options, csl_bibliographies
end


local function get_undefined_info(core, citation)
  local res = ""
  for _, cite_item in ipairs(citation.citationItems) do
    if not core.item_dict[cite_item.id] then
      if res ~= "" then
        res = res .. ","
      end
      res = res .. cite_item.id
    end
  end
  if res ~= "" then
    res = string.format("\\cslsetup{undefined-cites={%s}}", res)
  end
  return res
end


---@param aux_file string
local function process_aux_file(aux_file)
  if not util.endswith(aux_file, ".aux") then
    aux_file = aux_file .. ".aux"
  end
  local blg_file = string.gsub(aux_file, "%.aux$", ".blg")
  util.set_logging_file(blg_file)

  local banner = string.format("This is citeproc-lua, Version %s", citeproc.__VERSION__)
  util.info(banner)
  util.info(string.format("The top-level auxiliary file: %s", aux_file))

  local style_name, bib_files, citations, csl_options, bibliographies = read_aux_file(aux_file)

  if style_name and style_name ~= "" then
    util.info(string.format("The style file: %s.csl", style_name))
  else
    util.error("citeproc-lua: missing style name")
  end

  if #citations == 0 then
    util.error(string.format("No citation commands in file %s", aux_file))
  end

  if #bib_files == 0 then
    util.warning("empty bibliography data files")
  else
    for i, bib_file in ipairs(bib_files) do
      util.info(string.format("Database file #%d: %s", i, bib_file))
    end
  end

  local lang = csl_options.locale

  local engine = core.init(style_name, bib_files, lang)
  if not engine then
    error("citeproc-lua: fails in initialize engine")
  end
  if csl_options.linking then
    engine:enable_linking()
  end
  local style_class = engine:get_style_class()

  if style_class == "in-text" then
    for _, citation in ipairs(citations) do
      citation.properties.noteIndex = 0
    end
  end

  local citation_strings = core.process_citations(engine, citations)

  -- util.debug(citation_strings)

  local output_string = string.format("\\cslsetup{class = %s}\n\n", style_class)

  for _, citation in ipairs(citations) do
    local citation_id = citation.citationID
    if citation_id ~= "@nocite" then
      local citation_str = citation_strings[citation_id]
      local undefined_entry_info = get_undefined_info(core, citation)
      output_string = output_string .. string.format("\\cslcitation{%s}{%s%s}\n",
        citation_id, undefined_entry_info, citation_str)
    end
  end

  output_string = output_string .. "\n"
  local categories_str = csl_options["categories"]
  if categories_str then
    core.set_categories(engine, categories_str)
  end

  for _, bib_filter_str in ipairs(bibliographies) do
    local result = core.make_bibliography(engine, bib_filter_str)
    output_string = output_string .. "\n\n\n" .. result
  end

  local output_path = string.gsub(aux_file, "%.aux$", ".bbl")
  util.write_file(output_string, output_path)

  util.quiet_mode = false;
  if util.num_errors > 1 then
    util.info(string.format("(There were %d error messages)", util.num_errors))
  elseif util.num_errors == 1 then
    util.info("(There was 1 error message)")
  end

  if util.num_warnings > 1 then
    util.info(string.format("(There were %d warning messages)", util.num_warnings))
  elseif util.num_warnings == 1 then
    util.info("(There was 1 warning message)")
  end

  util.close_logging_file()
end


function cli.main()
  local args = getopt(arg, "")

  -- for k, v in pairs(args) do
  --   print( k, v )
  -- end

  if args.V or args.version then
    print_version()
    return
  elseif args.h or args.help then
    print_help()
    return
  elseif args.q or args.quiet then
    util.quiet_mode = true
  end

  if not args.file then
    error("citeproc-lua: Need exactly one file argument.\n")
  end

  local path = args.file

  local output_path = args.o or args.output
  if util.endswith(path, ".bib") then
    convert_bib(path, output_path)
  else
    process_aux_file(path)
  end

  if util.num_errors > 0 then
    return 1
  end

  return 0

end


return cli
