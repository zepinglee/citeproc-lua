# citeproc test


All test scripts are supposed to be run from the root directory of the repository.


## CSL test-suite

The [`citeproc-test.lua`](https://github.com/zepinglee/citeproc-lua/tree/main/test/citeproc-test.lua) is used for running the [CSL test-suite](https://github.com/citation-style-language/test-suite).


First clone the two submodules `test-suite` and [`locales`](https://github.com/citation-style-language/locales).
```bash
git submodule update --init
```

Then you can run the test script
```bash
texlua test/citepric-test.lua
```

The names of failing tests are printed to [`test/failing_tests.txt`](https://github.com/zepinglee/citeproc-lua/tree/main/test/failing_tests.txt).


Run a single test.
```bash
texlua test/citepric-test.lua name_AfterInvertedName
```

Run a subset of tests with same prefix.
```bash
texlua test/citepric-test.lua name_
```


## Other tests

Other Lua script are for various tests purposes. They are run with [`busted`](https://github.com/Olivine-Labs/busted).

Run all tests.
```bash
busted
```

Run single test.
```bash
busted test/date-test.lua
```
