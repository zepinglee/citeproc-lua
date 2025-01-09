local element
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
  element = require("citeproc-element")
  util = require("citeproc-util")
else
  element = require("citeproc.element")
  util = require("citeproc.util")
end


describe("number", function ()

  it("parse number", function ()
    local number = "1-2"
    element.Element:split_number_parts_lpeg(number, nil)
  end)

  it("parse number", function ()
    local number = "i-ix"
    element.Element:split_number_parts_lpeg(number, nil)
  end)

  it("parse number", function ()
    local number = "3\\-B"
    element.Element:split_number_parts_lpeg(number, nil)
  end)

  it("parse number", function ()
    local number = "4–6"
    element.Element:split_number_parts_lpeg(number, nil)
  end)

  it("parse number", function ()
    local number = "Michaelson-Morely"
    element.Element:split_number_parts_lpeg(number, nil)
  end)

end)
