.PHONY: install test

test:
	busted --run=citeproc

install:
	l3build install

ctan:
	l3build ctan
