# Bib CSL mapping


## Item Types

Bib|CSL|Notes
-|-|-
`@article`|`article`|May also be `article-journal`, `article-magazine` or `article-newspaper` depending upon the field `entrysubtype`.
`@artwork`|`graphic`|
`@audio`|`song`|CSL's `song` can be used for any audio recording (not only music).
`@bibnote`|-|Not supported.
`@book`|`book`|
`@bookinbook`|`chapter`|
`@booklet`|`pamphlet`|
`@collection`|`book`|
`@commentary`|-|Not supported.
`@conference`|`paper-conference`|Alias for `@inproceedings`.
`@dataset`|`dataset`|
`@electronic`|`webpage`|Alias for `@online`.
`@image`|`graphic`|
`@inbook`|`chapter`|
`@incollection`|`chapter`|
`@inproceedings`|`paper-conference`|
`@inreference`|`entry`|May also be `entry`, `entry-dictionary` or `entry-encyclopedia`.
`@jurisdiction`|-|"Court decisions, court recordings, and similar things."
`@legal`|`treaty`|"Legal documents such as treaties."
`@legislation`|`legislation`|"Laws, bills, legislative proposals, and similar things." The `bill` in CSL is used for a proposed piece of legislation.
`@letter`|`personal_communication`|
`@manual`|`report`|
`@mastersthesis`|`thesis`|Alias for `@thesis`.
`@misc`|`article`|Use `article` as default generic type.
`@movie`|`motion_picture`|
`@music`|`song`|
`@mvbook`|`book`|
`@mvcollection`|`book`|
`@mvproceedings`|`book`|
`@mvreference`|`book`|
`@online`|`webpage`|
`@patent`|`patent`|
`@performance`|`performance`|
`@periodical`|`periodical`|
`@phdthesis`|`thesis`|Alias for `@thesis`.
`@proceedings`|`book`|
`@reference`|`book`|
`@report`|`report`|
`@review`|`review`|"A more specific variant of the `@article` type"
`@set`|-|Not supported.
`@software`|`software`|
`@standard`|`standard`|
`@suppbook`|`chapter`|lossy mapping; "Supplemental material in a `@book`. This type is closely related to the @inbook entry type. While `@inbook` is primarily intended for a part of a book with its own title (e. g., a single essay in a collection of essays by the same author), this type is provided for elements such as prefaces, introductions, forewords, afterwords, etc. which often have a generic title only. Style guides may require such items to be formatted differently from other `@inbook` items."
`@suppcollection`|`chapter`|lossy mapping; see `suppbook`
`@suppperiodical`|`article`|see `article`
`@techreport`|`report`|Alias for `@report`.
`@thesis`|`thesis`|
`@unpublished`|`manuscript`|
`@video`|`motion_picture`|
`@www`|`webpage`|Alias for `@online`.
`@xdata`|-|special item type: "`@xdata` entries hold data which may be inherited by other entries using the xdata field. Entries of this type only serve as data containers; they may not be cited or added to the bibliography."


## Fields

Bib|CSL|Notes
-|-|-
`@abstract`|`abstract`|
`@addendum`|-|Not supported.
`@address`|-|Alias for `location`.
`@afterword`|-|Not supported.
`@annotation`|-|
`@annotator`|-|
`@annote`|-|Alias for `annotation`.
`@archiveprefix`|-|Alias for `eprinttype`.
`@author`|`author`|
`@authortype`|-|
`@bookauthor`|`container-author`|
`@bookpagination`|-|
`@booksubtitle`|-|
`@booktitle`|`container-title`|
`@booktitleaddon`|-|
`@chapter`|`chapter-number`|
`@commentator`|-|
`@crossref`|-|Inherits data from a parent entry.
`@date`|`issued`|
`@doi`|`DOI`|
`@edition`|`edition`|
`@editor`|`editor`|
`@editortype`|-|
`@eid`|-|
`@entryset`|-|Not supported.
`@entrysubtype`|-|Not supported.
`@eprint`|-|
`@eprintclass`|-|
`@eprinttype`|-|
`@eventdate`|-|
`@eventtitle`|-|
`@eventtitleaddon`|-|
`@execute`|-|Not supported.
`@file`|-|
`@foreword`|-|
`@gender`|-|Not supported.
`@holder`|-|
`@howpublished`|-|Not supported.
`@hyphenation`|-|Alias for `langid`.
`@ids`|-|
`@indexsorttitle`|-|Not supported.
`@indextitle`|-|
`@institution`|`publisher`|
`@introduction`|-|
`@isan`|-|
`@isbn`|-|
`@ismn`|-|
`@isrn`|-|
`@issn`|-|
`@issue`|`issue`|
`@issuesubtitle`|-|
`@issuetitle`|-|
`@issuetitleaddon`|-|
`@iswc`|-|
`@journal`|`container-title`|Alias for `journaltitle`.
`@journalsubtitle`|-|It should be concatenated to the `container-title`.
`@journaltitle`|`container-title`|
`@journaltitleaddon`|-|
`@key`|-|Alias for `sortkey`. Not supported.
`@keywords`|-|
`@label`|-|
`@langid`|-|
`@langidopts`|-|
`@language`|`language`|
`@library`|-|
`@location`|-|
`@mainsubtitle`|-|
`@maintitle`|-|
`@maintitleaddon`|-|
`@month`|-|Part of `issued` date
`@note`|`note`|
`@number`|`issue`|It is mapped to `issue` in `@ariticle` but to `number` in `@patent` or `@report`.
`@options`|-|Not supported.
`@organization`|`publisher`|It is mapped to `author` (in `institution` property) if possible.
`@origdate`|-|
`@origlanguage`|-|
`@origlocation`|-|
`@origpublisher`|-|
`@origtitle`|-|
`@pages`|`page`|
`@pagetotal`|`number-of-pages`|
`@pagination`|-|
`@part`|`part`|
`@pdf`|-|Alias for `file`.
`@presort`|-|Not supported.
`@primaryclass`|-|Alias for `eprintclass`.
`@publisher`|`publisher`|
`@pubstate`|-|
`@related`|-|Not supported.
`@relatedoptions`|-|Not supported.
`@relatedstring`|-|Not supported.
`@relatedtype`|-|Not supported.
`@reprinttitle`|-|
`@school`|`publisher`|Alias for `institution`.
`@series`|`collection-title`|
`@shortauthor`|-|
`@shorteditor`|-|
`@shorthand`|-|Not supported.
`@shorthandintro`|-|Not supported.
`@shortjournal`|-|
`@shortseries`|-|
`@shorttitle`|-|
`@sortkey`|-|Not supported.
`@sortname`|-|Not supported.
`@sortshorthand`|-|Not supported.
`@sorttitle`|-|Not supported.
`@sortyear`|-|
`@subtitle`|-|
`@title`|`title`|
`@titleaddon`|-|
`@translator`|`translator`|
`@type`|`genre`|
`@url`|-|
`@urldate`|-|
`@venue`|-|
`@version`|`version`|
`@volume`|`volume`|
`@volumes`|`number-of-volumes`|
`@xdata`|-|inherits fields from other items.
`@xref`|-|Establishes a parent-child relationship in biblatex, but without inheriting data => no need to parse this.
`@year`|`issued`|
