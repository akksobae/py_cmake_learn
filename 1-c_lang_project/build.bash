#!/usr/bin/env bash

set -e

source ./util.bash

_info "Copy the source code dir to the dir for building process."
_debug '開発用ディレクトリである src 配下を汚したくないので、'
_debug '丸ごとコピーしてビルド用ディレクトリを作る。'
rm -rf "${BUILD_DIR:?}"
cp -r "${SRC_DIR:?}" "${BUILD_DIR:?}"

_info "Build mypkg."
cd "${MYPKG_DIR:?}"
_debug 'gcc -I"${MYPKG_INCLUDE_DIR}" -shared -fPIC -o libmypkg.so mypkg.c'
_debug '* -I"${MYPKG_INCLUDE_DIR}": ヘッダファイルをインクルードする。'
_debug '    ソースコードをインクルードしないように、 include ディレクトリに入れておく。'
_debug '* -shared -fPIC: 共有ライブラリ(インクルードして使い回せるコード群)としてコンパイルする。'
_debug '* -o libmypkg.so: 共有ライブラリ .so ファイルとして出力する'
gcc -I"${MYPKG_INCLUDE_DIR}" -shared -fPIC -o libmypkg.so mypkg.c

_info "Build myapp."
cd "${MYAPP_DIR:?}"
_debug 'gcc -I"${MYPKG_INCLUDE_DIR}" -o myapp main.c "${MYPKG_DIR}"/libmypkg.so'
_debug '* -l"${MYPKG_DIR}/libmypkg.so": 共有ライブラリとして libmypkg.so をインクルードする。'
_debug '    今回はローカルで作成したので、ローカルのパスを直接指定している。'
gcc -I"${MYPKG_INCLUDE_DIR}" -o myapp main.c "${MYPKG_DIR}"/libmypkg.so

_info "Run myapp."
./myapp