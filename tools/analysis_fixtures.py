import glob
from collections import Counter
import os
import re
from telnetlib import theNULL
from unicodedata import name
import xml.etree.ElementTree as ET

failed_fixtures = []
skipped_fixtures = [
    'affix_CommaAfterQuote.txt',
    'bugreports_ApostropheOnParticle.txt',
    'bugreports_EtAlSubsequent.txt',
    'bugreports_FrenchApostrophe.txt',
    'bugreports_parseName.txt',
    'decorations_NoNormalWithoutDecoration.txt',
    'flipflop_LeadingMarkupWithApostrophe.txt',
    'flipflop_OrphanQuote.txt',
    'flipflop_SingleBeforeColon.txt',
    'integration_FirstReferenceNoteNumberPositionChange.txt',
    'integration_IbidOnInsert.txt',
    'label_EditorTranslator2.txt',
    'label_NoFirstCharCapWithInTextClass.txt',
    'locator_SimpleLocators.txt',
    'magic_NameSuffixWithComma.txt',
    'name_CollapseRoleLabels.txt',
    'name_EditorTranslatorSameWithTerm.txt',
    'name_HebrewAnd.txt',
    'name_InTextMarkupInitialize.txt',
    'name_InTextMarkupNormalizeInitials.txt',
    'name_ParsedNonDroppingParticleWithApostrophe.txt',
    'name_ParticlesDemoteNonDroppingNever.txt',
    'name_WithNonBreakingSpace.txt',
    'name_namepartAffixes.txt',
    'number_OrdinalSpacing.txt',
    'number_PlainHyphenOrEnDashAlwaysPlural.txt',
    'position_IbidWithPrefixFullStop.txt',
    'position_ResetNoteNumbers.txt',
    'sort_BibliographyCitationNumberDescendingViaCompositeMacro.txt',
    'sort_BibliographyCitationNumberDescendingViaMacro.txt',
    'sort_CitationNumberPrimaryDescendingViaMacroBibliography.txt',
    'sort_CitationNumberPrimaryDescendingViaMacroCitation.txt',
    'sort_CitationNumberPrimaryDescendingViaVariableBibliography.txt',
    'sort_CitationNumberSecondaryAscendingViaVariableCitation.txt',
    'textcase_LocaleUnicode.txt',
    'sort_CitationNumberPrimaryDescendingViaVariableCitation.txt',
    'textcase_NoSpaceBeforeApostrophe.txt',
    'textcase_SentenceCapitalization.txt',
    'textcase_SkipNameParticlesInTitleCase.txt',
]

with open('./test/citeproc-test.log') as f:
    for line in f:
        if line.startswith('Failure → citeproc test test-suite') or \
            line.startswith('Error → citeproc test test-suite'):
            failure_file = line.split()[-1]
            failed_fixtures.append(failure_file)

namespaces = {
    'cs': 'http://purl.org/net/xbiblio/csl',
}

# paths = sorted(glob.glob('./test/test-suite/processor-tests/humans/*.txt'))
paths = sorted([
    './test/test-suite/processor-tests/humans/' + f for f in failed_fixtures
    if f not in skipped_fixtures and not f.startswith('punctuation_')
])

fixtures = []
for path in paths:
    # print(path)

    with open(path) as f:
        lines = f.readlines()

    xml = ''
    in_xml = False
    for line in lines:
        if re.match(r'>>=+\s*CSL\s*=+>>', line):
            in_xml = True
        elif re.match(r'<<=+\s*CSL\s*=+<<', line):
            break
        elif in_xml:
            xml += line

    root = ET.fromstring(xml)
    tags = set()
    attrs = set()

    for el in root.iter():
        tag = el.tag.split("}")[1]
        tags.add(tag)
        for attr in el.attrib.keys():
            attrs.add(attr)

    # root = root.getroot()
    count = len(tags)

    fixture = {
        'path': path,
        'count': count,
        'tags': tags,
        'attrs': attrs,
    }
    fixtures.append(fixture)

skip_tags = [
]
skip_attrs = [
    'disambiguate-add-givenname',
    'disambiguate-add-names',
    'disambiguate',
    'disambiguate-add-year-suffix',
    'collapse',
    'cite-group-delimiter',
    'subsequent-author-substitute',
    'subsequent-author-substitute-rule',
]
def skip_fixture(fixture):
    for tag in skip_tags:
        if tag in fixture['tags']:
            return True
    for attr in skip_attrs:
        if attr in fixture['attrs']:
            return True
    return False

fixtures = [fixture for fixture in fixtures if not skip_fixture(fixture)]

for fixture in list(sorted(fixtures, key=lambda x: x['count']))[:10]:
    print(f'{fixture["count"]:<3} {os.path.split(fixture["path"])[1]:50} {fixture["path"]}')

# print(len(failed_fixtures))
