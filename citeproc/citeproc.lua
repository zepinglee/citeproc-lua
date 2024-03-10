--
-- Copyright (c) 2021-2024 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local citeproc = {}

local engine
local util
if kpse then
  engine = require("citeproc-engine")
  util = require("citeproc-util")
else
  engine = require("citeproc.engine")
  util = require("citeproc.util")
end

citeproc.__VERSION__ = "0.4.7"

citeproc.new = engine.CiteProc.new
citeproc.util = util

return citeproc
