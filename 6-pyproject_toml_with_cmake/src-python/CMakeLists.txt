add_custom_target(py_libmypkg ALL
    COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_BINARY_DIR}/src/mypkg_wrap/libmypkg_wrap.so mypkg/libmypkg.so
    DEPENDS mypkg_wrap
)
