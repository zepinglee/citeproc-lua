```bash
cd ../styles
git checkout v1.0.2
git pull
cd ../citeproc-lua
for style in submodules/styles/*.csl; do echo "y" | cp -f "../styles/$(basename $style)" submodules/styles; done

cd submodules/locales
git fetch upstream
git checkout ctan
git merge upstream/v1.0.2
git push
cd ../..

git submodule update --init --remote --checkout

python3 scripts/update_bibtex_data.py
python3 scripts/update_latex_data.py
python3 scripts/collect_journal_abbrevs.py

busted --run citeproc
busted

l3build tag x.x.x
git commit -a -m "Bump to vx.x.x"
git push

git tag vx.x.x
git push origin vx.x.x
```
