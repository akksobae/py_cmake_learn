add_library(mypkg SHARED mypkg.c)
target_include_directories(mypkg PUBLIC include)
set_property(TARGET mypkg PROPERTY POSITION_INDEPENDENT_CODE ON)
