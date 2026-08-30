#include <stdio.h>
#include <dlfcn.h>

typedef void (*unwind_fn)(void);

int main(void)
{
    printf("PHASE265: runtime test started\n");

    void *handle = dlopen(
        "./p264_real_unwind.so",
        RTLD_NOW | RTLD_LOCAL
    );

    if (!handle) {
        const char *err = dlerror();
        printf("PHASE265: dlopen FAILED\n");
        if (err)
            printf("ERROR: %s\n", err);
        return 1;
    }

    printf("PHASE265: dlopen SUCCESS\n");

    dlerror();

    unwind_fn fn = (unwind_fn)dlsym(
        handle,
        "test_real_unwind"
    );

    const char *err = dlerror();

    if (err != NULL || fn == NULL) {
        printf("PHASE265: dlsym FAILED\n");
        if (err)
            printf("ERROR: %s\n", err);
        dlclose(handle);
        return 2;
    }

    printf("PHASE265: test_real_unwind symbol FOUND\n");
    printf("PHASE265: calling test_real_unwind()\n");

    fn();

    printf("PHASE265: _Unwind_Backtrace EXECUTION RETURNED\n");

    dlclose(handle);

    printf("PHASE265: runtime test SUCCESS\n");

    return 0;
}
