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

find_library(log-lib log)
target_link_libraries(device_safety_ffi ${log-lib})
