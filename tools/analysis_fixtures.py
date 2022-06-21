import glob
from collections import Counter
import os
import re
from unicodedata import name
import xml.etree.ElementTree as ET

failed_fixtures = []
skipped_fixtures = [
    'affix_CommaAfterQuote.txt',
    'bugreports_ApostropheOnParticle.txt',
    'bugreports_ArabicLocale.txt',
    'bugreports_BadCitationUpdate.txt',
    'bugreports_EtAlSubsequent.txt',
    'bugreports_FrenchApostrophe.txt',
    'date_IgnoreNonexistentSort.txt',
    'date_NonexistentSortReverseCitation.txt',
    'decorations_NoNormalWithoutDecoration.txt',
    'flipflop_OrphanQuote.txt',
    'flipflop_SingleBeforeColon.txt',
    'flipflop_StartingApostrophe.txt',
    'integration_DeleteName.txt',
    'label_EditorTranslator2.txt',
    'magic_CapitalizeFirstOccurringNameParticle.txt',
    'name_AfterInvertedName.txt',
    'name_EditorTranslatorSameWithTerm.txt',
    'name_ParsedNonDroppingParticleWithApostrophe.txt',
    'name_ParticlesDemoteNonDroppingNever.txt',
    'name_WithNonBreakingSpace.txt',
    'name_namepartAffixes.txt',
    'punctuation_FrenchOrthography.txt',
    'punctuation_FullMontyField.txt',
    'punctuation_FullMontyPlain.txt',
    'textcase_LocaleUnicode.txt',
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

num_tags = dict()

# paths = sorted(glob.glob('./test/test-suite/processor-tests/humans/*.txt'))
paths = sorted([
    './test/test-suite/processor-tests/humans/' + f for f in failed_fixtures
    if f not in skipped_fixtures
    # and not f.startswith('bugreports_')
    and not f.startswith('collapse_')
    # and not f.startswith('date_')
    # and not f.startswith('decorations_')
    and not f.startswith('disambiguate_')
    # and not f.startswith('flipflop_')
    and not f.startswith('magic_Name')
    # and not f.startswith('name')
    # and not f.startswith('number_')
    # and not f.startswith('textcase_')
])

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
    tags = []

    for el in root.iter():
        tag = el.tag.split("}")[1]
        tags.append(tag)

    # root = root.getroot()
    count = Counter(tags)

    # file = os.path.split(path)[1]
    num_tags[path] = len(count.items())

# print(num_tags)

for path in list(sorted(paths, key=lambda x: num_tags[x]))[:10]:
    print(f'{num_tags[path]:<3} {os.path.split(path)[1]:50} {path}')

# print(len(failed_fixtures))
