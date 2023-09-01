#!/usr/bin/env bash

set -e

source ./util.bash

_info "Copy the source code dir to the dir for building process."
_debug '開発用ディレクトリである src 配下を汚したくないので、'
_debug '丸ごとコピーしてビルド用ディレクトリを作る。'
rm -rf "${BUILD_DIR:?}"
mkdir -p "${BUILD_DIR:?}"
cp -r * "${BUILD_DIR:?}/"
cd "${BUILD_DIR:?}"

_info "CMake mypkg."
cmake .
make
make test
