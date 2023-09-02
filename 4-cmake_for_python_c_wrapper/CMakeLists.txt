cmake_minimum_required(VERSION 3.16)
project(my_package)

find_package(Python REQUIRED COMPONENTS Interpreter Development)

add_subdirectory(src/mypkg)
add_subdirectory(src/myapp)
add_subdirectory(src/mypkg_wrap)
add_subdirectory(src-python/mypkg)
add_subdirectory(tests)

enable_testing()
add_test(NAME test_with_run_test COMMAND run_test
    WORKING_DIRECTORY tests)
add_test(NAME test_with_pytest COMMAND pytest
    WORKING_DIRECTORY .)
set_tests_properties(test_with_pytest PROPERTIES
    ENVIRONMENT "PYTHONPATH=${PROJECT_SOURCE_DIR}/src-python:$ENV{PYTHONPATH}")
