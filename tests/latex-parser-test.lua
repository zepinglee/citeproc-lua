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
local latex_parser = require("citeproc-latex-parser")
local util = require("citeproc-util")


describe("Coverting LaTeX to CSL rich text", function()

  it("italic", function()
    local latex_str = "See the \\textit{opposite} view in"
    local res = latex_parser.convert_latex_to_rich_text(latex_str)
    local expected = {
      "See the ",
      { italic = "opposite" },
       " view in" ,
    }
    assert.same(expected, res)
  end)

  it("italic", function()
    local latex_str = "Foo \\textit{bar \\textbf{baz}}"
    local res = latex_parser.convert_latex_to_rich_text(latex_str)
    local expected = {
      "Foo ",
      {
        italic = {
          "bar ",
          {bold = "baz"},
        },
      },
    }
    assert.same(expected, res)
  end)

  it("escaped characters", function()
    local latex_str = "Foo \\& bar\\_baz \\{\\$"
    local res = latex_parser.convert_latex_to_rich_text(latex_str)
    local expected = "Foo & bar_baz {$"
    assert.same(expected, res)
  end)

  it("group and control sequence", function()
    local latex_str = "Foo {\\small bar} baz"
    local res = latex_parser.convert_latex_to_rich_text(latex_str)
    local expected = {
      "Foo ",
      {code = "{\\small "},
      "bar" ,
      {code = "}"},
      " baz" ,
    }
    assert.same(expected, res)
  end)

  it("math", function()
    local latex_str = "Foo $y = \\alpha_1 x^2$ bar"
    local res = latex_parser.convert_latex_to_rich_text(latex_str)
    local expected = {
      "Foo ",
      {["math-tex"] = "y = \\alpha_1 x^2"},
      " bar" ,
    }
    assert.same(expected, res)
  end)

end)


describe("Parsing simple LaTeX keys", function()

  it("seq", function ()
    local str = "{field=type,value=book},{field=type,value=article-journal,negative=true}"
    local res = latex_parser.parse_seq(str)
    local expected = {
      "field=type,value=book",
      "field=type,value=article-journal,negative=true"
    }
    assert.same(expected, res)
  end)

  it("prop", function ()
    local str = "field=type,value=book,"
    local res = latex_parser.parse_prop(str)
    local expected = {
      field = "type",
      value = "book",
    }
    assert.same(expected, res)
  end)

  it("prop with braces", function ()
    local str = "field={type},value=book"
    local res = latex_parser.parse_prop(str)
    local expected = {
      field = "type",
      value = "book",
    }
    assert.same(expected, res)
  end)

end)
