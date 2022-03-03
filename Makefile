.PHONY: ctan doc install save test uninstall

test:
	busted --run=citeproc

ctan:
	l3build ctan

doc:
	latexmk -cd doc/citation-style-language-doc.tex

install:
	l3build install

save:
	bash tools/l3build-save.sh

uninstall:
	l3build uninstall
