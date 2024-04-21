```bash
cd ../styles
git checkout v1.0.2
git pull
cd ../citeproc-lua
for style in submodules/styles/*.csl; do
    cp -f "../styles/$(basename $style)" submodules/styles;
done

cd submodules/locales
git fetch upstream
git checkout ctan
git merge upstream/v1.0.2
git push
cd ../..

git submodule update --init --remote --merge

python3 scripts/update-bibtex-data.py
python3 scripts/update-latex-data.py
python3 scripts/collect-journal-abbrevs.py

busted --run citeproc
busted

l3build tag x.x.x
git commit -a -m "Bump to vx.x.x"
git push

git tag vxx.x.x
git push vx.x.x
```
