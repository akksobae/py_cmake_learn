cmake_minimum_required(VERSION 3.16)
project(my_package)

add_subdirectory(src/mypkg)
add_subdirectory(src/myapp)
add_subdirectory(tests)

enable_testing()
add_test(NAME test_with_run_test COMMAND run_test
    WORKING_DIRECTORY tests)
