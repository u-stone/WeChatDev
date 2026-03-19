# WASM 调试服务器技术方案：解决微信开发者工具 SourceMap 加载问题

## 1. 背景与问题分析

在微信小游戏开发中，将 C++ 源码编译为 WebAssembly (WASM) 后的调试是一个核心痛点。传统的调试方式常遇到以下障碍：

1. **协议不支持 (`ERR_UNKNOWN_URL_SCHEME`)**:
   Emscripten 默认生成的 `sourceMappingURL` 通常使用相对路径或虚拟协议（如 `wasm://`）。微信开发者工具的 Chromium 内核网络层不识别这些非标准协议。
2. **沙箱环境限制 (`404 Not Found`)**:
   微信小游戏运行在受限的沙箱内，出于安全考虑，它无法直接通过文件路径（`file:///`）访问工程目录以外的源代码。
3. **跨域策略 (CORS)**:
   即使通过网络请求加载映射文件，如果服务端未配置 CORS，浏览器出于安全策略会拦截请求。

## 2. 解决方案：本地调试服务器

本方案采用 **外部 HTTP 托管 + CORS 支持 + 统一根目录** 的策略，彻底打通 WASM、SourceMap 与 C++ 源码之间的链路。

### 2.1 核心原理
通过在项目根目录启动一个轻量级 HTTP 服务器，将整个工程目录（包括 `cpp-module/src` 和 `minigame/wasm`）暴露在标准的 `http://` 协议下。在编译 WASM 时，显式地将 `sourceMappingURL` 指向该服务器地址。

### 2.2 关键参数配置

在 `cpp-module/CMakeLists.txt` 中，通过以下变量和 Emscripten 标志实现路径改写：

```cmake
# 默认端口为 3000
set(WASM_DEBUG_PORT "3000" CACHE STRING "Local server port")
# 动态构建 URL
set(WASM_DEBUG_URL "http://127.0.0.1:${WASM_DEBUG_PORT}/minigame/wasm/")

target_link_options(demo PRIVATE "-gsource-map" "--source-map-base=${WASM_DEBUG_URL}")
```

*   **`-gsource-map`**: 强制生成 `.wasm.map` 文件。
*   **`--source-map-base`**: 将 WASM 二进制内部引用的 SourceMap 地址从本地相对路径修改为固定的网络 URL。

## 3. 实现细节

### 3.1 调试服务器脚本 (`minigame/debug-server.py`)

该脚本是一个定制化的 Python HTTP 服务器，具备以下特性：

1.  **命令行参数支持**: 可以通过 `--port` 参数动态指定监听端口。
2.  **自动根目录定位**: 脚本无论在何处运行，都会自动将工作目录切换到项目根目录（`minigame` 的上一级），从而能同时提供 WASM 产物和 C++ 源码服务。
3.  **强制 CORS 响应**: 手动注入 `Access-Control-Allow-Origin: *` 头，确保微信开发者工具可以无障碍请求。
4.  **禁用缓存**: 注入 `Cache-Control: no-cache`，确保每次代码修改编译后，开发者工具能即时加载最新的映射信息。

### 3.2 调试链路路径解析

当开发者工具加载 `http://127.0.0.1:3000/minigame/wasm/demo.wasm` 时：
1.  它读取到内部的 `sourceMappingURL` 为 `http://127.0.0.1:3000/minigame/wasm/demo.wasm.map`。
2.  解析 `.map` 文件内容，其中记录的源码相对路径（如 `../../cpp-module/src/demo.cpp`）会基于 `.map` 的 URL 进行拼接。
3.  最终推导出源码 URL 为 `http://127.0.0.1:3000/cpp-module/src/demo.cpp`。
4.  由于服务器运行在项目根目录，上述所有资源均能被正确访问。

## 4. 使用指南

### 第一步：准备环境
确保已安装 Python 环境，且 `cpp-module/CMakeLists.txt` 中的 `DEBUG_MODE` 设置为 `sourcemap_external` (默认)。

### 第二步：编译 WASM
运行对应平台的构建脚本，生成带有网络 URL 引用的 WASM 文件。

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
在项目根目录下保持该服务器窗口在后台运行。

**macOS / Linux (Bash):**
```bash
python3 minigame/debug-server.py --port 3000
```

**Windows (PowerShell):**
```powershell
python minigame/debug-server.py --port 3000
```

### 第四步：在微信开发者工具中调试
1.  重新编译/刷新小游戏项目。
2.  打开 **调试面板 -> Sources**。
3.  你会发现左侧文件树中出现了 `http://127.0.0.1:3000` (或你指定的端口) 的分类，展开即可看到完整的 C++ 源码结构。

4.  直接在 `.cpp` 文件中点击行号设置断点，当物理引擎运行到该位置时，执行流会自动暂停。

## 5. 常见问题排查

| 现象 | 可能原因 | 解决方法 |
|---|---|---|
| Sources 面板中看不到源码 | 服务器未运行或端口不对 | 检查 `debug-server.py` 输出的监听地址。 |
| 加载 SourceMap 报 CORS 错误 | 未正确设置 Access-Control 头 | 确保使用本项目提供的 `debug-server.py` 而非默认的 `http.server`。 |
| 源码文件路径显示不对 | `source-map-base` 与服务器路径不匹配 | 检查 `CMakeLists.txt` 中的 `WASM_DEBUG_URL` 变量。 |
| 变量或函数无法查看 | 编译开启了优化 | 确保使用 `-O0` 构建，以获得最完整的符号支持。 |
