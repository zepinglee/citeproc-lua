```bash
cd ../styles
git checkout v1.0.2
git pull
cd ../citeproc-lua
for style in submodules/styles/*.csl; do cp -f "../styles/$(basename $style)" .; done

cd submodules/locales
git fetch upstream
git merge upstream
git push
cd ../..

git submodule update --init --remote --merge

py scripts/update-bibtex-data.py
py scripts/update-latex-data.py
py scripts/collect-journal-abbrevs.py

busted --run citeproc
busted

code build.lua
code ctan.ann
l3build ctan
l3build upload
```
