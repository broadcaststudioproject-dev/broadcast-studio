# CMake కనీస వెర్షన్
cmake_minimum_required(VERSION 3.18)

# ప్రాజెక్ట్ పేరు
project(pocket_pcr_native C CXX)

# ఆండ్రాయిడ్ లాగ్స్ (Logcat) సిస్టమ్ లైబ్రరీని వెతికి పట్టుకోవడం
find_library(
    log-lib
    log
)

# మీ C/C++ కోడ్‌ను షేర్డ్ లైబ్రరీ (.so) గా మార్చడం
# గమనిక: ఇక్కడ test.c బదులు మీ అసలైన ఫైల్ పేరు ఇవ్వండి (ఉదాహరణకు native_stream.cpp)
add_library(
    pocket_pcr_native
    SHARED
    test.c 
)

# మీ లైబ్రరీకి ఆండ్రాయిడ్ లాగ్ లైబ్రరీని లింక్ చేయడం
target_link_libraries(
    pocket_pcr_native
    ${log-lib}
)
