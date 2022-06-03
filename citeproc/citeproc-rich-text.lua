--
-- Copyright (c) 2021-2022 Zeping Lee
-- Released under the MIT license.
-- Repository: https://github.com/zepinglee/citeproc-lua
--

local rich_text = {}

local Element = require("citeproc-element").Element
local IrNode = require("citeproc-richtext").IrNode
local util = require("citeproc-util")


local RichText = Element:derive("number")


rich_text.RichText = RichText

return rich_text
