
#include <assert.h>
#include "mypkg.h"

int test_res_of_message()
{
    int res;
    res = message(0);
    assert(res == 0);
}
