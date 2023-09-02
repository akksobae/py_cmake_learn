from . import libmypkg as _mypkg


def message(res):
    res = _mypkg.message(res)
    return res
