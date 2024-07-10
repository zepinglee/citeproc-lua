---@diagnostic disable: lowercase-global

testfiledir = "./tests/latex/luatex-2"

checkengines = {"luatex"}
stdengine = "luatex"
-- Since LuaTeX 2024-01-04, the `debug` library must be enabled with `--luadebug` argument.
checkopts = "-interaction=nonstopmode --luadebug"

checkruns = 2
