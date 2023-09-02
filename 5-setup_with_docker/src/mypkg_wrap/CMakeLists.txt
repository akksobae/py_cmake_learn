add_library(mypkg_wrap SHARED mypkg_wrap.c)
target_include_directories(mypkg_wrap
    PUBLIC include)
target_link_libraries(mypkg_wrap
    PRIVATE Python::Python mypkg)
set_property(TARGET mypkg_wrap PROPERTY POSITION_INDEPENDENT_CODE ON)
