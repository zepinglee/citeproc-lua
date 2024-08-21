import argparse

from csltest import CslTest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('files', nargs='+')
    args = parser.parse_args()

    for path in args.files:
        print(path)
        fixture = CslTest(path)
        # print(fixture.data)
        with open(path, 'w') as f:
            f.write(fixture.dumps())


if __name__ == '__main__':
    main()
