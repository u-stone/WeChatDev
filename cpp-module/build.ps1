# build.ps1 — Compile C++ source to WebAssembly using Emscripten + CMake

param (
    [Parameter(Position=0)]
    [ValidateSet("debug", "release")]
    [string]$BuildType = "debug"
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$BuildDir = Join-Path $ScriptDir "build"
$EmsdkRoot = "D:\OpenSource\emsdk" 

if ($BuildType -eq "release") {
    $CMakeBuildType = "Release"
} else {
    $CMakeBuildType = "Debug"
}

# ── Environment Activation ───────────────────────────────────────────────────
if (!(Get-Command emcc -ErrorAction SilentlyContinue)) {
    $EnvPs1 = Join-Path $EmsdkRoot "emsdk_env.ps1"
    if (Test-Path $EnvPs1) {
        Write-Host ">>> Activating emsdk..." -ForegroundColor Gray
        & $EnvPs1
    } else {
        Write-Host "ERROR: emcc not found and emsdk not at $EmsdkRoot" -ForegroundColor Red
        exit 1
    }
}

# ── Absolute Path Discovery ──────────────────────────────────────────────────
$EmccPath = Get-Command emcc | Select-Object -ExpandProperty Source
$EmscriptenDir = Split-Path (Split-Path $EmccPath) # D:\...\upstream\emscripten

# 1. 定位 Python (优先使用 EMSDK 内置的)
$PythonExe = Get-Command python -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (!$PythonExe -and $env:EMSDK_PYTHON) { $PythonExe = $env:EMSDK_PYTHON }

Write-Host ">>> Found Python: $PythonExe" -ForegroundColor Gray

# ── Build ────────────────────────────────────────────────────────────────────
if (Test-Path $BuildDir) { Remove-Item -Recurse -Force $BuildDir }
New-Item -ItemType Directory -Path $BuildDir | Out-Null

$OriginalLocation = Get-Location
Set-Location $BuildDir

try {
    $CmakeArgs = @(
        "$ScriptDir",
        "-G", "MinGW Makefiles",
        "-DCMAKE_BUILD_TYPE=$CMakeBuildType",
        "-DINTERNAL_PYTHON_EXE=$PythonExe"
    )
    
    & emcmake cmake @CmakeArgs
    & emmake cmake --build . -- -j $env:NUMBER_OF_PROCESSORS
}
finally {
    Set-Location $OriginalLocation
}

Write-Host "`n>>> Build complete!" -ForegroundColor Green
