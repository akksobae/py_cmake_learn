add_executable(run_test test_mypkg.c run_test.c)
target_link_libraries(run_test mypkg)

add_custom_command(
    OUTPUT run_test.c run_test.h
    COMMAND ./cmake_support.bash
    DEPENDS cmake_support.bash run_test.base.c run_test.base.h
)
