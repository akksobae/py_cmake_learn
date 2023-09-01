<style>
    div.title{
        text-align: center; line-height: 120%;
        font-size: xx-large; font-weight: bold; 
        padding-bottom: 0.3em; margin-bottom:1em;
        border-bottom-width: 4px; border-bottom-style: double;
    }
</style>
<div class="title">
[マニュアル（３）Python 用 C 言語 Wrapper 実装](LINK)
</div>

- [1. 調査](#1-調査)
- [2. パッケージインストール](#2-パッケージインストール)
- [3. ディレクトリ構成](#3-ディレクトリ構成)
- [4. test 工程](#4-test-工程)
- [5. Python Wrapper コーディング](#5-python-wrapper-コーディング)
  - [5.1. mypkg の Wrapper: mypkg\_wrap.c (コードの全体構造)](#51-mypkg-の-wrapper-mypkg_wrapc-コードの全体構造)
  - [5.2. mypkg\_wrap.c (メソッド実装編)](#52-mypkg_wrapc-メソッド実装編)
    - [5.2.1. \[A\] メソッド定義](#521-a-メソッド定義)
    - [5.2.2. \[B\] C 言語コード本体](#522-b-c-言語コード本体)
    - [5.2.3. \[C\] ランタイムエラー](#523-c-ランタイムエラー)
    - [5.2.4. \[D\] 返り値](#524-d-返り値)
  - [5.3. mypkg\_wrap.c (メソッド定義編)](#53-mypkg_wrapc-メソッド定義編)
  - [5.4. mypkg\_wrap.c (モジュール定義・おまじない編)](#54-mypkg_wrapc-モジュール定義おまじない編)
  - [5.5. mypkg\_wrap.c (モジュール定義編)](#55-mypkg_wrapc-モジュール定義編)
  - [5.6. mypkg\_wrap.c (モジュール初期化編)](#56-mypkg_wrapc-モジュール初期化編)
  - [5.7. mypkg\_wrap.h (ヘッダ編)](#57-mypkg_wraph-ヘッダ編)
- [6. build 工程](#6-build-工程)
  - [6.1. libmypkg\_wrap.so の作成](#61-libmypkg_wrapso-の作成)
  - [6.2. src-python/libmypkg.so の作成と src-python/mypkg の実装](#62-src-pythonlibmypkgso-の作成と-src-pythonmypkg-の実装)
- [7. test 確認](#7-test-確認)
- [8. まとめ](#8-まとめ)

<!-- omit in toc -->
Introduction
============

先の章では、 CMake の使い方を学んだ。
ここでは、 CMake を一旦脇において、
C 言語で定義された関数を Python から呼び出す方法を解説する。

# 1. 調査

* everylittle, [pytestに入門してみたメモ](https://qiita.com/everylittle/items/1a2748e443d8282c94b2) -- Qiita, 2018/01
* Python Software Foundation, [Python 3 への拡張モジュール移植](https://docs.python.org/ja/3.6/howto/cporting.html) -- Python HOWTO, 2021/12
* Python Software Foundation, [引数の解釈と値の構築](https://docs.python.org/ja/3/c-api/arg.html) -- Python/C API リファレンスマニュアル, 2023/08
* Python Software Foundation, [共通のオブジェクト構造体](https://docs.python.org/ja/3/c-api/structures.html) -- Python/C API リファレンスマニュアル, 2023/08
* Python Software Foundation, [循環参照ガベージコレクションをサポートする](https://docs.python.org/ja/3/c-api/gcsupport.html) -- Python/C API リファレンスマニュアル, 2023/08

# 2. パッケージインストール

```bash
sudo apt install -y python3-dev python3-pip python3-venv
pip install pytest pytest-sugar
```

# 3. ディレクトリ構成

基本的に 1-c_lang_project を引き継ぐ。
更新点は、ファイル名末尾に `(*)` とつけている。

```tree
3-c_wapper_for_python
├── util.bash
├── build.bash
├── src
│   ├── myapp
│   │   └── main.c
│   ├── mypkg
│   │   ├── include
│   │   │   └── mypkg.h
│   │   └── mypkg.c
│   └── mypkg_wrap (*)
│       ├── include (*)
│       │   └── mypkg_wrap.h (*)
│       └── mypkg_wrap.c (*)
├── src-python (*)
│   └── mypkg (*)
│       ├── __init__.py (*)
│       └── core.py (*)
├── test.bash
└── tests
　   ├── run_test.base.c
　   ├── run_test.base.h
　   ├── test_mypkg.c
　   └── test_mypkg.py (*)

```

# 4. test 工程

TDD に従い、 tests/test_mypkg.py を作っておいた。
以下のテストを実行させることが、この章の目的となる。

```py
import mypkg


def test_run_mypkg_ret():
    assert mypkg.message(0) == 0


def test_run_mypkg_out(capfd):
    mypkg.message(0)
    captured = capfd.readouterr()
    assert captured.out == "Hello world!\n"
```

先に、 pytest について簡単に説明しておく。
pytest は、 Python 用のテストフレームワークで、色々とテストの実行を便利にしてくれる。
例えば、以下のような特徴がある。

* `test_*.py` のファイルを勝手に見つけてきて、 `def test_*()` で定義された関数をテスト関数と認識して、テストを実行してくれる。
* `assert <bool>` となるような書き方をするだけで、「テストにおいてこうあるべき」というのを一貫して簡潔に書ける。

上の例だと、 

* `test_run_mypkg_ret()` では、 mypkg.message() の返り値が 0 であることを確かめている。
* `test_run_mypkg_out(capfd)` では、標準出力が "Hello world!" となることを確かめている。
  * capfd は標準出力等のファイルディスクリプタ(fd)をキャプチャー(capture)するための、 pytest が提供している便利オブジェクトである。

さて、実際にトップディレクトリで `pytest` と実行してみよう。
パスが通っていない場合は、 `python3 -m pytest` で実行だ。

```bash
$ pytest
Test session starts (platform: linux, Python 3.11.4, pytest 7.3.1, pytest-sugar 0.9.7)
rootdir: /tmp/3-c_wrapper_for_Python
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collecting ...
―――――――――――――――――――――――――――――――――――――――――――――――――― ERROR collecting tests/test_mypkg.py  ―――――――――――――――――――――――――――――――――――――――――――――――――――
ImportError while importing test module '/tmp/3-c_wrapper_for_Python/tests/test_mypkg.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/usr/lib/python3.11/importlib/__init__.py:126: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
tests/test_mypkg.py:4: in <module>
    import mypkg
E   ModuleNotFoundError: No module named 'mypkg'
collected 0 items / 1 error

========================================================= short test summary info =========================================================
FAILED tests/test_mypkg.py
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Results (0.04s):
```

pytest-sugar もインストールしたなら、ログがいい感じに色づいているはずである。

当たり前だが、今の時点では `import mypkg` からして動かない。
エラーメッセージもそれを語るように `No module named 'mypkg'` と書いてある。

主にこれを解決していくのがこの章の目的である。
CMake で自動解決してくれるのは、環境依存を避ける意味でも良いことではあるが、
動作原理を確認する意味でも、 gcc から一度ビルドしておこう。

環境依存のコードになるだろうから、先に wsl の Ubuntu 20.04 環境であることを注記しておく。
異なる環境の人で、もしここに書いてあることをハンズオン的にやろうとしているなら、
眺めるだけに留めて、第四章に移ることをお勧めする。

# 5. Python Wrapper コーディング

まず、Wrapper (ラッパー) という概念を整理しよう。
Wrapper とは、誕生日のラッピングと同じで、「包み込む」という意味だ。
例えば、宴会用の風船も、テレビゲームも、 Google Play ギフトコードも、
**外見を全部「正方形のきれいな箱」にしてしまえる**。
ここでは、「C 言語」をラップして、「Python 言語」のコードに見せかけてしまう。

こういった特殊なことをやる都合上、多数の「おまじない」が絡んできて、
恐らくそれらは環境依存であることも多いと思われるので、
以降の解説には注意してほしい。

閑話休題。
この「ラップする」という工程には、通常のラッピングがそうであるように、次の3つの登場人物が出てくる。

* 包み込まれるもの： C 言語のコード (libmypkg.so, mypkg_wrap.c)
* 包み込んだ後のもの： 上述の C 言語のコードを Python にしたライブラリ (libmypkg_wrap.so)
* 包み込んだ後のものを受け取る人：上述のライブラリを呼び出す Python コード (mypkg.py)

ここでは、第一章で作成した mypkg を Python で呼び出すことを目指して、
これらの登場人物を順番に実装・説明していく。

## 5.1. mypkg の Wrapper: mypkg_wrap.c (コードの全体構造)

それでは、 src 配下に mypkg_wrap ディレクトリを作成し、
mypkg_wrap.c を作成しよう。

詳細な実装部分を省けば、全体は以下のような構成になる。

```c
#include "mypkg_wrap.h"
#include "mypkg.h"

/***********************************************************
 * Body (ラップ関数の定義部分)
 ***********************************************************/

static PyObject *pywrap_message(
    PyObject *self, PyObject *args, PyObject *kw)
{
    // ...
}

/***********************************************************
 * Magic code (Python で呼び出せるようにするための「おまじない」部分)
 ***********************************************************/

// 定義した Python メソッドの一覧
static PyMethodDef libmypkg_methods[] = {
    { "message", /* ... */, }, // message() メソッド。
    // ...
};

// ...

// mypkg モジュールの定義
static struct PyModuleDef moduledef = {
    // ...
    "libmypkg",                  // const char*: モジュール名。
    // ...
    libmypkg_methods,            // libmypkg が含むモジュール一覧。
    // ...
};

// mypkg の __init__ に対応する C 言語コード
PyMODINIT_FUNC PyInit_libmypkg(void)
{
    PyObject *module = PyModule_Create(&moduledef);
    // ...
    return module;
}
```

順番に解説しよう。
とはいえ、具体的な中身は後で解説するとして、先ずは全体の概要を掴むこと優先する。


まず、ヘッダーインクルードの部分だが、 mypkg をラップする予定なので、
mypkg.h をインクルードしている。
mypkg_wrap.h には「おまじない」しか書かず、
意味のあることを書くことは無いので、説明を後回しにする。

```c
#include "mypkg_wrap.h"
#include "mypkg.h"
```

次に、ラップする関数を定義する部分だ。
今回は libmypkg という名前のモジュールになるので、
python のモジュールとしては `libmypkg.message()` メソッドを定義することになる。

```c
static PyObject *pywrap_message(
    PyObject *self, PyObject *args, PyObject *kw)
{
    // ...
}
```

PyObject というそれっぽい型名が並んでいて、いかにも Python 用コードといった感じだ。
このコードを Python で書くとするなら、以下のようになる。

```py
(libmypkg.py)

def message(*args, **kw):
    # ...
```

次の部分は、「おまじない」部分だ。
Python ならメソッドを .py に書いたら、そのモジュールのメソッドとして認識してくれるが、
C 言語ではちゃんと自分で定義してやらなければならない。

```c
// 定義した Python メソッドの一覧
static PyMethodDef libmypkg_methods[] = {
    { "message", (PyCFunction)pywrap_message,　/* ... */, }, // message() メソッド。
    // ...
};

// ...

// mypkg モジュールの定義
static struct PyModuleDef moduledef = {
    // ...
    "libmypkg",                  // const char*: モジュール名。
    // ...
    libmypkg_methods,            // libmypkg が含むメソッド一覧。
    // ...
};
```

多数のおまじないに紛れた重要な部分だけをピックアップしている。

最初に、 `PyMethodDef libmypkg_methods[]` は、 Body 部分で実装した個々のメソッドを、
Python でのメソッド名を含む設定値と組にして定義している情報の配列である。

このメソッド定義配列を、今度はモジュール定義変数 `struct PyModuleDef moduledef` に渡す。
`moduledef` は、モジュールの定義として、少なくともモジュールの名前と、
`libmypkg_methods` で定義されたメソッド群を含むことが分かる。

最後に、この `moduledef` を Python の `__init__()` メソッド相当の関数に渡す。

```c
// mypkg の __init__ に対応する C 言語コード
PyMODINIT_FUNC PyInit_libmypkg(void)
{
    PyObject *module = PyModule_Create(&moduledef);
    // ...
    return module;
}
```

これで、 C 言語のコードのお作法に則って、 `libmypkg` モジュールを定義できる。

後は gcc を上手くすれば libmypkg.so ができてインポートできるようになる。
そこまで先に進みたい人は5節に進もう。

各コードの内容を確認したい場合は、引き続き次の項に進んでほしい。

## 5.2. mypkg_wrap.c (メソッド実装編)

C 言語としての `message()` 関数の実装は済んでいて、 mypkg.c で実装されている。
では、ただそれを呼んで来ればいいのかというと、
この関数を Python に見せかける上で色々とやらないといけないことがある。

* Python の型の引数を受け取る必要がある。
* 返り値を Python の型に直す必要がある。

ご存知の通り、 Python には型がない。
正確には、すべての型 (クラス) が Object 型を継承していて、
Object 型の変数として値をやり取りするので、
Python の実装は極めて楽である。

しかし、中身の実装までそうではないのも周知のとおりだ。
文字列と int の足し算はできないし (掛け算はできるのがややこしいところだが)、
re とかの返り値オブジェクトのメソッドを呼び出そうとして「それ None だよ」と怒られるなんてしょっちゅうである。

一方、C 言語は型を厳密に扱う。継承という概念もサポートされていない (やるとしたら手動)。
実装は大変だが、静的解析が効く分、バグが少なくなっていいという話も聴く。

ともあれ、この厳密な型管理を行う C 言語のお作法に従って、
Python のゆるゆるな型で `message()` 関数が使えるように、
様々な変数を PyObject へとラッピングしていく必要がある。
というか、そのラッピングがこの Wrapper コードのすべてである。

```c
static PyObject *pywrap_message(
    PyObject *self, PyObject *args, PyObject *kw)
{
    long long res_for_py;

    /* [A] Python のメソッド定義と対応する C 言語のコード */
    int res_for_c;
    static char *keywords[] = {"res", NULL};

    if (!PyArg_ParseTupleAndKeywords(
            args, kw, "i", keywords, &res_for_c))
    {
        return NULL; /* Error on parse parameters on Python. */
    }

    /* [B] C 言語のコードの実行部分の本体 */
    res_for_py = (long long)message(res_for_c);

    /* [C] ランタイムエラー時の処理 (raise RuntimeError(...) と対応) */
    if (res_for_py < 0)
    {
        PyErr_SetString(PyExc_RuntimeError, "Error on message().");
        return NULL;
    }

    /* [D] (Python のメソッドとしての) 返り値の処理 */
    return Py_BuildValue("L", res_for_py);
}
```

元のコードには無いが、実行部分に沿って、 [A] から [D] の記号を振った。
基本的にはコメントに概略が書いてあるが、以降で簡単に記述していく。

### 5.2.1. [A] メソッド定義

[A] は、 Python のメソッド定義と対応する C 言語のコードである。

まず、keywords に引数の名前を書いていく。今回は res しかないので、それだけ書いている。

次に、 PyArg_ParseTupleAndKeywords で、 Python から受け取った引数データをパースする。
keywords の宣言と、 `"i"` として定義されている部分が対応していて、各引数の型を表す。
`i` は `int32` を意味していて、 `res` 引数が `int` 型であることを意味している。
`L` としたら、 `long long` つまり `int128` を表すこととなる。

複数の引数がある場合は、単純に文字列を長くしていく。２つ int の引数があるなら `ii` だ。
オプション引数の場合は、 `i|i` を指定する。
また、その場合は C 言語側で初期値を設定しておかなければならないことに注意する。
今回の場合で例えると、 `int res_for_c` ではなく
`int res_for_c = 0;` とかにしておかなければならない。

### 5.2.2. [B] C 言語コード本体

[B] は、 C 言語コード本体である。
ここでは mypkg.c の message() 関数を呼び出しているが、
ここに直接実装を書いてももちろん構わない。
関数が複雑になるので、別の関数にするくらいはした方がいいかもしれないが、
これくらいの規模ならライブラリまでわざわざ分ける必要はないだろう。

`PyArg_ParseTupleAndKeywords` は、第一・第二引数で、
名前なし引数`args`と名前付き引数`kw`を受け取る。
その後、引数ごとの型と、引数の名前を続けて書く。
返り値は最後に書いて、値を入れてほしい変数へのポインターを渡す(参照渡し)。

### 5.2.3. [C] ランタイムエラー

[C] のランタイムエラー時の処理はオプションである。無くてもいい。
また、エラーの種類によってより柔軟なエラーを投げることも検討しうる。

`PyErr_SetString` には、例外の型と、エラーメッセージを引数として渡す。
ここでは、 message が負の値を返したらエラーということにして、
そのときは RuntimeError を投げるようにしている。
もちろん、 Python 側の try-catch 構文で受け取ることができる。

### 5.2.4. [D] 返り値

[D] は返り値の処理である。
`Py_BuildValue`は、`PyArg_ParseTupleAndKeywords`と同様に、
第一引数に型を文字列として渡して、その後に(可変長引数として)返り値を渡す。
複数返したい場合は、型に複数の文字を並べて、返り値も対応する数だけ渡せばいい。


## 5.3. mypkg_wrap.c (メソッド定義編)

次に、実装したメソッドを、 `libmypkg` モジュールに登録していく作業に移っていく。
先に示した通り、先ずは `libmypkg_methods` にメソッド定義を放り込んでいく。

```c
// 定義した Python メソッドの一覧
static PyMethodDef libmypkg_methods[] = {
    {
        "message",                      // メソッド名。
        (PyCFunction)pywrap_message,    // メソッドが呼び出す C 言語の関数名。
        (METH_VARARGS | METH_KEYWORDS), // メソッドの構造を設定するフラグ。
                                        // 引数だけなのか、キーワード引数を取るのか等。
        "Show Hello world.",            // docstring。
    },
    {NULL, NULL, 0, NULL},
};
```

4つの引数があり、説明はコメントを参照。

第三引数についてだけ補足が必要と思われる。
METH_VARARGS や METH_KEYWORDS は Python.h で定義されたフラグ定数で、
メソッドの名前付き引数の有無等を制御するフラグになっている。
フラグ制御とかいうとややこしく聞こえるかもしれないが、基本は2パターンしかない。

* `METH_VARARGS`: キーワード引数がない場合
* `(METH_VARARGS | METH_KEYWORDS)`: キーワード引数がある場合

3.7 からMETH_FASTCALL というのが追加されているらしいが、
使ったことが無くて解説できないので、説明を省略する
(むしろ誰か教えてください)。

## 5.4. mypkg_wrap.c (モジュール定義・おまじない編)

[循環参照ガベージコレクションをサポートする](https://docs.python.org/ja/3/c-api/gcsupport.html)ためには、
以下の関数を設定しておく必要がある。

```c
// 循環参照ガーベージコレクション用の関数設定
static int libmypkg_traverse(PyObject *m, visitproc visit, void *arg)
{
    Py_VISIT(GETSTATE(m)->error);
    return 0;
}

static int libmypkg_clear(PyObject *m)
{
    Py_CLEAR(GETSTATE(m)->error);
    return 0;
}
```

ただし、 GETSTATE は以下のマクロである ([ここ](https://docs.python.org/ja/3.6/howto/cporting.html)の記述を踏襲)。

```c
#define GETSTATE(m) ((struct module_state *)PyModule_GetState(m))
```

詳しくは調査できていないが、
循環参照が起きるとガーベージコレクションが上手く働かない、
というのは、知っている人は知っている有名な話だろう。

ガーベージコレクションを知らない人向けの説明はしないが、
簡単に言えば、Python はコードを簡単に書ける利便性が売りな一方で、
便利さに起因する問題があるとだけ認識しておけばいいと思う。

それを回避するための手段とのことなので、導入しない手は無い。


## 5.5. mypkg_wrap.c (モジュール定義編)

いよいよモジュールの定義に移る。

```c
// mypkg モジュールの定義
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "libmypkg",                  // const char*: モジュール名。
    NULL,                        // const char*: docstring。
    sizeof(struct module_state), // Py_ssize_t: モジュールのサイズ。
    libmypkg_methods,            // libmypkg が含むメソッド一覧。
    NULL,                        // 「多段階初期化のためのスロット定義の配列」らしいが、
                                 // 一段回初期化なので NULL。
    libmypkg_traverse,           // 上で定義したガーベージコレクション用関数。
    libmypkg_clear,              // 上で定義したガーベージコレクション用関数。
    NULL,                        // ガーベージコレクションがモジュールオブジェクトを開放するときに呼び出す関数。
                                 // 今回は必要ないので NULL。
};
```

ここでモジュールの構造体を定義している。
ただ、`PyModuleDef_HEAD_INIT` という「おまじない」の後にモジュール名を書き、
その後もほぼ「おまじない」で埋まっていて、あまり説明できるところもない。
コピペする場合には `mypkg` 云々のところの名前を帰るように気をつけよう、というくらいしか言うことはない。

概要はコメントを参照のこと。


## 5.6. mypkg_wrap.c (モジュール初期化編)

ここもほぼ「おまじない」パートである。
先程定義した `moduledef` をなんやかんやして return する。

```c
// mypkg の __init__ に対応する C 言語コード
PyMODINIT_FUNC PyInit_libmypkg(void)
{
    PyObject *module = PyModule_Create(&moduledef);
    if (module == NULL)
    {
        return NULL; // Erorr on __init__ process.
    }
    struct module_state *st = GETSTATE(module);
    st->error = PyErr_NewException("libmypkg.Error", NULL, NULL);
    if (st->error == NULL)
    {
        Py_DECREF(module);
        return NULL; // Erorr on __init__ process.
    }
    return module;
}
```

なんやかんやというのは大体エラー処理で、
エラー処理をしないならば、以下のような定義でも良いくらい中身はあまりない。

```c
PyMODINIT_FUNC PyInit_libmypkg(void)
{
    return PyModule_Create(&moduledef);
}
```


## 5.7. mypkg_wrap.h (ヘッダ編)

基本的には[参考ページ](https://docs.python.org/ja/3.6/howto/cporting.html)を元に、
Python3 向けの以下の機能のみを残している。

```c
#ifndef __MYPKG_WRAP_HEADER__
#define __MYPKG_WRAP_HEADER__

#define PY_SSIZE_T_CLEAN
#include <Python.h>

struct module_state
{
    PyObject *error;
};

#define GETSTATE(m) ((struct module_state *)PyModule_GetState(m))

#endif
```

# 6. build 工程

## 6.1. libmypkg_wrap.so の作成

さて、いよいよ build (gcc) していく。
gcc によって Python からインクルード可能な libmypkg_wrap.so を作成することが目標だが、
これには以下のファイルが必要となる。

* libmypkg.so: libmypkg_wrap.so が参照するファイル。
* mypkg_wrap.c: 先程作成した、 mypkg.so を Python 用にラップする C 言語コード。

また、それぞれのインクルードディレクトリも指定してやる必要がある。

そこまでは通常のコンパイルと同じだが、今回は `<Python.h>` をインクルードしたため、
そのインクルードディレクトリも指定しなければならない。
そして、インクルードディレクトリ情報の表示は、 python3 の標準機能として提供されている。
`python3 -m sysconfig` で表示される情報の中に含まれるのだが、
`INCLUDEPY` という変数がそれだ。

```bash
$ python3 -m sysconfig | grep -E "\WINCLUDEPY\W"
        INCLUDEPY = "/usr/include/python3.11"
```

ということで、これもインクルードディレクトリに指定してやる。

最終的には、カレントディレクトリを src/mypkg_wrap に移し、
以下の gcc コマンドを実行すれば良い。

```c
gcc -I ../mypkg/include -I ../mypkg_wrap/include -I /usr/include/python3.11 \
    -shared -fPIC -o libmypkg_wrap.so \
    mypkg_wrap.c ../mypkg/libmypkg.so
```

これで、 src/mypkg_wrap ディレクトリ配下に libmypkg_wrap.so ができる。

## 6.2. src-python/libmypkg.so の作成と src-python/mypkg の実装

さて、では、libmypkg_wrap.so　を実際に呼び出す python パッケージが必要である。
ここでは極めて単純なものとして、
`src-python/mypkg` 配下に Python コードを書いて
libmypkg_wrap.so を呼び出すようにしよう。
(C 言語でも Python でも mypkg という名前にしてしまったので src ディレクトリを分けたが、
そこの名前が衝突しない限りは、両方とも src 配下に入れても構わない。
もちろん、 C 言語と Python でディレクトリを分けるのも有りだろう。)

まず、 cp コマンドか何かで、 libmypkg_wrap.so を、
src-python ディレクトリ配下に libmypkg.so という名前で配置する。
名前を変えるのは、 `libmypkg` という名前でモジュールを定義したからである
(逆に言うと、 C 言語ライブラリ mypkg と丸かぶりの名前で Python パッケージを作ろうとして苦労している…)。

Python はこの libmypkg.so を直接インポートできる。具体的には、以下のように書けばいい。

```py
import libmypkg
```

Python の検索パスが通っている限りは、これで問題なく mypkg をインポートできる。

これで、やっと `libmypkg` モジュールの `message()` メソッドとして、
C 言語ライブラリ `mypkg` の `message()` 関数を呼び出せるようになった。

ここでは、以下のコードを core.py に書こう。

```py
import libmypkg


def message(res):
    res = libmypkg.message(res)
    return res
```

そして、`__init__.py` でこれをインポートすることで、
`mypkg.message()` の形で Python の他のコードから呼び出せるようにする。

```py
from mypkg.core import message
```

長かったが、これでビルドお呼び実装は完了である。

# 7. test 確認

それでは、4節で作った pytest 環境を再実行することで、本章を〆ていこう。

トップディレクトリで `pytest` と実行すれば、自動的にテストコマンドを実行してくれるのだった。

```bash
$ pytest
Test session starts (platform: linux, Python 3.11.4, pytest 7.3.1, pytest-sugar 0.9.7)
rootdir: /tmp/3-c_wrapper_for_Python
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collecting ...
―――――――――――――――――――――――――――――――――――――――――――――――― ERROR collecting tests/test_mypkg.py  ―――――――――――――――――――――――――――――――――――――――――――――――――
ImportError while importing test module '/tmp/3-c_wrapper_for_Python/tests/test_mypkg.py'.
Hint: make sure your test modules/packages have valid Python names.
Traceback:
/usr/lib/python3.11/importlib/__init__.py:126: in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
tests/test_mypkg.py:4: in <module>
    import mypkg
E   ModuleNotFoundError: No module named 'mypkg'
collected 0 items / 1 error

======================================================= short test summary info =======================================================
FAILED tests/test_mypkg.py
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! Interrupted: 1 error during collection !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Results (0.04s):
```

おや、先程と同じエラー `No module named 'mypkg'` である。
なぜだろうか？

これは、 Python のライブラリ検索パスが通っていないからだ。
libmypkg.so も mypkg も、 src-python 配下にあるため、
src-python へとパスを通さなければならない。

通常はモジュールを環境にインストールすることによってそれを実現すべきだろうが、
こんな試作モジュールをインストールはしたくないので、
ここでは PYTHONPATH の環境変数にパスを追加することで対応をする。

```bash
$ PYTHONPATH="$PYTHONPATH:./src-python" pytest
Test session starts (platform: linux, Python 3.11.4, pytest 7.3.1, pytest-sugar 0.9.7)
rootdir: /tmp/3-c_wrapper_for_Python
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collected 2 items

 tests/test_mypkg.py ✓                                                                                                   50% █████

――――――――――――――――――――――――――――――――――――――――――――――――――――――――― test_run_mypkg_out  ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――

capfd = <_pytest.capture.CaptureFixture object at 0x7f05dce2c810>

    def test_run_mypkg_out(capfd):
        mypkg.message(0)
        captured = capfd.readouterr()
>       assert captured.out == "Hello world!\n"
E       AssertionError: assert '' == 'Hello world!\n'
E         - Hello world!

tests/test_mypkg.py:14: AssertionError

 tests/test_mypkg.py ⨯                                                                                                  100% ██████████
======================================================= short test summary info =======================================================
FAILED tests/test_mypkg.py::test_run_mypkg_out - AssertionError: assert '' == 'Hello world!\n'

Results (0.05s):
       1 passed
       1 failed
         - tests/test_mypkg.py:11 test_run_mypkg_out
Hello world!
Hello world!
```

どうやらパスは通ったようだが、エラーが発生してしまった。

エラーの内容を見ると、「標準出力に Hello world! と表示されるはずが、されていない」というものだ。
だが、テスト後に "Hello world!" と2回表示されていることにすぐに気づく。
これを見ると、 C 言語の printf にありがちなバッファリング問題を疑わざるを得ない。

細かい解説は省くが、 C 言語の printf 関数は、 printf を実行した瞬間に標準出力に書き込まれるのではなく、
一時的にバッファリングされていて、 CPU が空いたとき等に書き込まれる仕様となっている。

これを防いで強制的に書き込ませるには `fflush(stdout)` という関数を使う。
この関数を使うために、mypkg.c を修正してやる必要がある。

```c
#include <stdio.h>

int message(int res)
{
    printf("Hello world!\n");
    fflush(stdout); // Add this line.
    return res;
}
```

では、もう一度テストを実行してみよう。

```bash
$ PYTHONPATH="$PYTHONPATH:./src-python" pytest
Test session starts (platform: linux, Python 3.11.4, pytest 7.3.1, pytest-sugar 0.9.7)
rootdir: /tmp/3-c_wrapper_for_Python
plugins: tap-3.3, anyio-3.6.2, sugar-0.9.7
collected 2 items

 tests/test_mypkg.py ✓✓                                                                                                 100% ██████████

Results (0.01s):
       2 passed
```

ということで、無事テストが通ることが確認できた。

# 8. まとめ

ここでは、 C 言語を Python 用にラップするために最低限必要なコードと、
これまた最低限必要なビルド方法について学んだ。

次は、2章と3章を組み合わせて、 CMake で Python 用 C 言語 Wrapper を作成することを目指す。
