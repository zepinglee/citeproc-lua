kpse.set_program_name("texlua")

local kpse_searcher = package.searchers[2]
---@diagnostic disable-next-line: duplicate-set-field
package.searchers[2] = function (pkg_name)
  local pkg_file = package.searchpath(pkg_name, package.path)
  if pkg_file then
    return loadfile(pkg_file)
  end
  return kpse_searcher(pkg_name)
end


require("busted.runner")()

local latex_parser = require("citeproc-latex-parser")
local util = require("citeproc-util")


describe("LaTeX parser", function ()

  describe("from LaTeX to Unicode", function ()

    it("diacritics", function ()
      local diacritics = {
        {"\\textexclamdown ", "¡"},
        {"\\`A ", "À "},
        {"\\`{A} ", "À "},
        {"\\` A ", "À "},
        {"\\` {A} ", "À "},
        {"{\\`A} ", "À "},
        {"{\\`{A}} ", "À "},
        {"{\\` A} ", "À "},
        {"{\\` {A}} ", "À "},
        {"\\`\\i ", "ì"},
        {"\\` \\i ", "ì"},
        {"\\r ABC", "ÅBC"},
        {"\\r{A}BC", "ÅBC"},
        {"\\.{}", "˙"},
        {"\\. {}", "˙"},
        {"Jasmine Ana{\\'i}{\\'i}s", "Jasmine Anaíís"},
        {"\\textbf{\\`A}", "\\textbf{À}"},
      }
      for _, pair in ipairs(diacritics) do
        local latex_str, unicode_str = table.unpack(pair)
        assert.equal(unicode_str, latex_parser.latex_to_unicode(latex_str))
      end
    end)

    it("Escaped char", function ()
      assert.same("Ultrasound in Medicine & Biology",
        latex_parser.latex_to_unicode("Ultrasound in Medicine \\& Biology")
      )
    end)

  end)


  describe("convert LaTeX markup to HTML-like tags", function ()

    it("italic", function ()
      assert.same("See the <i>opposite</i> view in",
        latex_parser.latex_to_pseudo_html("See the \\textit{opposite} view in")
      )
    end)

    it("multiple", function ()
      assert.same("Foo <i>bar <b>baz</b></i>",
        latex_parser.latex_to_pseudo_html("Foo \\textit{bar \\textbf{baz}}")
      )
    end)

    it("escaped characters", function ()
      assert.same("Foo & bar_baz {$",
        latex_parser.latex_to_pseudo_html("Foo \\& bar\\_baz \\{\\$")
      )
    end)

    it("group and control sequence", function ()
      assert.same("Foo bar baz",
        latex_parser.latex_to_pseudo_html("Foo {\\small bar} baz")
      )
    end)

    it("math", function ()
      assert.same("Foo <math>y = \\alpha_1 x^2</math> bar",
        latex_parser.latex_to_pseudo_html("Foo $y = \\alpha_1 x^2$ bar")
      )
    end)

    it("command with arguments", function ()
      assert.same("<code>\\mbox{</code><span class=\"nocase\">G-Animal’s</span><code>}</code> Journal",
        latex_parser.latex_to_pseudo_html("\\mbox{G-Animal's} Journal", true, true)
      )
    end)

    it("\\noopsort", function ()
      assert.same("1973",
        latex_parser.latex_to_pseudo_html("{\\noopsort{1973b}}1973", true, true)
      )
    end)

  end)


  describe("check sentence case", function ()

    it("check sentence case", function ()
      assert.equal("An introduction to LaTeX",
        latex_parser.latex_to_sentence_case_pseudo_html("an Introduction to LaTeX", true, true, true)
      )
    end)

    it("check sentence case with lowercase word", function ()
      assert.equal("An Introduction to LaTeX programming",
        latex_parser.latex_to_sentence_case_pseudo_html("an Introduction to LaTeX programming", true, true, true)
      )
    end)

    it("protected command", function ()
      assert.equal('The story of <span class="nocase">HMS</span> <i><span class="nocase">Erebus</span></i> in <i>really</i> strong wind',
        latex_parser.latex_to_sentence_case_pseudo_html(
          "The Story of {HMS} \\emph{Erebus} in {\\emph{Really}} Strong Wind",
          true, true, true
        )
      )
    end)

  end)


  describe("convert to sentence case", function ()

    it("unprotected", function ()
      assert.equal("An introduction to LaTeX",
        latex_parser.latex_to_sentence_case_pseudo_html("an Introduction to LaTeX", true, true, false)
      )
    end)

    it("with protecting braces", function ()
      assert.equal('An introduction to <span class="nocase">LaTeX</span>',
        latex_parser.latex_to_sentence_case_pseudo_html("an Introduction to {LaTeX}", true, true, false)
      )
    end)

    it("protected command", function ()
      assert.equal("The <code>{\\TeX </code>book<code>}</code>",
        latex_parser.latex_to_sentence_case_pseudo_html("The {\\TeX book}", true, true, false)
      )
    end)

    it("protected command", function ()
      assert.equal('The story of <span class="nocase">HMS</span> <i><span class="nocase">Erebus</span></i> in <i>really</i> strong wind',
        latex_parser.latex_to_sentence_case_pseudo_html(
          "The Story of {HMS} \\emph{Erebus} in {\\emph{Really}} Strong Wind",
          true, true, false
        )
      )
    end)

    it("\\NoCaseChange", function ()
      assert.equal('An introduction to <span class="nocase">LaTeX</span>',
        latex_parser.latex_to_sentence_case_pseudo_html(
          "An Introduction to \\NoCaseChange{LaTeX}",
          true, true, false
        )
      )
    end)

    it("with parenthesis", function ()
      -- From <https://www.unicode.org/reports/tr29/#Word_Boundaries>
      assert.equal("The quick (“brown”) fox can’t jump 32.3 feet, right?",
        latex_parser.latex_to_sentence_case_pseudo_html(
          "The Quick (“Brown”) Fox Can’t Jump 32.3 Feet, Right?",
          true, true, false
        )
      )
    end)

    it("after colon", function ()
      -- From <https://apastyle.apa.org/style-grammar-guidelines/capitalization/sentence-case>
      assert.equal("Suicide prevention: An ethically and scientifically informed approach",
        latex_parser.latex_to_sentence_case_pseudo_html(
          "Suicide Prevention: An Ethically and Scientifically Informed Approach",
          true, true, false
        )
      )
    end)

    it("after colon", function ()
      -- From <https://apastyle.apa.org/style-grammar-guidelines/capitalization/sentence-case>
      local s = "The Need for Cultural Adaptations to Health Interventions for {African} {American} Women: A Qualitative Analysis"
      local res = latex_parser.latex_to_sentence_case_pseudo_html(s, true, true, false)
      local expected = 'The need for cultural adaptations to health interventions for <span class="nocase">African</span> <span class="nocase">American</span> women: A qualitative analysis'
      assert.equal(expected, res)
    end)

  end)


  describe("LaTeX keys", function ()

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

end)
