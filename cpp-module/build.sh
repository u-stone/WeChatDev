#!/usr/bin/env bash
# build.sh — Compile C++ source to WebAssembly using Emscripten + CMake
#
# Prerequisites: emsdk must be installed and activated.
# See README.md for installation instructions.
#
# Usage:
#   ./build.sh                    — Debug build (default; sourcemap_external)
#   ./build.sh debug              — Debug build (sourcemap_external)
#   ./build.sh debug --embed      — Debug build (sourcemap_embed)
#   ./build.sh debug --dwarf      — Debug build (dwarf)
#   ./build.sh release            — Release build (optimised, no debug info)
# 
# Debug Modes:
#   sourcemap_external (default) — Generates external .wasm.map file
#   sourcemap_embed             — Embeds sourcemap as Data URI in .wasm
#   dwarf                       — Uses DWARF debug symbols in .wasm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
BUILD_TYPE="${1:-debug}"
DEBUG_MODE="sourcemap_external"

shift || true
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

case "$BUILD_TYPE" in
    debug)
        CMAKE_BUILD_TYPE="Debug"
        case "$DEBUG_MODE" in
            sourcemap_external)
                echo ">>> Building in DEBUG mode (sourcemap_external)"
                ;;
            sourcemap_embed)
                echo ">>> Building in DEBUG mode (sourcemap_embed)"
                ;;
            dwarf)
                echo ">>> Building in DEBUG mode (dwarf)"
                ;;
            *)
                echo "ERROR: Unknown debug mode '$DEBUG_MODE'. Use 'sourcemap_external', 'sourcemap_embed', or 'dwarf'."
                exit 1
                ;;
        esac
        ;;
    release)
        CMAKE_BUILD_TYPE="Release"
        DEBUG_MODE="none"
        echo ">>> Building in RELEASE mode"
        ;;
    *)
        echo "ERROR: Unknown build type '$BUILD_TYPE'. Use 'debug' or 'release'."
        exit 1
        ;;
esac

# ── Verify emcc is available ─────────────────────────────────────────────────
if ! command -v emcc &>/dev/null; then
    echo ""
    echo "ERROR: emcc not found. Please install and activate emsdk first:"
    echo "  git clone https://github.com/emscripten-core/emsdk.git ~/emsdk"
    echo "  cd ~/emsdk && ./emsdk install latest && ./emsdk activate latest"
    echo "  source ~/emsdk/emsdk_env.sh"
    echo ""
    exit 1
fi

echo ">>> emcc version: $(emcc --version | head -1)"
echo ">>> Build type:   $CMAKE_BUILD_TYPE"
echo ">>> Output dir:   $SCRIPT_DIR/../minigame/wasm/"
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# emcmake wraps cmake to inject the Emscripten toolchain automatically
emcmake cmake "$SCRIPT_DIR" \
    -DCMAKE_BUILD_TYPE="$CMAKE_BUILD_TYPE" \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DDEBUG_MODE="$DEBUG_MODE"

# ── Build ────────────────────────────────────────────────────────────────────
# emmake ensures Emscripten environment variables are present during make
emmake make -j"$(nproc 2>/dev/null || sysctl -n hw.logicalcpu)"

echo ""
echo ">>> Build complete! Output files:"
ls -lh "$SCRIPT_DIR/../minigame/wasm/"

# Verify source map was generated for debug builds
if [[ "$CMAKE_BUILD_TYPE" == "Debug" ]]; then
    MAP_FILE="$SCRIPT_DIR/../minigame/wasm/demo.wasm.map"
    if [[ -f "$MAP_FILE" ]]; then
        echo ""
        echo ">>> ✓ demo.wasm.map generated (C++ source debugging enabled)"
    else
        echo ""
        echo ">>> ⚠️  WARNING: demo.wasm.map was NOT generated."
        echo "    Check that your emcc version supports -gsource-map:"
        echo "    emcc --version"
    fi
fi

echo ""
echo ">>> Open minigame/ in WeChat DevTools to run the demo."
