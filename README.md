# py_cmake_learn

Python パッケージから、
cmake でコンパイルされたパッケージを導入しつつ、
pip install できるようなパッケージとしてパッケージングしたい。
そのための方法について、段階的に調査・実装・試験を行う。

実行環境は wsl (Ubuntu 20.04) 環境。

以下の仕様を満たす C 言語ライブラリ mypkg を cmake で作ろう。

* `int message(int res)` のシグネチャを保つ関数で、 "Hello world!" と表示できる。
* Python から `import mypkg` とするとこの関数を呼び出せる。
* 各コンパイル段階でテストできる。

以下のリンクから、各マニュアルに飛べる。

* [1. C language project 実装](./manual_jp/manual-01.md)
* [2. CMake 実装](./manual_jp/manual-02.md)
* [3. CMake を用いた Python 実装](./manual_jp/manual-03.md)
* [4. Python/C Wrapper の CMake 化](./manual_jp/manual-04.md)
* [5. Docker と setup.py の整備](./manual_jp/manual-05.md)
* [6. pyproject.toml の整備](./manual_jp/manual-06.md)


# py_cmake_learn (ENG version)

I would like to crate a Python package 
that uses C-lang library compiled by CMake.
In addition, I would like to package it 
so that the package can be installed via pip.
I will investigate, implement, and test how to achieve this goal step by step.

The execution environment is wsl (Ubuntu 20.04).

Let's create a C-lang library `mypkg` with CMake that meets the following specifications:

* Using a function `int message(int res)`, you can print "Hello world!"
* You can call this function by `import mypkg` in Python.
* You can test it at each compilation stage.

You can jump to each manual from the following links (written in Japanese):

* [1. C language project Implementation](./manual_jp/manual-01.md)
* [2. CMake Implementation](./manual_jp/manual-02.md)
* [3. Python Implementation with CMake](./manual_jp/manual-03.md)
* [4. CMake Implementation of Python/C Wrapper](./manual_jp/manual-04.md)
* [5. Create Docker environment and setup.py](./manual_jp/manual-05.md)
* [6. Create pyproject.toml](./manual_jp/manual-06.md)
