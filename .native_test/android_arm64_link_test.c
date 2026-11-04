#include <stdint.h>

uint64_t add_numbers(uint64_t a, uint64_t b) {
    return a + b;
}

int main(void) {
    uint64_t result = add_numbers(40, 2);

    if (result == 42) {
        return 0;
    }

    return 1;
}
