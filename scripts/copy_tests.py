from pathlib import Path
import shutil


test_dir = Path("./tests/latex")
luatex1_dir = test_dir.joinpath("luatex-1")

for file in luatex1_dir.glob("*.lvt"):
    for config in ["luatex-2", "pdftex-1", "pdftex-2"]:
        shutil.copy(file, test_dir.joinpath(config).joinpath(file.name))

for config in ["luatex-2", "pdftex-1", "pdftex-2"]:
    for file in test_dir.joinpath(config).glob("*.lvt"):
        if not luatex1_dir.joinpath(file.name).exists():
            print(print(file))
