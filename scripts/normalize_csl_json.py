import argparse
import json


def get_item_sort_key(item):
    key = item[0].lower()
    if key == 'id':
        return chr(0x21)
    elif key == 'type':
        return chr(0x22)
    else:
        return key


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+')
    args = parser.parse_args()

    for path in args.files:
        if not path.endswith('.json'):
            raise ValueError(f'Path "{path}" is not a CSL-JSON file.')
        with open(path) as f:
            data = json.load(f)
        data = [
            dict(sorted(entry.items(), key=get_item_sort_key))
            for entry in data
        ]
        with open(path, 'w') as f:
            json.dump(data, f, indent='\t', ensure_ascii=False)
            f.write('\n')


if __name__ == '__main__':
    main()
