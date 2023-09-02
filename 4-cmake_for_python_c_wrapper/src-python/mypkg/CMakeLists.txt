add_custom_target(py_libmypkg ALL
    COMMAND ${CMAKE_COMMAND} -E copy
    $<TARGET_FILE:mypkg_wrap> libmypkg.so
    DEPENDS mypkg_wrap
)
