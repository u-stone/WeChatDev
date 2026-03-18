# Quick Start Script for Web Demo
# 
# Usage:
#   .\quickstart.ps1          — Debug build (sourcemap_external, default)
#   .\quickstart.ps1 -Embed   — Debug build (sourcemap_embed)
#   .\quickstart.ps1 -Dwarf   — Debug build (dwarf)
# 
# Debug Modes:
#   sourcemap_external (default) — Generates external .wasm.map file
#   sourcemap_embed             — Embeds sourcemap as Data URI in .wasm
#   dwarf                       — Uses DWARF debug symbols in .wasm

param (
    [Parameter()]
    [switch]$Embed = $false,

    [Parameter()]
    [switch]$Dwarf = $false
)

Write-Host "=== C++ WASM Physics Web Demo Quick Start ===" -ForegroundColor Cyan
if ($Dwarf) {
    $ModeDesc = "dwarf (DWARF debug symbols)"
} elseif ($Embed) {
    $ModeDesc = "sourcemap_embed (embedded Data URI)"
} else {
    $ModeDesc = "sourcemap_external (external .wasm.map)"
}
Write-Host "Debug Mode: $ModeDesc"
Write-Host ""

# Step 1: Clean and build
$wasmDir = Join-Path $PSScriptRoot "web/wasm"
Write-Host ">>> Cleaning old WASM files..." -ForegroundColor Yellow
Remove-Item (Join-Path $wasmDir "demo.js") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $wasmDir "demo.wasm") -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $wasmDir "demo.wasm.map") -Force -ErrorAction SilentlyContinue
Write-Host ">>> WASM files cleaned" -ForegroundColor Green
Write-Host ""

Write-Host ">>> Building C++ module..." -ForegroundColor Yellow

$cppModuleDir = Join-Path $PSScriptRoot "cpp-module"
if (Test-Path (Join-Path $cppModuleDir "build.ps1")) {
    if ($Dwarf) {
        Write-Host "Running build.ps1 with -Dwarf switch..." -ForegroundColor Gray
        & (Join-Path $cppModuleDir "build.ps1") debug -Dwarf
    } elseif ($Embed) {
        Write-Host "Running build.ps1 with -Embed switch..." -ForegroundColor Gray
        & (Join-Path $cppModuleDir "build.ps1") debug -Embed
    } else {
        Write-Host "Running build.ps1 (sourcemap_external)..." -ForegroundColor Gray
        & (Join-Path $cppModuleDir "build.ps1") debug
    }
    
    # Wait a moment for files to be copied
    Start-Sleep -Seconds 1
    
    # Verify files were created
    if (-not (Test-Path (Join-Path $wasmDir "demo.js"))) {
        Write-Host "ERROR: WASM files were not generated. Check build output." -ForegroundColor Red
        exit 1
    }
    Write-Host ">>> WASM files generated successfully" -ForegroundColor Green
} else {
    Write-Host "ERROR: build.ps1 not found at $cppModuleDir" -ForegroundColor Red
    exit 1
}

# Step 2: Start HTTP server
Write-Host ""
Write-Host ">>> Starting HTTP server..." -ForegroundColor Cyan

$originalLocation = Get-Location
$webDir = Join-Path $PSScriptRoot "web"
Set-Location $webDir

try {
    Write-Host ""
    Write-Host "=== Server Starting ===" -ForegroundColor Green
    Write-Host "Open your browser and visit: http://localhost:8080" -ForegroundColor White
    Write-Host ""
    Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Gray
    Write-Host ""

    # Use Python's built-in HTTP server
    python -m http.server 8080
} finally {
    Set-Location $originalLocation
}
