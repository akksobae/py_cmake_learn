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

_debug "実行時のフラグに合わせて、 docker compose build 用のオプションを設定する。"
_no_cache_opt="--progress=plain --no-cache"
if ${_ON_DEBUG}; then
    _build_opt="${_no_cache_opt}"
    if ${_ON_CLEAR}; then _clear_opt="${_no_cache_opt}"; fi
fi

_info "Docker compose"
tar -czf ${DOCKER_DIR}/mypkg_install/mypkg.tar.gz --exclude='docker' .
cd "${DOCKER_DIR}"
docker compose build ${_clear_opt} mypkg_test_base
docker compose build ${_build_opt} mypkg_test_install
docker compose build ${_build_opt} mypkg_test_run
docker compose up

# _info "CMake mypkg."
# cmake .
# make
# export CTEST_OUTPUT_ON_FAILURE="1"
# make test
