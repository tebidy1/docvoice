# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(scribeflow LANGUAGES CXX C)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "scribeflow")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)

# =========================================================================
# Build whisper_bridge.dll
# =========================================================================
set(WHISPER_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../android/app/src/main/cpp/whisper_src")

# Disable AVX2 enforcement for maximum CPU compatibility on older machines
if(MSVC)
    add_compile_options(/EHsc)
    add_compile_definitions(_CRT_SECURE_NO_WARNINGS)
else()
    # CMake handles -O3 normally for release, but this is fine globally or remove it as well.
endif()

set(GGML_SOURCES
    "${WHISPER_SRC}/ggml/src/ggml.c"
    "${WHISPER_SRC}/ggml/src/ggml-alloc.c"
    "${WHISPER_SRC}/ggml/src/ggml-backend.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-backend-reg.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-backend-dl.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-opt.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-quants.c"
    "${WHISPER_SRC}/ggml/src/ggml-threading.cpp"
    "${WHISPER_SRC}/ggml/src/gguf.cpp"
    "${WHISPER_SRC}/ggml/src/ggml.cpp"
)

set(GGML_CPU_SOURCES
    "${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.c"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/ops.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/vec.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/binary-ops.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/unary-ops.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/traits.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/quants.c"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/repack.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/arch/x86/quants.c"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/arch/x86/repack.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/amx/amx.cpp"
    "${WHISPER_SRC}/ggml/src/ggml-cpu/amx/mmq.cpp"
)

set(WHISPER_SOURCES
    "${WHISPER_SRC}/src/whisper.cpp"
)

set(BRIDGE_SOURCES
    "${CMAKE_CURRENT_SOURCE_DIR}/whisper_bridge.cpp"
)

add_library(whisper_bridge SHARED
    ${GGML_SOURCES}
    ${GGML_CPU_SOURCES}
    ${WHISPER_SOURCES}
    ${BRIDGE_SOURCES}
)

target_include_directories(whisper_bridge PRIVATE
    "${WHISPER_SRC}/include"
    "${WHISPER_SRC}/ggml/include"
    "${WHISPER_SRC}/ggml/src"
    "${WHISPER_SRC}/ggml/src/ggml-cpu"
    "${WHISPER_SRC}/src"
)

target_compile_features(whisper_bridge PUBLIC cxx_std_17)
if(MSVC)
    # ── Performance: unlock AVX2 SIMD and full speed optimizations ──
    # These flags tell the MSVC code generator to emit AVX2/FMA instructions.
    target_compile_options(whisper_bridge PRIVATE
        /O2          # Maximize speed (replaces Debug /Od)
        /arch:AVX2   # Enable AVX2 + FMA SIMD (Intel Haswell+ / i7-1065G7)
        /fp:fast     # Permit floating-point reassociation for speed
        /Oi          # Enable compiler intrinsic functions
    )
    # ── Suppress verbose whisper.cpp conversion warnings ──
    target_compile_options(whisper_bridge PRIVATE /wd4244 /wd4267 /wd4305 /wd4984)
endif()

target_compile_definitions(whisper_bridge PRIVATE
    WHISPER_SHARED
    WHISPER_BUILD
    GGML_BUILD
    GGML_USE_CPU
    # ── CRITICAL: Tell the GGML C sources to compile AVX2/FMA intrinsic paths ──
    # The /arch:AVX2 compiler flag only affects code generation.
    # These macros are what actually #ifdef-enables the SIMD loops in ggml-cpu.c
    GGML_USE_AVX
    GGML_USE_AVX2
    GGML_USE_FMA
    GGML_USE_F16C
    WHISPER_VERSION=\"1.0.0\"
    GGML_VERSION=\"0.0.0\"
    GGML_COMMIT=\"unknown\"
)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# === Whisper Bridge DLL ===
# Install whisper_bridge.dll next to the executable for Dart FFI loading.
install(TARGETS whisper_bridge RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)
