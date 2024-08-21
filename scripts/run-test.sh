for config in luatex-2 pdftex-1 pdftex-2; do
    cp -f "tests/latex/luatex-1/$1.lvt" "tests/latex/$config/"
done

for config in luatex-1 luatex-2 pdftex-1 pdftex-2; do
    l3build save --config tests/latex/config-$config "$1";
done
