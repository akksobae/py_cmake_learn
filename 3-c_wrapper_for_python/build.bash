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

_info "Build mypkg."
cd "${MYPKG_DIR:?}"
_debug 'gcc -I"${MYPKG_INCLUDE_DIR}" -shared -fPIC -o libmypkg.so mypkg.c'
_debug '* -I"${MYPKG_INCLUDE_DIR}": ヘッダファイルをインクルードする。'
_debug '    ソースコードをインクルードしないように、 include ディレクトリに入れておく。'
_debug '* -shared -fPIC: 共有ライブラリ(インクルードして使い回せるコード群)としてコンパイルする。'
_debug '* -o libmypkg.so: 共有ライブラリ .so ファイルとして出力する'
gcc -I"${MYPKG_INCLUDE_DIR}" -shared -fPIC -o libmypkg.so mypkg.c

function get_python_include_path() {
    _PATH=$(python3 -m sysconfig | \
    grep INCLUDEPY | cut -f 2 -d "=" | head -n 1)
    eval echo $_PATH
}

PYTHON_INCLUDE_PATH=$(get_python_include_path)
_info "Include '${PYTHON_INCLUDE_PATH:?}' as the python path."

_info "Build mypkg_wrap."
cd "${MYPKG_WRAP_DIR:?}"
gcc -I"${MYPKG_INCLUDE_DIR}" -I"${MYPKG_WRAP_INCLUDE_DIR}" \
-I "${PYTHON_INCLUDE_PATH}" \
-shared -fPIC -o libmypkg_wrap.so \
mypkg_wrap.c "${MYPKG_DIR}"/libmypkg.so

_info "Copy libmypkg_wrap into src-python/mypkg."
cd "${BUILD_DIR:?}"
cp "${MYPKG_WRAP_DIR:?}/libmypkg_wrap.so"  "${SRC_PYTHON_DIR}/libmypkg.so"
