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
    ENVIRONMENT "PYTHONPATH=${CMAKE_BINARY_DIR}/src-python:$ENV{PYTHONPATH}")

file(STRINGS ${CMAKE_BINARY_DIR}/setup.cfg version
    REGEX "^version = [0-9]+\\.[0-9]+\\.[0-9]+.+$")
string(REGEX REPLACE "^version = ([0-9]+\\.[0-9]+\\.[0-9]+.+)$" "\\1" version "${version}")

install(
    CODE
    "execute_process(
        COMMAND ${Python_EXECUTABLE} -m build
        COMMAND ${Python_EXECUTABLE} -m pip install
        ${CMAKE_BINARY_DIR}/dist/mypkg-${version}.tar.gz
        COMMAND_ERROR_IS_FATAL ANY
    )"
)

add_custom_target(uninstall
    COMMAND ${Python_EXECUTABLE} -m pip uninstall --yes mypkg
)
