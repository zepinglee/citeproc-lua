from copy import deepcopy
import datetime
import json
from pathlib import Path
import re

from lxml import etree


RE_ELEMENT = "(?sm)^(.*>>=[^\n]*{tag}[^\n]+)(.*)(\n<<=.*{tag})"

DEFAULT_STYLE = """\
<style
      xmlns="http://purl.org/net/xbiblio/csl"
      class="note"
      version="1.0">
  <info>
    <id />
    <title />
    <updated>{updated}</updated>
  </info>
  <citation>
    <layout>
      <text variable="title"/>
    </layout>
  </citation>
</style>
"""

DEFAULT_ITEMS = [{"id": "ITEM-1", "type": "book", "title": "Foo"}]


def remove_bom(s: str) -> str:
    if s.startswith("\ufeff"):
        s = s[1:]
    return s


def fixEndings(s):
    s = s.replace("\r\n", "\n")
    s = s.replace("\r", "\n")
    return s


class CslTest:
    def __init__(self, style=None, data=None):
        self.data = {
            "MODE": "citation",
            "DESCRIPTION": "",
            "OPTIONS": None,
            "RESULT": "",
            "CITATIONS": [],
            "CITATION-ITEMS": [],
            "BIBENTRIES": None,
            "BIBSECTION": None,
            "ABBREVIATIONS": None,
            "CSL": None,
            "INPUT": [],
            "TAGS": None,
            "VERSION": "1.0",
        }

        self.is_json = {
            "MODE": False,
            "DESCRIPTION": False,
            "OPTIONS": True,
            "RESULT": False,
            "CITATIONS": True,
            "CITATION-ITEMS": True,
            "BIBENTRIES": True,
            "BIBSECTION": True,
            "ABBREVIATIONS": True,
            "CSL": False,
            "INPUT": True,
            "TAGS": False,
            "VERSION": False,
        }

        self.raw_csl = ""
        if not style:
            now = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
            style = DEFAULT_STYLE.format(updated=now)
        if isinstance(style, etree._ElementTree):
            self.data["CSL"] = style
            self.raw_csl = etree.tostring(style, encoding="unicode", pretty_print=True)
        elif isinstance(style, bytes):
            self.data["CSL"] = etree.fromstring(style)
            self.raw_csl = style.decode()
        elif isinstance(style, str):
            self.data["CSL"] = etree.fromstring(style.encode())
            self.raw_csl = style
        elif isinstance(style, Path):
            self.data["CSL"] = etree.parse(str(style))
            self.raw_csl = style.read_text()

        if not data:
            data = deepcopy(DEFAULT_ITEMS)
        self.data["INPUT"] = data
        self.make_citations()

    @staticmethod
    def from_string(s):
        test = CslTest()
        test._parse(s)
        return test

    @staticmethod
    def from_path(path):
        return CslTest.from_string(remove_bom(Path(path).read_text()))

    def make_citations(self):
        if not self.data["CITATIONS"]:
            self.data["CITATIONS"] = self._make_citations(self.data["INPUT"])
        if not self.data["CITATION-ITEMS"]:
            self.data["CITATION-ITEMS"] = [
                [{"id": item["id"]}] for item in self.data["INPUT"]
            ]

    def dumps(self) -> str:
        res = ""
        for tag, data in self.data.items():
            text = data
            if tag == "CSL":
                if data is not None:
                    text = self._dump_csl_style(data)
                else:
                    text = ""
            elif self.is_json[tag] and data:
                text = json.dumps(self.data[tag], ensure_ascii=False, indent=4)
            if text is not None:
                res += f"\n\n>>===== {tag} =====>>\n{text.rstrip()}\n<<===== {tag} =====<<\n"
        res = res.lstrip()
        return res

    def _make_citations(self, data):
        citations_pre = []
        citations_post = []
        citations = []
        for i, item in enumerate(data):
            citation_id = f"CITATION-{i+1}"
            note_index = 0
            if 'class="note"' in self.raw_csl:
                note_index = i + 1
            citation = {
                "citationID": citation_id,
                "citationItems": [{"id": item["id"]}],
                "properties": {"noteIndex": note_index},
            }
            citations.append([citation, citations_pre, citations_post])
            citations_pre = citations_pre + [[citation_id, i]]
        return citations

    def _parse(self, raw):
        for element in self.data.keys():
            self._extract(element, raw)

    def _extract(self, tag, raw):
        matched = re.match(RE_ELEMENT.format(tag=tag), raw)
        if matched:
            data = matched.group(2).strip()
            if tag == "CSL":
                self.raw_csl = data
                data = etree.fromstring(data.encode())
            elif self.is_json[tag]:
                data = json.loads(data)
            self.data[tag] = data

    def _dump_csl_style(self, style):
        text = etree.tostring(style, pretty_print=True, encoding="unicode")
        if '<?xml version="1.0"' in self.raw_csl:
            text = '<?xml version="1.0" encoding="utf-8"?>\n' + text
        text = text.replace(" ", "&#160;")  # no-break space
        text = text.replace(" ", "&#8195;")  # em space
        text = text.replace("ᵉ", "&#7497;")
        text = text.replace("‑", "&#8209;")  # non-breaking hyphen
        # style_str = style_str.replace("–", "&#8211;")  # en dash
        text = text.replace("&#8211;", "–")  # en dash
        text = text.replace("—", "&#8212;")  # em dash

        if re.search(r"<style\s*\n\s+xmlns", self.raw_csl):
            text = text.replace(" xmlns=", "\n      xmlns=")
            text = text.replace(" class=", "\n      class=")
            text = text.replace(" version=", "\n      version=")
            text = text.replace(" default-locale=", "\n      default-locale=")
        if "<id />" in self.raw_csl:
            text = text.replace("<id/>", "<id />")
            text = text.replace("<title/>", "<title />")

        return text
