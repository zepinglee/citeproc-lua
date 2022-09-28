---@diagnostic disable: lowercase-global

testfiledir = "./test/latex/pdftex-1"

checkengines = {"pdftex"}
stdengine = "pdftex"

checkruns = 1

-- function runtest_tasks(name, run)
--   if run == 1 then
--     return "texlua citeproc-lua.lua " .. name
--   else
--     return ""
--   end
-- end
