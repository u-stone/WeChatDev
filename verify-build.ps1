# Verify WASM Build Script
# Usage: .\verify-build.ps1

Write-Host "=== Verifying WASM Build ===" -ForegroundColor Cyan
Write-Host ""

$cppModuleDir = Join-Path $PSScriptRoot "cpp-module"
$minigameWasmDir = Join-Path $PSScriptRoot "minigame/wasm"
$webWasmDir = Join-Path $PSScriptRoot "web/wasm"

# Check if cpp-module exists
if (-not (Test-Path $cppModuleDir)) {
    Write-Host "ERROR: cpp-module directory not found" -ForegroundColor Red
    exit 1
}

# Check if WASM files exist
$wasmFiles = @("demo.js", "demo.wasm", "demo.wasm.map")
$missingFiles = @()

foreach ($file in $wasmFiles) {
    $minigamePath = Join-Path $minigameWasmDir $file
    $webPath = Join-Path $webWasmDir $file
    
    if (-not (Test-Path $minigamePath) -and -not (Test-Path $webPath)) {
        $missingFiles += $file
    }
}

if ($missingFiles.Count -gt 0) {
    Write-Host "Missing WASM files:" -ForegroundColor Yellow
    foreach ($file in $missingFiles) {
        Write-Host "  - $file" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please run build.ps1 first:" -ForegroundColor Cyan
    Write-Host "  cd cpp-module" -ForegroundColor Gray
    Write-Host "  .\build.ps1 debug" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "✓ All WASM files found" -ForegroundColor Green
Write-Host ""

# Check file sizes
Write-Host "WASM file sizes:" -ForegroundColor Cyan
foreach ($dir in @($minigameWasmDir, $webWasmDir)) {
    if (Test-Path $dir) {
        $dirName = Split-Path $dir -Leaf
        Write-Host "  $dirName/:" -ForegroundColor White
        Get-ChildItem $dir | ForEach-Object {
            $size = $_.Length / 1KB
            if ($size -lt 1) {
                $sizeStr = "{0:N0} KB" -f $size
            } else {
                $sizeStr = "{0:N2} MB" -f ($size / 1024)
            }
            Write-Host "    $($_.Name) - $sizeStr" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "Build verification complete!" -ForegroundColor Green
