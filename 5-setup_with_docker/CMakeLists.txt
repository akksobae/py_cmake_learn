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

if(COMMAND sudo)
    install(
        CODE "execute_process(COMMAND sudo -EH
            ${Python_EXECUTABLE} setup.py install --record uninstall.txt)"
    )
else()
    install(
        CODE "execute_process(COMMAND
            ${Python_EXECUTABLE} setup.py install --record uninstall.txt)"
    )
endif()

add_custom_target(uninstall
    COMMAND echo "[Uninstall] Checking uninstall.txt..."
    COMMAND test -f uninstall.txt
    COMMAND echo "[Uninstall] Removing following files..."
    COMMAND cat uninstall.txt | sed 's/^/\ \ \ \ + /g'
    COMMAND xargs rm -f < uninstall.txt
    COMMAND xargs dirname < uninstall.txt | sort -u | sort -rn | xargs rmdir
    COMMAND mv uninstall.txt uninstall.txt.bak
    COMMAND echo "[Uninstall] Completed."
)
