import glob
import os

for path in glob.glob(os.path.join('tests', 'latex', '**', 'bib-resource-*')):
    dir, file = os.path.split(path)
    file = file.replace('bib-resource-', 'data-')
    new_path = os.path.join(dir, file)
    os.rename(path, new_path)
