# CMake implementation for Android Native Build of Whisper Bridge
cmake_minimum_required(VERSION 3.10.2)
project(whisper_android)

# Include the upstream whisper.cpp CMake build
# This correctly defines the `whisper` and `ggml` targets compiled for Android architectures (ARM)
add_subdirectory(whisper_src)

# Path to the shared bridge wrapper that Dart FFI expects
set(BRIDGE_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../windows/whisper_bridge.cpp")

# Build the bridge into a shared library (.so on Android)
add_library(whisper_bridge SHARED
    ${BRIDGE_SRC}
)

# Link the bridge against whisper (which internally links ggml)
target_link_libraries(whisper_bridge PRIVATE whisper)

# Allow the bridge to find whisper.h
target_include_directories(whisper_bridge PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/whisper_src/include"
)

# Enable modern C++ for the bridge
target_compile_features(whisper_bridge PUBLIC cxx_std_17)
