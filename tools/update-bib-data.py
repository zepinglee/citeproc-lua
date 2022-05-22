from collections import OrderedDict
import json
import re
import os
import glob
from typing import TYPE_CHECKING
import warnings

# References:
# https://github.com/jgm/pandoc/blob/master/src/Text/Pandoc/Citeproc/BibTeX.hs
# https://github.com/andras-simonyi/citeproc-el/wiki/BibLaTeX-CSL-mapping
# https://github.com/brechtm/citeproc-py/blob/master/citeproc/source/bibtex/bibtex.py
# https://github.com/citation-js/bibtex-mappings/blob/main/biblatex/output/types.json


class BibData(OrderedDict):
    def __init__(self, path):
        super().__init__({
            'description': 'Bib CSL mapping',
            'types': dict(),
            'fields': dict(),
            'macros': dict(),
        })

        if os.path.exists(path):
            with open(path) as f:
                self.update(json.load(f))
        else:
            warnings.warn(f'Invalid path "{path}".')

        self.texmf_dist = None
        if not self.texmf_dist:
            paths = glob.glob('/usr/local/texlive/*/texmf-dist')
            if paths:
                self.texmf_dist = sorted(paths)[-1]

        self.skip_field_prefixes = [
            'CTL',
            'abnt-',
            'abnt-',
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
        for match in re.finditer(r'FUNCTION\s*\{\s*(\w+)\s*\}\s*\{\s*([^}]*)\s*\}', contents):
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
                    r'MACRO\s*\{\s*(\S+)\s*\}\s*\{\s*"([^"]*)"\s*\}', contents):
                macro = match.group(1)
                value = match.group(2)
                if macro not in self['macros']:
                    self['macros'][macro] = {
                        'value': value,
                        'source': source,
                    }

    def update_biblatex(self):
        if not self.texmf_dist:
            return
        source = 'biblatex'
        biblatex_path = os.path.join(self.texmf_dist, 'tex', 'latex',
                                     'biblatex')
        with open(os.path.join(biblatex_path, 'blx-dm.def')) as f:
            contents = f.read()

        for match in re.finditer(
                r'\\DeclareDatamodelEntrytypes(\[.*\])?\{(([^}]|\s)*)\}',
                contents):
            for entry_type in match.group(2).split(','):
                entry_type = entry_type.strip()
                if entry_type not in self['types']:
                    self['types'][entry_type] = {
                        'csl': None,
                        'source': source,
                    }

        for match in re.finditer(
                r'\\DeclareDatamodelFields(\[(.*)\])?\{(([^}]|\s)*)\}',
                contents):
            field_type = re.search(r'datatype=(\w+)', match.group(2)).group(1)
            for field in match.group(3).split(','):
                field = field.strip()
                if field not in self['fields']:
                    self['fields'][field] = {
                        'csl': None,
                        'source': source,
                    }
                if 'type' not in self['fields'][field]:
                    self['fields'][field]['type'] = field_type

        with open(os.path.join(biblatex_path, 'biblatex.def')) as f:
            contents = f.read()

        for match in re.finditer(r'typesource=(\w+),\s*typetarget=(\w+)',
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

        for match in re.finditer(r'fieldsource=(\w+),\s*fieldtarget=(\w+)',
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

    def update_all_bst(self):
        paths = glob.glob(os.path.join(self.texmf_dist, 'bibtex', 'bst', '**' , '*.bst'))
        for file_name in ['plainnat.bst', 'apacite.bst', 'chicago.bst',
            'IEEEtran.bst', 'vancouver.bst', 'amsplain.bst', 'biblatex.bst',
            'cell.bst', 'elsarticle-num.bst', 'apsrev4-2.bst', 'tugboat.bst',
            'plainurl.bst', 'gbt7714-numerical.bst',
        ]:
            self.update_bst(file_name)

        for path in sorted(paths):
            try:
                self.update_bst(path)
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
        csl_data_path = './schema/schemas/input/csl-data.json'  # v1.0.2+
        if not os.path.exists(csl_data_path):
            warnings.warn(f'Invalid schema path "{csl_data_path}".')
            return
        with open(csl_data_path) as f:
            csl_data = json.load(f)

        # with open('csl-data-v1.1.json') as f:
        #     csl_1_1_data = json.load(f)
        # csl_1_1_fields = csl_1_1_data['definitions']['refitem']['properties'].keys()

        for category in ['types', 'fields']:
            if category == 'types':
                csl_fields = csl_data['items']['properties']['type']['enum']
                # Fix a typo
                if csl_fields[8] == 'dateset':
                    csl_fields[8] = 'dataset'
            elif category == 'fields':
                csl_fields = csl_data['items']['properties'].keys()

            csl_mapped_fields = dict()
            for field in csl_fields:
                csl_mapped_fields[field] = False

            for field, value in self[category].items():
                if 'csl' not in value:
                    print(f'Empty CSL mapping in "{field}".')
                    continue
                target = value['csl']
                csl_mapped_fields[target] = True

                if target and target not in csl_fields:
                    if category == 'types':
                        print(f'Invalid CSL type "{target}".')
                    # elif category == 'fields':
                    #     print(f'Invalid CSL field "{target}".')

            # # Check unmapped CSL fields.
            # for field, mapped in csl_mapped_fields.items():
            #     if not mapped:
            #         if category == 'types':
            #             print(f'CSL type "{field}" not mapped.')
            #         elif category == 'fields':
            #             print(f'CSL field "{field}" not mapped.')

    def sort_keys(self):
        self['types'] = OrderedDict(sorted(self['types'].items()))
        self['fields'] = OrderedDict(sorted(self['fields'].items()))

        for entry_type, value in self['types'].items():
            self['types'][entry_type] = OrderedDict(sorted(value.items()))
        for field, value in self['fields'].items():
            self['fields'][field] = OrderedDict(sorted(value.items()))

    def export_lua(self):
        res = '-- This file is generated from citeproc-bib-data.json by update-bib-date.py\n\n'

        def to_lua_table(obj, level=0):
            res = ''
            if obj is None:
                res = "nil"
            elif isinstance(obj, str):
                res = '"' + obj.replace('"', '\\"') + '"'
            elif isinstance(obj, dict) or isinstance(obj, OrderedDict):
                res += '{\n'
                for key, value in obj.items():
                    if key == "alias" or key == "notes" or key == "source":
                        continue
                    res += '    ' * (level + 1) + f'["{key}"] = ' + to_lua_table(value, level+1) + ',\n'
                res += '    ' * level + '}'
            else:
                print(obj)
            return res

        res += "return " + to_lua_table(self)
        # print(to_lua_table(self))

        with open('citeproc/citeproc-bib-data.lua', 'w') as f:
            f.write(res)

    def export_markdown(self):
        res = '# Bib CSL mapping\n'
        for category in ['types', 'fields']:
            if category == 'types':
                res += '\n\n## Item Types\n'
            elif category == 'fields':
                res += '\n\n## Fields\n'
            res += '\nBib|CSL|Notes\n-|-|-\n'

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
                line = f'{field}|{target}|{notes}\n'
                res += line

        with open('tools/bib-csl-mapping.md', 'w') as f:
            f.write(res)


if __name__ == '__main__':
    bib_data_path = 'tools/citeproc-bib-data.json'
    bib_data = BibData(bib_data_path)

    bib_data.update_bibtex()

    bib_data.update_biblatex()
    bib_data.update_alias_mappings()

    bib_data.update_all_bst()

    bib_data.check_csl_schema()
    bib_data.sort_keys()
    bib_data.export_lua()
    bib_data.export_markdown()

    with open(bib_data_path, 'w') as f:
        json.dump(bib_data, f, indent=4)
        f.write('\n')
