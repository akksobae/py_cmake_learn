<style>
    div.title{
        text-align: center; line-height: 120%;
        font-size: xx-large; font-weight: bold; 
        padding-bottom: 0.3em; margin-bottom:1em;
        border-bottom-width: 4px; border-bottom-style: double;
    }
</style>
<div class="title">
[マニュアル（２） CMake 実装](LINK)
</div>

- [1. 調査](#1-調査)
- [2. パッケージインストール](#2-パッケージインストール)
- [3. ディレクトリ構成](#3-ディレクトリ構成)
- [4. CMake 工程](#4-cmake-工程)
  - [4.1. トップレベル CMakeLists.txt](#41-トップレベル-cmakeliststxt)
  - [4.2. src/mypkg/CMakeLists.txt](#42-srcmypkgcmakeliststxt)
  - [4.3. 余談: -fPIC とは何か](#43-余談--fpic-とは何か)
  - [4.4. src/myapp/CMakeLists.txt](#44-srcmyappcmakeliststxt)
- [5. build 工程](#5-build-工程)
- [6. test 工程](#6-test-工程)
- [7. まとめ](#7-まとめ)

<!-- omit in toc -->
Introduction
============

先の章では、 C 言語における共有ライブラリの作り方・使い方の復習を行った。
次は、この共有ライブラリのコンパイル工程を CMake 化してみる。

gcc の直接実行や bash ファイルに頼らずにコンパイルすることを目指していこう。

# 1. 調査

参考文献は以下の通り。

* CMake.org, [CMake Tutorial](https://cmake.org/cmake/help/latest/guide/tutorial/index.html) -- 2023
* Hiroya_W, [C/C++プロジェクトをCMakeでビルドする](https://qiita.com/Hiroya_W/items/049bfb4c6ad3dfe6ff0c) -- Qiita, 2021/09
* 広瀬 翔, [CMakeスクリプトを作成する際のガイドライン](https://qiita.com/shohirose/items/5b406f060cd5557814e9) -- Qiita, 2018/11 (updated on: 2020/08)
* [Linux の共有ライブラリを作るとき PIC でコンパイルするのはなぜか](http://0xcc.net/blog/archives/000107.html) -- bkブログ, 2006/02

# 2. パッケージインストール

```bash
sudo apt install -y cmake
```

# 3. ディレクトリ構成

基本的に 1-c_lang_project を引き継ぐ。
先程のプロジェクトからの更新点は、ファイル名末尾に `(*)` とつけている。

```tree
2-cmake_project
├── util.bash
├── build.bash
├── CMakeLists.txt (*)
├── src
│   ├── myapp
│   │   ├── CMakeLists.txt (*)
│   │   └── main.c
│   └── mypkg
│       ├── CMakeLists.txt (*)
│       ├── include
│       │   └── mypkg.h
│       └── mypkg.c
└── tests
    ├── CMakeLists.txt (*)
    ├── cmake_support.bash (*)
    ├── run_test.base.c
    ├── run_test.base.h
    └── test_mypkg.c
```

ほぼファイル追加のみだが、 test.bash のみ削除されている。
これは、テスト機能を CMake の機能で実現することにしたためである。
一部機能を cmake_support.bash に移しつつ、
トップディレクトリの test.bash は削除した。

# 4. CMake 工程

CMake では、 **CMakeLists.txt** という設定ファイルを書けば、
後は `cmake .; make` でビルドできるようにしてくれるというものだ。
本当は Makefile から入るべきだったかもしれないが、ここでは省略する。

それでは、先程のコードをコピーして、
CMakeLists.txt を作っていこう。

## 4.1. トップレベル CMakeLists.txt

とりあえず、プロジェクトのトップディレクトリに移動して、
以下のような CMakeLists.txt を作る。

```c
cmake_minimum_required(VERSION 3.16)
project(my_package)

add_subdirectory(src/mypkg)
add_subdirectory(src/myapp)
```

これらはほぼ「おまじない」で、具体的なコンパイル命令ではない。

`cmake_minimum_required(VERSION 3.16)` は cmake のバージョンを指定するものだ。
`cmake --version` で、自分が使用している cmake のバージョンを確認できる。

`project(my_package)` はこのプロジェクトの名前である。
指定しないと怒られるのだが、どこで使われてるかはいまいちよくわからない。
実際、後述の「ターゲット」というのがコンパイルの単位になり、
それがプロジェクト名と一致している必要は無い。
ただし、これが欠けていると、以下のように言われる。

```
$ cmake .
CMake Warning (dev) in CMakeLists.txt:
  No project() command is present.  The top-level CMakeLists.txt file must
  contain a literal, direct call to the project() command. ...(省略)
```

その後の `add_subdirectory(...)` は、
「そこ(引数の場所)にコンパイル対象がありますよ」と伝えるものになっている。
ただし、コンパイル対象をどうコンパイルするかまで自動で判断してくれる訳ではない。
ちゃんとその場所に CMakeLists.txt を書いてやる必要がある。

というか、 CMake の処理はディレクトリごとに行われるので、
C 言語でのコンパイルに関わるすべてのディレクトリに基本的には CMakeLists.txt を書く必要がある。
ただし、 `cmake_minimum_required(...)`と`project(...)`のおまじないの部分は、
トップレベル、つまり、一番上のディレクトリの CMakeLists.txt に一回書けばいい
(言い換えれば、この CMakeLists.txt が `main.c` や `__main__.py` に当たる)。

## 4.2. src/mypkg/CMakeLists.txt

共有ライブラリを作るために、 src/mypkg にも CMakeLists.txt を書く必要がある。
これも、中身を先に示そう。

```c
add_library(mypkg SHARED mypkg.c)
target_include_directories(mypkg PUBLIC include)
set_property(TARGET mypkg PROPERTY POSITION_INDEPENDENT_CODE ON)
```

先程も述べたように、 CMake では基本となるコンパイル対象を「ターゲット」と呼ぶ。
そして、それを追加する関数が主に 3 つくらいある。

* `add_library(lib_name TYPE file1 file2 ...)`
    + ライブラリ生成用。
* `add_executable(exe_name file1 file2 ...)`
    + 実行ファイル生成用。
* `add_custom_target(target_name TYPE ...)`
    + カスタム実行用。 bash のように比較的何でも実行できるように指定できる。

ここでは共有ライブラリを作るので、 `TYPE=SHARED` を指定して add_library を呼ぶ。
これで、 CMake は「libmypkg.so を作ればいいんだな」ということを理解する。

引数にはそれを構成する .c ソースファイルを指定し、
CMake はそれを材料にコンパイルを実行してくれる。
このとき、同一ディレクトリのヘッダファイルは自動的に見つけてくれるらしい。

とはいえ、ヘッダファイルを見つける場所を追加しなければならないこともある。
その場所の指定 (`gcc` でいうところの `-I` オプションの指定) 方法は以下の通りである。

```c
target_include_directories(mypkg PUBLIC include)
```

PUBLIC とは、「mypkg を使うターゲットも、この include/*.h を見えるようにする」という意味だ。
このおかげで、後で myapp や run_test の CMakeLists.txt を作るとき、
`target_include_directories(...)` を呼ばなくてよくなる。
逆に、 mypkg だけでしか使わないヘッダファイルなら、 PRIVATE を指定する。

最後に、オプションの追加である。
共有ライブラリを作るなら `-fPIC` オプションを付けたい。
オプションの付け方は、オプションの種類によって調べなければならないのだが、
`-fPIC` なら以下のように書く。

```c
set_property(TARGET mypkg PROPERTY POSITION_INDEPENDENT_CODE ON)
```

これで、 mypkg (libmypkg.so) に関する CMakeLists.txt は完成である。
3行書くだけでも面倒そうに感じたかもしれないが、
この3行から自動生成される Makefile が実に 180行あることから、
どれほど楽になったかを感じてほしい。
ついでに、Makefile に関する記述を避けた理由も察してほしい。


## 4.3. 余談: -fPIC とは何か

一応、なぜ `-fPIC` を付けるのか整理しておこう。
`-fPIC` とは「PIC を有効にするフラグを立てる」という意味のオプションである。

PIC とは Position Independent Code、「位置独立実行形式」の略である。
これをつけないと「位置独立」ではない、つまり、「位置依存(Position Dependent)」なコードが生成されてしまう。
では、「位置依存」とは何だろうか。

「位置依存か否か」というのは、全世界的に流行りのゲームであるところの MineCraft で考えると分かりやすい。
ここでは、「プログラムの実行形式ファイル (.so とか .exe)」を「家の設計図」として例えてみる。
もしあなたが設計図を公開するとしたら、
例えば「玄関はx=100, y=64から始まり、土台はx=...から...」みたいな書き方をすることになるだろう。

このとき、座標の書き方は以下の2通りある。

* (1) 実際に家を作った座標に基づいて、座標を書く。
* (2) 家のどこかを原点 (x,y,z)=(0,0,0) にして、そこに基づいて座標を書く。

(1) の方法は、設計図を書く人にとっては分かりやすい方法だ。
というのも、そのブロックがある場所に立ってみて、座標を調べて書き込めばいいからだ。

しかし、明らかに不都合なことがいくつかある。例えば、

* 基準点が零点ではないので、座標の値が複雑になる。 10x10 マスの土台を作ったとしても、
    例えば南西の点は (x,z)=(1746,-587) で、北東の点は(x,z)=(1756,-577) かもしれない。
    もし座標をずらして家を建てたい人は、毎回毎回「私の家のここはこの座標だから…」と計算し直す必要がある。
* 他の設計図と被る可能性がある。仮に運良く全く同じ座標に家を建てられるとしても、
    「街を作るために別の人の設計図を借りてきたら、家の一部の座標が被ってしまった」ということが起こりうる。
    同じ座標には複数の家を建てることはできない。そのときは先述のような「座標ずらし」が必要になる。

なので、 (2) で最初から書いておいてくれたら、設計図を読んで作る人は計算が楽でいい。
座標をずらす計算を毎回せずとも、自分の基準点に合わせて計算してやればいいし、その計算も容易だからだ。
(1) は、本当に同じ座標に建てたいという場合にしか便利ではない。

座標の書き方について、(1)を**位置依存**と言い、(2)を**位置独立**と表現する。
位置とはつまり絶対的の座標のことであり「実際に家を建てた位置に依存しているか否か」ということである。

そして、これはプログラムの実行形式ファイルと同じなのである。
そもそもプログラムとはメモリに書き込まれて実行されるものだから、
プログラムの実行形式ファイルには、データの場所や実行すべき関数の場所、命令文の場所などがあり、
家の設計図と同じように様々な「場所(位置)」の情報が書き込まれている。

もしそれが (1)位置依存だと、
毎回毎回それらの場所を翻訳しながら実行しなければならないから、
プログラムの実行速度が落ちてしまう。
複数のライブラリを include する場合は、そもそも実行できないかもしれない。

一方、 (2)位置独立なら、
プログラムは場所の翻訳をしなくていいから、実行速度も早くなる。
他のライブラリと併用する場合も、場所の取り合いを考えなくてよくなる。

ということで、みんなに使ってもらう .so 共有ライブラリを作る場合には、
`-fPIC` オプションを付けて `POSITION_INDEPENDENT_CODE` (位置独立実行形式) にすべきである。

逆に言うと、 .exe は独立した一軒家を建てるようなものなので、付ける必要はない。
実際、プログラムの「位置」は、基本的に .exe を基準にして、 .so 等のライブラリがメモリに展開される。
.so は、外見重視の一軒家(.exe)に付け加えて作る、地下施設や自動化設備のようなものだと思えばいい。


## 4.4. src/myapp/CMakeLists.txt

せっかくだからではないが、実行形式ファイル .exe を生成する方法についても、
myapp の方で学ぼう。

myapp 用の CMakeLists.txt は以下のようになる。

```c
add_executable(myapp main.c)
target_link_libraries(myapp mypkg)
```

今回は実行形式ファイルを作るので、 `add_executable(...)` を使う。
これでターゲット `myapp` が追加される。

この `myapp` は、ライブラリ mypkg を利用している。
なので、 `target_link_libraries(myapp mypkg)` で、
利用するパッケージとして mypkg を指定する。

この mypkg はグローバルにインストールされている訳では無いが、
本プロジェクト内部では `mypkg` というターゲット名で管理されているので、
このように書いても問題なく認識される。
gcc のときを思い出すと、そのときは `../mypkg/libmypkg.so` と書かなければいけなかった。
それに比べれば、このターゲット名で管理するやり方は楽になっている。
このおかげで、例えば mypkg のファイルパスが変わったとしても、
ターゲット名が変わらない限りは問題なく認識される。

プロジェクトのターゲットに含まれていないようなライブラリは、
グローバルにインストールされている必要があるので注意である。


# 5. build 工程

ビルドは2段階で行われる。
トップディレクトリに戻って、以下を実行しよう。

```
$ cmake .
$ make
```

1段階目は、 cmake の実行である。
引数にカレントディレクトリを与えるのを忘れてはいけない。
これでビルドに必要な Makefile が作られる。

2段階目は、 make の実行である。
ここで実際に実行形式ファイルが生成される。

`cmake .` は、ファイルの増減等が無い限り、最初の一回だけやればいい。
言い換えれば、開発しながら make する場合は、 make だけやりなおせば済む。


# 6. test 工程

CMakeLists.txt では、テストの実行も管理できる。

本当はテストフレームワークと連携した行儀の良い方法を学ぶべきだろうが、
そこは別の機会に譲ろう。

とはいえ、 CMake には最低限のテストツール CTest が用意されていて、
基本的には CTest に「このテストコードを実行してください」とお願いするだけで、
ちょっといい感じのテスト出力結果を出せるようにしてくれる。

テストを追加するためには、トップディレクトリの CMakeLists.txt で定義を行う。
そうすれば、わざわざ tests ディレクトリに入らずともテストを実行できる。
具体的には、以下のような記述を追加すればいい。

```c
enable_testing()
add_test(NAME test_with_run_test COMMAND run_test
    WORKING_DIRECTORY tests)
```

`enable_testing()` は、後で `make test` で CTest を用いたテストが行えるようにする「おまじない」である。

`add_test(...)` が、実際に実行するテストの中身を指定している。
`NAME` はこのテスト自体の名前であり、
実際に実行するテストコマンドは COMMAND で指定する。
WORKING_DIRECTORY で、テストを実行するディレクトリを指定してやることもできる。

さて、では、 run_test も CMake 用に整備していこう。
とりあえず run_test.base.c と run_test.base.h を
無理やり bash ファイルで弄っていくスタイルを踏襲しつつ、
テストが実行可能なようにしてみよう。

```c
add_executable(run_test test_mypkg.c run_test.c)
target_link_libraries(run_test mypkg)
```

run_test は、テストを実行する当プロジェクト謹製(笑)のテスト用プログラムである。
これは mypkg を参照するので、 先程の myapp と同様に `target_link_libraries(...)` を指定する。
このとき、コピペしてターゲット名を間違えないように注意しよう (一敗)。

ただ、これだけだと run_test.c ができていない。
これを生成させるにはどうすればいいだろうか？

答えは、以下のように `add_custom_command(...)` というのを使う。

```c
add_custom_command(
    OUTPUT run_test.c run_test.h
    COMMAND ./cmake_support.bash
    DEPENDS cmake_support.bash run_test.base.c run_test.base.h
)
```

ターゲット名をしてきた今までとは少し面持ちが異なるが、
「ターゲット」というのが「出力するファイルの名前」だと思うと、それほど違和感は無い。
`add_custom_command()` では、
ターゲット名として出力を指定するのではなく、
直接ファイル名として OUTPUT に出力するファイル名を指定する。

そして、他のターゲットが入力として受け取るファイルの中で依存関係が解決されていないもの
(今回の場合でいうと run_test.c) の中で、
`add_custom_command(OUTPUT ...)` で定義されたものがあれば、
そのターゲットの実行前に `add_custom_command(... COMMAND ...)` で指定したコマンドを実行してくれる。

COMMAND の前に、 DEPENDS について話をしよう。
DEPENDS は、`add_custom_command(...)` が依存するファイルを指定する。言い換えれば、このファイルに変更があった場合にのみ、 `add_custom_command(...)` の中身が再実行される。

さて、 COMMAND に話を戻す。
COMMAND は、 cmake に実行を頼りにできない、自己定義したコマンドの実行を指定する
(おそらく通常は cp コマンドくらいを想定していると思う。 .bash でソース変更はやり過ぎかなと反省している)。

今回は、以前は test.bash 中で実行していた bash の中身を抽出して、
tests/cmake_support.bash に置いておいた。
中身を少し変更したので、それぞれ示しておこう。

* **run_test.base.c**

```c
#include <stdio.h>
#include "run_test.h"

int run_test(test_function f, char *test_name)
{
    [...]
}

int main(int argc, char const *argv[])
{
    test_function test_target_list[] = {
        // TEST_FUNCTIONS_LIST
        NULL,
    };
    for (test_function *p = test_target_list; *p != NULL; p++)
    {
        (*p)(0);
    }
    return 0;
}
```

コードの細かい説明はしないし、一部省略するが、
関数の実行を直接指定するのではなく、関数のリストを渡して for 文で実行することにした。
それに合わせて、プリプロセッサマクロの名前を変更した。

* **run_test.base.h**

```c
#ifndef __RUNTEST_HEADER__
#define __RUNTEST_HEADER__

typedef int (*test_function)();

// TEST_FUNCTIONS_DEF

#endif
```

こちらは typedef 宣言を移してきた。
また、プリプロセッサマクロの名前を変更した。

* **cmake_support.bash**

```c
#!/usr/bin/env bash
 -*- coding: utf-8 -*-

function list_test_function_names() {
    [...]
}
function list_call_of_test_functions() {
    list_test_function_names | while read line; do
        echo "$line,"
    done
}
function list_def_of_test_functions() {
    list_test_function_names | while read line; do
        echo "int ${line}();"
    done
}

sed "s@// TEST_FUNCTIONS_DEF@$(list_def_of_test_functions)@" \
run_test.base.h > "run_test.h"

sed "s@// TEST_FUNCTIONS_LIST@$(list_call_of_test_functions)@" \
run_test.base.c > "run_test.c"
```

ここでは、デバッグ用の機能等はすべて省き、微修正しつつスクリプト生成機能だけを残した。

これで `make test` を実行すると、以下のようにいい感じに出力してくれる。

```bash
$ make test
Running tests...
Test project /tmp/2-CMake_project
    Start 1: test_with_run_test
1/1 Test #1: test_with_run_test ...............   Passed    0.00 sec

100% tests passed, 0 tests failed out of 1

Total Test time (real) =   0.00 sec
```

順序としては、以下のようになっている(はず)。

1. `cmake .` を実行すると、テスト用の Makefile が生成される。
2. `make test` を実行すると、
   1. ターゲット `run_test` には `run_test.c` が必要なのに無いので、 `add_custom_command` から `./cmake_support.bash` が実行される。
   2. ターゲット `run_tests` が実行され、 `run_test` 実行形式ファイルが生成される。
   3. `add_test(...)` で指定した `run_test` が実行される。
3. CMake 謹製テストツール Ctest のテスト結果が表示される。

逆に、仮にエラーが起きると、以下のような出力になる
(「なぜコンパイルエラーからこの章を始めなかった、言え！」という TDD 過激派の声が聴こえてくる)。

```bash
$ make test
Running tests...
Test project /tmp/2-CMake_project
    Start 1: test_with_run_test
1/1 Test #1: test_with_run_test ...............Child aborted***Exception:   0.00 sec

0% tests passed, 1 tests failed out of 1

Total Test time (real) =   0.01 sec

The following tests FAILED:
          1 - test_with_run_test (Child aborted)
Errors while running CTest
```

ただ、これだとテストのログが見れない。
中身のログまで見たい場合は、 `make test` 経由ではなく、
`add_test(...)` の裏で動いている CMake 謹製のツール `ctest` を直接呼ぶ必要がある。
具体的には、 cmake 後に `ctest --verbose` をトップディレクトリから呼んでやればいい。

```bash
$ ctest --verbose
UpdateCTestConfiguration  from :/tmp/2-CMake_project/DartConfiguration.tcl
UpdateCTestConfiguration  from :/tmp/2-CMake_project/DartConfiguration.tcl
Test project /tmp/2-CMake_project
Constructing a list of tests
Done constructing a list of tests
Updating test list for fixtures
Added 0 tests to meet fixture requirements
Checking test dependency graph...
Checking test dependency graph end
test 1
    Start 1: test_with_run_test

1: Test command: /tmp/2-CMake_project/tests/run_test
1: Test timeout computed to be: 10000000
1: run_test: /tmp/2-CMake_project/tests/test_mypkg.c:9: test_res_of_message: Assertion `res == 0' failed.
1/1 Test #1: test_with_run_test ...............Child aborted***Exception:   0.00 sec

0% tests passed, 1 tests failed out of 1

Total Test time (real) =   0.01 sec

The following tests FAILED:
          1 - test_with_run_test (Child aborted)
Errors while running CTest
```

``run_test: /tmp/2-CMake_project/tests/test_mypkg.c:9: test_res_of_message: Assertion `res == 1' failed.`` という感じで、実際にどんなエラーが出て終了したのかが分かる。

# 7. まとめ

1章では、とりあえず C 言語でのコンパイルの仕方を復習したが、
それを2章では CMake で実行できるようにした。
今回は簡単なプロジェクトだから良いが、
特に include 周りとか library 周りは、
CMake のパワフルさが活きてくると思う。

次は、 CMake に Python を導入していく。
