add_library(mypkg_wrap SHARED mypkg_wrap.c)
target_include_directories(mypkg_wrap
    PUBLIC include
    PRIVATE ${Python_INCLUDE_DIRS})
target_link_libraries(mypkg_wrap
    PRIVATE mypkg)
set_property(TARGET mypkg_wrap PROPERTY POSITION_INDEPENDENT_CODE ON)
