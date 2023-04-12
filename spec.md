# CSL 1.0.2 Specification

Principal Authors [Rintze M. Zelle,
PhD](https://twitter.com/rintzezelle), [Brenton M.
Wiernik](https://twitter.com/bmwiernik), Frank G. Bennett, Jr., Bruce
D'Arcus, Denis Maier

with additional contributions from Julien Gonzalez, Sebastian Karcher,
Sylvester Keil, Cormac Relf, Lars Willighagen, and other CSL
contributors.

![CCBYSA](/media/cc-by-sa-80x15.png)\_  
This work is licensed under a [Creative Commons Attribution-ShareAlike
4.0 International
License](https://creativecommons.org/licenses/by-sa/4.0/).

<div class="contents">

**Table of Contents**

</div>

## Introduction

The Citation Style Language (CSL) is an XML-based format to describe the
formatting of citations, notes and bibliographies, offering:

- An open format
- Compact and robust styles
- Extensive support for style requirements
- Automatic style localization
- Infrastructure for style distribution and updating
- Thousands of freely available styles (Creative Commons BY-SA licensed)

For additional documentation, the CSL schema, styles, and locales, visit
the CSL project home, [citationstyles.org](http://citationstyles.org).

### Terminology

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD
NOT, RECOMMENDED, MAY, and OPTIONAL, are to be interpreted as described
in [IETF RFC 2119](http://tools.ietf.org/html/rfc2119).

## Namespacing

The CSL [XML namespace URI](http://en.wikipedia.org/wiki/XML_Namespace)
is "<http://purl.org/net/xbiblio/csl>". The namespace prefix `cs:` is
used throughout this specification when referring to CSL elements, but
is generally omitted in favor of a default namespace declaration (set
with the `xmlns` attribute) on the root `cs:style` or `cs:locale`
element.

## Whitespace Handling

CSL styles are valid XML, but CSL processors MUST NOT normalize
attribute values by trimming leading or trailing whitespace from
attributes which define text that is intended for output:

- after-collapse-delimiter
- cite-group-delimiter
- delimiter
- initialize-with
- name-delimiter
- names-delimiter
- prefix
- range-delimiter
- sort-separator
- suffix
- year-suffix-delimiter
- value

## File Types

There are three types of CSL files: independent and dependent styles
(both types use the ".csl" extension), and locale files (named
"locales-xx-XX.xml", where "xx-XX" is a language dialect, e.g. "en-US"
for American English).

### Independent Styles

Independent styles contain formatting instructions for citations, notes
and bibliographies. While mostly self-contained, they rely on locale
files for (default) localization data.

### Dependent Styles

A dependent style is an alias for an independent style. Its contents are
limited to style metadata, and doesn't include any formatting
instructions (the sole exception is that dependent styles can specify an
overriding style locale). By linking dependent styles for journals that
share the same citation style (e.g., "Nature Biotechnology", "Nature
Nanotechnology", etc.) to a single independent style (e.g., "Nature
Journals"), there is no need to duplicate formatting instructions.

### Locale Files

Each locale file contains a set of localization data (term translations,
localized date formats, and grammar options) for a particular language
dialect.

## XML Declaration

Each style or locale should begin with an XML declaration, specifying
the XML version and character encoding. In most cases, the declaration
will be:

``` xml
<?xml version="1.0" encoding="UTF-8"?>
```

## Styles - Structure

### The Root Element - `cs:style`

The root element of styles is `cs:style`. In independent styles, the
element carries the following attributes:

`class`  
Determines whether the style uses in-text citations (value "in-text") or
notes ("note").

`default-locale` (optional)  
Sets a default locale for style localization. Value must be a [locale
code](http://books.xmlschemata.org/relaxng/ch19-77191.html).

`version`  
The CSL version of the style. Must be "1.0" for CSL 1.0-compatible
styles.

In addition, `cs:style` may carry any of the [global
options](#global-options) and [inheritable name
options](#inheritable-name-options).

Of these attributes, only `version` is required on `cs:style` in
dependent styles, while the `default-locale` attribute may be set to
specify an overriding style locale. The other attributes are allowed but
ignored.

An example of `cs:style` for an independent style, preceded by the XML
declaration:

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" version="1.0" class="in-text" default-locale="fr-FR"/>
```

### Child Elements of `cs:style`

In independent styles, the `cs:style` root element has the following
child elements:

`cs:info`  
Must appear as the first child element of `cs:style`. Contains the
metadata describing the style (style name, ID, authors, etc.).

`cs:citation`  
Must appear once. Describes the formatting of in-text citations or
notes.

`cs:bibliography` (optional)  
May appear once. Describes the formatting of the bibliography.

`cs:macro` (optional)  
May appear multiple times. Macros allow formatting instructions to be
reused, keeping styles compact and maintainable.

`cs:locale` (optional)  
May appear multiple times. Used to specify (overriding) localization
data.

In [dependent styles](#dependent-styles), `cs:style` has only one child
element, `cs:info`.

#### Info

The `cs:info` element contains the style's metadata. Its structure is
based on the [Atom Syndication
Format](http://tools.ietf.org/html/rfc4287).

In independent styles, `cs:info` has the following child elements:

`cs:author` and `cs:contributor` (optional)  
`cs:author` and `cs:contributor`, used to respectively acknowledge style
authors and contributors, may each be used multiple times. Within these
elements, the child element `cs:name` must appear once, while `cs:email`
and `cs:uri` each may appear once. These child elements should contain
respectively the name, email address and URI of the author or
contributor.

`cs:category` (optional)  
Styles may be assigned one or more categories. `cs:category` may be used
once to describe how in-text citations are rendered, using the
`citation-format` attribute set to one of the following values:

- "author-date" - e.g. "… (Doe, 1999)"
- "author" - e.g. "… (Doe)"
- "numeric" - e.g. "… \[1\]"
- "label" - e.g. "… \[doe99\]"
- "note" - the citation appears as a footnote or endnote

`cs:category` may be used multiple times with the `field` attribute, set
to one of the discipline categories (see [Appendix I -
Categories](#appendix-i---categories)), to indicates the field(s) for
which the style is relevant.

`cs:id`  
Must appear once and contain a stable, unique identifier to establish
the identity of the style. For historical reasons, existing styles may
use URIs, but new styles should use a UUID to guarantee stability and
uniqueness.

`cs:issn`/`cs:eissn`/`cs:issnl` (optional)  
The `cs:issn` element may be used multiple times to indicate the ISSN
identifier(s) of the journal for which the style was written. The
`cs:eissn` and `cs:issnl` elements may each be used once for the eISSN
and [ISSN-L](http://www.issn.org/2-22637-What-is-an-ISSN-L.php)
identifiers, respectively.

`cs:link` (optional)  
May be used multiple times. `cs:link` must carry two attributes: `href`,
set to a URI (usually a URL), and `rel`, whose value indicates how the
URI relates to the style. The possible values of `rel`:

- "self" - style URI
- "template" - URI of the style from which the current style is derived
- "documentation" - URI of style documentation

The `cs:link` element may contain content describing the link.

`cs:published` (optional)  
May appear once. The contents of `cs:published` must be a
[timestamp](http://books.xmlschemata.org/relaxng/ch19-77049.html),
indicating when the style was initially created or made available.

`cs:rights` (optional)  
May appear once. The contents of `cs:rights` specifies the license under
which the style file is released. The element may carry a `license`
attribute to specify the URI of the license.

`cs:summary` (optional)  
May appear once. The contents of `cs:summary` gives a (short)
description of the style.

`cs:title`  
Must appear once. The contents of `cs:title` should be the name of the
style as shown to users.

`cs:title-short` (optional)  
May appear once. The contents of `cs:title-short` should be a shortened
style name (e.g. "APA").

`cs:updated`  
Must appear once. The contents of `cs:updated` must be a
[timestamp](http://books.xmlschemata.org/relaxng/ch19-77049.html) that
shows when the style was last updated.

The `cs:link`, `cs:rights`, `cs:summary`, `cs:title` and
`cs:title-short` elements may carry a `xml:lang` attribute to specify
the language of the element's content (the value must be an
[xsd:language locale
code](http://books.xmlschemata.org/relaxng/ch19-77191.html)). For
`cs:link`, the attribute can also be used to indicate the language of
the link target.

In [dependent styles](#dependent-styles), `cs:link` must be used with
`rel` set to "independent-parent", with the URI of the independent
parent style set on `href`. In addition, `cs:link` may not be used with
`rel` set to "template".

An example of `cs:info` for an independent style:

``` xml
<info>
  <title>Style Title</title>
  <id>http://www.zotero.org/styles/style-title</id>
  <link href="http://www.zotero.org/styles/style-title" rel="self"/>
  <link href="http://www.example.org/instructions-to-authors#references" rel="documentation"/>
  <author>
    <name>Author Name</name>
    <email>name@example.org</email>
    <uri>http://www.example.org/name</uri>
  </author>
  <category citation-format="author-date"/>
  <category field="zoology"/>
  <updated>2011-10-29T21:01:24+00:00</updated>
  <rights license="http://creativecommons.org/licenses/by-sa/3.0/">This work
  is licensed under a Creative Commons Attribution-ShareAlike 3.0 License</rights>
</info>
```

#### Citation

The `cs:citation` element describes the formatting of citations, which
consist of one or more references ("cites") to bibliographic sources.
Citations appear in the form of either in-text citations (in the author
(e.g. "\[Doe\]"), author-date ("\[Doe 1999\]"), label ("\[doe99\]") or
number ("\[1\]") format) or notes. The required `cs:layout` child
element describes what, and how, bibliographic data should be included
in the citations (see [Layout](#layout)). `cs:layout` may be preceded by
a `cs:sort` element, which can be used to specify how cites within a
citation should be sorted (see [Sorting](#sorting)). The `cs:citation`
element may carry attributes for [Citation-specific
Options](#citation-specific-options) and [Inheritable Name
Options](#inheritable-name-options). An example of a `cs:citation`
element:

``` xml
<citation>
  <sort>
    <key variable="citation-number"/>
  </sort>
  <layout>
    <text variable="citation-number"/>
  </layout>
</citation>
```

**A note to CSL processor developers** In note styles, a citation is
often a sentence by itself. Therefore, the first character of a citation
should preferably be uppercased when there is no preceding text in the
note. In all other cases (e.g. when a citation is inserted into the
middle of a pre-existing footnote), the citation should be printed as
is.

#### Bibliography

The `cs:bibliography` element describes the formatting of
bibliographies, which list one or more bibliographic sources. The
required `cs:layout` child element describes how each bibliographic
entry should be formatted. `cs:layout` may be preceded by a `cs:sort`
element, which can be used to specify how references within the
bibliography should be sorted (see [Sorting](#sorting)). The
`cs:bibliography` element may carry attributes for
[Bibliography-specific Options](#bibliography-specific-options) and
[Inheritable Name Options](#inheritable-name-options). An example of a
`cs:bibliography` element:

``` xml
<bibliography>
  <sort>
    <key macro="author"/>
  </sort>
  <layout>
    <group delimiter=". ">
      <text macro="author"/>
      <text variable="title"/>
    </group>
  </layout>
</bibliography>
```

#### Macro

Macros, defined with `cs:macro` elements, contain formatting
instructions. Macros can be called with `cs:text` from within other
macros and the `cs:layout` element of `cs:citation` and
`cs:bibliography`, and with `cs:key` from within `cs:sort` of
`cs:citation` and `cs:bibliography`. It is recommended to place macros
after any `cs:locale` elements and before the `cs:citation` element.

Macros are referenced by the value of the required `name` attribute on
`cs:macro`. The `cs:macro` element must contain one or more [rendering
elements](#rendering-elements).

The use of macros can improve style readability, compactness and
maintainability. It is recommended to keep the contents of `cs:citation`
and `cs:bibliography` compact and agnostic of item types (e.g. books,
journal articles, etc.) by depending on macro calls. To allow for easy
reuse of macros in other styles, it is recommended to use common macro
names.

In the example below, cites consist of the item title, rendered in
italics when the item type is "book":

``` xml
<style>
  <macro name="title">
    <choose>
      <if type="book">
        <text variable="title" font-style="italic"/>
      </if>
      <else>
        <text variable="title"/>
      </else>
    </choose>
  </macro>
  <citation>
    <layout>
      <text macro="title"/>
    </layout>
  </citation>
</style>
```

Delimiters from any ancestor delimiting element are not applied within
the output of a `<text macro="...">` element (see
[delimiter](#delimiter)).

#### Locale

Localization data, by default drawn from the "locales-xx-XX.xml" locale
files, may be redefined or supplemented with `cs:locale` elements, which
should be placed directly after the `cs:info` element.

The value of the optional `xml:lang` attribute on `cs:locale`, which
must be set to an [xsd:language locale
code](http://books.xmlschemata.org/relaxng/ch19-77191.html), determines
which languages or language dialects are affected (see [Locale
Fallback](#locale-fallback)).

See [Terms](#terms), [Localized Date Formats](#localized-date-formats)
and [Localized Options](#localized-options) for further details on the
use of `cs:locale`.

An example of `cs:locale` in a style:

``` xml
<style>
  <locale xml:lang="en">
    <terms>
      <term name="editortranslator" form="short">
        <single>ed. &amp; trans.</single>
        <multiple>eds. &amp; trans.</multiple>
      </term>
    </terms>
  </locale>
</style>
```

##### Locale Fallback

Locale files provide localization data for language dialects (e.g.
"en-US" for American English), whereas the optional `cs:locale` elements
in styles can either lack the `xml:lang` attribute, or have it set to
either a language (e.g. "en" for English) or dialect. Locale fallback is
the mechanism determining from which of these sources each localizable
unit (a date format, localized option, or specific form of a term) is
retrieved.

For dialects of the same language, one is designated the primary
dialect. All others are secondaries. At the moment of writing, the
available locale files include:

| Primary dialect    | Secondary dialect(s)                 |
|--------------------|--------------------------------------|
| de-DE (German)     | de-AT (Austria), de-CH (Switzerland) |
| en-US (English)    | en-GB (UK)                           |
| es-ES (Spanish)    | es-CL (Chile), es-MX (Mexico)        |
| fr-FR (French)     | fr-CA (Canada)                       |
| pt-PT (Portuguese) | pt-BR (Brazil)                       |
| zh-CN (Chinese)    | zh-TW (Taiwan)                       |

Locale fallback is best described with an example. If the chosen output
locale is "de-AT" (Austrian German), localizable units are individually
drawn from the following sources, in decreasing order of priority:

1.  In-style `cs:locale` elements
    1.  `xml:lang` set to chosen dialect, "de-AT"
    2.  `xml:lang` set to matching language, "de" (German)
    3.  `xml:lang` not set
2.  Locale files
    4.  `xml:lang` set to chosen dialect, "de-AT"
    5.  `xml:lang` set to matching primary dialect, "de-DE" (Standard
        German) (only applicable when the chosen locale is a secondary
        dialect)
    6.  `xml:lang` set to "en-US" (American English)

If the chosen output locale is a language (e.g. "de"), the (primary)
dialect is used in step 1 (e.g. "de-DE").

Fallback stops once a localizable unit has been found. For terms, this
even is the case when they are defined as empty strings (e.g.
`<term name="and"/>` or `<term name="and"></term>`). Locale fallback
takes precedence over fallback of term forms (see [Terms](#terms)).

## Locale Files - Structure

While localization data can be included in styles (see
[Locale](#locale)), locale files conveniently provide sets of default
localization data, consisting of terms, date formats and grammar
options.

Each locale file contains localization data for a single language
dialect. This [locale
code](http://books.xmlschemata.org/relaxng/ch19-77191.html) is set on
the required `xml:lang` attribute on the `cs:locale` root element. The
same locale code must also be used in the file name of the locale file
(the "xx-XX" in "locales-xx-XX.xml"). The root element must carry the
`version` attribute, indicating the CSL version of the locale file (must
be "1.0" for CSL 1.0-compatible locale files). Locale files have the
same requirements for [namespacing](#namespacing) as styles. The
`cs:locale` element may contain `cs:info` as its first child element,
and requires the child elements `cs:terms`, `cs:date` and
`cs:style-options` (these elements are described below). An example
showing part of a locale file:

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<locale xml:lang="en-US" version="1.0" xmlns="http://purl.org/net/xbiblio/csl">
  <style-options punctuation-in-quote="true"/>
  <date form="text">
    <date-part name="month" suffix=" "/>
    <date-part name="day" suffix=", "/>
    <date-part name="year"/>
  </date>
  <date form="numeric">
    <date-part name="year"/>
    <date-part name="month" form="numeric" prefix="-" range-delimiter="/"/>
    <date-part name="day" prefix="-" range-delimiter="/"/>
  </date>
  <terms>
    <term name="no date">n.d.</term>
    <term name="et-al">et al.</term>
    <term name="page">
      <single>page</single>
      <multiple>pages</multiple>
    </term>
    <term name="page" form="short">
      <single>p.</single>
      <multiple>pp.</multiple>
    </term>
  </terms>
</locale>
```

### Info

The `cs:info` element may be used to give metadata on the locale file.
It has the following child elements:

`cs:translator` (optional)  
`cs:translator`, used to acknowledge locale translators, may be used
multiple times. Within the element, the child element `cs:name` must
appear once, while `cs:email` and `cs:uri` each may appear once. These
child elements should contain respectively the name, email address and
URI of the translator.

`cs:rights` (optional)  
May appear once. The contents of `cs:rights` specifies the license under
which the locale file is released. The element may carry a `license`
attribute to specify the URI of the license, and a `xml:lang` attribute
to specify the language of the element's content (the value must be an
[xsd:language locale
code](http://books.xmlschemata.org/relaxng/ch19-77191.html)).

`cs:updated` (optional)  
May appear once. The contents of `cs:updated` must be a
[timestamp](http://books.xmlschemata.org/relaxng/ch19-77049.html) that
shows when the locale file was last updated.

### Terms

Terms are localized strings (e.g. by using the "and" term, "Doe and
Smith" automatically becomes "Doe und Smith" when the style locale is
switched from English to German). Terms are defined with `cs:term`
elements, child elements of `cs:terms`. Each `cs:term` element must
carry a `name` attribute, set to one of the terms listed in [Appendix
II - Terms](#appendix-ii---terms).

Terms are either directly defined in the content of `cs:term`, or, in
cases where singular and plural variants are needed (e.g. "page" and
"pages"), in the content of the child elements `cs:single` and
`cs:multiple`, respectively.

Terms may be defined for specific forms by using `cs:term` with the
optional `form` attribute set to:

- "long" - (default), e.g. "editor" and "editors" for the "editor" term
- "short" - e.g. "ed." and "eds." for the term "editor"
- "verb" - e.g. "edited by" for the term "editor"
- "verb-short" - e.g. "ed." for the term "editor"
- "symbol" - e.g. "§" and "§§" for the term "section"

If a style uses a term in a form that is undefined (even after [Locale
Fallback](#locale-fallback)), there is fallback to other forms:
"verb-short" first falls back to "verb", "symbol" first falls back to
"short", and "verb" and "short" both fall back to "long". In addition,
the terms "long-ordinal-01" to "long-ordinal-10" fall back to the set of
ordinal suffix terms. If no locale or form fallback is available, the
term is rendered as an empty string.

The `match`, `gender`, and `gender-form` attributes can be used on
`cs:term` for the formatting of number variables rendered as ordinals
(e.g. "first", "2nd"). See [Ordinal Suffixes](#ordinal-suffixes) and
[Gender-specific Ordinals](#gender-specific-ordinals) below.

Term content should not contain markup such as LaTeX or HTML.
[Superscripted Unicode
characters](http://unicode.org/reports/tr30/datafiles/SuperscriptFolding.txt)
can be used for superscripting.

#### Ordinal Suffixes

Number variables can be rendered with `cs:number` in the "ordinal" form,
e.g. "2nd" (see [Number](#number)). The ordinal suffixes ("nd" for
"2nd") are defined with terms.

The "ordinal" term defines the default ordinal suffix. This default
suffix may be overridden for certain numbers with the following terms:

- "ordinal-00" through "ordinal-09" - by default, a term in this group
  is used when the last digit in the term name matches the last digit of
  the rendered number. E.g. "ordinal-00" would match the numbers "0",
  "10", "20", etc. By setting the optional `match` attribute to
  "last-two-digits" ("last-digit" is the default), matches are limited
  to numbers where the two last digits agree ("0", "100", "200", etc.).
  When `match` is set to "whole-number", there is only a match if the
  number is the same as that of the term.
- "ordinal-10" through "ordinal-99" - by default, a term in this group
  is used when the last two digits in the term name match the last two
  digits of the rendered number. When the optional `match` attribute is
  set to "whole-number" ("last-two-digits" is the default), there is
  only a match if the number is the same as that of the term.

When a number has matching terms from both groups (e.g. "13" can match
"ordinal-03" and "ordinal-13"), the term from the "ordinal-10" through
"ordinal-99" group is used.

Ordinal terms work differently in CSL 1.0.1 and later than they did in
CSL 1.0. When neither the style or locale file define the "ordinal"
term, but do define the terms "ordinal-01" through "ordinal-04", the
original CSL 1.0 scheme is used: "ordinal-01" is used for numbers ending
on a 1 (except those ending on 11), "ordinal-02" for those ending on a 2
(except those ending on 12), "ordinal-03" for those ending on a 3
(except those ending on 13) and "ordinal-04" for all other numbers.

The "ordinal" term, and "ordinal-00" through "ordinal-99" terms, behave
differently from other terms when it comes to
<span class="title-ref">Locale Fallback</span>. Whereas other terms can
be (re)defined individually, (re)defining any of the ordinal terms
through `cs:locale` replaces all previously defined ordinal terms.

#### Long Ordinals

Number variables can be rendered with `cs:number` in the "long-ordinal"
form, e.g. "second" (see [Number](#number)). The long ordinal terms
(e.g. "second" for "2") are defined with the "long-ordinal-01" through
"long-ordinal-10" terms.  
Long ordinal forms are available for the numbers 1 through 10. For other
numbers "long-ordinal" falls back to "ordinal".  
For the numbers 1 through 10 in "long-ordinal" form, the `match`
attribute is always treated as "whole-number". For other numbers
rendered in "long-ordinal" form, the optional `match` attribute follows
the behavior described in [Ordinal Suffixes](#ordinal-suffixes)
("last-two-digits" is the default).

#### Gender-specific Ordinals

Some languages use gender-specific ordinals. For example, the English
"1st" and "first" translate in French to "1<sup>er</sup>" and "premier"
if the target noun is masculine, and "1<sup>re</sup>" and "première" if
the noun is feminine.

Feminine and masculine variants of the ordinal terms (see
[Ordinals](#ordinals)) may be specified by setting the `gender-form`
attribute to "feminine" or "masculine" (the term without `gender-form`
represents the neuter variant). There are two types of target nouns: a)
the terms accompanying the [number variables](#number-variables), and b)
the month terms (see [Months](#months)). The gender of these nouns may
be specified on the "long" (default) form of the term using the `gender`
attribute (set to "feminine" or "masculine"). When a number variable is
rendered with `cs:number` in the "ordinal" or "long-ordinal" form, the
ordinal term of the same gender is used, with a fallback to the neuter
variant if the feminine or masculine variant is undefined. When the
"day" date-part is rendered in the "ordinal" form, the ordinal gender is
matched against that of the month term.

The example below gives "1re éd." ("1st ed."), "1er janvier" ("January
1st"), and "3e édition" ("3rd edition"):

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<locale xml:lang="fr-FR">
  <terms>
    <term name="edition" gender="feminine">
      <single>édition</single>
      <multiple>éditions</multiple>
    </term>
    <term name="edition" form="short">éd.</term>
    <term name="month-01" gender="masculine">janvier</term>
    <term name="ordinal">e</term>
    <term name="ordinal-01" gender-form="feminine" match="whole-number">re</term>
    <term name="ordinal-01" gender-form="masculine" match="whole-number">er</term>
  </terms>
</locale>
```

### Localized Date Formats

Two localized date formats can be defined with `cs:date` elements: a
"numeric" (e.g. "12-15-2005") and a "text" format (e.g. "December 15,
2005"). The format is set on `cs:date` with the required `form`
attribute.

A date format is constructed using `cs:date-part` child elements (see
[Date-part](#date-part)). With a required `name` attribute set to either
`day`, `month` or `year`, the order of these elements reflects the
display order of respectively the day, month, and year. The date can be
formatted with [formatting](#formatting) and [text-case](#text-case)
attributes on the `cs:date` and `cs:date-part` elements. The
[delimiter](#delimiter) attribute may be set on `cs:date` to specify the
delimiter for the `cs:date-part` elements, and [affixes](#affixes) may
be applied to the `cs:date-part` elements.

**Note** Affixes are not allowed on `cs:date` when defining localized
date formats. This restriction is in place to separate locale-specific
affixes (set on the `cs:date-part` elements) from any style-specific
affixes (set on the calling `cs:date` element), such as parentheses. An
example of a macro calling a localized date format:

``` xml
<macro name="issued">
 <date variable="issued" form="numeric" prefix="(" suffix=")"/>
</macro>
```

### Localized Options

There are two localized options, `limit-day-ordinals-to-day-1` and
`punctuation-in-quote` (see [Locale Options](#locale-options)). These
global options (which affect both citations and the bibliography) are
set as optional attributes on `cs:style-options`.

## Rendering Elements

Rendering elements specify which, and in what order, pieces of
bibliographic metadata are included in citations and bibliographies, and
offer control over their formatting.

### Layout

The `cs:layout` rendering element is a required child element of
`cs:citation` and `cs:bibliography`. It must contain one or more of the
other rendering elements described below, and may carry
[affixes](#affixes) and [formatting](#formatting) attributes. When used
within `cs:citation`, the [delimiter](#delimiter) attribute may be used
to specify a delimiter for cites within a citation. For example, a
citation like "(1, 2)" can be achieved with:

``` xml
<citation>
  <layout prefix="(" suffix=")" delimiter=", ">
    <text variable="citation-number"/>
  </layout>
</citation>
```

### Text

The `cs:text` rendering element outputs text. It must carry one of the
following attributes to select what should be rendered:

- `variable` - renders the text contents of a variable. Attribute value
  must be one of the [standard variables](#standard-variables). May be
  accompanied by the `form` attribute to select the "long" (default) or
  "short" form of a variable (e.g. the full or short title). If the
  "short" form is selected but unavailable, the "long" form is rendered
  instead.
- `macro` - renders the text output of a macro. Attribute value must
  match the value of the `name` attribute of a `cs:macro` element (see
  [Macro](#macro)).
- `term` - renders a term. Attribute value must be one of the terms
  listed in [Appendix II - Terms](#appendix-ii---terms). May be
  accompanied by the `plural` attribute to select the singular ("false",
  default) or plural ("true") variant of a term, and by the `form`
  attribute to select the "long" (default), "short", "verb",
  "verb-short" or "symbol" form variant (see also [Terms](#terms)).
- `value` - renders the attribute value itself.

An example of `cs:text` rendering the "title" variable:

``` xml
<text variable="title"/>
```

`cs:text` may also carry [affixes](#affixes), [display](#display),
[formatting](#formatting), [quotes](#quotes),
[strip-periods](#strip-periods) and [text-case](#text-case) attributes.

### Date

The `cs:date` rendering element outputs the date selected from the list
of [date variables](#date-variables) with the required `variable`
attribute. A date can be rendered in either a localized or non-localized
format.

[Localized date formats](#localized-date-formats) are selected with the
optional `form` attribute, which must be set to either "numeric" (for
fully numeric formats, e.g. "12-15-2005"), or "text" (for formats with a
non-numeric month, e.g. "December 15, 2005"). Localized date formats can
be customized in two ways. First, the `date-parts` attribute may be used
to show fewer date parts. The possible values are:

- "year-month-day" - (default), renders the year, month and day
- "year-month" - renders the year and month
- "year" - renders the year

Secondly, `cs:date` may have one or more `cs:date-part` child elements
(see [Date-part](#date-part)). The attributes set on these elements
override those specified for the localized date formats (e.g. to get
abbreviated months for all locales, the `form` attribute on the
month-`cs:date-part` element can be set to "short"). These
`cs:date-part` elements do not affect which, or in what order, date
parts are rendered. [Affixes](#affixes), which are very locale-specific,
are not allowed on these `cs:date-part` elements.

In the absence of the `form` attribute, `cs:date` describes a
self-contained non-localized date format. In this case, the date format
is constructed using `cs:date-part` child elements. With a required
`name` attribute set to either `day`, `month` or `year`, the order of
these elements reflects the display order of respectively the day,
month, and year. The date can be formatted with
[formatting](#formatting) attributes on the `cs:date-part` elements, as
well as several `cs:date-part`-specific attributes (see
[Date-part](#date-part)). The [delimiter](#delimiter) attribute may be
set on `cs:date` to specify the delimiter for the `cs:date-part`
elements, and [affixes](#affixes) may be applied to the `cs:date-part`
elements.

For both localized and non-localized dates, `cs:date` may carry
[affixes](#affixes), [display](#display), [formatting](#formatting) and
[text-case](#text-case) attributes.

#### Date-part

The `cs:date-part` elements control how date parts are rendered. Unless
the parent `cs:date` element calls a localized date format, they also
determine which, and in what order, date parts appear. A `cs:date-part`
element describes the date part selected with the required `name`
attribute:

"day"  
For "day", `cs:date-part` may carry the `form` attribute, with values:

- "numeric" - (default), e.g. "1"
- "numeric-leading-zeros" - e.g. "01"
- "ordinal" - e.g. "1st"

Some languages, such as French, only use the "ordinal" form for the
first day of the month ("1er janvier", "2 janvier", "3 janvier", etc.).
Such output can be achieved with the "ordinal" form and use of the
`limit-day-ordinals-to-day-1` attribute (see [Locale
Options](#locale-options)).

"month"  
For "month", `cs:date-part` may carry the
[strip-periods](#strip-periods) and `form` attributes. In locale files,
month abbreviations (the "short" form of the month [terms](#terms))
should be defined with periods if applicable (e.g. "Jan.", "Feb.",
etc.). These periods can be removed by setting
[strip-periods](#strip-periods) to "true" ("false" is the default). The
`form` attribute can be set to:

- "long" - (default), e.g. "January"
- "short" - e.g. "Jan."
- "numeric" - e.g. "1"
- "numeric-leading-zeros" - e.g. "01"

"year"  
For "year", `cs:date-part` may carry the `form` attribute, with values:

- "long" - (default), e.g. "2005"
- "short" - e.g. "05"

`cs:date-part` may also carry [formatting](#formatting),
[text-case](#text-case) and `range-delimiter` (see [Date
Ranges](#date-ranges)) attributes. Attributes for [affixes](#affixes)
are allowed, unless `cs:date` calls a localized date format.

##### Date Ranges

The default delimiter for dates in a date range is an en-dash (e.g. "May
– July 2008"). Custom range delimiters can be set on `cs:date-part`
elements with the optional `range-delimiter` attribute. When a date
range is rendered, the range delimiter is drawn from the `cs:date-part`
element matching the largest date part ("year", "month", or "day") that
differs between the two dates. For example,

``` xml
<style>
  <citation>
    <layout>
      <date variable="issued">
        <date-part name="day" suffix=" " range-delimiter="-"/>
        <date-part name="month" suffix=" "/>
        <date-part name="year" range-delimiter="/"/>
      </date>
    </layout>
  </citation>
</style>
```

would result in "1-4 May 2008", "May – July 2008" and "May 2008/June
2009".

#### AD and BC

The "ad" term (Anno Domini) is automatically appended to positive years
of less than four digits (e.g. "79" becomes "79AD"). The "bc" term
(Before Christ) is automatically appended to negative years (e.g.
"-2500" becomes "2500BC").

#### Seasons

If a date includes a season instead of a month, a season term
("season-01" to "season-04", respectively Spring, Summer, Autumn and
Winter) take the place of the month term. E.g.,

``` xml
<style>
  <citation>
    <layout>
      <date variable="issued">
        <date-part name="month" suffix=" "/>
        <date-part name="year"/>
      </date>
    </layout>
  </citation>
</style>
```

would result in "May 2008" and "Winter 2009".

#### Approximate Dates

Approximate dates test "true" for the `is-uncertain-date` conditional
(see [Choose](#choose)). For example,

``` xml
<style>
  <citation>
    <layout>
      <choose>
        <if is-uncertain-date="issued">
          <text term="circa" form="short" suffix=" "/>
        </if>
      </choose>
      <date variable="issued">
        <date-part name="year"/>
      </date>
    </layout>
  </citation>
</style>
```

would result in "2005" (normal date) and "ca. 2003" (approximate date).

### Number

The `cs:number` rendering element outputs the number variable selected
with the required `variable` attribute. [Number
variables](#number-variables) are a subset of the list of [standard
variables](#standard-variables).

If a number variable is rendered with `cs:number` and only contains
numeric content (as determined by the rules for `is-numeric`, see
[Choose](#choose)), the number(s) are extracted. Variable content is
rendered "as is" when the variable contains any non-numeric content
(e.g. "Special edition").

During the extraction, numbers separated by a hyphen are stripped of
intervening spaces ("2 - 4" becomes "2-4"). Numbers separated by a comma
receive one space after the comma ("2,3" and "2 , 3" become "2, 3"),
while numbers separated by an ampersand receive one space before and one
after the ampersand ("2&3" becomes "2 & 3").

Extracted numbers can be formatted via the optional `form` attribute,
with values:

- "numeric" - (default), e.g. "1", "2", "3"
- "ordinal" - e.g. "1st", "2nd", "3rd". Ordinal suffixes are defined
  with terms (see [Ordinal Suffixes](#ordinal-suffixes)).
- "long-ordinal" - e.g. "first", "second", "third". Long ordinals are
  defined with the [terms](#terms) "long-ordinal-01" to
  "long-ordinal-10", which are used for the numbers 1 through 10. For
  other numbers "long-ordinal" falls back to "ordinal".
- "roman" - e.g. "i", "ii", "iii"

Numbers with prefixes or suffixes are never ordinalized or rendered in
roman numerals (e.g. "2E" remains "2E). Numbers without affixes are
individually transformed ("2, 3" can become "2nd, 3rd", "second, third"
or "ii, iii").

`cs:number` may carry [affixes](#affixes), [display](#display),
[formatting](#formatting) and [text-case](#text-case) attributes.

### Names

The `cs:names` rendering element outputs the contents of one or more
[name variables](#name-variables) (selected with the required `variable`
attribute), each of which can contain multiple names (e.g. the "author"
variable contains all the author names of the cited item). If multiple
variables are selected (separated by single spaces, see example below),
each variable is independently rendered in the order specified, with one
exception: when the selection consists of "editor" and "translator", and
when the contents of these two name variables is identical, then the
contents of only one name variable is rendered. In addition, the
"editortranslator" term is used if the `cs:names` element contains a
`cs:label` element, replacing the default "editor" and "translator"
terms (e.g. resulting in "Doe (editor & translator)"). The
[delimiter](#delimiter) attribute may be set on `cs:names` to separate
the names of the different name variables (e.g. the semicolon in "Doe,
Smith (editors); Johnson (translator)").

``` xml
<names variable="editor translator" delimiter="; ">
  <label prefix=" (" suffix=")"/>
</names>
```

`cs:names` has four child elements (discussed below): `cs:name`,
`cs:et-al`, `cs:substitute` and `cs:label`. The `cs:names` element may
carry [affixes](#affixes), [display](#display) and
[formatting](#formatting) attributes.

#### Name

The `cs:name` element, an optional child element of `cs:names`, can be
used to describe the formatting of individual names, and the separation
of names within a name variable. `cs:name` may carry the following
attributes:

`and`  
Specifies the delimiter between the second to last and last name of the
names in a name variable. Allowed values are "text" (selects the "and"
term, e.g. "Doe, Johnson and Smith") and "symbol" (selects the
ampersand, e.g. "Doe, Johnson & Smith").

`delimiter`  
Specifies the text string used to separate names in a name variable.
Default is ", " (e.g. "Doe, Smith").

`delimiter-precedes-et-al`  
Determines when the name delimiter or a space is used between a
truncated name list and the "et-al" (or "and others") term in case of
et-al abbreviation. Allowed values:

- "contextual" - (default), name delimiter is only used for name lists
  truncated to two or more names
  - 1 name: "J. Doe et al."
  - 2 names: "J. Doe, S. Smith, et al."
- "after-inverted-name" - name delimiter is only used if the preceding
  name is inverted as a result of the `name-as-sort-order` attribute.
  E.g. with `name-as-sort-order` set to "first":
  - "Doe, J., et al."
  - "Doe, J., S. Smith et al."
- "always" - name delimiter is always used
  - 1 name: "J. Doe, et al."
  - 2 names: "J. Doe, S. Smith, et al."
- "never" - name delimiter is never used
  - 1 name: "J. Doe et al."
  - 2 names: "J. Doe, S. Smith et al."

`delimiter-precedes-last`  
Determines when the name delimiter is used to separate the second to
last and the last name in name lists (if `and` is not set, the name
delimiter is always used, regardless of the value of
`delimiter-precedes-last`). Allowed values:

- "contextual" - (default), name delimiter is only used for name lists
  with three or more names
  - 2 names: "J. Doe and T. Williams"
  - 3 names: "J. Doe, S. Smith, and T. Williams"
- "after-inverted-name" - name delimiter is only used if the preceding
  name is inverted as a result of the `name-as-sort-order` attribute.
  E.g. with `name-as-sort-order` set to "first":
  - "Doe, J., and T. Williams"
  - "Doe, J., S. Smith and T. Williams"
- "always" - name delimiter is always used
  - 2 names: "J. Doe, and T. Williams"
  - 3 names: "J. Doe, S. Smith, and T. Williams"
- "never" - name delimiter is never used
  - 2 names: "J. Doe and T. Williams"
  - 3 names: "J. Doe, S. Smith and T. Williams"

`et-al-min` / `et-al-use-first`  
Use of these two attributes enables et-al abbreviation. If the number of
names in a name variable matches or exceeds the number set on
`et-al-min`, the rendered name list is truncated after reaching the
number of names set on `et-al-use-first`. The "et-al" (or "and others")
term is appended to truncated name lists (see also [Et-al](#et-al)). By
default, when a name list is truncated to a single name, the name and
the "et-al" (or "and others") term are separated by a space (e.g. "Doe
et al."). When a name list is truncated to two or more names, the name
delimiter is used (e.g. "Doe, Smith, et al."). This behavior can be
changed with the `delimiter-precedes-et-al` attribute.

`et-al-subsequent-min` / `et-al-subsequent-use-first`  
If used, the values of these attributes replace those of respectively
`et-al-min` and `et-al-use-first` for subsequent cites (cites
referencing earlier cited items).

`et-al-use-last`  
When set to "true" (the default is "false"), name lists truncated by
et-al abbreviation are followed by the name delimiter, the ellipsis
character, and the last name of the original name list. This is only
possible when the original name list has at least two more names than
the truncated name list (for this the value of
`et-al-use-first`/`et-al-subsequent-min` must be at least 2 less than
the value of `et-al-min`/`et-al-subsequent-use-first`). An example:

    A. Goffeau, B. G. Barrell, H. Bussey, R. W. Davis, B. Dujon, H.
    Feldmann, … S. G. Oliver

The remaining attributes, discussed below, only affect personal names.
Personal names require a "family" name-part, and may also contain
"given", "suffix", "non-dropping-particle" and "dropping-particle"
name-parts. These name-parts are defined as:

- "family" - surname minus any particles and suffixes
- "given" - given names, either full ("John Edward") or initialized ("J.
  E.")
- "suffix" - name suffix, e.g. "Jr." in "John Smith Jr." and "III" in
  "Bill Gates III"
- "non-dropping-particle" - name particles that are not dropped when
  only the surname is shown ("van" in the Dutch surname "van Gogh") but
  which may be treated separately from the family name, e.g. for sorting
- "dropping-particle" - name particles that are dropped when only the
  surname is shown ("van" in "Ludwig van Beethoven", which becomes
  "Beethoven", or "von" in "Alexander von Humboldt", which becomes
  "Humboldt")

The attributes affecting personal names:

`form`  
Specifies whether all the name-parts of personal names should be
displayed (value "long", the default), or only the family name and the
non-dropping-particle (value "short"). A third value, "count", returns
the total number of names that would otherwise be rendered by the use of
the `cs:names` element (taking into account the effects of et-al
abbreviation and editor/translator collapsing), which allows for
advanced [sorting](#sorting).

`initialize`  
When set to "false" (the default is "true"), given names are no longer
initialized when "initialize-with" is set. However, the value of
"initialize-with" is still added after initials present in the full name
(e.g. with `initialize` set to "false", and `initialize-with` set to
".", "James T Kirk" becomes "James T. Kirk").

`initialize-with`  
When set, given names are converted to initials. The attribute value is
added after each initial ("." results in "J. J. Doe"). For compound
given names (e.g. "Jean-Luc"), hyphenation of the initials can be
controlled with the global `initialize-with-hyphen` option (see
[Hyphenation of Initialized Names](#hyphenation-of-initialized-names)).

`name-as-sort-order`  
Specifies that names should be displayed with the given name following
the family name (e.g. "John Doe" becomes "Doe, John"). The attribute has
two possible values:

- "first" - attribute only has an effect on the first name of each name
  variable
- "all" - attribute has an effect on all names

Note that even when `name-as-sort-order` changes the name-part order,
the display order is not necessarily the same as the sorting order for
names containing particles and suffixes (see [Name-part
order](#name-part-order)). Also, `name-as-sort-order` only affects names
written in scripts where the given name typically precedes the family
name, such as Latin, Greek, Cyrillic and Arabic. In contrast, names
written in Asian scripts are always displayed with the family name
preceding the given name.

`sort-separator`  
Sets the delimiter for name-parts that have switched positions as a
result of `name-as-sort-order`. The default value is ", " ("Doe, John").
As is the case for `name-as-sort-order`, this attribute only affects
names in scripts that know "given-name family-name" order.

`cs:name` may also carry [affixes](#affixes) and
[formatting](#formatting) attributes.

##### Name-part Order

The order of name-parts depends on the values of the `form` and
`name-as-sort-order` attributes on `cs:name`, the value of the
`demote-non-dropping-particle` attribute on `cs:style` (one of the
[global options](#global-options)), and the script of the individual
name. Note that the display and sorting order of name-parts often
differs. An overview of the possible orders:

**Display order of names in "given-name family-name" scripts (Latin,
etc.)**

------------------------------------------------------------------------

Conditions  
`form` set to "long"

Order  
1)  given
2)  dropping-particle
3)  non-dropping-particle
4)  family
5)  suffix

Example  
\[Vincent\] \[\] \[van\] \[Gogh\] \[III\]

Example  
\[Alexander\] \[von\] \[\] \[Humboldt\] \[Jr.\]

------------------------------------------------------------------------

Conditions  
`form` set to "long", name-as-sort-order active,
`demote-non-dropping-particle` set to "never" or "sort-only"

Order  
1)  non-dropping-particle
2)  family
3)  given
4)  dropping-particle
5)  suffix

Example  
\[van\] \[Gogh\], \[Vincent\] \[\], \[III\]

------------------------------------------------------------------------

Conditions  
`form` set to "long", name-as-sort-order active,
`demote-non-dropping-particle` set to "display-and-sort"

Order  
1)  family
2)  given
3)  dropping-particle
4)  non-dropping-particle
5)  suffix

Example  
\[Gogh\], \[Vincent\] \[\] \[van\], \[III\]

------------------------------------------------------------------------

Conditions  
`form` set to "short"

Order  
1)  non-dropping-particles
2)  family

Example  
\[van\] \[Gogh\]

------------------------------------------------------------------------

**Sorting order of names in "given-name family-name" scripts (Latin,
etc.)**

N.B. The sort keys are listed in descending order of priority.

------------------------------------------------------------------------

Conditions  
`demote-non-dropping-particle` set to "never"

Order  
1)  non-dropping-particle + family
2)  dropping-particle
3)  given
4)  suffix

Example  
\[van Gogh\] \[\] \[Vincent\] \[III\]

------------------------------------------------------------------------

Conditions  
`demote-non-dropping-particle` set to "sort-only" or "display-and-sort"

Order  
1)  family
2)  dropping-particle + non-dropping-particle
3)  given
4)  suffix

Example  
\[Gogh\] \[van\] \[Vincent\] \[III\]

------------------------------------------------------------------------

**Display and sorting order of names in "family-name given-name" scripts
(Chinese, etc.)**

------------------------------------------------------------------------

Conditions  
`form` set to "long"

Order  
1)  family
2)  given

Example  
毛 泽 东 \[Mao Zedong\]

------------------------------------------------------------------------

Conditions  
`form` set to "short"

Order  
1)  family

Example  
毛 \[Mao\]

------------------------------------------------------------------------

Non-personal names lack name-parts and are sorted as is, although
English articles ("a", "an" and "the") at the start of the name are
stripped. For example, "The New York Times" sorts as "New York Times".

##### Name-part Formatting

The `cs:name` element may contain one or two `cs:name-part` child
elements for name-part-specific formatting. `cs:name-part` must carry
the `name` attribute, set to either "given" or "family".

If set to "given", [formatting](#formatting) and [text-case](#text-case)
attributes on `cs:name-part` affect the "given" and "dropping-particle"
name-parts. [affixes](#affixes) surround the "given" name-part,
enclosing any demoted name particles for inverted names.

If set to "family", [formatting](#formatting) and
[text-case](#text-case) attributes affect the "family" and
"non-dropping-particle" name-parts. [affixes](#affixes) surround the
"family" name-part, enclosing any preceding name particles, as well as
the "suffix" name-part for non-inverted names.

The "suffix" name-part is not subject to name-part formatting. The use
of `cs:name-part` elements does not influence which, or in what order,
name-parts are rendered. An example, yielding names like "Jane DOE":

``` xml
<names variable="author">
  <name>
    <name-part name="family" text-case="uppercase"/>
  </name>
</names>
```

#### Et-al

Et-al abbreviation, controlled via the `et-al-…` attributes (see
[Name](#name)), can be further customized with the optional `cs:et-al`
element, which must follow the `cs:name` element (if present).

The [formatting](#formatting) attributes may be used on `cs:et-al`, for
example to italicize the "et-al" term:

``` xml
<names variable="author">
  <et-al font-style="italic"/>
</names>
```

The `term` attribute may also be set, to either "et-al" (the default) or
"and others", to use either term:

``` xml
<names variable="author">
  <et-al term="and others"/>
</names>
```

#### Substitute

The optional `cs:substitute` element, which must be included as the last
child element of `cs:names`, adds substitution in case the [name
variables](#name-variables) specified in the parent `cs:names` element
are empty. The substitutions are specified as child elements of
`cs:substitute`, and must consist of one or more [rendering
elements](#rendering-elements) (with the exception of `cs:layout`). A
shorthand version of `cs:names` without child elements, which inherits
the attributes values set on the `cs:name` and `cs:et-al` child elements
of the original `cs:names` element, may also be used. If `cs:substitute`
contains multiple child elements, the first element to return a
non-empty result is used for substitution. Substituted variables are
suppressed in the rest of the output to prevent duplication. Substituted
variables are considered empty for the purposes of determining whether
to suppress an enclosing `cs:group`. If the variable was rendered
earlier in the citation, before the "substitute" element, it is not
suppressed. An example, where an empty "author" name variable is
substituted by the "editor" name variable, or, when no editors exist, by
the "title" macro:

``` xml
<macro name="author">
  <names variable="author">
    <substitute>
      <names variable="editor"/>
      <text macro="title"/>
    </substitute>
  </names>
</macro>
```

#### Label in `cs:names`

A `cs:label` element (see [label](#label)) may optionally be included in
`cs:names`. It must appear before the `cs:substitute` element. The
position of `cs:label` relative to `cs:name` determines the order of the
name and label in the rendered text. When used as a child element of
`cs:names`, `cs:label` does not carry the `variable` attribute; it uses
the variable(s) set on the parent `cs:names` element instead. A second
difference is that the `form` attribute may also be set to "verb" or
"verb-short", so that the allowed values are:

- "long" - (default), e.g. "editor" and "editors" for the "editor" term
- "short" - e.g. "ed." and "eds." for the term "editor"
- "verb" - e.g. "edited by" for the term "editor"
- "verb-short" - e.g. "ed." for the term "editor"
- "symbol" - e.g. "§" and "§§" for the term "section"

### Label

The `cs:label` rendering element outputs the term matching the variable
selected with the required `variable` attribute, which must be set to
"locator", "page", or one of the [number variables](#number-variables).
The term is only rendered if the selected variable is non-empty. For
example,

``` xml
<group delimiter=" ">
  <label variable="page"/>
  <text variable="page"/>
</group>
```

can result in "page 3" or "pages 5-7". `cs:label` may carry the
following attributes:

`form`  
Selects the form of the term, with allowed values:

- "long" - (default), e.g. "page"/"pages" for the "page" term
- "short" - e.g. "p."/"pp." for the "page" term
- "symbol" - e.g. "§"/"§§" for the "section" term

`plural`  
Sets pluralization of the term, with allowed values:

- "contextual" - (default), the term plurality matches that of the
  variable content. Content is considered plural when it contains
  multiple numbers (e.g. "page 1", "pages 1-3", "volume 2", "volumes 2 &
  4"), or, in the case of the "number-of-pages" and "number-of-volumes"
  variables, when the number is higher than 1 ("1 volume" and "3
  volumes").
- "always" - always use the plural form, e.g. "pages 1" and "pages 1-3"
- "never" - always use the singular form, e.g. "page 1" and "page 1-3"

`cs:label` may also carry [affixes](#affixes),
[formatting](#formatting), [text-case](#text-case) and
[strip-periods](#strip-periods) attributes.

### Group

The `cs:group` rendering element must contain one or more [rendering
elements](#rendering-elements) (with the exception of `cs:layout`).
`cs:group` may carry the [delimiter](#delimiter) attribute to separate
its child elements, as well as [affixes](#affixes), [display](#display),
and [formatting](#formatting) attributes (applied to the output of the
group as a whole). `cs:group` implicitly acts as a conditional:
`cs:group` and its child elements are suppressed if a) at least one
rendering element in `cs:group` calls a variable (either directly or via
a macro), and b) all variables that are called are empty. This
accommodates descriptive <span class="title-ref">cs:text</span> and
\`cs:label\`elements. For example,

``` xml
<layout>
  <group delimiter=" ">
    <text term="retrieved"/>
    <text term="from"/>
    <text variable="URL"/>
  </group>
</layout>
```

can result in "retrieved from <https://doi.org/10.1128/AEM.02591-07>",
but doesn't generate output when the "URL" variable is empty.

If a `cs:group` is nested within another `cs:group`, the inner group is
evaluated first: a non-empty nested `cs:group` is treated as a non-empty
variable for the puropses of determining suppression of the outer
`cs:group`.

When a `cs:group` contains a child `cs:macro`, if the `cs:macro` is
non-empty, it is treated as a non-empty variable for the purposes of
determining suppression of the outer `cs:group`.

### Choose

The `cs:choose` rendering element allows for conditional rendering of
[rendering elements](#rendering-elements). An example that renders the
"issued" date variable when it exists, and the "no date" term when it
doesn't:

``` xml
<choose>
  <if variable="issued">
    <date variable="issued" form="numeric"/>
  </if>
  <else>
    <text term="no date"/>
  </else>
</choose>
```

`cs:choose` requires a `cs:if` child element, which may be followed by
one or more `cs:else-if` child elements, and an optional closing
`cs:else` child element. The `cs:if` and `cs:else-if` elements may
contain any number of [rendering elements](#rendering-elements) (except
for `cs:layout`). As an empty `cs:else` element would be superfluous,
`cs:else` must contain at least one rendering element. `cs:if` and
`cs:else-if` elements must carry one or more conditions, which are set
with the attributes:

`disambiguate`  
When set to "true" (the only allowed value), the element content is only
rendered if it disambiguates two otherwise identical citations. This
attempt at [disambiguation](#disambiguation) is only made when all other
disambiguation methods have failed to uniquely identify the target
source.

`is-numeric`  
Tests whether the given variables ([Appendix IV -
Variables](#appendix-iv---variables)) contain numeric content. Content
is considered numeric if it solely consists of numbers. Numbers may have
prefixes and suffixes ("D2", "2b", "L2d"), and may be separated by a
comma, hyphen, or ampersand, with or without spaces ("2, 3", "2-4", "2 &
4"). For example, "2nd" tests "true" whereas "second" and "2nd edition"
test "false".

`is-uncertain-date`  
Tests whether the given [date variables](#date-variables) contain
[approximate dates](#approximate-dates).

`locator`  
Tests whether the locator matches the given locator types (see
[Locators](#locators)). Use "sub-verbo" to test for the "sub verbo"
locator type.

`position`  
Tests whether the cite position matches the given positions
(terminology: citations consist of one or more cites to individual
items). When called within the scope of cs:bibliography, `position`
tests "false". The positions that can be tested are:

- "first": position of cites that are the first to reference an item

- "ibid"/"ibid-with-locator"/"subsequent": cites referencing previously
  cited items have the "subsequent" position. Such cites may also have
  the "ibid" or "ibid-with-locator" position when:

  1)  the current cite immediately follows on another cite, within the
      same citation, that references the same item

  or

  2)  the current cite is the first cite in the citation, and the
      previous citation consists of a single cite referencing the same
      item

  If either requirement is met, the presence of locators determines
  which position is assigned:

  - **Preceding cite does not have a locator**: if the current cite has
    a locator, the position of the current cite is "ibid-with-locator".
    Otherwise the position is "ibid".
  - **Preceding cite does have a locator**: if the current cite has the
    same locator, the position of the current cite is "ibid". If the
    locator differs the position is "ibid-with-locator". If the current
    cite lacks a locator its only position is "subsequent".

- "near-note": position of a cite following another cite referencing the
  same item. Both cites have to be located in foot or endnotes, and the
  distance between both cites may not exceed the maximum distance
  (measured in number of foot or endnotes) set with the
  `near-note-distance` option (see [Note Distance](#note-distance)).

Whenever position="ibid-with-locator" tests true, position="ibid" also
tests true. And whenever position="ibid" or position="near-note" test
true, position="subsequent" also tests true.

`type`  
Tests whether the item matches the given types ([Appendix III -
Types](#appendix-iii---types)).

`variable`  
Tests whether the default (long) forms of the given variables ([Appendix
IV - Variables](#appendix-iv---variables)) contain non-empty values.

With the exception of `disambiguate`, all conditions allow for multiple
test values (separated with spaces, e.g. "book thesis").

The `cs:if` and `cs:else-if` elements may carry the `match` attribute to
control the testing logic, with allowed values:

- "all" - (default), element only tests "true" when all conditions test
  "true" for all given test values
- "any" - element tests "true" when any condition tests "true" for any
  given test value
- "none" - element only tests "true" when none of the conditions test
  "true" for any given test value

Delimiters from the nearest delimiters from the nearest ancestor
delimiting element *are* applied within the output of `cs:choose` (i.e.,
the output of the matching `cs:if`, `cs:else-if`, or `cs:else`; see
[delimiter](#delimiter)).

## Style Behavior

### Options

Styles may be configured with [citation-specific
options](#citation-specific-options), set as attributes on set on
`cs:citation`, [bibliography-specific
options](#bibliography-specific-options), set on `cs:bibliography`, and
[global options](#global-options) (these affect both citations and the
bibliography), set on `cs:style`. [Inheritable name
options](#inheritable-name-options) may be set on `cs:style`,
`cs:citation` and `cs:bibliography`. Finally, [locale
options](#locale-options) may be set on `cs:locale` elements.

#### Citation-specific Options

##### Disambiguation

A cite is ambiguous when it matches multiple bibliographic entries[^1].
Four methods are available to eliminate such ambiguity, which are always
tried in the following order:

1.  Expand names (adding initials or full given names)
2.  Show more names
3.  Render the cite with the `disambiguate` attribute of `cs:choose`
    conditions testing "true"
4.  Add a year-suffix

Method 1 can also be used for the separate purpose of global *name
disambiguation*, covering both ambiguous and unambiguous cites
throughout the document.

The four disambiguation methods can be individually activated with the
following optional attributes:

`disambiguate-add-givenname` \[Method (1)\]  
If set to "true" ("false" is the default), ambiguous names (names that
are identical in their "short" or initialized "long" form, but differ
when initials are added or the full given name is shown) are expanded.
Name expansion can be configured with `givenname-disambiguation-rule`.
An example of cite disambiguation:

| Original ambiguous cites     | Disambiguated cites                |
|------------------------------|------------------------------------|
| (Simpson 2005; Simpson 2005) | (H. Simpson 2005; B. Simpson 2005) |
| (Doe 1950; Doe 1950)         | (John Doe 1950; Jane Doe 1950)     |

`givenname-disambiguation-rule`  
Specifies (a) whether the purpose of name expansion is limited to
disambiguating cites, or has the additional goal of disambiguating names
(only in the latter case are ambiguous names in unambiguous cites
expanded, e.g. from "(Doe 1950; Doe 2000)" to "(Jane Doe 1950; John Doe
2000)"), (b) whether name expansion targets all, or just the first name
of each cite, and (c) the method by which each name is expanded.

**Expansion of Individual Names**  
The steps for expanding individual names are:

1.  If `initialize-with` is set and `initialize` has its default value
    of "true", then:

    \(a\) Initials can be shown by rendering the name with a `form`
    value of "long" instead of "short" (e.g. "Doe" becomes "J. Doe").

    \(b\) Full given names can be shown instead of initials by rendering
    the name with `initialize` set to "false" (e.g. "J. Doe" becomes
    "John Doe").

2.  If `initialize-with` is *not* set, full given names can be shown by
    rendering the name with a `form` value of "long" instead of "short"
    (e.g. "Doe" becomes "John Doe").

**Given Name Disambiguation Rules**  
Allowed values of `givenname-disambiguation-rule`:

"all-names"  
Name expansion has the dual purpose of disambiguating cites and names.
All rendered ambiguous names, in both ambiguous and unambiguous cites,
are subject to disambiguation. Each name is progressively transformed
until it is disambiguated. Names that cannot be disambiguated remain in
their original form.

"all-names-with-initials"  
As "all-names", but name expansion is limited to showing initials (see
step 1(a) above). No disambiguation attempt is made when
`initialize-with` is not set or when `initialize` is set to "false".

"primary-name"  
As "all-names", but disambiguation is limited to the first name of each
cite.

"primary-name-with-initials"  
As "all-names-with-initials", but disambiguation is limited to the first
name of each cite.

"by-cite"  
Default. As "all-names", but the goal of name expansion is limited to
disambiguating cites. Only ambiguous names in ambiguous cites are
affected, and disambiguation stops after the first name that eliminates
cite ambiguity.

`disambiguate-add-names` \[Method (2)\]  
If set to "true" ("false" is the default), names that would otherwise be
hidden as a result of et-al abbreviation are added one by one to all
members of a set of ambiguous cites, until no more cites in the set can
be disambiguated by adding names.

If both `disambiguate-add-givenname` and `disambiguate-add-names` are
set to "true", given name expansion is applied to rendered names first.
If cites cannot be (fully) disambiguated by expanding the rendered
names, then the names still hidden as a result of et-al abbreviation are
added one by one to all members of a set of ambiguous cites. Added names
are expanded if doing so would disambiguate the ambiguous cites. This
process contines until no more cites in the set can be disambiguated by
adding expanded names.

In the description of disambiguation methods (1) and (2) above, we
assumed that each (disambiguated) cite has an unambiguous link to its
bibliographic entry. To assure that each cite does in fact uniquely
identify its entry in the bibliography, detail that distinguishes cites
(such as names, initials, and full given names) must be shown in the
corresponding bibliography entries. If this is not the case,
disambiguation methods (1) and (2) also act on all members of a set of
ambiguously cited bibliographic entries, until no more entries in the
set can be unambiguously cited by adding (expanded) names. Each method
only takes effect on the involved bibliographic entries after it has
been used to disambiguate cites.

`disambiguate` condition \[Method (3)\]  
A disambiguation attempt can also be made by rendering ambiguous cites
with the `disambiguate` condition testing "true" (see
[Choose](#choose)).

`disambiguate-add-year-suffix` \[Method (4)\]  
If set to "true" ("false" is the default), an alphabetic year-suffix is
added to ambiguous cites (e.g. "Doe 2007, Doe 2007" becomes "Doe 2007a,
Doe 2007b") and to their corresponding bibliographic entries. This final
disambiguation method is always successful. The assignment of
year-suffixes follows the order of the bibliographies entries, and
additional letters are used once "z" is reached ("z", "aa", "ab", ...,
"az", "ba", etc.). By default, the year-suffix is appended the first
year rendered through `cs:date` in the cite and in the bibliographic
entry, but its location can be controlled by explicitly rendering the
"year-suffix" variable using `cs:text`. If "year-suffix" is rendered
through `cs:text` in the scope of `cs:citation`, it is suppressed for
`cs:bibliography`, unless it is also rendered through `cs:text` in the
scope of `cs:bibliography`, and vice versa.

##### Cite Grouping

With cite grouping, cites in in-text citations with identical rendered
names are grouped together, e.g. the year-sorted "(Doe 1999; Smith 2002;
Doe 2006; Doe et al. 2007)" becomes "(Doe 1999; Doe 2006; Smith 2002;
Doe et al. 2007)". The comparison is limited to the output of the
(first) `cs:names` element, but includes output rendered through
`cs:substitute`. Cite grouping takes places after cite sorting and
disambiguation. Grouped cites maintain their relative order, and are
moved to the original location of the first cite of the group.

Cite grouping can be activated by setting the `cite-group-delimiter`
attribute or the `collapse` attributes on `cs:citation` (see also [Cite
Collapsing](#cite-collapsing)).

`cite-group-delimiter`  
Activates cite grouping and specifies the delimiter for cites within a
cite group. Defaults to ", ". E.g. with `delimiter` on `cs:layout` in
`cs:citation` set to "; ", `collapse` set to "year", and
`cite-group-delimiter` set to ",", citations look like "(Doe 1999,2001;
Jones 2000)".

##### Cite Collapsing

Cite groups (author and author-date styles), and numeric cite ranges
(numeric styles) can be collapsed through the use of the `collapse`
attribute. Delimiters for collapsed cite groups can be customized with
the `year-suffix-delimiter` and `after-collapse-delimiter` attributes:

`collapse`  
Activates cite grouping and collapsing. Allowed values:

- "citation-number" - collapses ranges of cite numbers (rendered through
  the "citation-number" variable) in citations for "numeric" styles
  (e.g. from "\[1, 2, 3, 5\]" to "\[1 – 3, 5\]"). Only increasing ranges
  collapse, e.g. "\[3, 2, 1\]" will not collapse (to see how to sort
  cites by "citation-number", see [Sorting](#sorting)).
- "year" - collapses cite groups by suppressing the output of the
  `cs:names` element for subsequent cites in the group, e.g. "(Doe 2000,
  Doe 2001)" becomes "(Doe 2000, 2001)".
- "year-suffix" - collapses as "year", but also suppresses repeating
  years within the cite group, e.g. "(Doe 2000a, b)" instead of "(Doe
  2000a, 2000b)".
- "year-suffix-ranged" - collapses as "year-suffix", but also collapses
  ranges of year-suffixes, e.g. "(Doe 2000a – c,e)" instead of "(Doe
  2000a, b, c, e)".

"year-suffix" and "year-suffix-ranged" fall back to "year" when
`disambiguate-add-year-suffix` is "false" (see
[Disambiguation](#disambiguation)), or when a cite has a locator (e.g.
"(Doe 2000a-c, 2000d, p. 5, 2000e,f)", where the cite for "Doe 2000d"
has a locator that prevents the cite from further collapsing).

`year-suffix-delimiter`  
Specifies the delimiter for year-suffixes. Defaults to the delimiter set
on `cs:layout` in `cs:citation`. E.g. with `collapse` set to
"year-suffix", `delimiter` on `cs:layout` in `cs:citation` set to "; ",
and `year-suffix-delimiter` set to ",", citations look like "(Doe
1999a,b; Jones 2000)".

`after-collapse-delimiter`  
Specifies the cite delimiter to be used *after* a collapsed cite group.
Defaults to the delimiter set on `cs:layout` in `cs:citation`. E.g. with
`collapse` set to "year", `delimiter` on `cs:layout` in `cs:citation`
set to ", ", and `after-collapse-delimiter` set to "; ", citations look
like "(Doe 1999, 2001; Jones 2000, Brown 2001)".

##### Note Distance

`near-note-distance`  
A cite tests true for the "near-note" position (see [Choose](#choose))
when a preceding note exists that a) refers to the same item and b) does
not precede the current note by more footnotes or endnotes than the
value of `near-note-distance` (default value is "5").

#### Bibliography-specific Options

##### Whitespace

`hanging-indent`  
If set to "true" ("false" is the default), bibliographic entries are
rendered with hanging-indents.

`second-field-align`  
If set, subsequent lines of bibliographic entries are aligned along the
second field. With "flush", the first field is flush with the margin.
With "margin", the first field is put in the margin, and subsequent
lines are aligned with the margin. An example, where the first field is
`<text variable="citation-number" suffix=". "/>`:

    9.  Adams, D. (2002). The Ultimate Hitchhiker's Guide to the
        Galaxy (1st ed.).
    10. Asimov, I. (1951). Foundation.

`line-spacing`  
Specifies vertical line distance. Defaults to "1" (single-spacing), and
can be set to any positive integer to specify a multiple of the standard
unit of line height (e.g. "2" for double-spacing).

`entry-spacing`  
Specifies vertical distance between bibliographic entries. By default
(with a value of "1"), entries are separated by a single additional
line-height (as set by the line-spacing attribute). Can be set to any
non-negative integer to specify a multiple of this amount.

##### Reference Grouping

`subsequent-author-substitute`  
If set, the value of this attribute replaces names in a bibliographic
entry that also occur in the preceding entry. The exact method of
substitution depends on the value of the
`subsequent-author-substitute-rule` attribute. Substitution is limited
to the names of the first `cs:names` element rendered.

`subsequent-author-substitute-rule`  
Specifies when and how names are substituted as a result of
`subsequent-author-substitute`. Allowed values:

- "complete-all" - (default), when all names of the name variable match
  those in the preceding bibliographic entry, the value of
  `subsequent-author-substitute` replaces the entire name list
  (including punctuation and terms like "et al" and "and"), except for
  the affixes set on the `cs:names` element.
- "complete-each" - requires a complete match like "complete-all", but
  now the value of `subsequent-author-substitute` substitutes for each
  rendered name.
- "partial-each" - when one or more rendered names in the name variable
  match those in the preceding bibliographic entry, the value of
  `subsequent-author-substitute` substitutes for each matching name.
  Matching starts with the first name, and continues up to the first
  mismatch.
- "partial-first" - as "partial-each", but substitution is limited to
  the first name of the name variable.

For example, take the following bibliographic entries:

    Doe. 1999.
    Doe. 2000.
    Doe, Johnson & Williams. 2001.
    Doe & Smith. 2002.
    Doe, Stevens & Miller. 2003.
    Doe, Stevens & Miller. 2004.
    Doe, Williams et al. 2005.
    Doe, Williams et al. 2006.

With `subsequent-author-substitute` set to "---", and
`subsequent-author-substitute-rule` set to "complete-all", this becomes:

    Doe. 1999.
    ---. 2000.
    Doe, Johnson & Williams. 2001.
    Doe & Smith. 2002.
    Doe, Stevens & Miller. 2003.
    ---. 2004.
    Doe, Williams et al. 2005.
    ---. 2005.

With `subsequent-author-substitute-rule` set to "complete-each", this
becomes:

    Doe. 1999.
    ---. 2000.
    Doe, Johnson & Williams. 2001.
    Doe & Smith. 2002.
    Doe, Stevens & Miller. 2003.
    ---, --- & ---. 2004.
    Doe, Williams et al. 2005.
    ---, --- et al. 2006.

With `subsequent-author-substitute-rule` set to "partial-each", this
becomes:

    Doe. 1999.
    ---. 2000.
    Doe, Johnson & Williams. 2001.
    --- & Smith. 2002.
    Doe, Stevens & Miller. 2003.
    ---, --- & ---. 2004.
    Doe, Williams et al. 2005.
    ---, --- et al. 2005.

With `subsequent-author-substitute-rule` set to "partial-first", this
becomes:

    Doe. 1999.
    ---. 2000.
    Doe, Johnson & Williams. 2001.
    --- & Smith. 2002.
    Doe, Stevens & Miller. 2003.
    ---, Stevens & Miller. 2004.
    Doe, Williams et al. 2005.
    ---, Williams et al. 2005.

#### Global Options

##### Hyphenation of Initialized Names

`initialize-with-hyphen`  
Specifies whether compound given names (e.g. "Jean-Luc") should be
initialized with a hyphen ("J.-L.", value "true", default) or without
("J. L.", value "false").

##### Page Ranges

`page-range-format`  
Activates expansion or collapsing of page ranges: "chicago" ("321 –
28"), "expanded" (e.g. "321 – 328"), "minimal" ("321 – 8"), or
"minimal-two" ("321 – 28") (see also [Appendix V - Page Range
Formats](#appendix-v---page-range-formats)). Delimits page ranges with
the "page-range-delimiter" term (introduced with CSL 1.0.1, and defaults
to an en-dash). If the attribute is not set, page ranges are rendered
without reformatting.

##### Name Particles

Western names frequently contain one or more name particles (e.g. "van"
in the Dutch name "Vincent van Gogh"). These name particles can be
either kept or dropped when only the surname is shown: these two types
are referred to as non-dropping and dropping particles, respectively.
Theoretically, a single name might contain particles of both types (with
non-dropping particles always following dropping particles), though
currently we are not aware of any real-life examples. For example, the
Dutch name "Vincent van Gogh", the German name "Alexander von Humboldt",
and the Arabic name "Tawfiq al-Hakim" can be deconstructed into:

>     {
>         "author": [
>             {
>                 "given": "Vincent",
>                 "non-dropping-particle": "van",
>                 "family": "Gogh"
>             },
>             {
>                 "given": "Alexander",
>                 "dropping-particle": "von",
>                 "family": "Humboldt"
>             }
>             {
>                 "given": "Tawfiq",
>                 "non-dropping-particle": "al-",
>                 "family": "Hakim"
>             }
>         ]
>     }

When just the surname is shown, only the non-dropping-particle is kept:
"Van Gogh" and "al-Hakim", but "Humboldt".

In the case of inverted names, where the family name precedes the given
name, the dropping-particle is always appended to the family name, but
the non-dropping-particle can be either prepended (e.g. "van Gogh,
Vincent") or appended (after initials or given names, e.g. "Gogh,
Vincent van"). For inverted names where the non-dropping-particle is
prepended, names can either be sorted by keeping the
non-dropping-particle together with the family name as part of the
primary sort key (sort order A), or by separating the
non-dropping-particle from the family name and have it become (part of)
a secondary sort key, joining the dropping-particle, if available (sort
order B):

**Sort order A: non-dropping-particle not demoted**

- primary sort key: "van Gogh"
- secondary sort key: ""
- tertiary sort key: "Vincent"

**Sort order B: non-dropping-particle demoted**

- primary sort key: "Gogh"
- secondary sort key: "van"
- tertiary sort key: "Vincent"

The handling of the non-dropping-particle can be customized with the
`demote-non-dropping-particle` option:

`demote-non-dropping-particle`  
Sets the display and sorting behavior of the non-dropping-particle in
inverted names (e.g. "Gogh, Vincent van"). Allowed values:

- "never": the non-dropping-particle is treated as part of the family
  name, whereas the dropping-particle is appended (e.g. "van Gogh,
  Vincent", "Humboldt, Alexander von"). The non-dropping-particle is
  part of the primary sort key (sort order A, e.g. "van Gogh, Vincent"
  appears under "V").
- "sort-only": same display behavior as "never", but the
  non-dropping-particle is demoted to a secondary sort key (sort order
  B, e.g. "van Gogh, Vincent" appears under "G").
- "display-and-sort" (default): the dropping and non-dropping-particle
  are appended (e.g. "Gogh, Vincent van" and "Humboldt, Alexander von").
  For name sorting, all particles are part of the secondary sort key
  (sort order B, e.g. "Gogh, Vincent van" appears under "G").

Some names include a particle that should never be demoted. For these
cases the particle should just be included in the family name field, for
example for the French general Charles de Gaulle and the writer Jean de
La Fontaine:

>     {
>         "author": [
>             {
>                 "given": "Charles"
>                 "family": "de Gaulle",
>             },
>             {
>                 "given": "Jean"
>                 "dropping-particle": "de",
>                 "family": "La Fontaine",
>             }
>         ]
>     }

#### Inheritable Name Options

Attributes for the `cs:names` and `cs:name` elements may also be set on
`cs:style`, `cs:citation` and `cs:bibliography`. This eliminates the
need to repeat the same attributes and attribute values for every
occurrence of the `cs:names` and `cs:name` elements.

The available inheritable attributes for `cs:name` are `and`,
`delimiter-precedes-et-al`, `delimiter-precedes-last`, `et-al-min`,
`et-al-use-first`, `et-al-use-last`, `et-al-subsequent-min`,
`et-al-subsequent-use-first`, `initialize`, `initialize-with`,
`name-as-sort-order` and `sort-separator`. The attributes `name-form`
and `name-delimiter` correspond to the `form` and `delimiter` attributes
on `cs:name`. Similarly, `names-delimiter` corresponds to the
`delimiter` attribute on `cs:names`.

When an inheritable name attribute is set on `cs:style`, `cs:citation`
or `cs:bibliography`, its value is used for all `cs:names` elements
within the scope of the element carrying the attribute. If an attribute
is set on multiple hierarchical levels, the value set at the lowest
level is used.

#### Locale Options

`limit-day-ordinals-to-day-1`  
Date formats are defined by the `cs:date` element and its `cs:date-part`
child elements (see [Date](#date)). By default, when the `cs:date-part`
element with `name` set to "day" has `form` set to "ordinal", all days
(1 through 31) are rendered in the ordinal form, e.g. "January 1st",
"January 2nd", etc. By setting `limit-day-ordinals-to-day-1` to "true"
("false" is the default), the "ordinal" form is limited to the first day
of each month (other days will use the "numeric" form). This is
desirable for some languages, such as French: "1er janvier", but "2
janvier", "3 janvier", etc.

`punctuation-in-quote`  
For `cs:text` elements rendered with the `quotes` attribute set to
"true" (see [Formatting](#formatting)), and for which the output is
followed by a comma or period, `punctuation-in-quote` specifies whether
this punctuation is placed outside (value "false", default) or inside
(value "true") the closing quotation mark.

### Sorting

`cs:citation` and `cs:bibliography` may include a `cs:sort` child
element before the `cs:layout` element to specify the sorting order of
respectively cites within citations, and bibliographic entries within
the bibliography. In the absence of `cs:sort`, cites and bibliographic
entries appear in the order in which they are cited.

The `cs:sort` element must contain one or more `cs:key` child elements.
The sort key, set as an attribute on `cs:key`, must be a variable (see
[Appendix IV - Variables](#appendix-iv---variables)) or macro name. For
each `cs:key` element, the sort direction can be set to either
"ascending" (default) or "descending" with the `sort` attribute. Sorting
is case-insensitive. The attributes `names-min`, `names-use-first`, and
`names-use-last` may be used to override the values of the corresponding
`et-al-min`/`et-al-subsequent-min`,
`et-al-use-first`/`et-al-subsequent-use-first` and `et-al-use-last`
attributes, and affect all names generated via macros called by
`cs:key`.

Sort keys are evaluated in sequence. A primary sort is performed on all
items using the first sort key. A secondary sort, using the second sort
key, is applied to items sharing the first sort key value. A tertiary
sort, using the third sort key, is applied to items sharing the first
and second sort key values. Sorting continues until either the order of
all items is fixed, or until the sort keys are exhausted. Items with an
empty sort key value are placed at the end of the sort, both for
ascending and descending sorts.

An example, where cites are first sorted by the output of the "author"
macro, with overriding settings for et-al abbreviation. Cites sharing
the primary sort key are subsequently sorted in descending order by the
"issued" date variable.

``` xml
<citation>
  <sort>
    <key macro="author" names-min="3" names-use-first="3"/>
    <key variable="issued" sort="descending"/>
  </sort>
  <layout>
    <!-- rendering elements -->
  </layout>
</citation>
```

The sort key value of a variable or macro can differ from the "normal"
rendered output. The specifics of sorting variables and macros:

#### Sorting Variables

The sort key value for a variable called by `cs:key` via the `variable`
attribute consists of the string value, without rich text markup.
Exceptions are name, date and numeric variables:

**names:** [Name variables](#name-variables) called via the `variable`
attribute (e.g. `<key variable="author"/>`) are returned as a name list
string, with the `cs:name` attributes `form` set to "long", and
`name-as-sort-order` set to "all".

**dates:** [Date variables](#date-variables) called via the `variable`
attribute are returned in the YYYYMMDD format, with zeros substituted
for any missing date-parts (e.g. 20001200 for December 2000). As a
result, less specific dates precede more specific dates in ascending
sorts, e.g. "2000, May 2000, May 1st 2000". Negative years are sorted
inversely, e.g. "100BC, 50BC, 50AD, 100AD". Seasons are ignored for
sorting, as the chronological order of the seasons differs between the
northern and southern hemispheres. In the case of date ranges, the start
date is used for the primary sort, and the end date is used for a
secondary sort, e.g. "2000 – 2001, 2000 – 2005, 2002 – 2003, 2002 –
2009". Date ranges are placed after single dates when they share the
same (start) date, e.g. "2000, 2000 – 2002".

**numbers:** [Number variables](#number-variables) called via the
`variable` attribute are returned as integers (`form` is "numeric"). If
the original variable value only consists of non-numeric text, the value
is returned as a text string.

#### Sorting Macros

The sort key value for a macro called via `cs:key` via the `macro`
attribute generally consists of the string value the macro would
ordinarily generate, without rich text markup (exceptions are discussed
below).

When sorting by [name variables](#name-variables) rendered within the
macro, any `cs:label` elements are excluded from the sort key values.
Name variables are also returned with the `cs:name` attribute
`name-as-sort-order` set to "all". When et-al abbreviation occurs, the
"et-al" and "and others" terms are excluded from the sort key values.

There are four advantages in using the same macro for rendering and
sorting, instead of sorting directly on the name variable. First,
substitution is available (e.g. the "editor" variable might substitute
for an empty "author" variable). Second, et-al abbreviation can be used
(using either the `et-al-min`/`et-al-subsequent-min`,
`et-al-use-first`/`et-al-subsequent-use-first`, and `et-al-use-last`
options defined for the macro, or the overriding `names-min`,
`names-use-first` and `names-use-last` attributes set on `cs:key`).
Third, names can be sorted by just the surname (using a macro for which
the `form` attribute on `cs:name` is set to "short"). Fourth, it is
possible to sort by the number of names in a name list, by calling a
macro for which the `form` attribute on `cs:name` is set to "count".

[Number variables](#number-variables) rendered within the macro with
`cs:number` and [date variables](#date-variables) are treated the same
as when they are called via `variable`. The only exception is that the
complete date is returned if a date variable is called via the
`variable` attribute. In contrast, macros return only those date-parts
that would otherwise be rendered (respecting the value of the
`date-parts` attribute for localized dates, or the listing of
`cs:date-part` elements for non-localized dates).

### Range Delimiters

Collapsed ranges for the "citation-number" and "year-suffix" variables
are delimited by an en-dash (e.g. "(1 – 3, 5)" and "(Doe 2000a – c,e)").

The "locator" variable is always rendered with an en-dash replacing any
hyphens. For the "page" variable, this replacement is only performed if
the `page-range-format` attribute is set on `cs:style` (see [Page
Ranges](#page-ranges)).

### Formatting

The following formatting attributes may be set on `cs:date`,
`cs:date-part`, `cs:et-al`, `cs:group`, `cs:label`, `cs:layout`,
`cs:name`, `cs:name-part`, `cs:names`, `cs:number` and `cs:text`:

`font-style`  
Sets the font style, with values:

- "normal" (default)
- "italic"
- "oblique" (i.e. slanted)

`font-variant`  
Allows for the use of small capitals, with values:

- "normal" (default)
- "small-caps"

`font-weight`  
Sets the font weight, with values:

- "normal" (default)
- "bold"
- "light"

`text-decoration`  
Allows for the use of underlining, with values:

- "none" (default)
- "underline"

`vertical-align`  
Sets the vertical alignment, with values:

- "baseline" (default)
- "sup" (superscript)
- "sub" (subscript)

### Affixes

The affixes attributes `prefix` and `suffix` may be set on `cs:date`
(except when `cs:date` defines a localized date format), `cs:date-part`
(except when the parent `cs:date` element calls a localized date
format), `cs:group`, `cs:label`, `cs:layout`, `cs:name`, `cs:name-part`,
`cs:names`, `cs:number` and `cs:text`. The attribute value is either
added before (`prefix`) or after (`suffix`) the output of the element
carrying the attribute, but affixes are only rendered if the element
produces output. With the exception of affixes set on `cs:layout`,
affixes are outside the scope of [formatting](#formatting),
[quotes](#quotes), [strip-periods](#strip-periods) and
[text-case](#text-case) attributes set on the same element (as a
workaround, these attributes take effect on affixes when set on a parent
`cs:group` element).

### Delimiter

The `delimiter` attribute, whose value delimits non-empty pieces of
output, may be set on `cs:date` (delimiting the date-parts; `delimiter`
is not allowed when `cs:date` calls a localized date format), `cs:names`
(delimiting name lists from different [name
variables](#name-variables)), `cs:name` (delimiting names within name
lists), `cs:group` and `cs:layout` (delimiting the output of the child
elements).

A delimiting element is any element as above which takes a `delimiter`
attribute, whether the attribute is supplied or not.

Delimiters from any ancestor delimiting element are not applied within
the output of a delimiting element. The following produces
`retrieved: <http://example.com>`:

``` xml
<group delimiter=": ">
  <text term="retrieved" />
  <group>
    <text value="&lt;" />
    <text variable="URL" />
    <text value="&gt;" />
  </group>
</group>
```

### Display

The `display` attribute (similar the "display" property in CSS) may be
used to structure individual bibliographic entries into one or more text
blocks. If used, all rendering elements should be under the control of a
display attribute. The allowed values:

- "block" - block stretching from margin to margin.
- "left-margin" - block starting at the left margin. If followed by a
  "right-inline" block, the "left-margin" blocks of all bibliographic
  entries are set to a fixed width to accommodate the longest content
  string found among these "left-margin" blocks. In the absence of a
  "right-inline" block the "left-margin" block extends to the right
  margin.
- "right-inline" - block starting to the right of a preceding
  "left-margin" block (behaves as "block" in the absence of such a
  "left-margin" block). Extends to the right margin.
- "indent" - block indented to the right by a standard amount. Extends
  to the right margin.

**Examples**

1)  Instead of using `second-field-align` (see
    [Whitespace](#whitespace)), a similar layout can be achieved with a
    "left-margin" and "right-inline" block. A potential benefit is that
    the styling of blocks can be further controlled in the final output
    (e.g. using CSS for HTML, styles for Word, etc.).

    ``` xml
    <bibliography>
      <layout>
        <text display="left-margin" variable="citation-number"
            prefix="[" suffix="]"/>
        <group display="right-inline">
          <!-- rendering elements -->
        </group>
      </layout>
    </bibliography>
    ```

------------------------------------------------------------------------

2)  A per-author publication listing. With
    `subsequent-author-substitute` (see [Reference
    Grouping](#reference-grouping)) set to an empty string, the block
    with the author names is only rendered once for items by the same
    authors.

    ``` xml
    <bibliography subsequent-author-substitute="">
      <sort>
        <key variable="author"/>
        <key variable="issued"/>
      </sort>
      <layout>
        <group display="block">
          <names variable="author"/>
        </group>
        <group display="left-margin">
          <date variable="issued">
            <date-part name="year" />
          </date>
        </group>
        <group display="right-inline">
          <text variable="title"/>
        </group>
      </layout>
    </bibliography>
    ```

    The output of this example would look like:

    |                   |                    |
    |-------------------|--------------------|
    | Author1           |                    |
    | year-publication1 | title-publication1 |
    | year-publication2 | title-publication2 |
    | Author2           |                    |
    | year-publication3 | title-publication3 |
    | year-publication4 | title-publication4 |

------------------------------------------------------------------------

3)  An annotated bibliography, where the annotation appears in an
    indented block below the reference.

    ``` xml
    <bibliography>
      <layout>
        <group display="block">
          <!-- rendering elements -->
        </group>
        <text display="indent" variable="abstract" />
      </layout>
    </bibliography>
    ```

### Quotes

The `quotes` attribute may set on `cs:text`. When set to "true" ("false"
is default), the rendered text is wrapped in quotes (the quotation marks
used are terms). The localized `punctuation-in-quote` option controls
whether an adjoining comma or period appears outside (default) or inside
the closing quotation mark (see [Locale Options](#locale-options)).

### Strip-periods

The `strip-periods` attribute may be set on `cs:date-part` (but only if
`name` is set to "month"), `cs:label` and `cs:text`. When set to "true"
("false" is the default), any periods in the rendered text are removed.

### Text-case

The `text-case` attribute may be set on `cs:date`, `cs:date-part`,
`cs:label`, `cs:name-part`, `cs:number` and `cs:text`. The allowed
values:

- "lowercase": renders text in lowercase
- "uppercase": renders text in uppercase
- "capitalize-first": capitalizes the first character of the first word,
  if the word is lowercase
- "capitalize-all": capitalizes the first character of every lowercase
  word
- "sentence": renders text in sentence case (deprecated; do not use)
- "title": renders text in title case

#### Sentence Case Conversion

Sentence case conversion (with `text-case` set to "sentence") is
performed by:

1.  For uppercase strings, the first character of the string remains
    capitalized. All other letters are lowercased.
2.  For lower or mixed case strings, the first character of the first
    word is capitalized if the word is lowercase. The case of all other
    words stays the same.

CSL processors don't recognize proper nouns. As a result, strings in
sentence case can be accurately converted to title case, but not vice
versa. For this reason, it is generally preferable to store strings such
as titles in sentence case, and only use `text-case` if a style desires
another case.

Sentence case conversion is deprecated and will be removed in a future
version.

#### Title Case Conversion

Title case conversion (with `text-case` set to "title") for
English-language items is performed by:

1.  For uppercase strings, the first character of each word remains
    capitalized. All other letters are lowercased.
2.  For lower or mixed case strings, the first character of each
    lowercase word is capitalized. The case of words in mixed or
    uppercase stays the same.

In both cases, stop words are lowercased, unless they are the first or
last word in the string, or follow a colon. The stop words are listed in
the CSL Schema file
[stop-words.json](https://resource.citationstyles.org/schema/latest/styles/stop-words.json).
Hyphenated word parts are treated as distinct words (e.g., "two-thirds"
becomes "Two-Thirds").

##### Non-English Items

As many languages do not use title case, title case conversion (with
`text-case` set to "title") only affects English-language items.

If the `default-locale` attribute on `cs:style` isn't set, or set to a
locale code with a primary language tag of "en" (English), items are
assumed to be English. An item is only considered to be non-English if
its metadata contains a `language` field with a non-nil value that
doesn't start with the "en" primary language tag.

If `default-locale` is set to a locale code with a primary language tag
other than "en", items are assumed to be non-English. An item is only
considered to be English if the value of its `language` field starts
with the "en" primary language tag.

## Appendix I - Categories

- anthropology
- astronomy
- biology
- botany
- chemistry
- communications
- engineering
- generic-base - used for generic styles like Harvard and APA
- geography
- geology
- history
- humanities
- law
- linguistics
- literature
- math
- medicine
- philosophy
- physics
- political_science
- psychology
- science
- social_science
- sociology
- theology
- zoology

## Appendix II - Terms

### Type Terms

For each item type listed in [Appendix III -
Types](#appendix-iii---types), there is a corresponding term.

### Name Variable Terms

For each of the [Name Variables](#name-variables) listed in [Appendix
IV - Variables](#appendix-iv---variables), there is a corresponding
term.

### Number Variable Terms

For each of the [Number Variables](#number-variables) listed in
[Appendix IV - Variables](#appendix-iv---variables), there is a
corresponding term.

### Locators

- appendix
- article-locator
- book
- canon
- chapter
- column
- elocation
- equation
- figure
- folio
- issue
- line
- note
- opus
- page
- paragraph
- part
- rule
- section
- sub-verbo
- supplement
- table
- timestamp
- title
- verse
- volume

### Months

- month-01
- month-02
- month-03
- month-04
- month-05
- month-06
- month-07
- month-08
- month-09
- month-10
- month-11
- month-12

### Ordinals

- ordinal
- ordinal-00 through ordinal-99
- long-ordinal-01
- long-ordinal-02
- long-ordinal-03
- long-ordinal-04
- long-ordinal-05
- long-ordinal-06
- long-ordinal-07
- long-ordinal-08
- long-ordinal-09
- long-ordinal-10

### Punctuation

- open-quote
- close-quote
- open-inner-quote
- close-inner-quote
- page-range-delimiter
- colon
- comma
- semicolon

### Seasons

- season-01
- season-02
- season-03
- season-04

### Miscellaneous

- accessed
- ad
- advance-online-publication
- album
- and
- and others
- anonymous
- at
- audio-recording
- available at
- bc
- bce
- by
- ce
- circa
- cited
- et-al
- film
- forthcoming
- from
- henceforth
- ibid
- in
- in press
- internet
- interview
- letter
- loc-cit
- no date
- no-place
- no-publisher
- on
- online
- op-cit
- original-work-published
- personal-communication
- podcast
- podcast-episode
- preprint
- presented at
- radio-broadcast
- radio-series
- radio-series-episode
- reference
- retrieved
- review-of
- scale
- special-issue
- special-section
- television-broadcast
- television-series
- television-series-episode
- video
- working-paper

## Appendix III - Types

article  
A self-contained work made widely available but not published in a
journal or other publication;  
Use for preprints, working papers, and similar works posted on a
platform where some level of persistence or stewardship is expected
(e.g. arXiv or other preprint repositories, working paper series);  
For unpublished works not made widely available or only hosted on
personal websites, use `manuscript`

article-journal  
An article published in an academic journal

article-magazine  
An article published in a non-academic magazine

article-newspaper  
An article published in a newspaper

bill  
A proposed piece of legislation

book  
A book or similar work;  
Can be an authored book or an edited collection of self-contained
chapters;  
Can be a physical book or an ebook;  
The format for an ebook may be specified using `medium`;  
Can be a single-volume work, a multivolume work, or one volume of a
multivolume work;  
If a `container-title` is present, the item is interpreted as a book
republished in a collection or anthology;  
Also used for whole conference proceedings volumes or exhibition
catalogs by specifying `event` and related variables

broadcast  
A recorded work broadcast over an electronic medium (e.g. a radio
broadcast, a television show, a podcast);  
The type of broadcast may be specified using `genre`;  
If `container-title` is present, the item is interpreted as an episode
contained within a larger broadcast series (e.g. an episode in a
television show or an episode of a podcast)

chapter  
A part of a book cited separately from the book as a whole (e.g. a
chapter in an edited book);  
Also used for introductions, forewords, and similar supplemental
components of a book

classic  
A classical or ancient work, sometimes cited using a common abbreviation

collection  
An archival collection in a museum or other institution

dataset  
A data set or a similar collection of (mostly) raw data

document  
A catch-all category for items not belonging to other types;  
Use a more specific type when appropriate

entry  
An entry in a database, directory, or catalog;  
For entries in a dictionary, use `entry-dictionary`;  
For entries in an encyclopedia, use `entry-encyclopedia`

entry-dictionary  
An entry in a dictionary

entry-encyclopedia  
An entry in an encyclopedia or similar reference work

event  
An organized event (e.g., an exhibition or conference);  
Use for direct citations to the event, rather than to works contained
within an event (e.g. a `presentation` in a conference, a `graphic` in
an exhibition) or based on an event (e.g. a `paper-conference` published
in a proceedings, an exhibition catalog)

figure  
A illustration or representation of data, typically as part of a journal
article or other larger work;  
May be in any format (e.g. image, video, audio recording, 3D model);  
The format of the item can be specified using `medium`

graphic  
A still visual work;  
Can be used for artwork or other works (e.g. journalistic or historical
photographs);  
Can be used for any still visual work (e.g. photographs, drawings,
paintings, sculptures, clothing);  
The format of the item can be specified using `medium`

hearing  
A hearing by a government committee or transcript thereof

interview  
An interview of a person;  
Also used for a recording or transcript of an interview; `author` is
interpreted as the interviewee

legal_case  
A legal case

legislation  
A law or resolution enacted by a governing body

manuscript  
An unpublished manuscript;  
Use for both modern unpublished works and classical manuscripts;  
For working papers, preprints, and similar works posted to a repository,
use `article`

map  
A geographic map

motion_picture  
A video or visual recording;  
If a `container-title` is present, the item is interpreted as a part
contained within a larger compilation of recordings (e.g. a part of a
multipart documentary))

musical_score  
The printed score for a piece of music;  
For a live performance of the music, use `performance`;  
For recordings of the music, use `song` (for audio recordings) or
`motion_picture` (for video recordings)

pamphlet  
A fragment, historical document, or other unusually-published or
ephemeral work (e.g. a sales brochure)

paper-conference  
A paper formally published in conference proceedings;  
For papers presented at a conference, but not published in a
proceedings, use `speech`

patent  
A patent for an invention

performance  
A live performance of an artistic work;  
For non-artistic presentations, use `speech`;  
For recordings of a performance, use `song` or `motion_picture`

periodical  
A full issue or run of issues in a periodical publication (e.g. a
special issue of a journal)

personal_communication  
Personal communications between multiple parties;  
May be unpublished (e.g. private correspondence between two researchers)
or collected/published (e.g. a letter published in a collection)

post  
A post on a online forum, social media platform, or similar platform;  
Also used for comments posted to online items

post-weblog  
A blog post

regulation  
An administrative order from any level of government

report  
A technical report, government report, white paper, brief, or similar
work distributed by an institution;  
Also used for manuals and similar technical documentation (e.g. a
software, instrument, or test manual);  
If a `container-title` is present, the item is interpreted as a chapter
contained within a larger report

review  
A review of an item other than a book (e.g. a film review, posted peer
review of an article);  
If `reviewed-title` is absent, `title` is taken to be the title of the
reviewed item

review-book  
A review of a book;  
If `reviewed-title` is absent, `title` is taken to be the title of the
reviewed book

software  
A computer program, app, or other piece of software

song  
An audio recording;  
Can be used for any audio recording (not only music);  
If a `container-title` is present, the item is interpreted as a track
contained within a larger album or compilation of recordings

speech  
A speech or other presentation (e.g. a paper, talk, poster, or symposium
at a conference);  
Use `genre` to specify the type of presentation;  
Use `event` to indicate the event where the presentation was made (e.g.
the conference name);  
Use `container-title` if the presentation is part of a larger session
(e.g. a paper in a symposium);  
For papers published in conference proceedings, use
`paper-conference`;  
For artistic performances, use `performance`

standard  
A technical standard or similar set of rules or norms

thesis  
A thesis written to satisfy requirements for a degree;  
Use `genre` to specify the type of thesis

treaty  
A treaty agreement among political authorities

webpage  
A website or page on a website;  
Intended for sources which are intrinsically online; use a more specific
type when appropriate (e.g. `article-journal`, `post-weblog`, `report`,
`entry`);  
If a `container-title` is present, the item is interpreted as a page
contained within a larger website

## Appendix IV - Variables

### Standard Variables

abstract  
Abstract of the item (e.g. the abstract of a journal article)

annote  
Short markup, decoration, or annotation to the item (e.g., to indicate
items included in a review);  
For descriptive text (e.g., in an annotated bibliography), use `note`
instead

archive  
Archive storing the item

archive_collection  
Collection the item is part of within an archive

archive_location  
Storage location within an archive (e.g. a box and folder number)

archive-place  
Geographic location of the archive

authority  
Issuing or judicial authority (e.g. "USPTO" for a patent, "Fairfax
Circuit Court" for a legal case)

call-number  
Call number (to locate the item in a library)

citation-key  
Identifier of the item in the input data file (analogous to BibTeX
entrykey);  
Use this variable to facilitate conversion between word-processor and
plain-text writing systems;  
For an identifer intended as formatted output label for a citation (e.g.
"Ferr78"), use `citation-label` instead

citation-label  
Label identifying the item in in-text citations of label styles (e.g.
"Ferr78");  
May be assigned by the CSL processor based on item metadata;  
For the identifier of the item in the input data file, use
`citation-key` instead

collection-title  
Title of the collection holding the item (e.g. the series title for a
book; the lecture series title for a presentation)

container-title  
Title of the container holding the item (e.g. the book title for a book
chapter, the journal title for a journal article; the album title for a
recording; the session title for multi-part presentation at a
conference)

container-title-short  
Short/abbreviated form of `container-title`;  
Deprecated; use `variable="container-title" form="short"` instead

dimensions  
Physical (e.g. size) or temporal (e.g. running time) dimensions of the
item

division  
Minor subdivision of a court with a `jurisdiction` for a legal item

DOI  
Digital Object Identifier (e.g. "10.1128/AEM.02591-07")

event  
Deprecated legacy variant of `event-title`

event-title  
Name of the event related to the item (e.g. the conference name when
citing a conference paper; the meeting where presentation was made)

event-place  
Geographic location of the event related to the item (e.g. "Amsterdam,
The Netherlands")

genre  
Type, class, or subtype of the item (e.g. "Doctoral dissertation" for a
PhD thesis; "NIH Publication" for an NIH technical report);  
Do not use for topical descriptions or categories (e.g. "adventure" for
an adventure movie)

ISBN  
International Standard Book Number (e.g. "978-3-8474-1017-1")

ISSN  
International Standard Serial Number

jurisdiction  
Geographic scope of relevance (e.g. "US" for a US patent; the court
hearing a legal case)

keyword  
Keyword(s) or tag(s) attached to the item

language  
The language of the item;  
Should be entered as an ISO 639-1 two-letter language code (e.g. "en",
"zh"), optionally with a two-letter locale code (e.g. "de-DE", "de-AT")

license  
The license information applicable to an item (e.g. the license an
article or software is released under; the copyright information for an
item; the classification status of a document)

medium  
Description of the item's format or medium (e.g. "CD", "DVD", "Album",
etc.)

note  
Descriptive text or notes about an item (e.g. in an annotated
bibliography)

original-publisher  
Original publisher, for items that have been republished by a different
publisher

original-publisher-place  
Geographic location of the original publisher (e.g. "London, UK")

original-title  
Title of the original version (e.g. "Война и мир", the untranslated
Russian title of "War and Peace")

part-title  
Title of the specific part of an item being cited

PMCID  
PubMed Central reference number

PMID  
PubMed reference number

publisher  
Publisher

publisher-place  
Geographic location of the publisher

references  
Resources related to the procedural history of a legal case or
legislation;  
Can also be used to refer to the procedural history of other items (e.g.
"Conference canceled" for a presentation accepted as a conference that
was subsequently canceled; details of a retraction or correction notice)

reviewed-genre  
Type of the item being reviewed by the current item (e.g. book, film)

reviewed-title  
Title of the item reviewed by the current item

scale  
Scale of e.g. a map or model

source  
Source from whence the item originates (e.g. a library catalog or
database)

status  
Publication status of the item (e.g. "forthcoming"; "in press"; "advance
online publication"; "retracted")

title  
Primary title of the item

title-short  
Short/abbreviated form of `title`;  
Deprecated; use `variable="title" form="short"` instead

URL  
Uniform Resource Locator (e.g.
"<https://aem.asm.org/cgi/content/full/74/9/2766>")

volume-title  
Title of the volume of the item or container holding the item;  
Also use for titles of periodical special issues, special sections, and
the like

year-suffix  
Disambiguating year suffix in author-date styles (e.g. "a" in "Doe,
1999a")

#### Number Variables

Number variables are a subset of the [Standard
Variables](#standard-variables).

chapter-number  
Chapter number (e.g. chapter number in a book; track number on an album)

citation-number  
Index (starting at 1) of the cited reference in the bibliography
(generated by the CSL processor)

collection-number  
Number identifying the collection holding the item (e.g. the series
number for a book)

edition  
(Container) edition holding the item (e.g. "3" when citing a chapter in
the third edition of a book)

first-reference-note-number  
Number of a preceding note containing the first reference to the item;  
Assigned by the CSL processor;  
Empty in non-note-based styles or when the item hasn't been cited in any
preceding notes in a document

issue  
Issue number of the item or container holding the item (e.g. "5" when
citing a journal article from journal volume 2, issue 5);  
Use `volume-title` for the title of the issue, if any

locator  
A cite-specific pinpointer within the item (e.g. a page number within a
book, or a volume in a multi-volume work);  
Must be accompanied in the input data by a label indicating the locator
type (see the [Locators](#locators) term list), which determines which
term is rendered by `cs:label` when the `locator` variable is selected.

number  
Number identifying the item (e.g. a report number)

number-of-pages  
Total number of pages of the cited item

number-of-volumes  
Total number of volumes, used when citing multi-volume books and such

page  
Range of pages the item (e.g. a journal article) covers in a container
(e.g. a journal issue)

page-first  
First page of the range of pages the item (e.g. a journal article)
covers in a container (e.g. a journal issue)

part-number  
Number of the specific part of the item being cited (e.g. part 2 of a
journal article);  
Use `part-title` for the title of the part, if any

printing-number  
Printing number of the item or container holding the item

section  
Section of the item or container holding the item (e.g. "§2.0.1" for a
law; "politics" for a newspaper article)

supplement-number  
Supplement number of the item or container holding the item (e.g. for
secondary legal items that are regularly updated between editions)

version  
Version of the item (e.g. "2.0.9" for a software program)

volume  
Volume number of the item (e.g. "2" when citing volume 2 of a book) or
the container holding the item (e.g. "2" when citing a chapter from
volume 2 of a book);  
Use `volume-title` for the title of the volume, if any

### Date Variables

accessed  
Date the item has been accessed

available-date  
Date the item was initially available (e.g. the online publication date
of a journal article before its formal publication date; the date a
treaty was made available for signing)

event-date  
Date the event related to an item took place

issued  
Date the item was issued/published

original-date  
Issue date of the original version

submitted  
Date the item (e.g. a manuscript) was submitted for publication

### Name Variables

author  
Author

chair  
The person leading the session containing a presentation (e.g. the
organizer of the `container-title` of a `speech`)

collection-editor  
Editor of the collection holding the item (e.g. the series editor for a
book)

compiler  
Person compiling or selecting material for an item from the works of
various persons or bodies (e.g. for an anthology)

composer  
Composer (e.g. of a musical score)

container-author  
Author of the container holding the item (e.g. the book author for a
book chapter)

contributor  
A minor contributor to the item; typically cited using "with" before the
name when listed in a bibliography

curator  
Curator of an exhibit or collection (e.g. in a museum)

director  
Director (e.g. of a film)

editor  
Editor

editorial-director  
Managing editor ("Directeur de la Publication" in French)

editor-translator  
Combined editor and translator of a work;  
The citation processory must be automatically generate if `editor` and
`translator` variables are identical;  
May also be provided directly in item data

executive-producer  
Executive producer (e.g. of a television series)

guest  
Guest (e.g. on a TV show or podcast)

host  
Host (e.g. of a TV show or podcast)

illustrator  
Illustrator (e.g. of a children's book or graphic novel)

interviewer  
Interviewer (e.g. of an interview)

narrator  
Narrator (e.g. of an audio book)

organizer  
Organizer of an event (e.g. organizer of a workshop or conference)

original-author  
The original creator of a work (e.g. the form of the author name listed
on the original version of a book; the historical author of a work; the
original songwriter or performer for a musical piece; the original
developer or programmer for a piece of software; the original author of
an adapted work such as a book adapted into a screenplay)

performer  
Performer of an item (e.g. an actor appearing in a film; a muscian
performing a piece of music)

producer  
Producer (e.g. of a television or radio broadcast)

recipient  
Recipient (e.g. of a letter)

reviewed-author  
Author of the item reviewed by the current item

script-writer  
Writer of a script or screenplay (e.g. of a film)

series-creator  
Creator of a series (e.g. of a television series)

translator  
Translator

## Appendix V - Page Range Formats

The page abbreviation rules for the different values of the
`page-range-format` attribute on `cs:style` are:

"chicago"  
Alias for "chicago-15"; will change to be an alias for "chicago-16" in
CSL v1.1.

"chicago-15"  
Page ranges are abbreviated according to the [Chicago Manual of Style
(15th ed and earlier) rules]() (see 15th ed, section 9.64):

| First number                          | Second number                                                           | Examples                                     |
|---------------------------------------|-------------------------------------------------------------------------|----------------------------------------------|
| Less than 100                         | Use all digits                                                          | 3 – 10; 71 – 72                              |
| 100 or multiple of 100                | Use all digits                                                          | 100 – 104; 600 – 613; 1100 – 1123            |
| 101 through 109 (in multiples of 100) | Use changed part only, omitting unneeded zeros                          | 107 – 8; 505 – 17; 1002 – 6                  |
| 110 through 199 (in multiples of 100) | Use two digits, or more as needed                                       | 321 – 25; 415 – 532; 11564 – 68; 13792 – 803 |
| 4 digits                              | If numbers are four digits long and three digits change, use all digits | 1496 – 1504; 2787 – 2816                     |

"chicago-16"  
Page ranges are abbreviated according to the [Chicago Manual of Style
(16th ed and later)
rules](http://cmosshoptalk.com/2018/04/10/316-7-316-17-or-316-317-chicago-style-for-number-ranges/)
(see 16th ed, section 9.61):

| First number                                                                       | Second number                                                          | Examples                                                                         |
|------------------------------------------------------------------------------------|------------------------------------------------------------------------|----------------------------------------------------------------------------------|
| Less than 100                                                                      | Use all digits                                                         | 3 – 10; 71 – 72; 92 – 113;                                                       |
| 100 or multiple of 100                                                             | Use all digits                                                         | 100 – 104; 600 – 613; 1100 – 1123                                                |
| 101 through 109, 201 through 209, etc. (for each multiple of 100)                  | Use changed part only, omitting unneeded zeros                         | 107 – 8; 505 – 17; 1002 – 6                                                      |
| Everything else (110 through 199, 210 through 299, etc.; for each multiple of 100) | Use two digits, unless more digits are needed to show the changed part | 321 – 25; 415 – 532; 1087 – 89; 1496 – 500; 11564 – 68; 13792 – 803 12991 – 3001 |

"expanded"  
Abbreviated page ranges are expanded to their non-abbreviated form: 42 –
45, 321 – 328, 2787 – 2816

"minimal"  
All digits repeated in the second number are left out: 42 – 5, 321 – 8,
2787 – 816

"minimal-two"  
As "minimal", but at least two digits are kept in the second number when
it has two or more digits long.

## Appendix VI: Links

The CSL syntax does not have support for configuration of links.
However, processors should include links on bibliographic references,
using the following rules:

If the bibliography entry for an item renders any of the following
identifiers, the identifier should be anchored as a link, with the
target of the link as follows:

1.  `url`: output as is
2.  `doi`: prepend with "<https://doi.org/>"
3.  `pmid`: prepend with "<https://www.ncbi.nlm.nih.gov/pubmed/>"
4.  `pmcid`: prepend with "<https://www.ncbi.nlm.nih.gov/pmc/articles/>"

If the identifier is rendered as a URI, include rendered URI components
(e.g. "<https://doi.org/>") in the link anchor. Do not include any other
affix text in the link anchor (e.g. "Available from: ", "doi: ", "PMID:
").

Citation processors should include an option flag for calling
applications to disable bibliography linking behavior.

[^1]: Including uncited entries in the bibliography can make cites in
    the document ambiguous. To make sure such cites are disambiguated,
    the CSL processor should include (invisible) cites for such uncited
    bibliographic entries in the disambiguation process.
