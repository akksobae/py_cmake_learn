#include <stdio.h>
#include "run_test.h"

typedef int (*test_function)();

int run_test(test_function f, char *test_name)
{
    int test_has_succeeded;
    fprintf(stderr, "[TEST] Test: %16s.\n", test_name);
    test_has_succeeded = f();
    if (test_has_succeeded != 0)
    {
        fprintf(stderr, "[TEST] ERROR: %16s.\n", test_name);
    }
    fprintf(stderr, "[TEST] Success: %16s.\n", test_name);
}

int main(int argc, char const *argv[])
{
    // TEST_MAIN_BLOCK
    return 0;
}
