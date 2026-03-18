# build.ps1 — Compile C++ source to WebAssembly using Emscripten + CMake
#
# Prerequisites: emsdk must be installed and activated.
# Usage:
#   .\build.ps1           — Debug build (default; sourcemap + DWARF symbols)
#   .\build.ps1 debug     — Debug build
#   .\build.ps1 release   — Release build (optimised, no debug info)

param (
    [Parameter(Position=0)]
    [ValidateSet("debug", "release")]
    [string]$BuildType = "debug"
)

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$BuildDir = Join-Path $ScriptDir "build"

if ($BuildType -eq "release") {
    $CMakeBuildType = "Release"
    Write-Host ">>> Building in RELEASE mode" -ForegroundColor Cyan
} else {
    $CMakeBuildType = "Debug"
    Write-Host ">>> Building in DEBUG mode (sourcemap + DWARF)" -ForegroundColor Cyan
}

# ── Verify emcc is available ─────────────────────────────────────────────────
if (!(Get-Command emcc -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: emcc not found. Please install and activate emsdk first:" -ForegroundColor Red
    Write-Host "  git clone https://github.com/emscripten-core/emsdk.git ~/emsdk"
    Write-Host "  cd ~/emsdk; .\emsdk install latest; .\emsdk activate latest"
    Write-Host "  & .\emsdk_env.ps1"
    Write-Host ""
    exit 1
}

$EmccVersion = (emcc --version | Select-Object -First 1)
Write-Host ">>> emcc version: $EmccVersion"
Write-Host ">>> Build type:   $CMakeBuildType"
Write-Host ">>> Output dir:   $ScriptDir\..\minigame\wasm\"
Write-Host ""

# Create build directory if it doesn't exist
if (!(Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
}

Set-Location $BuildDir

# ── Configure ────────────────────────────────────────────────────────────────
# emcmake wraps cmake to inject the Emscripten toolchain automatically.
# On Windows, we explicitly specify "Unix Makefiles" as it's the standard for Emscripten.
emcmake cmake $ScriptDir `
    -G "Unix Makefiles" `
    -DCMAKE_BUILD_TYPE=$CMakeBuildType `
    -DCMAKE_VERBOSE_MAKEFILE=ON

# ── Build ────────────────────────────────────────────────────────────────────
# emmake ensures Emscripten environment variables are present during make
$Jobs = $env:NUMBER_OF_PROCESSORS
emmake make -j $Jobs

Write-Host "`n>>> Build complete! Output files:"
Get-ChildItem "$ScriptDir\..\minigame\wasm\" | Select-Object Name, @{Name="Size(KB)";Expression={"{0:N2}" -f ($_.Length / 1KB)}}, LastWriteTime

# Verify source map was generated for debug builds
if ($CMakeBuildType -eq "Debug") {
    $MapFile = "$ScriptDir\..\minigame\wasm\demo.wasm.map"
    if (Test-Path $MapFile) {
        Write-Host "`n>>> ✓ demo.wasm.map generated (C++ source debugging enabled)" -ForegroundColor Green
    } else {
        Write-Host "`n>>> ⚠️  WARNING: demo.wasm.map was NOT generated." -ForegroundColor Yellow
    }
}

Write-Host "`n>>> Open minigame/ in WeChat DevTools to run the demo."
