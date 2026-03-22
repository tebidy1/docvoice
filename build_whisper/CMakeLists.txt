cmake_minimum_required(VERSION 3.14)
project(whisper_bridge LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# CRITICAL: Enable AVX2 for CPU inference speed
if(MSVC)
    add_compile_options(/arch:AVX2 /O2 /EHsc /DNDEBUG)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
else()
    add_compile_options(-mavx2 -mfma -mf16c -O3)
endif()

set(WHISPER_SRC "C:/DOCVOICE-ORG/docvoice/android/app/src/main/cpp/whisper_src")

# ggml core sources
set(GGML_SOURCES
    ${WHISPER_SRC}/ggml/src/ggml.c
    ${WHISPER_SRC}/ggml/src/ggml-alloc.c
    ${WHISPER_SRC}/ggml/src/ggml-backend.cpp
    ${WHISPER_SRC}/ggml/src/ggml-backend-reg.cpp
    ${WHISPER_SRC}/ggml/src/ggml-opt.cpp
    ${WHISPER_SRC}/ggml/src/ggml-quants.c
    ${WHISPER_SRC}/ggml/src/ggml-threading.cpp
    ${WHISPER_SRC}/ggml/src/gguf.cpp
    ${WHISPER_SRC}/ggml/src/ggml.cpp
)

# ggml-cpu sources
set(GGML_CPU_SOURCES
    ${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.c
    ${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/ops.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/vec.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/binary-ops.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/unary-ops.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/traits.cpp
    ${WHISPER_SRC}/ggml/src/ggml-cpu/quants.c
    ${WHISPER_SRC}/ggml/src/ggml-cpu/repack.cpp
)

# whisper sources
set(WHISPER_SOURCES
    ${WHISPER_SRC}/src/whisper.cpp
)

# Bridge source
set(BRIDGE_SOURCES
    C:/DOCVOICE-ORG/docvoice/windows/whisper_bridge.cpp
)

add_library(whisper_bridge SHARED
    ${GGML_SOURCES}
    ${GGML_CPU_SOURCES}
    ${WHISPER_SOURCES}
    ${BRIDGE_SOURCES}
)

target_include_directories(whisper_bridge PRIVATE
    ${WHISPER_SRC}/include
    ${WHISPER_SRC}/ggml/include
    ${WHISPER_SRC}/ggml/src
    ${WHISPER_SRC}/ggml/src/ggml-cpu
    ${WHISPER_SRC}/src
)

# Define GGML_BUILD for building as shared library
target_compile_definitions(whisper_bridge PRIVATE
    WHISPER_SHARED
    WHISPER_BUILD
    GGML_BUILD
)

# Install the DLL
install(TARGETS whisper_bridge RUNTIME DESTINATION bin)
