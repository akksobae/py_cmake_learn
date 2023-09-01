add_custom_target(py_libmypkg ALL
    COMMAND ${CMAKE_COMMAND} -E copy
    ${PROJECT_SOURCE_DIR}/src/mypkg_wrap/libmypkg_wrap.so libmypkg.so
    DEPENDS mypkg_wrap
)
