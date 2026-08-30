#include <cstdint>

class Calculator {
public:
    static std::uint64_t add(std::uint64_t a, std::uint64_t b) {
        return a + b;
    }
};

int main() {
    std::uint64_t result = Calculator::add(40, 2);

    if (result == 42) {
        return 0;
    }

    return 1;
}
