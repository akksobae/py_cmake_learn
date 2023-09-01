#!/usr/bin/env bash

# デバッグメッセージ表示関数。
if [[ $* =~ -.*g ]]; then _ON_DEBUG="true"; fi
if [[ $* =~ -.*C ]]; then _ON_CLEAR="true"; fi
_ON_DEBUG=${_ON_DEBUG:="false"}
_ON_CLEAR=${_ON_CLEAR:="false"}
_ON_INFO=${_ON_INFO:="true"}
_debug() { if ${_ON_DEBUG}; then printf "\033[0;95m[DEBUG] $*\033[m\n" 1>&2; fi; }
_info()  { if ${_ON_INFO};  then printf "\033[0;94m[ INFO] $*\033[m\n" 1>&2; fi; }

# 変数定義
PROJECT_DIR="$(pwd)"
BUILD_DIR="/tmp/5-setup_with_docker"
SRC_DIR="${BUILD_DIR:?}/src"
MYPKG_DIR="${BUILD_DIR:?}/mypkg"
MYPKG_INCLUDE_DIR="${BUILD_DIR:?}/mypkg/include"
MYAPP_DIR="${BUILD_DIR:?}/myapp"
TESTS_DIR="${BUILD_DIR:?}/tests"
DOCKER_DIR="${BUILD_DIR:?}/docker"
