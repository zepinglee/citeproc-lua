--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local cli = {}


require("lualibs")
local citeproc_manager = require("citeproc-manager")
local citeproc = require("citeproc")
local bibtex2csl  -- = require("citeproc-bibtex2csl")  -- load on demand
local util = require("citeproc-util")


-- http://lua-users.org/wiki/AlternativeGetOpt
local function getopt(arg, options)
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub(v, 1, 2) == "--" then
      local x = string.find(v, "=", 1, true)
      if x then
        tab[string.sub(v, 3, x - 1)] = string.sub(v, x + 1)
      else
        tab[string.sub(v, 3)] = true
      end
    elseif string.sub(v, 1, 1) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while (y <= l) do
        jopt = string.sub(v, y, y)
        if string.find(options, jopt, 1, true) then
          if y < l then
            tab[jopt] = string.sub(v, y + 1)
            y = l
          else
            tab[jopt] = arg[k + 1]
          end
        else
          tab[jopt] = true
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

  local csl_citation_manager = citeproc_manager.CslCitationManager:new()

  local aux_content = util.read_file(aux_file)
  if not aux_content then
    return
  end

  local bbl_str = csl_citation_manager:read_aux_file(aux_content)

  local output_path = string.gsub(aux_file, "%.aux$", ".bbl")
  util.write_file(bbl_str, output_path)

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
