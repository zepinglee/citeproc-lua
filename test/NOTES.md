# Notes on failures


## Capitalizing

It is beyond the spec to capitalize the initial term of each item.
See <https://github.com/jgm/citeproc/blob/b27201c3ac48ffd2853f77152df19b6e2cf36987/README.md#L107-L113>.

- `position_IbidWithLocator`
- `position_IfIbidWithLocatorIsTrueThenIbidIsTrue`


## Empty bibliography output

- `sort_OmittedBibRefMixedNumericStyle`
- `sort_OmittedBibRefNonNumericStyle`

How to distinguish a numeric style?


## Group suppressed

- `variables_TitleShortOnShortTitleNoTitleCondition`
  This test is contrary to the spec.  The whole group should
  be suppressed because it contains variables but none are
  called. See https://github.com/citation-style-language/test-suite/issues/29
- `variables_TitleShortOnShortTitleNoTitleCondition`


## Varibles set in `note` field

- label_NameLabelThroughSubstitute


### bugreports_UnisaHarvardInitialization

The expected output here includes a trailing space, which we delete.


### flipflop_LeadingMarkupWithApostrophe

Quotation marks in the prefix of cite-item are not transformed to double style and the punctuation after is not moved into quotes.


### label_EditorTranslator2

The period in `“Hello there.”` should be moved inside quotation marks.


### label_PluralWithLocalizedAmpersand

The `<term name="and" form="symbol">` does not exist in any locale files.


### name_AllCapsInitialsUntouched

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


### position_IbidWithSuffix

Name splitting issue.


### textcase_SentenceCapitalization.txt

The in-sentence words should not be changed to lowercase.


## variables_ContainerTitleShort2

`container-title-short` in `ntoe` field.
