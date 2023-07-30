import json
import re

from lxml import etree

xml_parser = etree.XMLParser(remove_blank_text=True)


def remove_bom(s: str) -> str:
    if s.startswith('\ufeff'):
        s = s[1:]
    return s


def fixEndings(s):
    s = s.replace('\r\n', '\n')
    s = s.replace('\r', '\n')
    return s


class CslTest:

    def __init__(self, path):
        self.path = path
        self.RE_ELEMENT = '(?sm)^(.*>>=[^\n]*%s[^\n]+)(.*)(\n<<=.*%s.*)'
        self.data = dict()
        self.raw_data = dict()

        with open(path) as f:
            self.raw = fixEndings(remove_bom(f.read()))

        self.is_json = {
            "MODE": False,
            "OPTIONS": True,
            "CSL": False,
            "VERSION": False,
            "TAGS": False,
            "RESULT": False,
            "INPUT": True,
            "CITATION-ITEMS": True,
            "CITATIONS": True,
            "BIBENTRIES": True,
            "BIBSECTION": True,
            "ABBREVIATIONS": True,
            "DESCRIPTION": False,
        }
        self.parse()

    def parse(self):
        descriptions = []
        part_lines = []
        part_name = None
        for line in self.raw.splitlines():
            # print(line.__repr__())
            matched = re.match(r'>>=+\s*([A-Za-z0-9-]+)\s*=+>>', line)
            if matched:
                part_name = matched.group(1)
                # print(part_name)
                if part_lines:
                    part = '\n'.join(part_lines).strip()
                    if part:
                        descriptions.append(part)
                    part_lines = []
            else:
                matched = re.match(r'<<=+\s*([A-Za-z0-9-]+)\s*=+<<', line)
                if matched:
                    assert part_name
                    self.raw_data[part_name] = '\n'.join(part_lines)
                    if part_name not in self.is_json:
                        raise ValueError(part_name)

                    if self.is_json[part_name]:
                        self.data[part_name] = json.loads(
                            self.raw_data[part_name])
                    elif part_name == 'CSL':
                        try:
                            self.data['CSL'] = etree.fromstring(
                                self.raw_data[part_name].strip().encode(
                                    'utf-8'),
                                parser=xml_parser)
                        except Exception as e:
                            print(f'{self.path}: XML parsing error: {e}')
                            # print(self.raw_data[part_name])
                    else:
                        self.data[part_name] = self.raw_data[part_name]

                    part_name = None
                    part_lines = []
                else:
                    part_lines.append(line.rstrip())

        if descriptions:
            if 'DESCRIPTION' in self.data:
                self.data['DESCRIPTION'] += '\n\n' + '\n\n'.join(descriptions)
            else:
                self.data['DESCRIPTION'] = '\n\n'.join(descriptions)

        if 'DESCRIPTION' in self.data:
            self.data['DESCRIPTION'] = re.sub(r'([^<])(https?://\S*)',
                                              r'\1<\2>',
                                              self.data['DESCRIPTION'])
            self.data['DESCRIPTION'] = re.sub(r'^(https?://\S*)', r'<\1>',
                                              self.data['DESCRIPTION'])

        if 'VERSION' not in self.data:
            self.data['VERSION'] = '1.0'

    def dumps(self) -> str:
        text = ''
        for tag in [
                'MODE', 'OPTIONS', 'DESCRIPTION', 'RESULT', 'CITATIONS',
                'CITATION-ITEMS', 'BIBENTRIES', 'BIBSECTION', 'ABBREVIATIONS',
                'CSL', 'INPUT', 'TAGS', 'VERSION'
        ]:
            if tag in self.data:
                text += f'\n\n>>===== {tag} =====>>\n'
                if self.is_json[tag]:
                    text += json.dumps(self.data[tag],
                                       ensure_ascii=False,
                                       indent=4)
                elif tag == 'CSL':
                    xml_str = etree.tostring(
                        self.data['CSL'], pretty_print=True,
                        encoding='utf-8').decode().strip()
                    if '<?xml version="1.0"' in self.raw_data['CSL']:
                        xml_str = '<?xml version="1.0" encoding="utf-8"?>\n' + xml_str
                    if re.search(r'<style\s*\n\s+xmlns', self.raw_data['CSL']):
                        xml_str = xml_str.replace(' xmlns=', '\n      xmlns=')
                        xml_str = xml_str.replace(' class=', '\n      class=')
                        xml_str = xml_str.replace(' version=',
                                                  '\n      version=')
                        xml_str = xml_str.replace(' default-locale=',
                                                  '\n      default-locale=')
                    if '<id />' in self.raw_data['CSL']:
                        xml_str = xml_str.replace('<id/>', '<id />')
                        xml_str = xml_str.replace('<title/>', '<title />')
                    text += xml_str
                else:
                    text += self.data[tag]
                text += f'\n<<===== {tag} =====<<\n'
        text = text.lstrip()
        return text
