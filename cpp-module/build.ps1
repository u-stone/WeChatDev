# build.ps1 — Compile C++ source to WebAssembly using Emscripten + CMake
# 
# Usage:
#   .\build.ps1 debug                    — Debug build (sourcemap_external, default)
#   .\build.ps1 debug -Embed             — Debug build (sourcemap_embed)
#   .\build.ps1 debug -Dwarf             — Debug build (dwarf)
#   .\build.ps1 release                  — Release build (optimised, no debug info)
# 
# Debug Modes:
#   sourcemap_external (default) — Generates external .wasm.map file
#   sourcemap_embed             — Embeds sourcemap as Data URI in .wasm
#   dwarf                       — Uses DWARF debug symbols in .wasm

param (
    [Parameter(Position=0)]
    [ValidateSet("debug", "release")]
    [string]$BuildType = "debug",

    [Parameter()]
    [switch]$Embed = $false,

    [Parameter()]
    [switch]$Dwarf = $false
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$BuildDir = Join-Path $ScriptDir "build"
$EmsdkRoot = "D:\OpenSource\emsdk" 

if ($BuildType -eq "release") {
    $CMakeBuildType = "Release"
    $DebugMode = "none"
    Write-Host ">>> Release build" -ForegroundColor Cyan
} else {
    $CMakeBuildType = "Debug"
    if ($Dwarf) {
        $DebugMode = "dwarf"
        $ModeDesc = "dwarf (DWARF debug symbols)"
    } elseif ($Embed) {
        $DebugMode = "sourcemap_embed"
        $ModeDesc = "sourcemap_embed (embedded Data URI)"
    } else {
        $DebugMode = "sourcemap_external"
        $ModeDesc = "sourcemap_external (external .wasm.map)"
    }
    Write-Host ">>> Debug build: Mode = $ModeDesc" -ForegroundColor Cyan
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
        "-DINTERNAL_PYTHON_EXE=$PythonExe",
        "-DDEBUG_MODE=$DebugMode"
    )
    
    & emcmake cmake @CmakeArgs
    & emmake cmake --build . -- -j $env:NUMBER_OF_PROCESSORS
}
finally {
    Set-Location $OriginalLocation
}

Write-Host "`n>>> Build complete!" -ForegroundColor Green
