# ============================================================
# build_whisper_dll.ps1 — Builds whisper.cpp as a Windows DLL
# ============================================================
# Prerequisites: CMake, Visual Studio Build Tools (MSVC)
# Usage: .\build_whisper_dll.ps1
# Output: build_whisper\Release\whisper_bridge.dll
# ============================================================

$ErrorActionPreference = "Stop"

$WHISPER_SRC = "$PSScriptRoot\android\app\src\main\cpp\whisper_src"
$BUILD_DIR   = "$PSScriptRoot\build_whisper"
$OUT_DIR     = "$PSScriptRoot\windows\runner"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building whisper_bridge.dll for Windows" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate source directory
if (-not (Test-Path "$WHISPER_SRC\include\whisper.h")) {
    Write-Host "ERROR: whisper.h not found at $WHISPER_SRC\include\whisper.h" -ForegroundColor Red
    exit 1
}

# Create build directory
if (Test-Path $BUILD_DIR) {
    Remove-Item -Recurse -Force $BUILD_DIR
}
New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null

# Create a standalone CMakeLists.txt for the DLL
$cmakeContent = @"
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

set(WHISPER_SRC "$($WHISPER_SRC -replace '\\', '/')")

# ggml core sources
set(GGML_SOURCES
    `${WHISPER_SRC}/ggml/src/ggml.c
    `${WHISPER_SRC}/ggml/src/ggml-alloc.c
    `${WHISPER_SRC}/ggml/src/ggml-backend.cpp
    `${WHISPER_SRC}/ggml/src/ggml-backend-reg.cpp
    `${WHISPER_SRC}/ggml/src/ggml-opt.cpp
    `${WHISPER_SRC}/ggml/src/ggml-quants.c
    `${WHISPER_SRC}/ggml/src/ggml-threading.cpp
    `${WHISPER_SRC}/ggml/src/gguf.cpp
    `${WHISPER_SRC}/ggml/src/ggml.cpp
)

# ggml-cpu sources (generic + x86-specific arch implementations)
set(GGML_CPU_SOURCES
    `${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.c
    `${WHISPER_SRC}/ggml/src/ggml-cpu/ggml-cpu.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/ops.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/vec.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/binary-ops.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/unary-ops.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/traits.cpp
    `${WHISPER_SRC}/ggml/src/ggml-cpu/quants.c
    `${WHISPER_SRC}/ggml/src/ggml-cpu/repack.cpp
    # x86-specific implementations (provides ggml_vec_dot_iq3_s_q8_K etc.)
    `${WHISPER_SRC}/ggml/src/ggml-cpu/arch/x86/quants.c
    `${WHISPER_SRC}/ggml/src/ggml-cpu/arch/x86/repack.cpp
)

# whisper sources
set(WHISPER_SOURCES
    `${WHISPER_SRC}/src/whisper.cpp
)

# Bridge source
set(BRIDGE_SOURCES
    $($PSScriptRoot -replace '\\', '/')/windows/whisper_bridge.cpp
)

add_library(whisper_bridge SHARED
    `${GGML_SOURCES}
    `${GGML_CPU_SOURCES}
    `${WHISPER_SOURCES}
    `${BRIDGE_SOURCES}
)

target_include_directories(whisper_bridge PRIVATE
    `${WHISPER_SRC}/include
    `${WHISPER_SRC}/ggml/include
    `${WHISPER_SRC}/ggml/src
    `${WHISPER_SRC}/ggml/src/ggml-cpu
    `${WHISPER_SRC}/src
)

# Define GGML_BUILD for building as shared library
target_compile_definitions(whisper_bridge PRIVATE
    WHISPER_SHARED
    WHISPER_BUILD
    GGML_BUILD
)

# Install the DLL
install(TARGETS whisper_bridge RUNTIME DESTINATION bin)
"@

Set-Content -Path "$BUILD_DIR\CMakeLists.txt" -Value $cmakeContent

Write-Host "Configuring CMake..." -ForegroundColor Yellow
Push-Location $BUILD_DIR
cmake . -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) {
    # Try Visual Studio 16 (2019) if 17 is not found
    Write-Host "Trying Visual Studio 16 2019..." -ForegroundColor Yellow
    cmake . -G "Visual Studio 16 2019" -A x64 -DCMAKE_BUILD_TYPE=Release
}
Pop-Location

Write-Host ""
Write-Host "Building..." -ForegroundColor Yellow
cmake --build $BUILD_DIR --config Release --parallel

if ($LASTEXITCODE -ne 0) {
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    exit 1
}

# Copy DLL to windows runner directory so it's included in the app bundle
$dllPath = "$BUILD_DIR\Release\whisper_bridge.dll"
if (Test-Path $dllPath) {
    Copy-Item $dllPath -Destination $OUT_DIR -Force
    Write-Host ""
    Write-Host "SUCCESS! DLL copied to: $OUT_DIR\whisper_bridge.dll" -ForegroundColor Green
    Write-Host "File size: $((Get-Item $dllPath).Length / 1MB) MB" -ForegroundColor Green
} else {
    # Check alternative location
    $dllPathAlt = Get-ChildItem -Recurse -Path $BUILD_DIR -Filter "whisper_bridge.dll" | Select-Object -First 1
    if ($dllPathAlt) {
        Copy-Item $dllPathAlt.FullName -Destination $OUT_DIR -Force
        Write-Host ""
        Write-Host "SUCCESS! DLL copied to: $OUT_DIR\whisper_bridge.dll" -ForegroundColor Green
    } else {
        Write-Host "ERROR: whisper_bridge.dll not found in build output!" -ForegroundColor Red
        exit 1
    }
}
