#include "mypkg_wrap.h"
#include "mypkg.h"

/***********************************************************
 * Body (ラップ関数の定義部分)
 ***********************************************************/

static PyObject *pywrap_message(
    PyObject *self, PyObject *args, PyObject *kw)
{
    long long res_for_py;

    /* Python のメソッド定義と対応する C 言語のコード */
    int res_for_c;
    static char *keywords[] = {"res", NULL};

    if (!PyArg_ParseTupleAndKeywords(
            args, kw, "i", keywords, &res_for_c))
    {
        return NULL; /* Error on parse parameters on Python. */
    }

    /* C 言語のコードの実行部分の本体 */
    res_for_py = (long long)message(res_for_c);

    /* ランタイムエラー時の処理 (raise RuntimeError(...) と対応) */
    if (res_for_py < 0)
    {
        PyErr_SetString(PyExc_RuntimeError, "Error on message().");
        return NULL;
    }

    /* (Python のメソッドとしての) 返り値の処理 */
    return Py_BuildValue("L", res_for_py);
}

/***********************************************************
 * Magic code (Python で呼び出せるようにするための「おまじない」部分)
 ***********************************************************/

// 定義した Python メソッドの一覧
static PyMethodDef libmypkg_methods[] = {
    {
        "message",                      // メソッド名。
        (PyCFunction)pywrap_message,    // メソッドが呼び出す C 言語の関数名。
        (METH_VARARGS | METH_KEYWORDS), // メソッドの構造を設定するフラグ。
                                        // 引数だけなのか、キーワード引数を取るのか等。
        "Show Hello world.",            // docstring。
    },
    {NULL, NULL, 0, NULL},
};

// 循環参照ガーベージコレクション用の関数設定
static int libmypkg_traverse(PyObject *m, visitproc visit, void *arg)
{
    Py_VISIT(GETSTATE(m)->error);
    return 0;
}

static int libmypkg_clear(PyObject *m)
{
    Py_CLEAR(GETSTATE(m)->error);
    return 0;
}

// mypkg モジュールの定義
static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "libmypkg",                  // const char*: モジュール名。
    NULL,                        // const char*: docstring。
    sizeof(struct module_state), // Py_ssize_t: モジュールのサイズ。
    libmypkg_methods,            // libmypkg が含むメソッド一覧。
    NULL,                        // 「多段階初期化のためのスロット定義の配列」らしいが、
                                 // 一段回初期化なので NULL。
    libmypkg_traverse,           // 上で定義したガーベージコレクション用関数。
    libmypkg_clear,              // 上で定義したガーベージコレクション用関数。
    NULL,                        // ガーベージコレクションがモジュールオブジェクトを開放するときに呼び出す関数。
                                 // 今回は必要ないので NULL。
};

// mypkg の __init__ に対応する C 言語コード
PyMODINIT_FUNC PyInit_libmypkg(void)
{
    PyObject *module = PyModule_Create(&moduledef);
    if (module == NULL)
    {
        return NULL; // Erorr on __init__ process.
    }
    struct module_state *st = GETSTATE(module);
    st->error = PyErr_NewException("libmypkg.Error", NULL, NULL);
    if (st->error == NULL)
    {
        Py_DECREF(module);
        return NULL; // Erorr on __init__ process.
    }
    return module;
}