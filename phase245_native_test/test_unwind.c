#include <unwind.h>

static _Unwind_Reason_Code callback(
    struct _Unwind_Context *context,
    void *arg)
{
    (void)context;
    (void)arg;
    return _URC_NO_REASON;
}

void test_real_unwind(void)
{
    _Unwind_Backtrace(callback, 0);
}
