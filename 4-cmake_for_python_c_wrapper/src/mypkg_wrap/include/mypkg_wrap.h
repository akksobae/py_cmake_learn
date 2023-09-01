#ifndef __MYPKG_WRAP_HEADER__
#define __MYPKG_WRAP_HEADER__

#define PY_SSIZE_T_CLEAN
#include <Python.h>

struct module_state
{
    PyObject *error;
};

#define GETSTATE(m) ((struct module_state *)PyModule_GetState(m))

#endif
