import argparse
import json
from pathlib import Path

from csl_test import CslTest


def make_csl_test(style_path, data_path):
    style = None
    if style_path:
        style = Path(style_path).read_bytes()

    data = None
    if data_path:
        data = json.loads(Path(data_path).read_text())

    return CslTest(style=style, data=data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-v", "--verbose", action="store_true")
    parser.add_argument("-s", "--style", type=Path)
    parser.add_argument("-d", "--data", type=Path)
    parser.add_argument("-c", "--cites", action="store_true")
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    output = Path(args.output)
    if output.exists():
        test = CslTest.from_path(output)
        if args.data:
            test.data["INPUT"] = json.loads(Path(args.data).read_text())
        if args.cites:
            test.make_citations()
        output.write_text(test.dumps())
    else:
        test = make_csl_test(args.style, args.data)
        output.write_text(test.dumps())


if __name__ == "__main__":
    main()
