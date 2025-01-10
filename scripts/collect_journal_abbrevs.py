import csv
import glob
import json
import os
import re
from collections import Counter, OrderedDict

import luadata

# https://github.com/retorquere/bibtex-parser
# https://github.com/citation-style-language/abbreviations
# https://github.com/JabRef/abbrv.jabref.org
# https://marcinwrochna.github.io/abbrevIso/


def accept(full, abbr):
    if not full or not abbr:
        return False

    if '"' in full:
        return False

    if "..." in full or "..." in abbr:
        return False

    #  ISSN: 0066-197X;ESSN:
    if full.startswith("ISSN:"):
        return False

    if abbr.startswith("#") and abbr.endswith("#"):
        return False

    # 1992 Ama Educators Proceedings, Vol 3;Ama Educ Pr;;
    # if re.search(r'^\d{4}\b', full) or re.search(r'\b\d{4}$', full):
    #     return False

    # if re.search(r'^proceedings\b', full, flags=re.I):
    #     return False
    # if re.search(r'\bproceedings$', full, flags=re.I):
    #     return False

    return True

def clean(str):
    str = str.strip()
    # TeX ligatures
    str = str.replace("---", "—")
    str = str.replace("--", "–")
    str = str.replace("``", "“")
    str = str.replace("''", "”")
    str = str.replace("`", "‘")
    str = str.replace("'", "’")
    # Acoustical Physics;Acoust. Phys+.+;;
    str = re.sub(r"\+\.\+$", "", str)
    # 15th International Conference On Pattern Recognition, Vol 1, Proceedings;Int C Patt Recog;;
    # str = re.sub(r'^\d+(st|nd|rd|th)\s+', '', str)
    # Acta Stereologica, Vol 10, No 1;Acta Stereol.;;
    str = re.sub(r",?\s+no\.?\s+\d+$", "", str, flags=re.I)
    # str = re.sub(r',?\s+proceedings$', '', str, flags=re.I)
    str = re.sub(r",?\s+vol\.?\s+(\d+|[ivxl]+)$", "", str, flags=re.I)
    str = re.sub(r",?\s+vols\.?\s+\d+(-|\s+and\s+)\d+$", "", str, flags=re.I)
    # Ieee International Conf On Consumer Electronics;Ieee Icce;;
    str = re.sub(r"\bIeee\b", "IEEE", str)
    # Acm Computing Surveys;Acm Comput. Surv.;;
    str = re.sub(r"\bAcm\b", "ACM", str)

    return str


def update_journal_abbrev_pair(abbrevs, unabbrevs, full, abbr, file):
    if not accept(full, abbr):
        return

    full_key = full.upper()
    if full_key not in abbrevs:
        abbrevs[full_key] = {
            "values": [],
            "files": [],
        }
    abbrevs[full_key]["values"].append(abbr)
    abbrevs[full_key]["files"].append(file)

    abbr_key = abbr.upper().replace(".", "")
    if abbr_key not in unabbrevs:
        unabbrevs[abbr_key] = {
            "values": [],
            "files": [],
        }
    unabbrevs[abbr_key]["values"].append(full)
    unabbrevs[abbr_key]["files"].append(file)


def update_from_retorquere_fixups(abbrevs, unabbrevs):
    # https://github.com/retorquere/bibtex-parser/blob/master/build/abbr.py
    file = "journal-abbrev-retorquere-fixups.json"
    with open("scripts/journal-abbrev-retorquere-fixups.json") as f:
        data = json.load(f)
    for abbr, full in data.items():
        abbr = abbr.title()
        update_journal_abbrev_pair(abbrevs, unabbrevs, full, abbr, file)


def update_from_csl_abbrevs(abbrevs, unabbrevs):
    csl_abbrev_dir = "submodules/abbreviations"
    paths = sorted(
        glob.glob(
            os.path.join(csl_abbrev_dir, "**", "*-abbreviations.json"), recursive=True
        )
    )
    for path in paths:
        file = os.path.split(path)[1]
        with open(path) as f:
            data = json.load(f)

        for full, abbr in data["default"]["container-title"].items():
            update_journal_abbrev_pair(abbrevs, unabbrevs, full, abbr, file)


