<!-- omit in toc -->
マニュアル（６）pyproject.toml の整備
============================================================

- [1. 調査](#1-調査)
- [2. ディレクトリ構成](#2-ディレクトリ構成)
- [3. パッケージインストール](#3-パッケージインストール)
- [4. test 工程](#4-test-工程)
- [5. pyproject.toml を用いたパッケージング・インストール](#5-pyprojecttoml-を用いたパッケージングインストール)
- [6. test 実行](#6-test-実行)
- [7. まとめ](#7-まとめ)


<!-- omit in toc -->
Introduction
============

setup.py は従来は主流の方法だったが、今では deprecated と怒られるようになってしまった。
現在は pyproject.toml への以降が勧められている。
ここではその対応を行って、最終章としよう。

# 1. 調査

* ieiringoo, [2022年版pyproject.tomlを使ったPythonパッケージの作り方](https://qiita.com/ieiringoo/items/4bef4fc9975803b08671) -- Qiita, 2022/06
* Python Software Foundation, [setup スクリプトを書く](https://docs.python.org/ja/3/distutils/setupscript.html) -- Python Documentation, 2023/09

# 2. ディレクトリ構成

```
6-pyproject_toml_with_cmake
├── CMakeLists.txt
├── LICENSE
├── README.md
├── build.bash
├── util.bash
├── pyproject.toml (*)
├── setup.cfg (*)
├── setup.py (*)
├── docker
│   ├── docker-compose.yml
│   ├── mypkg_base
│   │   └── Dockerfile
│   ├── mypkg_install
│   │   └── Dockerfile
│   └── mypkg_run
│       ├── Dockerfile
│       └── test.bash
├── src
│   ├── myapp
│   │   ├── CMakeLists.txt
│   │   └── main.c
│   ├── mypkg
│   │   ├── CMakeLists.txt
│   │   ├── include
│   │   │   └── mypkg.h
│   │   └── mypkg.c
│   └── mypkg_wrap
│       ├── CMakeLists.txt
│       ├── include
│       │   └── mypkg_wrap.h
│       └── mypkg_wrap.c
├── src-python
│   └── mypkg
│       ├── __init__.py
│       ├── CMakeLists.txt
│       └── core.py
└── tests
    ├── CMakeLists.txt
    ├── cmake_support.bash
    ├── run_test.base.c
    ├── run_test.base.h
    ├── test_mypkg.c
    └── test_mypkg.py
```

# 3. パッケージインストール


```bash
$ pip3 install --upgrade build
$ pip install virtualenv
```

# 4. test 工程

基本的には、テスト構成は 5章の Docker 環境を引き継ぐ。
変わるのは make install で実行される中身だけのはずだ。

ただ、 install/uninstall がやりやすくなったため、
アンインストールもテストできるように mypkg_run コンテナ用の test.bash の内容を変えておこう。

```bash
#!/usr/bin/env bash

set -ex

make test
(
    cd /
    python3 -c "import mypkg"
)

pytest

make uninstall

(
    cd /
    if python3 -c "import mypkg"; then
        echo "Uninstallation failed."
        exit 1
    else
        echo "Uninstallation succeeded."
        exit 0
    fi
)
```

# 5. pyproject.toml を用いたパッケージング・インストール

pyproject.toml と cmake を調査すると、
パッと見では scikit-build というのがお勧めらしいと出るのだが、
ドキュメントが十分に出回っていないように思われた。
同じく、「pyproject.toml だけで完結できるよ！」という記事も散見されるが、
調査した範囲ではうまくいかなかった。
setup.py **だけ** を使う方法は deprecated かもしれないが、
pyproject.toml だけを使う方法もまた未成熟であるようで、
現状(2023年8月)は両方を上手く使い分けるのがいいようだ。

また、 setup.py の設定値は、
setup.cfg に書く方が良いらしい。
実際、 ini 風の設定ファイルになっていて、こちらの方が書きやすい。

ほとんど setup.py をファイルに分けて書き直すだけになるため、
書き換えた結果を先に示そう。

* **pyproject.toml**

```toml
[build-system]
requires = ["setuptools", "wheel"]
build-backend = "setuptools.build_meta"
```

* **setup.py**

```py
from setuptools import setup

setup(
    packages=["mypkg"],
    package_data={"mypkg": ["libmypkg.so"]},
    package_dir={"": "src-python"},
)
```

* **setup.cfg**

```conf
[metadata]
name = mypkg
version = 0.0.1
description = Awesome package.
url = https://github.com
long_description = file: README.md
long_description_content_type = text/markdown
license = BSD License 2.0
license_files = LICENSE
author = Author
author_email = example@example.com
classifiers =
programming language :: Python :: 3
operating system :: Linux OS

[options]
install_requires =
```

コンセプトとしては、 deprecated な setpu.py と、
未成熟な pyproject.toml の内容は最低限になるようにしている。
いや、 cmake と組み合わせるということをしなければ pyproject.toml だけでも問題ないと思うのだが、
pyproject.toml だけでは、 .so ファイルを成果ファイルに含める工程がどうしても上手くいかなかった。

pyproject.toml では、使用するコンパイルツールとバックエンドを指定する。
バックエンドというのはあまり理解できていないが、
要は setuptools.build_meta で指定したものが、
pyproject.toml の内容を解釈してビルド・インストールをしてくれる機能を提供してくれるようだ。

次に、 setup.py については、ここからどうしても分離できなかった機能が残っている。
パッケージ名とディレクトリを指定してやれば、
`package_data` から、成果物ディレクトリに追加するファイルを指定できる
(尚、 `setup.py install` を使う方法では上手くいってくれなかった)。

残りのコンフィグについては、 setup.cfg に移されている。
一部独特の書き方をされている部分もあるが、基本的にはわかりやすくなっている。

# 6. test 実行

ここも5章とほぼ変わりないので省略する。

# 7. まとめ

構想から実現まで時間がかかった(主に pyproject.toml のせい)が、
pyproject.toml を使って C言語/CMake を含む Python パッケージを
ビルド・インストールする一連の方法を書けたと思う。