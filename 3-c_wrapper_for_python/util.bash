#!/usr/bin/env bash

# デバッグメッセージ表示関数。
if [[ $* =~ -.*g ]]; then _ON_DEBUG="true"; fi
_ON_DEBUG=${_ON_DEBUG:="false"}
_ON_INFO=${_ON_INFO:="true"}
_debug() { if ${_ON_DEBUG}; then printf "\033[0;95m[DEBUG] $*\033[m\n" 1>&2; fi; }
_info()  { if ${_ON_INFO};  then printf "\033[0;94m[ INFO] $*\033[m\n" 1>&2; fi; }

# 変数定義
PROJECT_DIR="$(pwd)"
BUILD_DIR="/tmp/3-c_wrapper_for_python"
SRC_DIR="${BUILD_DIR:?}/src"
MYPKG_DIR="${SRC_DIR:?}/mypkg"
MYPKG_INCLUDE_DIR="${SRC_DIR:?}/mypkg/include"
MYPKG_WRAP_DIR="${SRC_DIR:?}/mypkg_wrap"
MYPKG_WRAP_INCLUDE_DIR="${SRC_DIR:?}/mypkg_wrap/include"
MYAPP_DIR="${SRC_DIR:?}/myapp"
SRC_PYTHON_DIR="${BUILD_DIR:?}/src-python"
PY_MYPKG_DIR="${SRC_PYTHON_DIR:?}/mypkg"
TESTS_DIR="${BUILD_DIR:?}/tests"
