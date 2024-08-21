from collections import OrderedDict
import json
import re
import os
import glob
import warnings

import luadata

# References:
# https://github.com/jgm/pandoc/blob/master/src/Text/Pandoc/Citeproc/BibTeX.hs
# https://github.com/andras-simonyi/citeproc-el/wiki/BibLaTeX-CSL-mapping
# https://github.com/brechtm/citeproc-py/blob/master/citeproc/source/bibtex/bibtex.py
# https://github.com/citation-js/bibtex-mappings/blob/main/biblatex/output/types.json


class BibData(OrderedDict):

    def __init__(self, path):
        super().__init__({
            'description': 'BibTeX CSL mapping',
            'types': dict(),
            'fields': dict(),
            'macros': dict(),
        })

        if os.path.exists(path):
            with open(path) as f:
                self.update(json.load(f))
        else:
            warnings.warn(f'Invalid path "{path}".')

        self.texmf_dist = ''
        if not self.texmf_dist:
            paths = glob.glob('/usr/local/texlive/*/texmf-dist')
            if paths:
                self.texmf_dist = sorted(paths)[-1]

        self.skip_field_prefixes = [
            'CTL',
            'abnt-',
            'ctrl-',
            'p.',
            'r.',
            'w.',
        ]

    def update_bibtex(self):
        self.update_bst('plain.bst', 'bibtex')
        self.update_bst('unsrt.bst', 'bibtex')
        self.update_bst('alpha.bst', 'bibtex')
        self.update_bst('abbrv.bst', 'bibtex')
        self.update_bst('acm.bst', 'bibtex')
        self.update_bst('apalike.bst', 'bibtex')
        self.update_bst('ieeetr.bst', 'bibtex')
        self.update_bst('siam.bst', 'bibtex')

    def update_bst(self, file_name, source=None):
        if os.path.exists(file_name):
            path = file_name
        else:
            path = os.popen(f'kpsewhich {file_name}').read().strip()
            if not os.path.exists(path):
                warnings.warn(f'Invalid path "{path}".')
                return

        if not source:
            source = os.path.split(path)[1]

        with open(path) as f:
            contents = f.read()

        functions = dict()
        for match in re.finditer(
                r'FUNCTION\s*\{\s*(\w+)\s*\}\s*\{\s*([^}]*)\s*\}', contents):
            name = match.group(1).lower()
            body = match.group(2)
            functions[name] = body

        entry_types = []

        for name, body in functions.items():
            # entry_types.append(name)
            if 'output.bibitem' in body or 'fin.entry' in body:
                entry_types.append(name)
            elif re.match(r'^\w+$', body):
                entry_types.append(name)

        for name, body in functions.items():
            body_words = body.split()
            for entry_type in entry_types:
                if entry_type in body_words:
                    entry_types.append(name)
                    break

        for entry_type in entry_types:
            if entry_type not in self['types']:
                self['types'][entry_type] = {
                    'csl': None,
                    'source': source,
                }

        fields_str = re.search(r'ENTRY\s*\{\s*([^}]+)\s*\}', contents)
        if fields_str:
            for line in fields_str.group(1).splitlines():
                line = line.split('%')[0]
                for field in line.split():
                    field = field.strip()
                    skip_field = False
                    for prefix in self.skip_field_prefixes:
                        if field.startswith(prefix):
                            skip_field = True
                            break
                    if skip_field:
                        continue
                    field = field.lower()
                    if field not in self['fields']:
                        self['fields'][field] = {
                            'csl': None,
                            'source': source,
                        }

        if source == 'bibtex':
            for match in re.finditer(
                    r'MACRO\s*\{\s*(\S+)\s*\}\s*\{\s*"([^"]*)"\s*\}',
                    contents):
                macro = match.group(1)
                value = match.group(2)
                if macro not in self['macros']:
                    self['macros'][macro] = {
                        'value': value,
                        'source': source,
                    }

    def update_all_bst(self):
        paths = glob.glob(
            os.path.join(self.texmf_dist, 'bibtex', 'bst', '**', '*.bst'))
        for file_name in [
                'plainnat.bst',
                'apacite.bst',
                'chicago.bst',
                'IEEEtran.bst',
                'vancouver.bst',
                'amsplain.bst',
                'biblatex.bst',
                'cell.bst',
                'elsarticle-num.bst',
                'apsrev4-2.bst',
                'tugboat.bst',
                'plainurl.bst',
                'gbt7714-numerical.bst',
        ]:
            self.update_bst(file_name)

        for path in sorted(paths):
            try:
                self.update_bst(path)
            except UnicodeDecodeError:
                continue

    def update_biblatex(self):
        if not self.texmf_dist:
            return
        source = 'biblatex'
        biblatex_path = os.path.join(self.texmf_dist, 'tex', 'latex', 'biblatex')
        self.update_biblatex_style(os.path.join(biblatex_path, 'blx-dm.def'), source)
        self.update_biblatex_style(os.path.join(biblatex_path, 'biblatex.def'), source)

    def update_biblatex_style(self, path, source):
        with open(path) as f:
            contents = f.read()

        for match in re.finditer(
                r'\\DeclareDatamodelEntrytypes(\[.*\])?\{(([^}]|\s)*)\}',
                contents):
            for entry_type in match.group(2).split(','):
                entry_type = entry_type.strip()
                if entry_type and entry_type not in self['types']:
                    self['types'][entry_type] = {
                        'csl': None,
                        'source': source,
                    }

        for match in re.finditer(
                r'\\DeclareDatamodelFields(\[(.*)\])?\{(([^}]|\s)*)\}',
                contents):
            field_type = re.search(r'datatype=(\w+)', match.group(2))
            if not field_type:
                continue
            field_type = field_type.group(1)
            for field in match.group(3).split(','):
                field = re.sub(r'[^\n]\r?\n\s*', '', field)
                field = field.strip()
                if field in ['', '#1deleted'] :
                    continue
                if field not in self['fields']:
                    self['fields'][field] = {
                        'csl': None,
                        'source': source,
                    }
                if 'type' not in self['fields'][field]:
                    self['fields'][field]['type'] = field_type

        for match in re.finditer(r'typesource=([a-zA-Z0-9:_+-]+),\s*typetarget=([a-zA-Z0-9:_+-]+)',
                                 contents):
            entry_type = match.group(1)
            target = match.group(2)
            if entry_type not in self['types']:
                self['types'][entry_type] = {
                    'csl': None,
                    'source': source,
                }
            if 'alias' not in self['types'][entry_type]:
                self['types'][entry_type]['alias'] = target

        for match in re.finditer(r'fieldsource=([a-zA-Z0-9:_+-]+),\s*fieldtarget=([a-zA-Z0-9:_+-]+)',
                                 contents):
            field = match.group(1)
            target = match.group(2)
            if field not in self['fields']:
                self['fields'][field] = {
                    'csl': None,
                    'source': source,
                }
            if 'alias' not in self['fields'][field]:
                self['fields'][field]['alias'] = target

    def update_all_biblatex_styles(self):
        paths = glob.glob(
            os.path.join(self.texmf_dist, 'tex', 'latex', '**', '*.dbx'))
        for path in sorted(paths):
            source = os.path.split(path)[1]
            try:
                self.update_biblatex_style(path, source)
            except UnicodeDecodeError:
                continue

    def update_alias_mappings(self):
        for category in ['types', 'fields']:
            for field, value in self[category].items():
                if 'alias' not in value:
                    continue
                alias = self[category][value['alias']]
                if 'csl' in alias:
                    value['csl'] = alias['csl']
                if 'type' in alias:
                    value['type'] = alias['type']

    def check_csl_schema(self):
        # csl_data_path = './schema/csl-data.json'  # v1.0.1
        csl_data_path = 'submodules/schema/schemas/input/csl-data.json'  # v1.0.2+
        if not os.path.exists(csl_data_path):
            warnings.warn(f'Invalid schema path "{csl_data_path}".')
            return
        with open(csl_data_path) as f:
            csl_data = json.load(f)

        # with open('csl-data-v1.1.json') as f:
        #     csl_1_1_data = json.load(f)
        # csl_1_1_fields = csl_1_1_data['definitions']['refitem']['properties'].keys()

        for category in ['types', 'fields']:
            csl_fields = dict()
            if category == 'types':
                csl_fields = csl_data['items']['properties']['type']['enum']
                # Fix a typo
                if csl_fields[8] == 'dateset':
                    csl_fields[8] = 'dataset'
            elif category == 'fields':
                csl_fields = csl_data['items']['properties'].keys()

            csl_mapped_fields = set()

            for field, value in self[category].items():
                if 'csl' not in value:
                    print(f'Empty CSL mapping in "{field}".')
                    continue
                target = value['csl']
                csl_mapped_fields.add(target)

                if target and target not in csl_fields:
                    if category == 'types':
                        print(f'Invalid CSL type "{target}".')
                    # elif category == 'fields':
                    #     print(f'Invalid CSL field "{target}".')

            unmapped_fields = [
                field for field in csl_fields if field not in csl_mapped_fields
            ]
            ignored_fields = [
                'categories',
                'citation-key',
                'citation-label',
                'citation-number',
                'event',
                'first-reference-note-number',
                'id',
                'journalAbbreviation',
                'locator',
                'page-first',
                'printing',
                'shortTitle',
                'type',
                'year-suffix',
            ]

            category_name = 'type'
            if category == 'fields':
                category_name = 'field'

            # Check unmapped CSL fields.
            for field in sorted(unmapped_fields):
                if category == 'types':
                    print(f'CSL type "{field}" not mapped to.')
                elif category == 'fields':
                    if field not in ignored_fields:
                        # print(f'"{field}": {{"csl": "{field}", "source": "csl"}},')
                        print(f'Waring: CSL field "{field}" not mapped to.')

            for field in sorted(csl_fields):
                if field.lower() in self[category]:
                    target = self[category][field.lower()]['csl']
                    if target != field and field not in ignored_fields:
                        print(
                            f'Warning: BibTeX {category_name} "{field}" is mapped to "{target}".'
                        )
                else:
                    # print(field)
                    if field not in ignored_fields:
                        print(
                            f'Waring: CSL {category_name} "{field}" is unavailable in BibTeX.'
                        )
                        # print(
                        #     f'"{field.lower()}": {{"csl": "{field}", "source": "csl"}},'
                        # )

    def check_primary_fields(self):
        csl_field_reverse_map = dict()
        for bibtex_field, info in self['fields'].items():
            csl_field = None
            if 'csl' in info:
                csl_field = info['csl']
            if csl_field:
                if csl_field not in csl_field_reverse_map:
                    csl_field_reverse_map[csl_field] = []
                csl_field_reverse_map[csl_field].append(bibtex_field)

        for csl_field, bibtex_fields in csl_field_reverse_map.items():
            if len(bibtex_fields) > 1:

                has_primary_field = any([field in self['primary_fields'] for field in bibtex_fields])
                if not has_primary_field:
                    print(csl_field, bibtex_fields)
                    for field in bibtex_fields:
                        field_info = self['fields'][field]
                        if 'source' in field_info and field_info['source'] == 'biblatex' and 'alias' not in field_info:
                            self['primary_fields'][field] = csl_field
                            break

                has_primary_field = any([field in self['primary_fields'] for field in bibtex_fields])
                if not has_primary_field:
                    for field in bibtex_fields:
                        field_info = self['fields'][field]
                        if 'source' in field_info and field_info['source'] == 'bibtex' and 'alias' not in field_info:
                            self['primary_fields'][field] = csl_field
                            break

                has_primary_field = any([field in self['primary_fields'] for field in bibtex_fields])
                if not has_primary_field:
                    for field in bibtex_fields:
                        field_info = self['fields'][field]
                        if 'source' in field_info and field_info['source'] == 'csl' and 'alias' not in field_info:
                            self['primary_fields'][field] = csl_field
                            break

                has_primary_field = any([field in self['primary_fields'] for field in bibtex_fields])
                if not has_primary_field:
                    for field in bibtex_fields:
                        if field in csl_field_reverse_map:
                            self['primary_fields'][field] = csl_field
                            break

    def export_lua(self):
        res = "-- This file is generated from citeproc-bibtex-data.json by scripts/update_bibtex_data.py\n\n"
        res += 'return ' + luadata.dumps(self)
        with open('citeproc/citeproc-bibtex-data.lua', 'w') as f:
            f.write(res + '\n')

    def export_markdown(self):
        res = '# BibTeX CSL mapping\n'
        for category in ['types', 'fields']:
            if category == 'types':
                res += '\n\n## Item Types\n'
            elif category == 'fields':
                res += '\n\n## Fields\n'
            res += '\nBib(La)TeX | CSL | Notes\n--- | --- | ---\n'

            for field, contents in self[category].items():
                if contents['source'] not in ['bibtex', 'biblatex']:
                    continue
                if re.match(
                        r'(custom[a-f]|editor[a-c]|editor[a-c]type|name[a-c]|name[a-c]type|list[a-f]|user[a-f]|verb[a-c])',
                        field):
                    continue

                if category == 'types':
                    field = f"`@{field}`"
                else:
                    field = f"`{field}`"
                target = contents['csl']
                if not target:
                    target = '-'
                else:
                    target = f"`{target}`"
                if 'notes' in contents:
                    notes = contents['notes']
                else:
                    notes = ''
                if 'alias' in contents:
                    alias = contents['alias']
                    if category == 'types':
                        alias = '@' + alias
                    notes = f'Alias for `{alias}`. ' + notes
                notes = notes.strip()
                line = f'{field} | {target} | {notes}'.strip() + '\n'
                res += line

        with open('scripts/bib-csl-mapping.md', 'w') as f:
            f.write(res)


if __name__ == '__main__':
    bib_data_path = 'scripts/citeproc-bibtex-data.json'
    bib_data = BibData(bib_data_path)

    bib_data.update_bibtex()

    bib_data.update_biblatex()
    bib_data.update_alias_mappings()

    bib_data.update_all_bst()
    bib_data.update_all_biblatex_styles()

    bib_data.check_csl_schema()
    bib_data.check_primary_fields()

    bib_data.export_lua()
    bib_data.export_markdown()

    with open(bib_data_path, 'w') as f:
        json.dump(bib_data, f, indent=4, ensure_ascii=False, sort_keys=True)
        f.write('\n')
