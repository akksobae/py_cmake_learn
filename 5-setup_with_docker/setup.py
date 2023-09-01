from setuptools import setup, find_packages
from setuptools.command.install import install
import shutil
from pathlib import Path


class CustomInstall(install):
    def run(self):
        # .soファイルを適切な場所にコピーする
        shutil.copyfile(
            Path("src-python", "libmypkg.so"),
            Path(self.install_lib, "libmypkg.so"),
        )
        # 通常のインストール処理を実行する
        install.run(self)


setup(
    name="mypkg",
    version="0.0.1",
    author="Author",
    author_email="author@google.com",
    description="Awesome package.",
    long_description=Path("README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    url="https://github.com/akksobae/py_cmake_learn",
    # カレントディレクトリではなく src-python をパッケージディレクトリに指定する。
    packages=find_packages(where="src-python"),
    package_dir={"": "src-python"},
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: POSIX :: Linux",
    ],
    cmdclass={"install": CustomInstall},
)
