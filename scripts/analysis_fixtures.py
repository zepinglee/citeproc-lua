import glob
import os
import re
import xml.etree.ElementTree as ET


with open('./tests/citeproc-test-skip.txt') as f:
    skipped_fixtures = [
        line.strip() for line in f.readlines()
        if line.strip() and not line.startswith('#')
    ]

failed_fixtures = []
with open('./tests/citeproc-test.log') as f:
    for line in f:
        if line.startswith('Failure →') or \
            line.startswith('Error →'):
            failure_file = line.split()[-1]
            failed_fixtures.append(failure_file)


for fixture in skipped_fixtures:
    if fixture not in failed_fixtures:
        print(fixture)
