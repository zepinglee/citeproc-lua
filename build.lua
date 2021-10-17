#!/usr/bin/env texlua
---@diagnostic disable: lowercase-global

-- Configuration file of "citeproc" for use with "l3build"

module = "citeproc"

docfiledir = "./doc"
sourcefiledir = "./citeproc"
testfiledir = "./test"

scriptfiles = {"*.lua", "*.json"}
-- scriptmanfiles = {"citeproc.1"}
sourcefiles = {"*.lua", "*.json", "*.sty"}
-- tagfiles = {}
-- typesetdemofiles = {}
