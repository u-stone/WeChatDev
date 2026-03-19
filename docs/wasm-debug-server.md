# WASM 调试服务器技术方案：解决微信开发者工具 SourceMap 加载问题

## 1. 背景与问题分析

在微信小游戏开发中，将 C++ 源码编译为 WebAssembly (WASM) 后的调试是一个核心痛点。当尝试加载外部 SourceMap 时，开发者工具常报以下错误：
`DevTools failed to load SourceMap: Could not load content for wasm://wasm/demo.wasm.map: HTTP error: status code 404, net::ERR_UNKNOWN_URL_SCHEME`

### 1.1 核心原因分析

导致该报错的根本原因有两点：

1.  **协议不支持 (`ERR_UNKNOWN_URL_SCHEME`)**:
    Emscripten 默认生成的 `sourceMappingURL` 通常使用相对路径。微信开发者工具在加载 WASM 后会为其分配一个虚拟的 `wasm://` 协议头。然而，开发者工具底层的 Chromium 网络层并不识别这种自定义协议，导致无法发起获取 `.map` 文件的请求。
2.  **沙箱环境限制 (`404 Not Found`)**:
    即使路径解析正确，由于微信小程序的沙箱安全机制，开发者工具无法直接访问工程目录以外的磁盘文件（如 `cpp-module/src` 下的原始 C++ 文件）。

## 2. 解决方案：本地调试服务器

本方案采用 **外部 HTTP 托管 + CORS 支持 + 统一根目录** 的策略，彻底打通 WASM、SourceMap 与 C++ 源码之间的链路。

### 2.1 核心原理

通过在项目根目录启动一个轻量级 HTTP 服务器，将整个工程目录暴露在标准的 `http://` 协议下。在编译 WASM 时，通过显式配置，强制将 WASM 内部记录的 `sourceMappingURL` 从默认的相对路径改写为指向该服务器的绝对 HTTP URL。

这样，开发者工具在解析 SourceMap 时会通过标准的 HTTP 请求（而非受限的 `wasm://` 协议）去获取映射文件和源码。

### 2.2 关键参数配置

在 `cpp-module/CMakeLists.txt` 中，通过以下变量实现路径改写：

```cmake
# 1. 强制生成外部 .wasm.map 文件
target_compile_options(demo PRIVATE "-gsource-map")

# 2. 设置 SourceMap 的基础 URL 路径
# 这会将 wasm 文件内部的引用地址修改为标准的 http:// 基础路径
set(WASM_DEBUG_PORT "3000" CACHE STRING "Local server port")
set(WASM_DEBUG_URL "http://127.0.0.1:${WASM_DEBUG_PORT}/minigame/wasm/")

target_link_options(demo PRIVATE "-gsource-map" "--source-map-base=${WASM_DEBUG_URL}")
```

*   **`--source-map-base`**: **关键点**。它将 WASM 内部的引用地址从 `wasm://...` 修改为 `http://127.0.0.1:3000/minigame/wasm/demo.wasm.map`。

## 3. 实现细节

### 3.1 调试服务器脚本 (`minigame/debug-server.py`)

该脚本是一个定制化的 Python HTTP 服务器，具备以下特性：

1.  **参数化端口**: 支持通过 `--port` 指定端口，需与 CMake 配置保持一致。
2.  **自动根目录定位**: 脚本启动后会自动将工作目录切换到项目根目录，从而能同时提供编译产物（`minigame/wasm`）和源代码（`cpp-module/src`）的服务。
3.  **强制 CORS 响应**: 注入 `Access-Control-Allow-Origin: *` 头，防止跨域拦截。
4.  **禁用缓存**: 确保每次编译后开发者工具都能加载到最新的映射数据。

### 3.2 调试链路路径解析流程

当开发者工具加载 `http://127.0.0.1:3000/minigame/wasm/demo.wasm` 时：
1.  **获取 Map**: 它读取到内部嵌入的 URL，通过 HTTP 请求 `http://127.0.0.1:3000/minigame/wasm/demo.wasm.map`。
2.  **解析路径**: 解析 `.map` 文件内容，其中记录的源码相对路径（如 `../../cpp-module/src/demo.cpp`）会基于 `.map` 文件的 URL 进行拼接。
3.  **加载源码**: 最终推导出源码 URL 为 `http://127.0.0.1:3000/cpp-module/src/demo.cpp`。
4.  **完成映射**: 由于服务器运行在项目根目录，所有资源均能通过 HTTP 协议被正常访问，从而实现源码级调试。

## 4. 使用指南

### 第一步：准备环境
确保已安装 Python 3 环境。

### 第二步：编译 WASM
运行对应平台的构建脚本。注意：必须使用 `debug` 模式（默认模式）。

**macOS / Linux (Bash):**
```bash
cd cpp-module
./build.sh debug
```

**Windows (PowerShell):**
```powershell
cd cpp-module
.\build.ps1 debug
```

### 第三步：启动调试服务器
在后台运行服务器。确保端口与 CMake 中的 `WASM_DEBUG_PORT` (默认 3000) 对应。

**macOS / Linux (Bash):**
```bash
python3 minigame/debug-server.py --port 3000
```

**Windows (PowerShell):**
```powershell
python minigame/debug-server.py --port 3000
```

### 第四步：在微信开发者工具中调试
1.  刷新小游戏项目。
2.  打开 **调试面板 -> Sources**。
3.  在左侧文件树中找到 `http://127.0.0.1:3000`，展开即可看到 C++ 源码。
4.  在 `.cpp` 文件中设置断点进行调试。

## 5. 备选方案：内联 SourceMap

如果不希望启动本地服务器，可以在构建时开启内联模式：
```powershell
.\build.ps1 debug -Embed
```
**原理**: 将 SourceMap 的 JSON 内容经过 Base64 编码后，以 `data:application/json;base64,...` 的形式直接写入 `.wasm` 二进制文件的末尾。
**缺点**: 会显著增大 `.wasm` 文件体积，仅建议在临时快速测试时使用。

## 6. 常见问题排查

| 现象 | 可能原因 | 解决方法 |
|---|---|---|
| Sources 面板中看不到源码 | 服务器未运行或端口不匹配 | 检查 `debug-server.py` 输出的地址。 |
| 加载 SourceMap 报 CORS 错误 | 未正确设置 Access-Control 头 | 确保使用本项目提供的 `debug-server.py`。 |
| 源码文件路径显示不对 | `source-map-base` 与服务器路径不匹配 | 检查 `CMakeLists.txt` 中的 `WASM_DEBUG_URL`。 |
