## Notes on failures

### bugreports_UnisaHarvardInitialization

The expected output here includes a trailing space, which we delete.


## name_AllCapsInitialsUntouched

- Not initialized. It should be `<name initialized-with="." />`.


### number_OrdinalSpacing

Heuristics are used to render pages label.


### number_PlainHyphenOrEnDashAlwaysPlural

- The difference of cs:text and cs:name is not revealed.
  (Should it be `<number variable="page"/>`?)
- Duplicate item id `ITEM-4`.
- citeproc-js uses some heuristics to identify plurals,
  but they aren't part of the spec and aren't entirely reliable.
  "The logic will only set plurals where there is a numeric unit
  on either side of a hyphen or en-dash. Numeric units are strings
  ending in a number, or alphabetic strings consisting entirely of
  characters appropriate to a roman numeral."  This won't catch
  4a-5a or IIa-VIb.


### position_IbidWithLocator

Why is "ibid" converted to title case?


### position_IbidWithSuffix


Name splitting issue.


### variables_TitleShortOnShortTitleNoTitleCondition

This test is contrary to the spec.  The whole group should
be suppressed because it contains variables but none are
called. See https://github.com/citation-style-language/test-suite/issues/29
