#include <stdint.h>

int main(void)
{
    volatile int value = 212;

    if (value == 212)
        return 0;

    return 1;
}
