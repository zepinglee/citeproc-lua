#!/bin/sh
cp "$@" ../citeproc-js/fixtures/local/tmp.txt
cd ../citeproc-js
cslrun -s tmp
