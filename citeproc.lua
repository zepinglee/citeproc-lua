--[[
  Copyright (C) 2021 Zeping Lee
--]]

-- The kpse library replaces package.searchers[2] with its own loader function
-- which cannot find `./?/init.lua`.
-- Thus this file is required to load `./citeproc/init.lua`.

return require("citeproc.init")
