# Bib CSL mapping


## Item Types

Bib|CSL|Notes
-|-|-
`@article`|`article-journal`|May also be `article-magazine` or `article-newspaper` depending upon the field `entrysubtype`.
`@artwork`|`graphic`|
`@audio`|`song`|CSL's `song` can be used for any audio recording (not only music).
`@bibnote`|-|Not supported.
`@book`|`book`|
`@bookinbook`|`chapter`|
`@booklet`|`pamphlet`|
`@collection`|`book`|
`@comment`|-|Special entry type for Scribe compatibility
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
`@legislation`|`legislation`|"Laws, bills, legislative proposals, and similar things." May also be `bill`
`@letter`|`personal_communication`|
`@manual`|`report`|
`@mastersthesis`|`thesis`|Alias for `@thesis`.
`@misc`|-|Will be mapped to `document` in CSL v1.0.2.
`@movie`|`motion_picture`|
`@music`|`song`|
`@mvbook`|`book`|
`@mvcollection`|`book`|
`@mvproceedings`|`book`|
`@mvreference`|`book`|
`@online`|`webpage`|
`@patent`|`patent`|
`@performance`|-|Will be mapped to `performance` in CSL v1.0.2.
`@periodical`|`book`|Will be mapped to `periodical` in CSL v1.0.2.
`@phdthesis`|`thesis`|Alias for `@thesis`.
`@preamble`|-|Special entry type for inserting commands or text in the bbl
`@proceedings`|`book`|
`@reference`|`book`|
`@report`|`report`|
`@review`|`review`|"A more specific variant of the `@article` type"
`@set`|-|Not supported.
`@software`|`article`|Will be mapped to `software` in CSL v1.0.2.
`@standard`|`book`|Will be mapped to `standard` in CSL v1.0.2.
`@string`|-|Special entry type for defining abbreviations
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
`abstract`|`abstract`|
`addendum`|-|Not supported.
`address`|`publisher-place`|Alias for `location`.
`afterword`|-|Not supported.
`annotation`|-|
`annotator`|-|
`annote`|-|Alias for `annotation`.
`archiveprefix`|`archive`|Alias for `eprinttype`.
`author`|`author`|
`authortype`|-|
`bookauthor`|`container-author`|
`bookpagination`|-|
`booksubtitle`|-|
`booktitle`|`container-title`|
`booktitleaddon`|-|
`chapter`|`chapter-number`|
`commentator`|-|
`crossref`|-|Inherits data from a parent entry.
`date`|`issued`|
`doi`|`DOI`|
`edition`|`edition`|
`editor`|`editor`|
`editortype`|-|
`eid`|-|
`entryset`|-|Not supported.
`entrysubtype`|-|Not supported.
`eprint`|-|Mapped to `PMID` if `eprinttype` is "PubMed".
`eprintclass`|-|
`eprinttype`|`archive`|
`eventdate`|`event-date`|
`eventtitle`|`event`|Will be mapped to `event-title` in CSL v1.0.2.
`eventtitleaddon`|-|
`execute`|-|Not supported.
`file`|-|
`foreword`|-|
`gender`|-|Not supported.
`holder`|-|
`howpublished`|-|Check if a URL is contained.
`hyphenation`|-|Alias for `langid`.
`ids`|-|
`indexsorttitle`|-|Not supported.
`indextitle`|-|
`institution`|`publisher`|
`introduction`|-|
`isan`|-|
`isbn`|`ISBN`|
`ismn`|-|
`isrn`|-|
`issn`|`ISSN`|
`issue`|`issue`|
`issuesubtitle`|-|
`issuetitle`|-|
`issuetitleaddon`|-|
`iswc`|-|
`journal`|`container-title`|Alias for `journaltitle`.
`journalsubtitle`|-|It should be concatenated to the `container-title`.
`journaltitle`|`container-title`|
`journaltitleaddon`|-|
`key`|-|Alias for `sortkey`. Not supported.
`keywords`|-|
`label`|-|
`langid`|-|
`langidopts`|-|
`language`|`language`|
`library`|-|
`location`|`publisher-place`|
`mainsubtitle`|-|
`maintitle`|-|
`maintitleaddon`|-|
`month`|-|Used only when `date` is empty.
`note`|`note`|
`number`|`number`|It is mapped to `issue` in `@ariticle` but to `number` in `@patent` or `@report`.
`options`|-|Not supported.
`organization`|`publisher`|It is mapped to `author` (in `institution` property) if possible.
`origdate`|`original-date`|
`origlanguage`|-|
`origlocation`|`original-publisher-place`|
`origpublisher`|`original-publisher`|
`origtitle`|`original-title`|
`pages`|`page`|
`pagetotal`|`number-of-pages`|
`pagination`|-|
`part`|`part`|
`pdf`|-|Alias for `file`.
`presort`|-|Not supported.
`primaryclass`|-|Alias for `eprintclass`.
`publisher`|`publisher`|
`pubstate`|-|
`related`|-|Not supported.
`relatedoptions`|-|Not supported.
`relatedstring`|-|Not supported.
`relatedtype`|-|Not supported.
`reprinttitle`|-|
`school`|`publisher`|Alias for `institution`.
`series`|`collection-title`|
`shortauthor`|-|
`shorteditor`|-|
`shorthand`|-|Not supported.
`shorthandintro`|-|Not supported.
`shortjournal`|`container-title-short`|
`shortseries`|-|
`shorttitle`|`title-short`|
`sortkey`|-|Not supported.
`sortname`|-|Not supported.
`sortshorthand`|-|Not supported.
`sorttitle`|-|Not supported.
`sortyear`|-|
`subtitle`|-|
`title`|`title`|
`titleaddon`|-|
`translator`|`translator`|
`type`|`genre`|
`url`|`URL`|
`urldate`|`accessed`|
`venue`|`event-place`|
`version`|`version`|
`volume`|`volume`|
`volumes`|`number-of-volumes`|
`xdata`|-|inherits fields from other items.
`xref`|-|Establishes a parent-child relationship in biblatex, but without inheriting data => no need to parse this.
`year`|-|Used only when `date` is empty.
