<style>
    div.title{
        text-align: center; line-height: 120%;
        font-size: xx-large; font-weight: bold; 
        padding-bottom: 0.3em; margin-bottom:1em;
        border-bottom-width: 4px; border-bottom-style: double;
    }
</style>
<div class="title">
[マニュアル（１） C language project 実装](LINK)
</div>

- [1. 調査](#1-調査)
- [2. ディレクトリ構成](#2-ディレクトリ構成)
- [3. パッケージインストール](#3-パッケージインストール)
- [4. test 工程 (test.bash 解説)](#4-test-工程-testbash-解説)
  - [4.1. test.bash 前半解説](#41-testbash-前半解説)
  - [4.2. test.bash 後半解説](#42-testbash-後半解説)
- [5. build 工程 (build.bash 解説)](#5-build-工程-buildbash-解説)
  - [5.1. Build mypkg](#51-build-mypkg)
  - [5.2. Build myapp](#52-build-myapp)
  - [5.3. 各種オプションの解説](#53-各種オプションの解説)
    - [5.3.1. -I と -l オプション](#531--i-と--l-オプション)
    - [5.3.2. 動的ライブラリ・静的ライブラリ・共有ライブラリ](#532-動的ライブラリ静的ライブラリ共有ライブラリ)
- [6. まとめ](#6-まとめ)

<!-- omit in toc -->
Introduction
============

まず python と関係なく、
C 言語のコンパイルをするところから始めよう。
つまり、 C 言語として message 関数を実装し、
それをライブラリとして共有できる形にして、
実際に C 言語の関数として呼び出してみる。

# 1. 調査

参考文献は以下の通り。

* C言語ゼミ, [共有ライブラリの作成と利用方法](https://c.perlzemi.com/blog/20210628105352.html) - 2021/06
* tree コマンド関連
  * koyo-miyamura, [簡単なディレクトリ構成図を書く](https://qiita.com/koyo-miyamura/items/eb740ef082914796b996) -- Qiita,  2018/07
  * tnakamura, [ディレクトリ構成図作るのに便利だよ tree コマンド](https://bashalog.c-brains.jp/12/12/03-093334.php) -- バシャログ, 2012/12

# 2. ディレクトリ構成

```tree
1-c_lang_project/
├── util.bash
├── build.bash
├── test.bash
├── src
│   ├── myapp
│   │   └── main.c
│   └── mypkg
│       ├── include
│       │   └── mypkg.h
│       └── mypkg.c
└── tests
　   ├── run_test.base.c
　   ├── run_test.base.h
　   └── test_mypkg.c
```

bash ファイル群には、ここで解説するコマンドを一括で実行できるように記述されている。
ただし、 util.bash は変数定義とユーティリティの定義なので説明は省く。

# 3. パッケージインストール

```bash
$ sudo apt install build-essential
```


# 4. test 工程 (test.bash 解説)

テスト駆動開発を標榜しているので、テストから実装していこう。
ただし、簡単な関数であることもあるし、
C 言語のテストフレームワークは導入や設定がややこしそうなので、
手製の assert テストを作る。

ただし、テストの発見だけ楽にしておくため、
`run_test.base.c` と `run_test.base.h` から
`run_test.c` と `run_test.h` を自動生成するようにしよう。

本質部分ではないので、この4章は読み飛ばしても構わない。
本気でやるなら、それこそテストフレームワークを使うべきだ。
私は bash は比較的使い慣れてるので、 bash 芸で簡易テストフレームワークを作る。

## 4.1. test.bash 前半解説

list_test_function_names は、各テストファイルから、
テスト用関数を集めてくるためのコードだ。

```bash
function list_test_function_names() {
    for f in "${TESTS_DIR:?}"/test_*.c; do
        if [ ! -f "$f" ]; then
            echo "test file not found"
            exit 1
        fi
        grep -E ^"int test_[a-zA-Z0-9_]+\(\s*\)" "$f" | while read line; do
            echo $line | sed -E "s/^.+(test_[a-zA-Z0-9_]+).+$/\1/"
        done
    done
}
```

まず、ワイルドカードで tests ディレクトリから `test_*.c` にマッチするファイルを取ってくる。
次に、その各ファイル中から、 `int test_*()` の形のテスト用関数を取ってくる。
そして、そのうちの `test_*` 部分をテスト名として出力する。

list_test_function_names を利用して、
`run_test(test_*, "test_*");` という C 言語中でテスト用関数を呼ぶコードを生成する。

```bash
function list_call_of_test_functions() {
    list_test_function_names | while read line; do
        echo "run_test($line, \"$line\");"
    done
}
```

この list_call_of_test_functions　関数が、
`run_test.base.c` の `// TEST_MAIN_BLOCK` を置き換える。

```bash
sed "s@// TEST_MAIN_BLOCK@$(list_call_of_test_functions)@" \
    "${TESTS_DIR:?}/run_test.base.c" \
    > "${TESTS_DIR:?}/run_test.c"
```

```c
// (置き換え前: run_test.base.c)
int main(int argc, char const *argv[])
{
    // TEST_MAIN_BLOCK
    return 0;
}

// (置き換え後: run_test.c)
int main(int argc, char const *argv[])
{
    test_res_of_message();
    return 0;
}
```

run_test 関数は run_test.base.c 中で定義された以下のような関数である。
「このテストを実行します」という旨のメッセージを表示して、テストを実行して、
「成功しました/エラーが起きました」と伝えるだけの関数だ。

```c
typedef int (*test_function)();

int run_test(test_function f, char *test_name)
{
    int test_has_succeeded;
    fprintf(stderr, "[TEST] Test: %16s.\n", test_name);
    test_has_succeeded = f();
    if (test_has_succeeded != 0)
    {
        fprintf(stderr, "[TEST] ERROR: %16s.\n", test_name);
    }
    fprintf(stderr, "[TEST] Success: %16s.\n", test_name);
}
```

次に、 run_test.h を作る。
ここは、 list_test_function_names を利用して、
`int test_*());` という、ヘッダ中での関数定義用を生成する。

```bash
function list_def_of_test_functions() {
    list_test_function_names | while read line; do
        echo "int ${line}();"
    done
}

```

本当は各 test_*.c ファイルに対応する .h ヘッダーファイルを作るべきだろうが、
ここではその工程は省略して、すべてのテスト用関数の定義を `run_test.h` に集約する。

この関数で、 run_test.base.h は以下のように置き換えられる。

```bash
sed "s@// TEST_MAIN_BLOCK@$(list_def_of_test_functions)@" \
    "tests/run_test.base.h" \
    > "${TESTS_DIR:?}/run_test.h"
```

```c
// (置き換え前: run_test.base.h)
#ifndef __RUNTEST_HEADER__
#define __RUNTEST_HEADER__

// TEST_MAIN_BLOCK

#endif

// (置き換え後: run_test.h)
#ifndef __RUNTEST_HEADER__
#define __RUNTEST_HEADER__

int test_res_of_message();

#endif
```

うーん、 C 言語ファイルをテキストファイルとして無理やり処理する強引さ。
本番プロジェクトで真似することはないだろう。

## 4.2. test.bash 後半解説

後述する build.bash を使って、
`include "mypkg.h"` としてインクルード可能な共用ライブラリである `libmypkg.so` を作成する。
これを使って、先程自動生成した `run_test.c` をコンパイルする
(../.build ディレクトリは、 build.bash で自動生成される一時ディレクトリである)。

``` bash
cd tests
gcc -I../.build/mypkg/include -o run_test \
    test_*.c run_test.c ../.build/mypkg/libmypkg.so
```

これで `run_test` が生成されるので、テストを実行する準備が整った。

```bash
./run_test
```

では、実際にテストを書こう。

`tests/test_mypkg.c` として、 以下のテスト用関数を書いてみる。

```c
#include <assert.h>
#include "mypkg.h"

int test_res_of_message()
{
    int res;
    res = message(0);
    assert(res == 0);
}
```

message が標準出力する内容を見るのは面倒なので、
引数に 0 と与えたら、返り値が 0 になる仕様として、そのテストを書いた。

`assert()`関数は、引数の中身が true なら何もせず、
false ならエラーとしてプログラムを終了する関数である。
あまり行儀の良い関数ではないが、行数や引数の中身など、
最低限の情報を教えながら終了してくれる。
実際にエラーが出ると、以下のように表示される。

```
[TEST] Test: test_res_of_message.
run_test: test_mypkg.c:9: test_res_of_message: Assertion `res == 0' failed.
./test.bash: line 49: 16075 Aborted                 ./run_test
```

このように、簡易的なテストを行うには十分だ。

そして、現時点では `libmypkg.so` が無いから gcc は通らないし、
それをコンパイルする build.bash も無ければ、 
そもそもコンパイル対象のコードを書いていない。
そこから始めていくことにしよう。


# 5. build 工程 (build.bash 解説)

それでは、本題に戻ろう。
目標は以下の通りだった。

> C 言語として message 関数を実装し、 それをライブラリとして共有できる形にして、
> 実際に C 言語の関数として呼び出してみる。

ここでは、 message 関数を `mypkg` という名前の共有ライブラリにする。
そして、別の `myapp` というアプリケーションから呼び出すことにしよう。

## 5.1. Build mypkg

まず、 `mypkg.h` を書こう。
message() という関数を作りたいのだった。

```c
#ifndef __MYPKG_HEADER__
#define __MYPKG_HEADER__

int message(int res);

#endif
```

次に、 `mypkg.c` を書こう。
message() では、 "Hello world!" と表示してもらう。

```c
#include <stdio.h>

int message(int res)
{
    printf("Hello world!\n");
    return res;
}
```

C 言語のコンパイルは、言わずとしれた gcc コマンドによって行う。
以下のコマンドで、共有ライブラリ `libmypkg.so` を作成できる。
細かいオプションの解説は「[5.3. 各種オプションの解説](#53-各種オプションの解説)」の節に譲る。

```bash 
$ cd src/mypkg
$ gcc -Iinclude -shared -fPIC -o libmypkg.so mypkg.c
```

`libmypkg.so` は、他のプログラムから共有ライブラリとして使える。
言い換えれば、`include "mypkg.h"` としてやれば、
誰でも `message()` 関数を呼び出せるということになる。

## 5.2. Build myapp

例として、次のような `myapp.c` を、 src/myapp に作ろう。

```c
#include <stdio.h>
#include "mypkg.h"

int main(int argc, char const *argv[])
{
    message(0);
}
```

`myapp.c` は、 `#include mypkg.h` で `message()` 関数を呼べるようにしている。
そして、これをコンパイルするには、以下のようにすれば良い。

```bash 
$ cd myapp
$ gcc -I../mypkg/include -o myapp main.c ../mypkg/libmypkg.so
```

先程の共有ライブラリと、 include 用のヘッダファイルが入ったディレクトリを指定して、
コンパイルする。
実際に実行すると、以下のようになる。

```bash
$ ./myapp
Hello world!
```

## 5.3. 各種オプションの解説

### 5.3.1. -I と -l オプション

`-I` はインクルードディレクトリを指定するオプションである。
`-l` はライブラリを指定するオプションである。
だが、そもそもインクルードファイルとかヘッダーファイルはなぜ存在するのか、
なぜわざわざライブラリを作ってそれをインクルードするのか。
自身で忘れがちなので整理しておく。

結論を先にいうと、あるアプリケーションやライブラリがあるとき、
ヘッダーファイル/インクルードファイルというのは、
そのインターフェースを定義するものである
(ここは私自身の経験からそうすべきと思う、というだけなので誤りかもしれない)。

卑近な例で喩えてみよう。例えば、「炊飯器」という機械を考えてみる。
これをアプリケーションだと見做すと、
「炊飯器」には「炊飯ボタン」がついている。
これがインターフェース(小難しく言えば、外部向けに公開された操作用の装置)が付いている。
一方で、「炊飯器」には「炊飯機能」がついているのだが、
私達はどんなふうに炊飯が行われているか、詳細については知らない。
これをプログラム風に言えば、
「その機能の詳細な実装がどのようになされているか(内部仕様)は公開されていない」となる。

炊飯器の例に限らず、
洗濯機は「ボタンを押したら洗濯する」というインターフェースと
「(タテ型だろうがドラム式だろうが)中のものを洗濯する」という実装を持っている。
テレビは「リモコン(ボタンを押したらチャンネルが変わる)」というインターフェースと
「電波を受け取って指定されたチャンネルの映像を表示する」という実装を持っている。
スマートフォンは「電話番号を押したら相手に電話をかける」というインターフェースと
「無線通信規格に従って指定された電話番号の相手と接続する」という実装を持っている。
いずれも、ユーザは自身に公開されたインターフェース(=説明書に書いてあるようなこと)だけ理解しておけばよく、
内部の細かいことを知る必要がない。

これがプログラミングにおけるカプセル化、
専門用語で言えば Open-Closed の原則と呼ばれるものである。
このインターフェースと実装の分離を上手くすると、
機能を使う側がやるべきことを変えずに、その中身だけを新しくできる。
そして、外見を変えずに中身だけ更新できるというのは、
資産の再利用や置き換えがしやすい、という利点がある。

例えば「最近ボーナスが入ったから、炊飯器を新しくして白米のクオリティを上げよう」と思ったとき、
あなたがやるべきことは炊飯器をグレードアップして、いつもと同じように「炊飯ボタン」を押すだけでいい。

逆に、「土鍋で米を炊くと美味しくなるらしい」と聞いたから試してみよう、という場合には、
あなたは土鍋を使ってどうやって米を炊くか一から調べて、
鍋に米と水を入れ、焦げないように火加減と熱する時間を管理し……
といった、いつもとは全く違うことをしなければならなくなる。

料理への熱意があればそういうこともできるかもしれないが、
機能のアップグレードの度になんでもかんでもこんなことをしていたら、
人生というのは相当複雑になってしまうだろう。
実際、ただの炊飯器でも、今や炊飯モードがたくさんあるから、
メーカーを変えるだけでも「同じ機械とは思えない」という人もいるかもしれない。

閑話休題。

プログラムでは、例えばパフォーマンスチューニングとか
セキュリティアップデートとかの細かなアップデートがやりやすくなる。
逆に、そうした機能追加のたびに過去の機能が使えなくなることを繰り返されると、
その機能を使う人からすると溜まったものではない。
丁度、あるバージョンの PlayStation のソフトが後継ハードで使えなくなるようなものだ。
あるいは、アップデートの度に仕様が変わって前と同じように使えなくなる
OS についても似たようなことが言える (Windows、お前のことだ)。

そのため、自分がプログラムを作る際も、
外部に公開する関数の定義(シグネチャ)だけをヘッダーファイルにまとめ、
それを更にインクルードディレクトリにまとめるようにする。
そうすることで、そのプログラムを使おうとする人は、
その .h の中身だけ読めば、あなたが作った .c の中身までは知らなくても、
プログラムを使うことができるようになる。
言い換えれば、インクルードディレクトリを説明書のように使うことができるのである。

とはいえ、コンパイル時には、実際にその中身を実行してもらわなければならない。
そのためには、使う側は .c ソースコードで書かれた実装を受け取らなければならない。
このとき、その .c を直接渡してもいいのだが、
複数の .c ファイルの実装をまとめた一つの「ライブラリ」として渡してもらえると、
使う側でコンパイルしなくてもいいから楽だ。
また、 .c の数に増減があった場合にもその影響を受けずに済む。
他にも、企業戦略的には、 .c の中身が企業秘密という場合もあるだろう。
その場合は「ライブラリ」として .c の中身を隠蔽してもらえると助かる。

そういった諸々の理由で、自分が作ったプログラムについて、

* 「外見(インターフェース)」はヘッダーファイル/インクルードディレクトリにまとめる。
* 「中身(実装)」はライブラリにまとめる。

というのが通例となっている、のだと思う。


### 5.3.2. 動的ライブラリ・静的ライブラリ・共有ライブラリ

ライブラリにはいくつかの種類がある。
ややこしいしこれも忘れがちなので、これについても簡単にまとめておく。

まず、動的ライブラリとか静的ライブラリというが、
これらは「ライブラリのリンク方法」によって区別されており、
正確には「動的リンク」と「静的リンク」というのが正しい。
「動的 (dynamic)」と「静的 (static)」というのは英語的な表現である。
順番が前後するが、「静的」という言葉のイメージは、
「最初から全部完成してそれ以降変わることがない」というようなものだ。
逆に、「動的」という言葉のイメージは、
「使おうとしたときに必要に応じて機能を付け加えていく」というようなものになる。

これを「ライブラリのリンク方法」に当てはめると、以下のようになる。

* 静的リンクライブラリ: ライブラリ/プログラムをコンパイルするとき(=最初に作るとき)に使う用のライブラリ。
* 動的リンクライブラリ: ライブラリ/プログラムを実行するときに使う用のライブラリ。

`gcc` を実行するときにライブラリを指定したい場合は、静的ライブラリを用いる。
一方、プログラムを実行する際にライブラリを指定したい場合は、動的ライブラリを用いる
(この際、ライブラリの利用方法として、動的リンクと動的ローディングは混同されがち)。
普通にライブラリを使う場合、これらを意識することはあまり無いと思う。
通常は静的リンクで済むと思うが、実行時にプログラムの実装をごそっと入れ替えたい場合には、
動的リンクを用いることになる。

共有ライブラリというのは、大体動的リンクと一緒に使われるが、厳密には異なる概念である。
共有ライブラリという言葉があるということは、
「共有でないライブラリ」あるいは「非共有ライブラリ」とでもいうべきものがある。

例えば、あなたがキッチンの設備を整えようとしているとする。
そのとき、大体コンロや水道は備え付けものを使うことになり、
これらは他のキッチンと「共有」することができない。
一方、炊飯器や冷蔵庫は、引っ越す前に使っていたものを使ってもいい。
そういう意味で、他のキッチンと「共有」することができる。

プログラムでも同じような事情があり、
例えばあなたがプログラムを3つのライブラリに分けてコンパイルしようとするとき、
あなた自身がそのライブラリを使えればいいだけなら、
プログラム内でのライブラリの配置を固定(=備え付け)しておけばいい。

しかし、他の人の作ったライブラリを使う場合には、
その人のプログラムに備え付けられたライブラリになっていると使い物にならない。
これは無理やり例えれば、他の家に備え付けられたキッチンを引っ剥がして
無理やり自分の家のキッチンスペースに入れるようなことになる。
プログラムの場合は、大抵の場合コンパイルエラーとなるか、
パフォーマンスが悪化する(らしい。試したことはない)。

そのため、他の人でも使える、炊飯器や冷蔵庫のようにするためには、
それが「共有可能(=どこにでも置ける)」ものとなっている必要がある。
それをコンパイル時に指定してやるのが、`-shared -fPIC` オプションである。
これを指定しない場合は、単に分割コンパイルのためにライブラリを作ることになる。

# 6. まとめ

この章では、 C 言語における共有ライブラリの作り方・使い方の復習を行った。
include やライブラリ、動的ライブラリと静的ライブラリなど、
この時点でややこしい概念が多く出てくるが、
基本の「キ」でもあるので重要なところでもある。