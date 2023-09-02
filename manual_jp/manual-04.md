<!-- omit in toc -->
マニュアル（４）Python/C Wrapper の CMake 化
============================================================

- [1. 調査](#1-調査)
- [2. ディレクトリ構成](#2-ディレクトリ構成)
- [3. test 工程](#3-test-工程)
- [4. CMake for Python/C Wrapper](#4-cmake-for-pythonc-wrapper)
  - [4.1. 今までの再利用と復習](#41-今までの再利用と復習)
  - [4.2. find\_package(Python ...)](#42-find_packagepython-)
  - [4.3. Python モジュール mypkg 用整備](#43-python-モジュール-mypkg-用整備)
- [5. build 工程](#5-build-工程)
- [6. test 実行](#6-test-実行)
- [7. まとめ](#7-まとめ)


<!-- omit in toc -->
Introduction
============

さて、それでは、 CMake と Python/C Wrapper の両方を学んだところで、
CMake で Python/C Wrapper コードをビルドしていこう。

# 1. 調査

* [CTEST_OUTPUT_ON_FAILURE](https://runebook.dev/ja/docs/cmake/envvar/ctest_output_on_failure) -- Runebook.dev, 2023/08
* CMake.org, [FindPython](https://cmake.org/cmake/help/latest/module/FindPython.html) -- 2023
* CMake.org, [find_package](https://cmake.org/cmake/help/latest/command/find_package.html) -- 2023
* CMake.org, [set_tests_properties](https://cmake.org/cmake/help/latest/command/set_tests_properties.html) -- 2023


# 2. ディレクトリ構成

2-camke_project を引き継ぎつつ、
3-c_wrapper_for_python のファイルを組み込んでいく。
追加するファイルはたった2つの CMakeLists.txt しかない。
更新点は、ファイル末尾に (*) とつけて強調している。

```tree
4-cmake_for_python_c_wrapper
└── util.bash
├── build.bash
├── CMakeLists.txt
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
│       ├── CMakeLists.txt (*)
│       ├── include
│       │   └── mypkg_wrap.h
│       └── mypkg_wrap.c
├── src-python
│   └── mypkg
│       ├── __init__.py
│       ├── CMakeLists.txt (*)
│       └── core.py
└── tests
    ├── CMakeLists.txt
    ├── cmake_support.bash
    ├── run_test.base.c
    ├── run_test.base.h
    ├── test_mypkg.c
    └── test_mypkg.py
```

# 3. test 工程

実装は、2-camke_project を引き継ぎつつ、
3-c_wrapper_for_python のファイルを組み込んでいく方向で行っていく。

まずはTDD に従い、 tests/test_mypkg.py を引き継ぐ。
そして、 `make test` でテストが実行できるように、
`add_test` を追加する。

```cmake
add_test(NAME test_with_pytest COMMAND pytest
    WORKING_DIRECTORY .)
```

テスト名は適当につけて、コマンドは pytest を用いる。
後で PYTHONPATH が通っていないと言われそうな予感もするが、このままにしておこう。

ひとまずこれでテストを実行してみる。

```bash
$ make test
Running tests...
Test project /tmp/4-cmake_for_python_c_wrapper
    Start 1: test_with_run_test
1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
    Start 2: test_with_pytest
2/2 Test #2: test_with_pytest .................***Failed    0.22 sec

50% tests passed, 1 tests failed out of 2

Total Test time (real) =   0.22 sec

The following tests FAILED:
          2 - test_with_pytest (Failed)
Errors while running CTest
make: *** [Makefile:84: test] Error 8
```

エラーが出ているが、やはり中身が見れない。

調査中に判明したのだが、どうも ctest を直接実行せずとも、
環境変数を設定すれば、失敗時にログを見せてくれるようだ。

具体的には、 `export CTEST_OUTPUT_ON_FAILURE="1"` とすれば良い。
この場合のログは以下のようになる。

```bash
$ export CTEST_OUTPUT_ON_FAILURE="1"
$ make test
Running tests...
Test project /tmp/4-cmake_for_python_c_wrapper
    Start 1: test_with_run_test
1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
    Start 2: test_with_pytest
2/2 Test #2: test_with_pytest .................***Failed    0.22 sec
============================= test session starts ==============================
platform linux -- Python 3.11.4, pytest-7.3.1, pluggy-1.0.0
rootdir: /tmp/4-cmake_for_python_c_wrapper
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collected 0 items / 1 error

==================================== ERRORS ====================================
_____________________ ERROR collecting tests/test_mypkg.py _____________________
ImportError while importing test module '/tmp/4-cmake_for_python_c_wrapper/tests/test_mypkg.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/usr/lib/python3.11/importlib/__init__.py:126: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
tests/test_mypkg.py:4: in <module>
    import mypkg
E   ModuleNotFoundError: No module named 'mypkg'
=========================== short test summary info ============================
ERROR tests/test_mypkg.py
!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!
=============================== 1 error in 0.04s ===============================


50% tests passed, 1 tests failed out of 2

Total Test time (real) =   0.22 sec

The following tests FAILED:
          2 - test_with_pytest (Failed)
Errors while running CTest
make: *** [Makefile:84: test] Error 8
```

というわけで、想定通り `No module named 'mypkg'` が見られた。
これからの目標は、 Python モジュール mypkg を作っていくことになるが、
前章とは異なり CMake で完結することを目指す。


# 4. CMake for Python/C Wrapper

## 4.1. 今までの再利用と復習

CMakeLists.txt を作っていく前に、
まず、既に完成だけはしている mypkg_warp のコードを持ってこよう。
3章の 3-c_wapper_for_python から以下のファイルを持ってくる。

```tree
.
├── src
│   └── mypkg_wrap
│       ├── include
│       │   └── mypkg_wrap.h
│       └── mypkg_wrap.c
└── src-python
　   └── mypkg
　       ├── __init__.py
　       └── core.py
```

まず、 mypkg_wrap に対して CMakeLists.txt を追加しよう。
トップディレクトリの CMakeLists.txt に `add_subcirectory(src/mypkg_wrap)` を
追加することも忘れないように。

とりあえず、今までの知識を総動員すると、
インクルードディレクトリとライブラリへのリンクがあれば良さそうだ。

```cmake
add_library(mypkg_wrap SHARED mypkg_wrap.c)
target_include_directories(mypkg_wrap
    PUBLIC include)
target_link_libraries(mypkg_wrap
    PRIVATE mypkg)
set_property(TARGET mypkg_wrap PROPERTY POSITION_INDEPENDENT_CODE ON)
```

ちょっと改行が入ったりして見た目が変わっているかもしれないが、本質は mypkg + myapp の改変だ。
本当にコピペした人は、特にターゲット名を変え忘れていないか確かめよう (2敗)。

## 4.2. find_package(Python ...)

しかし、明らかに足りないものがある。 `<Python.h>` のインクルードディレクトリである。
前章では python3 のコマンドを使ってインクルードディレクトリを取ってきたが、
CMake にはインクルードディレクトリを解決してくれるコマンドがある。
それが find_package である。

これは名前の通り、パッケージの詳細情報を色々と見つけてきて、
変数に情報を自動的に登録してくれる CMake のコマンドである。
Python の場合は、例えば以下のように書く。

```
find_package(Python REQUIRED COMPONENTS Interpreter Development)
```

ラッパーを書くだけなら、 Python の後は `REQUIRED COMPONENTS Interpreter Development` と書いておけば十分である。
インタープリタ用、開発用のインクルードディレクトリやライブラリを探してきてくれる。
詳細は[調査文献](https://cmake.org/cmake/help/latest/module/FindPython.html)を参照のこと。

REQUIRED だけ説明しておくと、これは要は「このパッケージは必須です」というマークである。
[調査文献](https://cmake.org/cmake/help/latest/command/find_package.html)中の
以下の文に書かれている通り、パッケージが見つからない場合はエラーとして処理を終了する。

> The REQUIRED option stops processing with an error message if the package cannot be found.

これで設定されるターゲットや変数の一覧は、
[ここ](https://cmake.org/cmake/help/latest/module/FindPython.html)で見れる。
ここで使うのは `Python::Python` ターゲットだ。
3章で見た `/usr/include/python3.11` のようなパスもここに含まれる。
それでは、これを PRIVATE としてリンクライブラリに追加する。

```cmake
target_link_libraries(mypkg_wrap
    PRIVATE Python::Python mypkg)
```

これでコンパイルが通るはずだ。

## 4.3. Python モジュール mypkg 用整備

libmypkg_wrap.so を作成する準備が整ったので、
次はこれを Python のソースコード用ディレクトリである src-python に
libmypkg.so としてコピーする必要がある
(mypkg 下に libmypkg.so ができてしまっているので名前が被るが、
Python 用は src-python 下に分けたので衝突はしない。混乱を招くのでみんなは避けよう)。

これは、既に作成したライブラリをコピーするだけでいい。
しかし、生成ファイルとして libmypkg.so はあるものの、
他のライブラリのビルドにそれを使うことはない。
なので、 `add_custom_command` ではなく、
ターゲットを追加する `add_custom_target` を使おう。

`src-python/mypkg/CMakeLists.txt` を作成して、以下の内容を書き込もう。
add_subdirectory を追加するのも忘れてはいけない。

```cmake
add_custom_target(py_libmypkg ALL
    COMMAND ${CMAKE_COMMAND} -E copy
    $<TARGET_FILE:mypkg_wrap> libmypkg.so
    DEPENDS mypkg_wrap
)
```

ターゲット名は適当で良い。というのも、 `ALL` で、デフォルトターゲットに追加できるからだ。
逆に `ALL` を指定しない場合、 `make py_libmypkg` と指定する必要がある。

`COMMAND ${CMAKE_COMMAND} -E copy` は環境費依存のコピーコマンドで、
cmake が実行されている環境であればコピーを実行することができる。
大体のプラットフォームで cp コマンドが使えるような気がするが、
このように書けば、このファイルを読み込んで cmake できる環境であれば環境依存を気にしなくても良くなる。

これを使ってファイルをコピーする訳だが、
ターゲットの成果物は`$<TARGET_FILE:mypkg_wrap>`のような形で指定できる。
また、コピーするときに libmypkg_wrap.so ができていないといけないので、
`DEPENDS mypkg_wrap` も指定する。

core.py も微修正する。

```py
from . import libmypkg as _mypkg


def message(res):
    res = _mypkg.message(res)
    return res
```

`import libmypkg` のように環境にパスが通っている libmypkg をインポートするのではなく、
`from . import libmypkg` のように、
自身のパッケージに含まれる共有ライブラリをインポートする形に変更する。
`as _mypkg` として名前を変更するかは好みだが、
変に混同されることを防ぐために別名にしている。


# 5. build 工程

CMakeLists.txt のみを書き換えてきたが、これで cmake が通るだろうか。
途中で色々書き換えたトップディレクトリの CMakeLists.txt だけ再掲しておこう。

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_package)

find_package(Python REQUIRED COMPONENTS Interpreter Development)

add_subdirectory(src/mypkg)
add_subdirectory(src/myapp)
add_subdirectory(src/mypkg_wrap)
add_subdirectory(src-python/mypkg)
add_subdirectory(tests)

enable_testing()
add_test(NAME test_with_run_test COMMAND run_test
    WORKING_DIRECTORY tests)
add_test(NAME test_with_pytest COMMAND pytest
    WORKING_DIRECTORY .)
```

それでは、 cmake をやってみよう。

```bash
$ cmake .
-- The C compiler identification is GNU 9.4.0
-- The CXX compiler identification is GNU 9.4.0
-- Check for working C compiler: /usr/bin/cc
-- Check for working C compiler: /usr/bin/cc -- works
-- Detecting C compiler ABI info
-- Detecting C compiler ABI info - done
-- Detecting C compile features
-- Detecting C compile features - done
-- Check for working CXX compiler: /usr/bin/c++
-- Check for working CXX compiler: /usr/bin/c++ -- works
-- Detecting CXX compiler ABI info
-- Detecting CXX compiler ABI info - done
-- Detecting CXX compile features
-- Detecting CXX compile features - done
-- Found Python: /usr/bin/python3.8 (found version "3.8.10") found components: Interpreter Development
-- Configuring done
-- Generating done
-- Build files have been written to: /tmp/4-tmp
```

問題ないようだ。それでは、続いて make もしていこう。

```bash
$ make
Scanning dependencies of target mypkg
[ 10%] Building C object src/mypkg/CMakeFiles/mypkg.dir/mypkg.c.o
[ 20%] Linking C shared library libmypkg.so
[ 20%] Built target mypkg
Scanning dependencies of target myapp
[ 30%] Building C object src/myapp/CMakeFiles/myapp.dir/main.c.o
[ 40%] Linking C executable myapp
[ 40%] Built target myapp
Scanning dependencies of target mypkg_wrap
[ 50%] Building C object src/mypkg_wrap/CMakeFiles/mypkg_wrap.dir/mypkg_wrap.c.o
[ 60%] Linking C shared library libmypkg_wrap.so
[ 60%] Built target mypkg_wrap
Scanning dependencies of target py_libmypkg
[ 60%] Built target py_libmypkg
[ 70%] Generating run_test.c, run_test.h
Scanning dependencies of target run_test
[ 80%] Building C object tests/CMakeFiles/run_test.dir/test_mypkg.c.o
[ 90%] Building C object tests/CMakeFiles/run_test.dir/run_test.c.o
[100%] Linking C executable run_test
[100%] Built target run_test
```

問題なく make も通る。

# 6. test 実行

では、最後に make test が通るか確認しよう。

```bash
$ export CTEST_OUTPUT_ON_FAILURE="1"
$ make test
Running tests...
Test project /tmp/4-tmp
    Start 1: test_with_run_test
1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
    Start 2: test_with_pytest
2/2 Test #2: test_with_pytest .................***Failed    0.22 sec
============================= test session starts ==============================
platform linux -- Python 3.11.4, pytest-7.3.1, pluggy-1.0.0
rootdir: /tmp/4-tmp
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collected 0 items / 1 error

==================================== ERRORS ====================================
_____________________ ERROR collecting tests/test_mypkg.py _____________________
ImportError while importing test module '/tmp/4-tmp/tests/test_mypkg.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/usr/lib/python3.11/importlib/__init__.py:126: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
tests/test_mypkg.py:4: in <module>
    import mypkg
E   ModuleNotFoundError: No module named 'mypkg'
=========================== short test summary info ============================
ERROR tests/test_mypkg.py
!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!
=============================== 1 error in 0.04s ===============================


50% tests passed, 1 tests failed out of 2

Total Test time (real) =   0.22 sec

The following tests FAILED:
          2 - test_with_pytest (Failed)
Errors while running CTest
make: *** [Makefile:84: test] Error 8
```

おっと、 mypkg が見つからないと怒られてしまった。
PYTHONPATH が通っていなかったため以前は環境変数を通したが、
これを CMakeLists.txt でやるには以下のように書けばいい。

```cmake
set_tests_properties(test_with_pytest PROPERTIES
    ENVIRONMENT "PYTHONPATH=${PROJECT_SOURCE_DIR}/src-python:$ENV{PYTHONPATH}")
```

これでもう一度 `make test` しよう。

```bash
$ make test
Running tests...
Test project /tmp/4-cmake_for_python_c_wrapper
    Start 1: test_with_run_test
1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
    Start 2: test_with_pytest
2/2 Test #2: test_with_pytest .................   Passed    0.20 sec

100% tests passed, 0 tests failed out of 2

Total Test time (real) =   0.20 sec
```

これでテストが通った。

# 7. まとめ

以上のように、テストが通ることが確認できた。

これまでの工程で、 Python/C wrapper として mypkg モジュールを作成することができた。
ここからは、このモジュールをインストールできるように、
setup.py でパッケージングするところまで持っていくことを考えよう。
