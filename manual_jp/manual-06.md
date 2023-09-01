<style>
    div.title{
        text-align: center; line-height: 120%;
        font-size: xx-large; font-weight: bold; 
        padding-bottom: 0.3em; margin-bottom:1em;
        border-bottom-width: 4px; border-bottom-style: double;
    }
</style>
<div class="title">
[マニュアル（６）pyproject.toml の整備](LINK)
</div>

- [1. 調査](#1-調査)
- [2. ディレクトリ構成](#2-ディレクトリ構成)
- [3. パッケージインストール](#3-パッケージインストール)
- [4. test 工程](#4-test-工程)
- [5. setup.py を用いたパッケージング・インストール](#5-setuppy-を用いたパッケージングインストール)
- [6. test 実行](#6-test-実行)
- [7. まとめ](#7-まとめ)


<!-- omit in toc -->
Introduction
============

さて、それでは、 CMake と Python/C Wrapper の両方を学んだところで、
CMake で Python/C Wrapper コードをビルドしていこう。

# 1. 調査



# 2. ディレクトリ構成

```
6-pyproject_toml_with_cmake
├── CMakeLists.txt
├── LICENSE
├── MANIFEST.in
├── README.md
├── build.bash
├── docker
│   ├── docker-compose.yml
│   ├── mypkg_base
│   │   └── Dockerfile
│   ├── mypkg_install
│   │   └── Dockerfile
│   └── mypkg_run
│       ├── Dockerfile
│       └── test.bash
├── pyproject.toml
├── setup.cfg
├── setup.py
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
│   ├── CMakeLists.txt
│   └── mypkg
│       ├── __init__.py
│       └── core.py
├── tests
│   ├── CMakeLists.txt
│   ├── cmake_support.bash
│   ├── run_test.base.c
│   ├── run_test.base.h
│   ├── test_mypkg.c
│   └── test_mypkg.py
└── util.bash
```

# 3. パッケージインストール


```bash
$ pip3 install --upgrade build
$ pip install virtualenv
```

# 4. test 工程




# 5. setup.py を用いたパッケージング・インストール



# 6. test 実行



# 7. まとめ