def update_from_jabref_abbrv(abbrevs, unabbrevs):
    jabref_abbrv_dir = "submodules/jabref-abbrv/journals"

    # jabref_abbrv_high_priority = ['journal_abbreviations_webofscience-dotless.csv']
    jabref_abbrv_low_priority = [
        "journal_abbreviations_lifescience.csv",
        # Dotless
        "journal_abbreviations_medicus.csv",
        # Dotless
        "journal_abbreviations_entrez.csv",
    ]
    jabref_abbrv_exclude = ["journal_abbreviations_webofscience-dotless.csv"]

    files = [file for file in os.listdir(jabref_abbrv_dir) if file.endswith(".csv")]
    files = [file for file in files if file not in jabref_abbrv_exclude and file not in jabref_abbrv_low_priority]
    # files = sorted(files)
    files = list(files) + jabref_abbrv_low_priority

    for file in files:
        path = os.path.join(jabref_abbrv_dir, file)
        with open(path) as f:
            journals = csv.reader(f)
            for journal in journals:
                if len(journal) < 1:
                    continue
                full = clean(journal[0])
                abbr = full
                if len(journal) >= 2:
                    abbr = clean(journal[1])
                else:
                    raise ValueError(full)

                update_journal_abbrev_pair(abbrevs, unabbrevs, full, abbr, file)


def output_results(conflicts, abbrevs, unabbrevs):
    with open("j-abbr-conflicts.txt", "w") as f:
        f.writelines([line + "\n" for line in conflicts])
    with open("j-abbr-abbrevs.json", "w") as f:
        json.dump(abbrevs, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    with open("j-abbr-unabbrevs.json", "w") as f:
        json.dump(unabbrevs, f, indent="\t", ensure_ascii=False)
        f.write("\n")


def main():
    abbrevs = dict()
    unabbrevs = dict()

    conflicts = []
    conflict_file_counter = Counter()

    update_from_retorquere_fixups(abbrevs, unabbrevs)
    update_from_csl_abbrevs(abbrevs, unabbrevs)
    update_from_jabref_abbrv(abbrevs, unabbrevs)

    for full, abbr_dict in abbrevs.items():
        value_counter = Counter(abbr_dict["values"])
        num_unique_values = len(value_counter)
        if num_unique_values > 1:
            conflicts.append(f"{full.lower()}: {num_unique_values}")
            conflict_file_counter.update(abbr_dict["files"])
        abbrevs[full] = value_counter.most_common(1)[0][0]

    for abbr, full_dict in unabbrevs.items():
        value_counter = Counter(full_dict["values"])
        num_unique_values = len(value_counter)
        if num_unique_values > 1:
            conflicts.append(f"{abbr.lower()}: {num_unique_values}")
            conflict_file_counter.update(full_dict["files"])
        unabbrevs[abbr] = value_counter.most_common(1)[0][0]

    for file, count in sorted(dict(conflict_file_counter).items(), key=lambda x: x[1], reverse=True):
        print(f"{file:56}{count}")
    conflicts = sorted(conflicts)
    print(f"Conflicts: {len(conflicts)}")

    abbrevs = OrderedDict(sorted(abbrevs.items()))
    unabbrevs = OrderedDict(sorted(unabbrevs.items()))
    print(f"abbrevs: {len(abbrevs)}")
    print(f"unabbrevs: {len(unabbrevs)}")

    # output_results(conflicts, abbrevs, unabbrevs)

    with open("citeproc/citeproc-journal-data.lua", "w") as f:
        f.write("---@diagnostic disable\n")
        f.write("abbrevs = ")
        luadata.dump(abbrevs, f)
        f.write("\n\nunabbrevs = ")
        luadata.dump(unabbrevs, f)
        f.write("\n\nreturn {\n  abbrevs = abbrevs,\n  unabbrevs = unabbrevs,\n}\n")



if __name__ == "__main__":
    main()
