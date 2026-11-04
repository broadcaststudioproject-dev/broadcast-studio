#include <stdexcept>

int main() {
    try {
        throw std::runtime_error("test");
    } catch (...) {
        return 0;
    }

    return 1;
}
