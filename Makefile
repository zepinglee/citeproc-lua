.PHONY: install test

test: install
	busted --run=citeproc

install:
	l3build install
