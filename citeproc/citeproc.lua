--
-- Copyright (c) 2021-2025 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local citeproc = {}

local engine
local util
local using_luatex, kpse = pcall(require, "kpse")
if using_luatex then
  engine = require("citeproc-engine")
  util = require("citeproc-util")
else
  engine = require("citeproc.engine")
  util = require("citeproc.util")
end

citeproc.__VERSION__ = "0.9.1"

citeproc.new = engine.CiteProc.new
citeproc.util = util

return citeproc
