#!/bin/sh
cp "$@" ../citeproc-js/fixtures/local/lua_tmp.txt
cd ../citeproc-js
cslrun -s lua_tmp
