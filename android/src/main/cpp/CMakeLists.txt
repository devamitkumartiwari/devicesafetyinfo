cmake_minimum_required(VERSION 3.18.1)
project("device_safety_ffi")

add_library(device_safety_ffi SHARED device_safety_ffi.cpp)

target_compile_options(device_safety_ffi PRIVATE
    -std=c++17
    -fvisibility=hidden
    -O2
)

set_target_properties(device_safety_ffi PROPERTIES
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
)

# 16 KB page size support (required by Google Play as of Nov 2025).
# NDK r28+ aligns to 16 KB by default; these flags make the alignment explicit
# regardless of which NDK version a consuming app's Gradle build resolves.
target_link_options(device_safety_ffi PRIVATE
    "-Wl,-z,max-page-size=16384"
    "-Wl,-z,common-page-size=16384"
)

find_library(log-lib log)
target_link_libraries(device_safety_ffi ${log-lib})
