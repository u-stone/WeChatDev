# Project Overview: WeChat Mini Game + C++ WebAssembly

This project demonstrates a high-performance integration of C++ (compiled to WebAssembly) within a WeChat Mini Game environment. It features a 2D particle physics engine that handles gravity, collisions, and impulse resolution in C++, with a JavaScript-based Canvas 2D renderer.

## Project Structure

- **`cpp-module/`**: C++ Physics Engine & WASM Build System
  - `src/`: Core engine source (`math/vec2.h`, `physics/world.cpp`).
  - `scripts/embed_map.py`: Custom Python script to embed SourceMaps as Data URIs into the `.wasm` binary (useful for bypassing WeChat DevTools path limitations).
  - `CMakeLists.txt`: Emscripten-based build configuration.
  - `build.sh` / `build.ps1`: Cross-platform build scripts (Bash for macOS/Linux, PowerShell for Windows).
- **`minigame/`**: WeChat Mini Game Project
  - `game.js`: Entry point, rendering loop, and WASM API orchestration.
  - `js/wx-polyfills.js`: Essential compatibility layer for `WXWebAssembly` and WeChat file system APIs.
  - `wasm/`: Build artifacts (`demo.js`, `demo.wasm`).

## Building and Running

### 1. Build C++ to WebAssembly
Requires [emsdk (Emscripten SDK)](https://emscripten.org/docs/getting_started/downloads.html) to be installed and activated.

**Windows (PowerShell):**
```powershell
cd cpp-module
.\build.ps1 debug           # External SourceMap (Default)
.\build.ps1 debug -Embed    # Embedded SourceMap (Bypass wasm:// 404s)
.\build.ps1 release         # Optimized Release build
```

**macOS / Linux (Bash):**
```bash
cd cpp-module
./build.sh debug
./build.sh release
```

### 2. Run the Mini Game
1. Open **WeChat DevTools**.
2. Import the project using the `minigame/` directory.
3. Use "Tourist Mode" or your own AppID.

## Development Conventions

- **C++ Standards**: C++17.
- **Coding Style**: Google C++ Style Guide (PascalCase for classes, camelCase for methods).
- **Language**: English for all code, comments, and documentation.
- **SourceMap Handling**: 
  - Default: External `.wasm.map` files.
  - Optional: Use `-Embed` in `build.ps1` to inject the map into the `.wasm` binary via a custom Python-based LEB128 injector, solving path resolution issues in some environments.

## Technical Details

- **WASM Interop**: Uses `EMSCRIPTEN_KEEPALIVE` and `extern "C"` exports. JavaScript access is managed via `cwrap` in `wasm-loader.js`.
- **WeChat Compatibility**: The project includes a custom `fetch` and `WebAssembly` polyfill to translate standard Web APIs into `wx.getFileSystemManager` and `WXWebAssembly` calls.
- **Build System**: Utilizes a `try/finally` block in PowerShell to ensure directory restoration and clean builds by wiping the `build/` cache on every run.

## TODO / Future Enhancements
- [ ] Implement touch-based force application from JS.
- [ ] Add unit testing suite for the physics engine.
- [ ] Mirror `cpp-module/src` into `minigame/` to enable full source-level debugging.
