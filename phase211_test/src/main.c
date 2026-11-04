#include <stdint.h>

int main(void)
{
    volatile int value = 211;
    return value == 211 ? 0 : 1;
}
