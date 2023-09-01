from setuptools import setup, find_packages
from setuptools.command.install import install
import shutil
from pathlib import Path

setup(
    packages=["mypkg"],
    package_data={"mypkg": ["libmypkg.so"]},
    package_dir={"": "src-python"},
)
