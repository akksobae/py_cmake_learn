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