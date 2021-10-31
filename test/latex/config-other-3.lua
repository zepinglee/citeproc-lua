---@diagnostic disable: lowercase-global

includetests = {"other-3-*"}

checkengines = {"pdftex", "xetex"}
stdengine = "pdftex"

checkruns = 3

function runtest_tasks(name, run)
  if run == 1 then
    -- TODO:
    return ""
  else
    return ""
  end
end
