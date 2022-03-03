test_dir="./test/latex";

for path in "$test_dir"/*.lvt; do
    test="$(basename "$path" .lvt)";
    if [[ "$test" == luatex-1-* ]]; then
        l3build save --config test/latex/config-luatex-1 "$test" || exit 1;
    elif [[ "$test" == luatex-2-* ]]; then
        l3build save --config test/latex/config-luatex-2 "$test" || exit 1;
    elif [[ "$test" == other-1-* ]]; then
        l3build save --config test/latex/config-other-1 "$test" || exit 1;
    elif [[ "$test" == other-2-* ]]; then
        l3build save --config test/latex/config-other-2 "$test" || exit 1;
    fi
done
