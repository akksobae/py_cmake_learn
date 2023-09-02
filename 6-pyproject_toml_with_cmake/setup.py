from setuptools import setup

setup(
    packages=["mypkg"],
    package_data={"mypkg": ["libmypkg.so"]},
    package_dir={"": "src-python"},
)
