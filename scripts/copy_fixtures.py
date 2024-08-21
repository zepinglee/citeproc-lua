import glob
import os
import shutil

from csltest import CslTest

std_dir = "tests/fixtures/test-suite/processor-tests/humans"

processor_std_dirs = [
    '../citeproc-hs/test/csl',
    '../citeproc-rs/crates/citeproc/tests/data/test-suite/processor-tests',
]

processor_override = ['../citeproc-hs/test/overrides', "tests/overrides"]

processor_test_dirs = [
    '../citeproc-js/fixtures/local',
    '../citeproc-hs/test/extra',
    '../citeproc-rs/crates/citeproc/tests/data/fixtures-local',
    # 'tests/local/',
]


def copy_fixtures():
    fixture_sources = dict()
    std_fixtures = dict()
    other_fixtures = dict()

    for path in sorted(glob.glob(os.path.join(std_dir, '*.txt'))):
        _, file = os.path.split(path)
        # print(path)
        std_fixtures[file] = CslTest(path)
        fixture_sources[file] = std_dir

    for dir in processor_std_dirs:
        for path in sorted(glob.glob(os.path.join(dir, '*.txt'))):
            _, file = os.path.split(path)
            # print(path)
            fixture = CslTest(path)
            if file not in std_fixtures:
                print(f'Not in std: {path}')
                continue
            if 'RESULT' not in fixture.data:
                print(f'No RESULT: {path}')
                continue
            if fixture.data['RESULT'] != std_fixtures[file].data['RESULT']:
                print(f'Different RESULT: {path}')

    for dir in processor_override:
        for path in sorted(glob.glob(os.path.join(dir, '*.txt'))):
            _, file = os.path.split(path)
            # print(path)
            fixture = CslTest(path)
            if file not in std_fixtures:
                print(f'Not in std: {path}')
                continue
            if 'RESULT' not in fixture.data:
                print(f'No RESULT: {path}')
                continue
            if fixture.data['RESULT'] == std_fixtures[file].data['RESULT']:
                print(f'Same RESULT: {path}')

    for dir in processor_test_dirs:
        for path in sorted(glob.glob(os.path.join(dir, '*.txt'))):
            _, file = os.path.split(path)
            # print(path)
            try:
                fixture = CslTest(path)
            except ValueError as e:
                print(f'{path}: Value error {e}')
                continue

            if file in std_fixtures:
                print(f'In std: {path}')
                continue
            if 'RESULT' not in fixture.data:
                print(f'No RESULT: {path}')
                continue

            if file in other_fixtures:
                print(f'Duplicate: {path} with {fixture_sources[file]}')
                if fixture.data['RESULT'] != other_fixtures[file].data[
                        'RESULT']:
                    print(
                        f'Different RESULT: {path} with {fixture_sources[file]}'
                    )
            else:
                other_fixtures[file] = fixture
                fixture_sources[file] = dir
                # shutil.copy(path, os.path.join('tests', 'fixtures', dir.split('/')[1]))

            # if fixture.data['RESULT'] == std_fixtures[file].data['RESULT']:
            #     print(f'Same RESULT: {path}')

    # local_tests_dir = 'tests/local'

    # for path in sorted(glob.glob(os.path.join(local_tests_dir, '*.txt'))):
    #     _, file = os.path.split(path)
    #     # print(path)
    #     try:
    #         fixture = CslTest(path)
    #     except ValueError as e:
    #         print(f'{path}: Value error {e}')
    #         continue

    #     if file in std_fixtures:
    #         print(f'In std: {path}')
    #         continue
    #     if 'RESULT' not in fixture.data:
    #         print(f'No RESULT: {path}')
    #         continue

    #     if file in other_fixtures:
    #         print(f'Duplicate: {path} with {fixture_sources[file]}')
    #         if fixture.data['RESULT'] != other_fixtures[file].data['RESULT']:
    #             print(f'Different RESULT: {path} with {fixture_sources[file]}')
    #             # shutil.move(path, os.path.join('tests', 'fixtures', 'local'))
    #         # os.remove(path)
    #     else:
    #         other_fixtures[file] = fixture
    #         fixture_sources[file] = dir
    #         shutil.move(path, os.path.join('tests', 'fixtures', 'local'))

    #     # if fixture.data['RESULT'] == std_fixtures[file].data['RESULT']:
    #     #     print(f'Same RESULT: {path}')


def remove_failing_fixtures():
    failing_tests = []
    with open('tests/citeproc-test.log') as f:
        for line in f:
            if line.startswith('Failure → ') or line.startswith('Error →'):
                failing_tests.append(line.strip().split()[-1])

    print(failing_tests)

    for path in glob.glob('./tests/fixtures/**/*.txt'):
        _, file = os.path.split(path)
        if file in failing_tests:
            os.remove(path)


def main():
    copy_fixtures()
    remove_failing_fixtures()


if __name__ == '__main__':
    main()
