#!/bin/bash

# Quick Start Script for Web Demo
# 
# Usage:
#   ./quickstart.sh               — Debug build (sourcemap_external, default)
#   ./quickstart.sh --embed       — Debug build (sourcemap_embed)
#   ./quickstart.sh --dwarf       — Debug build (dwarf)
# 
# Debug Modes:
#   sourcemap_external (default) — Generates external .wasm.map file
#   sourcemap_embed             — Embeds sourcemap as Data URI in .wasm
#   dwarf                       — Uses DWARF debug symbols in .wasm

DEBUG_MODE="sourcemap_external"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --embed)
            DEBUG_MODE="sourcemap_embed"
            shift
            ;;
        --dwarf)
            DEBUG_MODE="dwarf"
            shift
            ;;
        *)
            echo "ERROR: Unknown option '$1'. Use --embed for sourcemap_embed, --dwarf for dwarf."
            exit 1
            ;;
    esac
done

echo "=== C++ WASM Physics Web Demo Quick Start ==="
case "$DEBUG_MODE" in
    sourcemap_embed)
        echo "Debug Mode: sourcemap_embed (embedded Data URI)"
        ;;
    dwarf)
        echo "Debug Mode: dwarf (DWARF debug symbols)"
        ;;
    *)
        echo "Debug Mode: sourcemap_external (external .wasm.map)"
        ;;
esac
echo ""

# Step 1: Clean and build
wasm_dir="web/wasm"
echo ">>> Cleaning old WASM files..." >&2
rm -f "$wasm_dir/demo.js" "$wasm_dir/demo.wasm" "$wasm_dir/demo.wasm.map" 2>/dev/null || true
echo ">>> WASM files cleaned" >&2
echo ""

echo ">>> Building C++ module..." >&2

cpp_module_dir="cpp-module"
if [ -f "$cpp_module_dir/build.sh" ]; then
    case "$DEBUG_MODE" in
        sourcemap_embed)
            echo "Running build.sh with --embed flag..." >&2
            bash "$cpp_module_dir/build.sh" debug --embed
            ;;
        dwarf)
            echo "Running build.sh with --dwarf flag..." >&2
            bash "$cpp_module_dir/build.sh" debug --dwarf
            ;;
        *)
            echo "Running build.sh (sourcemap_external)..." >&2
            bash "$cpp_module_dir/build.sh" debug
            ;;
    esac
    
    # Wait a moment for files to be copied
    sleep 1
    
    # Verify files were created
    if [ ! -f "$wasm_dir/demo.js" ]; then
        echo "ERROR: WASM files were not generated. Check build output." >&2
        exit 1
    fi
    echo ">>> WASM files generated successfully" >&2
else
    echo "ERROR: build.sh not found at $cpp_module_dir" >&2
    exit 1
fi

# Step 2: Start HTTP server
echo ""
echo ">>> Starting HTTP server..." >&2

original_dir="$(pwd)"
cd web

trap 'cd "$original_dir"' EXIT

echo ""
echo "=== Server Starting ===" >&2
echo "Open your browser and visit: http://localhost:8080" >&2
echo ""
echo "Press Ctrl+C to stop the server" >&2
echo ""

# Use Python's built-in HTTP server
python3 -m http.server 8080
