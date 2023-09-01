#!/usr/bin/env bash

set -e

source ./util.bash

_info "Build libmypck.so"
_debug "libmypkg.so を作成。"
./build.bash -q

cd "${BUILD_DIR:?}"

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
function list_call_of_test_functions() {
    list_test_function_names | while read line; do
        echo "run_test($line, \"$line\");"
    done
}
function list_def_of_test_functions() {
    list_test_function_names | while read line; do
        echo "int ${line}();"
    done
}

KEY="// TEST_MAIN_BLOCK"

_info ""
_debug "test_*.c から test_*() の関数を抽出して、 run_test.h を作る。"
sed "s@${KEY}@$(list_def_of_test_functions)@" "${TESTS_DIR:?}/run_test.base.h" \
> "${TESTS_DIR:?}/run_test.h"
_debug "test_*.c から test_*() の関数を抽出して、 run_test.c を作る。"
sed "s@${KEY}@$(list_call_of_test_functions)@" "${TESTS_DIR:?}/run_test.base.c" \
> "${TESTS_DIR:?}/run_test.c"

_info "Compile the code for running test."
_debug "run_test をコンパイルする。"
cd "${TESTS_DIR:?}"
gcc -I"${MYPKG_INCLUDE_DIR}" -o run_test test_*.c run_test.c "${MYPKG_DIR}"/libmypkg.so

_info "Run c-lang tests."
./run_test

_info "Run pytest."
cd "${BUILD_DIR:?}"
PYTHONPATH="$PYTHONPATH:./src-python" pytest --verbose
