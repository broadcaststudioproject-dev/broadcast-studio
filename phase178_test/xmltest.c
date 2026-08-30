#include <stdio.h>
#include <dlfcn.h>

int main(void)
{
    const char *path = "libxml2.so.2";

    void *h = dlopen(path, RTLD_NOW);

    if (!h) {
        printf("DLOPEN_FAILED\n");
        printf("ERROR=%s\n", dlerror());
        return 1;
    }

    printf("DLOPEN_SUCCESS\n");

    dlclose(h);

    return 0;
}
