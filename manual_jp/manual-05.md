<!-- omit in toc -->
マニュアル（５）Docker と setup.py の整備
============================================================

- [1. 調査](#1-調査)
- [2. ディレクトリ構成](#2-ディレクトリ構成)
- [3. パッケージインストール](#3-パッケージインストール)
  - [3.1. WSL へ Docker をインストール](#31-wsl-へ-docker-をインストール)
  - [3.2. WSL 1 から WSL 2 へ](#32-wsl-1-から-wsl-2-へ)
    - [3.2.1. カーネルコンポーネント更新](#321-カーネルコンポーネント更新)
    - [3.2.2. bios で仮想化を有効化](#322-bios-で仮想化を有効化)
    - [3.2.3. WSL バージョン更新](#323-wsl-バージョン更新)
  - [3.3. docker の起動](#33-docker-の起動)
- [4. test 工程](#4-test-工程)
  - [4.1. Docker コンテナの準備](#41-docker-コンテナの準備)
    - [4.1.1. Python コンテナ](#411-python-コンテナ)
    - [4.1.2. mypkg\_base コンテナ](#412-mypkg_base-コンテナ)
    - [4.1.3. mypkg\_install コンテナ](#413-mypkg_install-コンテナ)
    - [4.1.4. mypkg\_run コンテナ](#414-mypkg_run-コンテナ)
  - [4.2. docker-compose.yml](#42-docker-composeyml)
  - [4.3. docker compose](#43-docker-compose)
- [5. setup.py を用いたパッケージング・インストール](#5-setuppy-を用いたパッケージングインストール)
  - [5.1. setup.py の基本構成](#51-setuppy-の基本構成)
  - [5.2. カスタムインストール](#52-カスタムインストール)
  - [5.3. src レイアウトへの対応](#53-src-レイアウトへの対応)
  - [5.4. setup.py の全容](#54-setuppy-の全容)
- [6. CMakeLists.txt の調整](#6-cmakeliststxt-の調整)
- [7. test 実行](#7-test-実行)
- [8. まとめ](#8-まとめ)


<!-- omit in toc -->
Introduction
============

さて、それでは、 CMake と Python/C Wrapper の両方を学んだところで、
CMake で Python/C Wrapper コードをビルドしていこう。

# 1. 調査

* [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository) -- docker docs, 2023/08
* 小泉 健太郎, [【入門】Docker Desktopとは何ができるの？インストールと使い方](https://www.kagoya.jp/howto/cloud/container/dockerdesktop/) -- カゴヤのサーバー研究室, 2023/03
* craigloewen-msft, etc., [カーネルコンポーネントのダウンロード](https://learn.microsoft.com/ja-jp/windows/wsl/install-manual#step-4---download-the-linux-kernel-update-package) -- Microsoft, 2023/06
* quzq, [WSL2を操作しようとすると「カーネル コンポーネントの更新が必要です」と表示される](https://qiita.com/quzq/items/3de595e14426d0352fc4) -- Qiita, 2020/04
* [WSL 既定ディストリビューションの変更方法](https://kb.seeck.jp/archives/16946) -- SEECK.JP サポート, 2020/09
* [Dockerfile のベストプラクティス](https://docs.docker.jp/engine/articles/dockerfile_best-practice.html) -- Docker Docs Ja Project, 2015
* Python Software Foundation, [setup スクリプトを書く](https://docs.python.org/ja/3/distutils/setupscript.html) -- Python Documentation, 2023/08

# 2. ディレクトリ構成

基本的に 4-cmake_for_python_c_wrapper を引き継ぐ。
更新点は、ファイル名末尾に `(*)` とつけている。

```tree
5-setup_with_docker
└── util.bash
├── build.bash
├── CMakeLists.txt
├── README.md (*)
├── setup.py (*)
├── docker (*)
│   ├── docker-compose.yml (*)
│   ├── mypkg_base (*)
│   │   └── Dockerfile (*)
│   ├── mypkg_install (*)
│   │   └── Dockerfile (*)
│   └── mypkg_run (*)
│       ├── Dockerfile (*)
│       └── test.bash (*)
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

## 3.1. WSL へ Docker をインストール

本章では Docker を使う。
「Windows では Docker Desktop を使えば良い」……というのは過去の話で、
有料化したため可搬性が無くなった。
もちろん、個人利用や大学での利用、オープンソースプロジェクト利用なら問題ない。
しかし、いざ営利目的プロジェクトとなったとき、あるいは非営利でも企業で使いたいとなったときに、
「Docker Desktop しか使えないから Docker も使えない……」とならないようにしたい。

ではどうするかというと、 Docker Desktop、つまり、GUI サポート無しで Docker をインストールすればいい。
[ここ](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)の
手順に従って docker desktop を使わずに docker をインストールできる。
セキュリティソフトによっては curl の接続を遮断されるので除外設定するよう要注意。

```bash
# apt をアップデートし、必要なパッケージをインストールする。
$ sudo apt-get update
$ sudo apt-get install ca-certificates curl gnupg
# Docker の公式 GPG キー (apt-get でインストールできるようにするためのもの) をインストールする。
$ sudo install -m 0755 -d /etc/apt/keyrings
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
$ sudo chmod a+r /etc/apt/keyrings/docker.gpg
# * Linux Mint とかだと VERSION_CODENAME ではなく UBUNTU_CODENAME らしいので注意。
$ echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# 追加した GPG キーを反映するために update をしてから、 apt-get で必要なパッケージをインストールする。
$ sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
# テスト用に hello-world コンテナを実行してみる。
$ sudo docker run hello-world
```

## 3.2. WSL 1 から WSL 2 へ

これだけで Docker のインストールが上手くいったらいいのだが、
少なくとも私は以下のようなエラーが出た。

```bash
$ docker run hello-world
docker: Error response from daemon: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: waiting for init preliminary setup: EOF: unknown.
ERRO[0002] error waiting for container:
```

実は Docker を Windows 環境にインストールするためには、
色々と事前準備が要る。
ここでは、私の経験に基づく範囲で、必要な作業を整理しておこう。

* カーネルコンポーネントを更新する。
* bios から仮想化機能を ON にする。
* WSL のバージョンを 2 にする。

### 3.2.1. カーネルコンポーネント更新

[ここ](https://learn.microsoft.com/ja-jp/windows/wsl/install-manual#step-4---download-the-linux-kernel-update-package) にある
更新プログラムをインストールする
(リンク切れしてなければ、[このリンク](https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi)から直接 msi をダウンロードしてもいい)。

リンク先ではこの後 `wsl --set-default-version 2` としろと言われるが、
そうしようとすると「BIOS で仮想化を有効にしろ」と言われる。

### 3.2.2. bios で仮想化を有効化

この記事を見ている人で bios を知らない人はいないと思うが、
要は PC 起動時に F5 とかで入れる画面にいけということである。
いや、もしかすると最近の SSD やら NVMe やらで爆速化した起動画面しか知らない世代は、
BIOS といってもピンとこないかもしれない。
そういう人は、以下のコマンドを実行してほしい (Windows 専用コマンドなので要注意)。
CLI が使えない人は、そもそもここまでの記事で振り落とされてるだろうから、気にしないでいいだろう。

```
shutdown /r /fw
```

すると、いわゆる「BIOS 画面」に入るわけだが、ここからは自分で探すしかない。
私の場合は CPU の詳細設定画面に仮想化機能 (Virtualization 云々) みたいな項目があって、
それを有効化 (Enable) した。Save & Exit で設定を保存してから閉じるのも忘れないように。

日本語の UI を提供してくれているところも多いと思うが、
詳細な設定項目は英語のままなことがほとんどなので注意する。
PC が一台しかない人は PC で調べながら設定する、
というのができないので、事前にちゃんと調べるか、何回か BIOS を開く覚悟をしてやってほしい。

いや、今どきはみんなスマホを持っているだろうから大丈夫か。

その後、コマンドからも
[「仮想マシンプラットフォーム」オプション機能を有効にする](https://learn.microsoft.com/ja-jp/windows/wsl/install-manual#step-3---enable-virtual-machine-feature)
必要がある。
何をしているのかよくわからないが、とりあえず以下の手順に従おう。

```
$ dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

展開イメージのサービスと管理ツール
バージョン: 10.0.19041.844

イメージのバージョン: 10.0.19044.2728

機能を有効にしています
[==========================100.0%==========================]
操作は正常に完了しました。
```

そうしたら、 **PC を再起動して**、最後のステップに進もう。


### 3.2.3. WSL バージョン更新

WSL のバージョンを 2 に更新しよう。
以下のコマンドを実行していく。

```bash
$ wsl --set-default-version 2
WSL 2 との主な違いについては、https://aka.ms/wsl2 を参照してください
この操作を正しく終了しました。
$ wsl --set-version Ubuntu 2
変換中です。この処理には数分かかることがあります...
WSL 2 との主な違いについては、https://aka.ms/wsl2 を参照してください
変換が完了しました。
$ wsl -l -v
  NAME            STATE           VERSION
* Ubuntu          Stopped         2
  Ubuntu-22.04    Stopped         1
```

## 3.3. docker の起動

これで、 `wsl` コマンド (もしくは `bash` コマンド) から docker を起動する準備ができた。

```bash
$ sudo docker run hello-world
docker: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?.
See 'docker run --help'.
```

……と思ったら、最後のトラップがきた。
どうも、色々再起動している間に docker service が停止しているようだ。
これは `sudo service docker start` で開始できる。

```bash
$ sudo service docker start
 * Starting Docker: docker
```

それでは、改めて hello world しよう。

```bash
$ sudo docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
719385e32844: Pull complete
Digest: sha256:926fac19d22aa2d60f1a276b66a20eb765fbeea2db5dbdaafeb456ad8ce81598
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

色々とメッセージが表示されているが、8行目あたりでちゃんと「Hello from Docker!」と出てることが確認できる。

# 4. test 工程

今回の目的を再確認しておくと、
今回は Python モジュール mypkg をパッケージングして、
インストールできるようにすることだ。

そのためのテストを行いたいが、
現環境にインストールすると、アンインストールもセットにしないといけないし、
アンインストールですべてのファイルを消せているかの確認も必要になる。

別の手段として、インストールを試みる度にクリーンな Python (Ubuntu) 環境を作ろう。
そのために、がんばって準備した Docker を使っていく。

## 4.1. Docker コンテナの準備

mypkg インストールテスト用の Python コンテナの準備をしよう。

ここでは、以下の1+3つのコンテナを用意していく。

* Python コンテナ `python`
* 必須ライブラリインストール済みコンテナ: `mypkg_base`
* mypkg インストールテストコンテナ: `mypkg_install`
* mypkg 実行テストコンテナ: `mypkg_run`

### 4.1.1. Python コンテナ

`python` は公式コンテナなので、 pull だけでいい。
とはいえ、 GUI は使えないので、コマンドを書いておく。

```bash
$ docker pull python
Using default tag: latest
latest: Pulling from library/python
785ef8b9b236: Pull complete
(...)
4de52e7027c5: Pull complete
Digest: sha256:b3732a67dff67984721cabcb08cec7f7ccce87adfc96de7d5209fbfd19579f3f
Status: Downloaded newer image for python:latest
docker.io/library/python:latest
```

これをベースに、他のコンテナを作っていく。

### 4.1.2. mypkg_base コンテナ

mypkg_base は、必要な前提ライブラリをインストールした、インストールの基礎となるコンテナである。
なので、基本的には以下の bash が動けばいい。

```bash
apt-get install cmake python3-pip
pip3 install pytest
```

要はこれが動く Dockerfile を作ればいいのだが、
一から構築するというのは割と面倒で、以下のようなコード量になる。
説明はコメントを参照してほしい。

```dockerfile
# 元となるイメージを python で指定。わざわざ ARG を挟んでいるのは、
# docker compose の build-args で設定変更が容易となるように意図している。
ARG baseimage=python
FROM ${baseimage}

# FROM で用いない変数は、 FROM の直後で定義する。
# ここでは、プロジェクト名として、作業ディレクトリのトップディレクトリ名を決めている。
ARG projectname=myproject
RUN [ -n "${projectname}" ]
RUN mkdir -p /${projectname}/lib/
WORKDIR /${projectname}

# apt の設定をしている。というのも、デフォルトのサーバだと位置的な問題で遅いため。
# best-practice が知りたい人は、以下を参照。本来は apt update も避けるように書いてある。
#   c.f.: https://docs.docker.jp/engine/articles/dockerfile_best-practice.html
# ここでは、日本の JAIST のリポジトリを使うように設定して、 apt を高速化している。
RUN perl -p -i.bak -e \
    's%(deb(?:-src|)\s+)https?://(?!archive\.canonical\.com|security\.ubuntu\.com)[^\s]+%$1http://ftp.jaist.ac.jp/pub/Linux/ubuntu/%' \
    /etc/apt/sources.list
ENV TZ=Asia/Tokyo
RUN apt-get update \
    # タイムゾーンの設定のためのインタラクティブなプロンプトを要求されるのを回避する設定。
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    cmake \
    python3-pip \
    # キャッシュを削除して、コンテナの容量をなるべく小さく留める。
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# pip の設定を行う。
RUN pip3 install --upgrade pip
RUN pip3 install \
    pytest \
    # キャッシュを削除して、コンテナの容量をなるべく小さく留める。
    && pip3 cache purge
```

たった二行を実行するためだけに大層な分量になった。
クリーン環境からのインストールであることもあるから仕方ないと思うことにして、
他のコンテナもサクサクと用意してしまおう。

### 4.1.3. mypkg_install コンテナ

次は、実際に mypkg をインストールするコンテナである。
インストールするためには、インストールするファイルを、
Docker コンテキストに入れておいてやらなければならない。

「Docker コンテキスト」とは、
docker build を実行するときに指定するディレクトリのことである。
如何に相対パスを駆使してコンテキスト外のファイルを参照しようとしても、
docker build はこの**コンテキスト内部のファイルしか参照できない**。

逆に、コンテキスト内のファイルの情報はすべて持とうとする。
言い換えれば、ビルドしたイメージに**コンテキスト内のファイルすべてが含まれる**。
例え Dockerfile 内で参照していないとしても、だ。
なので、 Docker コンテキストは、ビルドイメージごとにディレクトリを作り、
必要最低限のファイルだけがそこに入っているようにしなければならない。

こういった事情から、コンテキスト内のファイルは圧縮している方が望ましい。
tar を使って、 docker ディレクトリ以外のファイルを圧縮し、
コンテキストとする予定の docker/mypkg_install 下に放り込もう。

```bash
tar -czf docker/mypkg_install/mypkg.tar.gz --exclude='docker' .
```

Docker では、コンテキストにあるファイルは `ADD` コマンドでコンテナに追加できる。
このとき、圧縮ファイルは自動で展開してくれるので、解凍については考えなくて良い。

その後は、以前にやったような `cmake .` や `make` を行う。
そして最後に、インストールを `make install` で行うことにしよう。
setup.py を使ったインストール方法はまだ説明できていないが、
`make install` で統一できるとスマートである。

以上の方針を Dockerfile に落とし込むと、以下のようになる。

```dockerfile
# mypkg_base と同様の変数定義。ただし、一部は後で docker-compose.yml から与える。
ARG baseimage
FROM ${baseimage}

ARG projectname=myproject
ARG packagename=mypkg
RUN [ -n "${projectname}" ] \
    && [ -n "${packagename}" ]

# mypkg をコピーするディレクトリを設定し、コピー (ADD) する。
RUN mkdir -p /${projectname}/lib/${packagename}
WORKDIR /${projectname}
ADD ${packagename}.tar.gz /${projectname}/lib/${packagename}
WORKDIR /${projectname}/lib/${packagename}

# mypkg をビルド・インストールする。
RUN cmake .
RUN make
RUN make install
```

### 4.1.4. mypkg_run コンテナ

最後に、テストを実行するコンテナである。
テスト内容まで build 内部でやるのはおかしな話なので、
test.bash にテスト内容を書いて、
これをコンテナのエントリーポイントに指定して実行してもらうことにしよう。

コンテナが test.bash を実行できるようにするには、

* test.bash の中身を書いて、
* test.bash を Docker コンテキストにおいて、
* test.bash をコンテナにコピー(COPY or ADD) する、

という工程を踏まなければならない。

test.bash の中身は以下のようにしよう。

```bash
#!/usr/bin/env bash

set -ex

make test
(
    cd /
    python3 -c "import mypkg"
)
pytest
```

まず、 `make test` で、今までのテストが通ることを確認する。

次に、 `python3 -c "import mypkg"` で、
mypkg がインストールされていること 
(つまり、グローバルに mypkg をインポートできること) を確認する。

最後に、 (PYTHONPATH を通さずに) pytest を実行しても、
問題なく動作することを確認する。

後は、この test.bash を docker/mypkg_run 配下に作成して、
それをコンテナにコピーするだけの最低限の Dockerfile を書けばいい。

```dockerfile
# mypkg_base と同様の変数定義。ただし、一部は後で docker-compose.yml から与える。
ARG baseimage
FROM ${baseimage}

ARG projectname
RUN [ -n "${projectname}" ]

RUN mkdir /${projectname}/test
COPY test.bash /${projectname}/test
```

## 4.2. docker-compose.yml

`docker compose` は、複数の docker イメージを扱うときに便利なコマンドだ。
あまり今回のようなビルドステージ的な使い方には向いていないのだが、
docker コマンドよりは使い勝手が良い。
なので、私は大体は docker-compose.yml で管理するようにしている。

というわけで、今回の Dockerfile ファイル達も docker-compose.yml で管理することにしよう。

docker-compose.yml は、「サービス」という単位でコンテナを定義する。
これが docker compose の設定ファイルとなり、
複数のサービスが連携した複合的な Docker サービスを作るために使われる。

基本的にはビルド済みイメージを使ってサービス用コンテナが作られる訳だが、
`docker compose build <service>` コマンドで、
サービス名を指定するだけでファイルの設定に従って Docker イメージをビルドしてくれる。

サービス名が `serviceX` のとき、 context を指定してビルドさせるには、
以下のように書けばいい。

```yml
services:
  serviceX:
    image: image_name
    build:
      context: ./context_dir
```

というわけで、各 Dockerfile に以下のようなサービス名とイメージ名をつけるとして、
`docker-compose.yml` を作ってみよう。

* サービス名: mypkg_test_base
  + イメージ名: myproject_mypkg_base:latest
* サービス名: mypkg_test_install
  + イメージ名: myproject_mypkg_install:latest
* サービス名: mypkg_test_run
  + イメージ名: myproject_mypkg_run:latest

要は、サービス名の接頭辞に `mypkg_test_` をつけて、
イメージ名の接頭辞に `myproject_mypkg_` を付けただけだ。
イメージ名の方にだけ myproject と付けているのは、
`mypkg_base` とかのイメージ名だと他のものと被るかもしれないと思ったためである。
名前の衝突を気にしないなら、もっと短い名前でもいい。

先の書き方に従いつつ、 `bulid` の項目に `args` を追加したり、諸々の項目を追加していくと、
以下のような docker-compose.yml が出来上がる。

```yml
version: '3'
services:
  mypkg_test_base:
    image: ${PROJECT_NAME}_${PACKAGE_NAME}_base${BUILD_TAG}
    build:
      context: ./${PACKAGE_NAME}_base
      args:
        baseimage: python
        projectname: ${PROJECT_NAME}
  mypkg_test_install:
    image: ${PROJECT_NAME}_${PACKAGE_NAME}_install${BUILD_TAG}
    build:
      context: ./${PACKAGE_NAME}_install
      args:
        baseimage: ${PROJECT_NAME}_${PACKAGE_NAME}_base${BUILD_TAG}
        projectname: ${PROJECT_NAME}
        packagename: ${PACKAGE_NAME}
    depends_on:
      - mypkg_test_base
  mypkg_test_run:
    image: ${PROJECT_NAME}_${PACKAGE_NAME}_run${BUILD_TAG}
    build:
      context: ./${PACKAGE_NAME}_run
      args:
        baseimage: ${PROJECT_NAME}_${PACKAGE_NAME}_install${BUILD_TAG}
        projectname: ${PROJECT_NAME}
    depends_on:
      - mypkg_test_install
    working_dir: /${PROJECT_NAME}/lib/${PACKAGE_NAME}
    entrypoint: ["/${PROJECT_NAME}/test/test.bash"]
```

先のテンプレートに当てはまらない部分を簡単に説明しよう。

* services.<name>.build.args: `--build-args` オプションに当たる。ここで設定した変数は、 Dockerfile 内で変数として利用可能になる。
* services.<name>.depends_on: サービスが他のサービスを前提としていることを `docker compose` に指示するために使う。ただ、ビルド時には意味がないし、そもそも前者2つはサービスコンテナとして使うつもりもないので、意図を明示するためだけの項目になっている。
* services.<name>.working_dir, entrypoint: それぞれ、ワーキングディレクトリと、エントリーポイントである。言い換えれば、「このディレクトリで、このコマンドを実行しろ」というものだ。

さて、追加で説明しなければならないのは、
この中で使っている定数の値の設定だ。
PROJECT_NAME, PACKAGE_NAME, BUILD_TAG の3つの定数を使っているが、
これはこの docker-compose.yml 後で再利用しやすいようにと意図したものである。

実際の定数の定義は、 `.env` ファイルで行う。
docker-compose.yml と同じディレクトリに、
以下のように `.env` ファイルを書くことで、定数を自動的に読み込んでくれる。

```bash
PROJECT_NAME=myproject
PACKAGE_NAME=mypkg
BUILD_TAG=
```

注意点として、実際の例示ソースコードには、プロキシー設定に関する build-args も追加している。
Warning が鬱陶しかったら消しても良いし、
何らかのプロキシー下で動かしている人は、
wsl 実行環境中の http_proxy や https_proxy を引き継げるようになっているので、
そのまま利用しても構わない。

さて、ともあれ、これで `docker compose build` する準備が整った。

## 4.3. docker compose

docker-compose.yml をがんばって書いたおかげで、
ビルドコマンドはシンプルで済む。

```bash
docker compose build mypkg_test_base
docker compose build mypkg_test_install
docker compose build mypkg_test_run
```

そして、最終的に以下のコマンドでテストを実行できる。

```bash
docker compose up
```

この時点で実際に実行してみると、以下のようになる。

```bash
$ docker compose build mypkg_test_base
[+] Building 0.1s (12/12) FINISHED
(...)                                    0.0s
 => => exporting layers                                                       0.0s
 => => writing image sha256:5acacbca4003d27291dddd60886ef4cef30c5cb330554468  0.0s
 => => naming to docker.io/library/myproject_mypkg_base                       0.0s
$ docker compose build mypkg_test_install
[+] Building 4.8s (14/14) FINISHED
(...)
 => => exporting layers                                                       0.1s
 => => writing image sha256:f0de0ef7200a1d11ca7fee73d7fe634564dcfa62ed92def9  0.0s
 => => naming to docker.io/library/myproject_mypkg_install                    0.0s
$ docker compose build mypkg_test_run
[+] Building 1.2s (9/9) FINISHED
(...)
 => exporting to image                                                        0.1s
 => => exporting layers                                                       0.1s
 => => writing image sha256:aacae4b345a01ede4ba537fbd2bad7904b3ac0c3c3fb0d57  0.0s
 => => naming to docker.io/library/myproject_mypkg_run                        0.0s
$ docker compose up
[+] Running 3/3
 ⠿ Container docker-mypkg_test_base-1     Created                             0.0s
 ⠿ Container docker-mypkg_test_install-1  Recreated                           0.1s
 ⠿ Container docker-mypkg_test_run-1      Recreated                           0.1s
 Attaching to docker-mypkg_test_base-1, docker-mypkg_test_install-1, docker-mypkg_test_run-1
docker-mypkg_test_base-1 exited with code 0
docker-mypkg_test_install-1 exited with code 0
docker-mypkg_test_run-1      | + make test
docker-mypkg_test_run-1      | Running tests...
docker-mypkg_test_run-1      | Test project /myproject/lib/mypkg
docker-mypkg_test_run-1      |     Start 1: test_with_run_test
docker-mypkg_test_run-1      | 1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
docker-mypkg_test_run-1      |     Start 2: test_with_pytest
docker-mypkg_test_run-1      | 2/2 Test #2: test_with_pytest .................   Passed    0.24 sec
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | 100% tests passed, 0 tests failed out of 2
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | Total Test time (real) =   0.25 sec
docker-mypkg_test_run-1      | + cd /
docker-mypkg_test_run-1      | + python3 -c 'import mypkg'
docker-mypkg_test_run-1      | Traceback (most recent call last):
docker-mypkg_test_run-1      |   File "<string>", line 1, in <module>
docker-mypkg_test_run-1      | ModuleNotFoundError: No module named 'mypkg'
docker-mypkg_test_run-1 exited with code 1
```

ログが長くて恐縮だが、 `docker compose build` の工程は滞りなく終了した一方で、
最後から二行目で`No module named 'mypkg'` というエラーが出ていることが分かる。
これは `python3 -c 'import mypkg'` でインポートできるか確認したテストで起きたエラーであり、
`make install` が実装されていないために起きたものだ。
グローバル環境に mypkg がインストールされていれば、問題なくなるはずである。

# 5. setup.py を用いたパッケージング・インストール

Python パッケージのインストールには、 setup.py を使うのが通例だ。

正確には、通例**だった**。
今は setup.py を使ってインストールしようとすると、
pyproject.toml などの新しい方法でパッケージングしろと怒られる。

だが、正直融通が効かないと言うか、
前提としているバックエンドが意味不明なので、
今回のような CMake やら .so ファイル導入やらを伴う処理にすら難儀する。
なので、安定版として Python コードで融通が効く
setup.py もちゃんと知っておいた方がいい。
pyproject.toml の利用方法は6章に譲る。

## 5.1. setup.py の基本構成

閑話休題。

setup.py は、基本的にプロジェクトのトップディレクトリに置いて、
そのパッケージの詳細情報とインストールのための情報を記述する Python スクリプトである。
その構成は単純で、

```py

from setuptools import setup

setup(
    name="mypkg",
    # ...
)
```

みたいな感じで、インストール対象のパッケージに対して `setup(...)` という設定用関数を書けばよい。

## 5.2. カスタムインストール

純粋な Python スクリプトなら本当にその流れに沿っていけばいいのだが、
今回は libmypkg.so という CMake で作られたライブラリを mypkg に含めたい。

CMake でコンパイルさせたようなことを setup.py の拡張としてやらせることもできるのだが、
CMakeLists.txt よりも遥かに柔軟性に欠ける。
せっかく CMakeLists.txt を作ったのだから、その成果ファイルだけ利用することにしよう。

その場合は、 setuptools の install をオーバーライドするようなクラスを作る。
以下のような感じだ。

```py
from setuptools.command.install import install

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
    # ...
    cmdclass={"install": CustomInstall},
)
```

CutomInstall は、通常の install を上書きしてカスタムした、
カスタムインストールクラスである。
どうカスタムしたかといえば、単にインストールする前に、
「インストール先のライブラリパスに libmypkg.so をコピーする」
という処理を挟んだだけだ。

逆になぜこれが必要なのかというと、
setup.py を使った方法では、基本的に .py 拡張子のファイルしか
パッケージング対象とみなしてくれないからである。
だから、敢えてライブラリにファイルを入れるには、自分でコピーするしかない
(もしかしたら、他のビルドツールなら、カスタムクラスを作るなんて
特別なことはしなくてもいいかもしれない。しかし、
とにかくコピーしなければならないという基本は同じだろう)。

## 5.3. src レイアウトへの対応

もう一点、 setup.py は、同じディレクトリ
(あるいは setup.py を実行したワーキングディレクトリ) に
対象の Python モジュールが存在することを前提としている。
しかし、今回は src レイアウトを取っているので、
対象のモジュール mypkg は src-python の下に存在する。

このサブディレクトリ下までは、デフォルトでは検索してくれない。
なので、ちゃんと指定してやる必要がある。

```py
from setuptools import setup, find_packages

setup(
    name="mypkg",
    # ...
    # カレントディレクトリではなく src-python をパッケージディレクトリに指定する。
    packages=find_packages(where="src-python"),
    package_dir={"": "src-python"},
    # ...
)
```

これで、 src-python をパッケージのディレクトリとして設定し、
また、パッケージ (mypkg モジュール) の検索を src-python から勝手に行ってくれる。
find_packages は Python モジュールを勝手に見つけてくれる便利な関数だが、
.py ファイルしか見ない (恐らく `__init__.py` を基準に動作している) ので、
libmypkg.so が存在したとしても見向きもされない。

## 5.4. setup.py の全容

こうして出来上がった setup.py が以下である。
細かいプロパティは、自分でググるか、
「[setup スクリプトを書く](https://docs.python.org/ja/3/distutils/setupscript.html)」
等をみてほしい。
要は、パッケージングに必要な情報を setup() のキーワード付き引数として追加していくだけだ。

```py
from setuptools import setup, find_packages
from setuptools.command.install import install
import shutil
from pathlib import Path


class CustomInstall(install):
    def run(self):
        # 通常のインストール処理を実行する
        install.run(self)
        # .soファイルを適切な場所にコピーする
        shutil.copyfile(
            Path("src-python", "mypkg", "libmypkg.so"),
            Path(self.install_lib, "mypkg", "libmypkg.so"),
        )


setup(
    name="mypkg",
    version="0.0.1",
    author="Author",
    author_email="author@google.com",
    description="Awesome package.",
    long_description=Path("README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    url="https://github.com",
    packages=find_packages(where="src-python"),
    package_dir={"": "src-python"},
    classifiers=[
        "Programming Language :: Python :: 3",
        "Operating System :: POSIX :: Linux",
    ],
    cmdclass={"install": CustomInstall},
)
```

long_description は README.md を読み込む習わしのようなので、
ここでついでに README.md も作っておくことにする。

```md
(README.md)
This is a very awersome package.
```

これで setup.py の完成である。


# 6. CMakeLists.txt の調整

setup.py を使ったインストールは、以下のコマンドで実行できる。

```bash
$ python setup.py install
```

アンインストール用のテキストファイルを残しておく場合
(アンインストール時に削除しなければならないファイルがそこに記載される)、
`--record` オプションをつける。

```bash
$ python setup.py install --record uninstall.txt
```

後は sudo を付けるかどうか程度の違いしかない。

これらを、直接 python コマンドを呼ぶのではなく、 `make install` でなんとかしたい。
では、 CMakeLists.txt に `add_custom_target(install ...)` で、
上述のコマンドを実行するように書けばいいだろうか。

実は、 install ターゲットは予約語扱いになっていて、
特別に `install(...)` という CMake コマンドが用意されている。
これは基本的には生成した実行ファイルや .so ライブラリ等を
グローバルな bin や lib に放り込んだりするためのものなので、
何か特定のコマンドを実行させる、というのには一工夫要る (一工夫で済む、とも言える)。

具体的には、以下のように書けばいい。

```cmake
install(
  CODE "execute_process(COMMAND ...)"
)
```

この `...` に好きなコマンドを書けるので、先程のコマンドを書けばいい。

ただ、先程のコマンドでは python コマンドを使ったが、
環境によっては python3 しか入ってなかったりする。
これを防ぐには、 `find_package(Python ...)` で設定された
`Python_EXECUTABLE` 変数を使えば、
実行可能な Python インタプリタのパスを呼び出すことができる。

加えて、sudo があるか否かで条件分岐をさせたいので、以下のように書こう。

```cmake
if(COMMAND sudo)
    install(
        CODE "execute_process(COMMAND sudo -EH
            ${Python_EXECUTABLE}  setup.py install --record uninstall.txt)"
    )
else()
    install(
        CODE "execute_process(COMMAND
            ${Python_EXECUTABLE}  setup.py install --record uninstall.txt)"
    )
endif()
```

これで `make install` で、 setup.py 経由のインストールができるようになった。

最後に、 uninstall も実装しておこう。
uninstall() というコマンドは用意されていないので、素直に add_custom_target を使う。

```bash
add_custom_target(uninstall
    COMMAND echo "[Uninstall] Checking uninstall.txt..."
    COMMAND test -f uninstall.txt
    COMMAND echo "[Uninstall] Removing following files..."
    COMMAND cat uninstall.txt | sed 's/^/\ \ \ \ + /g'
    COMMAND xargs rm -f < uninstall.txt
    COMMAND xargs dirname < uninstall.txt | sort -u | sort -rn | xargs rmdir
    COMMAND mv uninstall.txt uninstall.txt.bak
    COMMAND echo "[Uninstall] Completed."
)
```

少し bash 芸のスクリプトがややこしいが、以下のような感じの内容になっている。

* uninstall.txt があるかどうかを確かめる (無かったらエラー終了になって止まる)。
* uninstall.txt の中身を整形しながら、何を削除するかの一覧を表示する。
* uninstall.txt の中はファイル名が書いてある (ディレクトリは無い) ので、それを `rm -f` で消す。
* uninstall.txt の中に記載されたディレクトリが空になったはずなので、 rmdir で消す。
  * rm -rf でトップディレクトリからまるごと削除してもいいが、
  万が一にでも uninstall.txt にルートディレクトリが書き込まれてたりすると怖すぎるので、慎重に消す。
  * bash 芸の流れは以下の通り。rmdir は空のディレクトリしか消せないので、リーフノードの空ディレクトリから消していくために少し複雑になっている。
    * uninstall.txt の各行はファイル名の一覧なので、そのディレクトリ名を `dirname` で取得。
    * `sort -u` で、そのディレクトリ名一覧から重複する値を取り除く。
    * `sort -rn` で、ディレクトリ名の長い順 (短い順(`-n`)の逆順(`-r`))に並び替える。
    * 長いディレクトリ名のディレクトリ (=深いディレクトリ)から順に rmdir していく。
* 最後に、念のため uninstall.txt のバックアップを取る。


# 7. test 実行

それでは、最後に test を実行して、きれいに実行されるかを確認しよう。
setup.py を追加してソースコードを弄ったので、
mypkg_test_install をビルドし直すところからだ。

```bash
$ docker compose build mypkg_test_install
[+] Building 4.8s (14/14) FINISHED
(...)
 => => exporting layers                                                       0.1s
 => => writing image sha256:f0de0ef7200a1d11ca7fee73d7fe634564dcfa62ed92def9  0.0s
 => => naming to docker.io/library/myproject_mypkg_install                    0.0s
$ docker compose build mypkg_test_run
[+] Building 1.2s (9/9) FINISHED
(...)
 => exporting to image                                                        0.1s
 => => exporting layers                                                       0.1s
 => => writing image sha256:aacae4b345a01ede4ba537fbd2bad7904b3ac0c3c3fb0d57  0.0s
 => => naming to docker.io/library/myproject_mypkg_run                        0.0s
$ docker compose up
[+] Running 3/0
 ✔ Container docker-mypkg_test_base-1     Created                             0.0s
 ✔ Container docker-mypkg_test_install-1  Recreated                           0.0s
 ✔ Container docker-mypkg_test_run-1      Recreated                           0.0s
Attaching to docker-mypkg_test_base-1, docker-mypkg_test_install-1, docker-mypkg_test_run-1
docker-mypkg_test_base-1 exited with code 0
docker-mypkg_test_install-1 exited with code 0
docker-mypkg_test_run-1      | + make test
docker-mypkg_test_run-1      | Running tests...
docker-mypkg_test_run-1      | Test project /myproject/lib/mypkg
docker-mypkg_test_run-1      |     Start 1: test_with_run_test
docker-mypkg_test_run-1      | 1/2 Test #1: test_with_run_test ...............   Passed    0.00 sec
docker-mypkg_test_run-1      |     Start 2: test_with_pytest
docker-mypkg_test_run-1      | 2/2 Test #2: test_with_pytest .................   Passed    0.21 sec
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | 100% tests passed, 0 tests failed out of 2
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | Total Test time (real) =   0.21 sec
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | + cd /
docker-mypkg_test_run-1      | + python3 -c 'import mypkg'
docker-mypkg_test_run-1      | + pytest
docker-mypkg_test_run-1      | ============================= test session starts ==============================
docker-mypkg_test_run-1      | platform linux -- Python 3.11.4, pytest-7.4.0, pluggy-1.2.0
docker-mypkg_test_run-1      | rootdir: /myproject/lib/mypkg
docker-mypkg_test_run-1      | collected 2 items
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | tests/test_mypkg.py
docker-mypkg_test_run-1      | .
docker-mypkg_test_run-1      | .
docker-mypkg_test_run-1      |                                                    [100%]
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1      | ============================== 2 passed in 0.02s ===============================
docker-mypkg_test_run-1      |
docker-mypkg_test_run-1 exited with code 0
```

import は成功しているし、続く pytest も成功が確認できた。


# 8. まとめ

以上で、 setup.py を用いたパッケージング・インストール方法の解説は終わりである。
最終章では、 pyproject.toml を用いた方法を試す。
