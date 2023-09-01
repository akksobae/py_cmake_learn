#!/usr/bin/env bash
# -*- coding: utf-8 -*-

function list_test_function_names() {
    for f in test_*.c; do
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
        echo "$line,"
    done
}
function list_def_of_test_functions() {
    list_test_function_names | while read line; do
        echo "int ${line}();"
    done
}

sed "s@// TEST_FUNCTIONS_DEF@$(list_def_of_test_functions)@" \
run_test.base.h > "run_test.h"

sed "s@// TEST_FUNCTIONS_LIST@$(list_call_of_test_functions)@" \
run_test.base.c > "run_test.c"
