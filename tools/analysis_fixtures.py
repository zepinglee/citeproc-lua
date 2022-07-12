import glob
import os
import re
import xml.etree.ElementTree as ET

skip_tags = [
]
skip_attrs = [
    'cite-group-delimiter',
    'collapse',
    # 'subsequent-author-substitute',
    # 'subsequent-author-substitute-rule',
]
skip_attr_values = [
    'citation-label',
]
skipped_fixtures = [
    'disambiguate_BasedOnSubsequentFormWithBackref2.txt',
    'bugreports_EnvAndUrb.txt',
    # Disambiguation is based on the subsequent
    'disambiguate_BasedOnEtAlSubsequent.txt',
    'disambiguate_DisambiguationHang.txt',
    # Disambiguation with only issued date?
    'date_YearSuffixImplicitWithNoDate.txt',
    'date_YearSuffixWithNoDate.txt',
    # Quotes
    'punctuation_FrenchOrthography.txt',
    # Punctuation merge
    'position_IbidWithPrefixFullStop.txt'
]

failed_fixtures = []
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
    if f not in skipped_fixtures
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
    attr_values = set()

    for el in root.iter():
        tag = el.tag.split("}")[1]
        tags.add(tag)
        for attr, value in el.attrib.items():
            attrs.add(attr)
            for value_var in value.split():
                attr_values.add(value_var)

    # root = root.getroot()
    count = len(tags)

    fixture = {
        'path': path,
        'count': count,
        'tags': tags,
        'attrs': attrs,
        'attr_values': attr_values,
    }
    fixtures.append(fixture)

def skip_fixture(fixture):
    for tag in skip_tags:
        if tag in fixture['tags']:
            return True
    for attr in skip_attrs:
        if attr in fixture['attrs']:
            return True
    for value in skip_attr_values:
        if value in fixture['attr_values']:
            return True
    return False

fixtures = [fixture for fixture in fixtures if not skip_fixture(fixture)]

for fixture in reversed(sorted(fixtures, key=lambda x: x['count'])):
    print(f'{fixture["count"]:<3} {os.path.split(fixture["path"])[1]:65} {fixture["path"]}')

# print(len(failed_fixtures))
