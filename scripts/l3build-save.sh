test_dir="./tests/latex";

for path in "$test_dir"/luatex-1/*.lvt; do
    test="$(basename "$path" .lvt)";
    l3build save --config tests/latex/config-luatex-1 "$test" || exit 1;
done

for path in "$test_dir"/luatex-2/*.lvt; do
    test="$(basename "$path" .lvt)";
    l3build save --config tests/latex/config-luatex-2 "$test" || exit 1;
done

for path in "$test_dir"/pdftex-1/*.lvt; do
    test="$(basename "$path" .lvt)";
    l3build save --config tests/latex/config-pdftex-1 "$test" || exit 1;
done

for path in "$test_dir"/pdftex-2/*.lvt; do
    test="$(basename "$path" .lvt)";
    l3build save --config tests/latex/config-pdftex-2 "$test" || exit 1;
done
