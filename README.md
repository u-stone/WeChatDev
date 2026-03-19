# WeChat Mini Game + C++ WebAssembly Demo

本项目演示如何在微信小游戏中集成 C++ 代码（编译为 WebAssembly），并在微信开发者工具中运行和调试。

运行效果：**20 个彩色粒子在重力作用下弹跳、相互碰撞**，所有物理计算均在 C++ WASM 内核中执行，JS 只负责 Canvas 渲染。

---

## 项目结构

```
WeChatDev/
├── README.md                        ← 本文件（快速上手）
│
├── cpp-module/                      ← 子项目：C++ 物理引擎 → WebAssembly
│   ├── src/
│   │   ├── math/
│   │   │   └── vec2.h               2D 向量库（header-only）
│   │   ├── physics/
│   │   │   ├── particle.h           粒子数据结构
│   │   │   ├── world.h              物理世界接口
│   │   │   └── world.cpp            物理引擎实现（重力、碰撞）
│   │   └── demo.cpp                 WASM 导出层（15 个导出函数）
│   ├── CMakeLists.txt               CMake + Emscripten 编译配置
│   ├── build.sh                     一键构建脚本
│   └── README.md                    C++ 模块详细说明
│
├── minigame/                        ← 子项目：微信小游戏
│   ├── game.js                      入口：动画循环 + Canvas 渲染
│   ├── game.json                    小游戏基础配置
│   ├── project.config.json          微信开发者工具项目配置
│   ├── js/
│   │   └── wasm-loader.js           WASM 模块加载与函数绑定
│   ├── wasm/                        ← 构建产物（由 build.sh 生成）
│   │   ├── demo.js                  Emscripten 胶水代码
│   │   ├── demo.wasm                WebAssembly 二进制
│   │   └── demo.wasm.map            C++ 调试 sourcemap（debug 构建）
│   └── README.md                    JS 模块详细说明
│
└── web/                             ← 子项目：标准浏览器 Web Demo
    ├── index.html                   HTML 入口
    ├── style.css                    样式文件
    ├── js/
    │   ├── game.js                  入口：动画循环 + Canvas 渲染
    │   └── wasm-loader.js           WASM 模块加载与函数绑定
    ├── wasm/                        ← 构建产物（由 cpp-module 生成）
    │   ├── demo.js                  Emscripten 胶水代码
    │   ├── demo.wasm                WebAssembly 二进制
    │   └── demo.wasm.map            C++ 调试 sourcemap（debug 构建）
    └── README.md                    Web Demo 详细说明
```

> `minigame/wasm/` 和 `web/wasm/` 中的文件由 `cpp-module/build.sh` 自动生成，**无需手动创建**。

---

## 环境准备

### 1. Xcode Command Line Tools（macOS）

```bash
xcode-select --install
```

### 2. 安装 emsdk（Emscripten SDK）

**macOS / Linux (Bash):**
```bash
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/emscripten-core/emsdk.git C:\emsdk
cd C:\emsdk
.\emsdk install latest
.\emsdk activate latest
& .\emsdk_env.ps1
```

**每次新开终端**都需要激活环境。建议加入 shell 配置：
- **macOS/Linux**: `echo 'source ~/emsdk/emsdk_env.sh' >> ~/.zshrc`
- **Windows**: 建议将 `emsdk` 路径加入系统环境变量，或在当前窗口运行 `& C:\emsdk\emsdk_env.ps1`。

---

## 编译 C++ → WebAssembly

**macOS / Linux (Bash):**
```bash
cd cpp-module
./build.sh debug     # Debug 构建（默认）：含 sourcemap
./build.sh release   # Release 构建：-O2 优化
```

**Windows (PowerShell):**
```powershell
cd cpp-module
.\build.ps1 debug    # Debug 构建（默认）：含 sourcemap
.\build.ps1 release   # Release 构建：-O2 优化
```

---

## 运行 Web Demo（推荐用于调试）

Web Demo 可以在标准浏览器中运行，支持完整的 Chrome DevTools C++ 调试功能。

### 快速启动（推荐）

**Windows (PowerShell):**
```powershell
.\quickstart.ps1
```

**macOS / Linux (Bash):**
```bash
./quickstart.sh
```

### 手动启动

**Windows (PowerShell):**
```powershell
cd web
python -m http.server 8080
# 或使用 Node.js
npx http-server -p 8080 --cors
```

**macOS / Linux (Bash):**
```bash
cd web
python3 -m http.server 8080
# 或使用 Node.js
npx http-server -p 8080 --cors
```

然后在浏览器中访问：`http://localhost:8080`

**优势**：
- ✅ 支持 Chrome DevTools C++ 断点调试
- ✅ 支持 WASM sourcemap 自动加载
- ✅ 无需微信开发者工具
- ✅ 调试体验更完整

---

## 运行小游戏（微信平台）

1. 打开**微信开发者工具** → 导入项目 → 选择 `WeChatDev/minigame/` 目录
2. AppID 使用「**游客身份**」（或填入真实 AppID）
3. 点击确定，模拟器中即可看到粒子物理模拟

> **注意**：运行时可能会在控制台看到 `webapi_getwxaasyncsecinfo:fail` 错误。这是微信开发者工具内部的安全检查调用，**不影响实际运行**，可以安全忽略。该错误不会影响 WASM 加载和物理模拟的正常执行。

---

## 调试 C++（WebAssembly）

本项目支持三种调试模式，均在 `cpp-module` 中配置：

### 构建命令

**macOS / Linux:**
```bash
cd cpp-module
./build.sh                    # Sourcemap 外置模式（默认）
./build.sh debug --embed      # Sourcemap 内嵌模式
./build.sh debug --dwarf      # DWARF 模式
./build.sh release            # -O2 优化，适合发布
```

**Windows (PowerShell):**
```powershell
cd cpp-module
.\build.ps1 debug             # Sourcemap 外置模式（默认）
.\build.ps1 debug -Embed      # Sourcemap 内嵌模式
.\build.ps1 debug -Dwarf      # DWARF 模式
.\build.ps1 release           # -O2 优化，适合发布
```

### 调试模式说明

| 模式 | 标志 | 输出文件 | 适用场景 |
|------|------|---------|---------|
| **sourcemap_external** *(默认)* | `-gsource-map` | `demo.wasm.map` | 微信开发者工具、需要外部 sourcemap 的环境 |
| **sourcemap_embed** | `-gsource-map` | 内嵌在 `demo.wasm` | 单文件部署，避免额外 .map 文件请求 |
| **dwarf** | `-g4` | 内置在 `demo.wasm` | Chrome DevTools 直接调试 C++ 源码 |

### 调试模式对比

| 特性 | sourcemap_external | sourcemap_embed | dwarf |
|------|-------------------|-----------------|-------|
| **调试信息位置** | 外部 `.wasm.map` | 内嵌在 `.wasm` | 内嵌在 `.wasm` |
| **文件数量** | 3 个 | 2 个 | 2 个 |
| **WASM 文件大小** | 较小 | 稍大 | 最大 |
| **加载速度** | 需要额外加载 .map | 一次性加载 | 一次性加载 |
| **Chrome DevTools** | 需要 .map 文件 | 自动加载 | 自动加载 |
| **微信开发者工具** | ✅ 支持 | ✅ 支持 | ✅ 支持 |

### 快速启动（推荐）

```bash
# Windows PowerShell
.\quickstart.ps1          # sourcemap_external (默认)
.\quickstart.ps1 -Embed   # sourcemap_embed
.\quickstart.ps1 -Dwarf   # dwarf

# macOS/Linux
./quickstart.sh           # sourcemap_external (默认)
./quickstart.sh --embed   # sourcemap_embed
./quickstart.sh --dwarf   # dwarf
```

脚本会自动：
1. 检查并编译 C++ WASM 模块（使用指定的调试模式）
2. 启动本地 HTTP 服务器
3. 在浏览器中打开项目

### 调试 C++（WASM Sourcemap）

#### Web Demo（推荐）

1. 在浏览器中打开 DevTools（F12）
2. 切换到 **Sources** 面板
3. 展开 `wasm://` 虚拟目录
4. 找到并打开 `world.cpp` 或 `demo.cpp`
5. 点击行号设置断点

#### 微信开发者工具（有限支持）

> 需 debug 构建 + 微信开发者工具 ≥ 1.05.x

1. DevTools **Sources** 面板 → 找到 `world.cpp` / `demo.cpp`
2. 点击行号打断点
3. `world_update()` 被调用时会在对应 C++ 行暂停

### 常见问题

| 现象 | 排查 |
|---|---|
| WASM 加载失败 | 确认 `minigame/wasm/demo.js` 和 `demo.wasm` 存在 |
| C++ 断点不生效 | 确认使用 debug 构建；检查 `demo.wasm.map` 存在（sourcemap_external） |
| `emcc` 找不到 | `source ~/emsdk/emsdk_env.sh` |
| CMake 配置失败 | 确认在 `cpp-module/` 目录内执行 `./build.sh` |
| 切换 debug/release 后编译异常 | `build.sh` 会自动清理 `build/` 目录重新配置 |
| **微信开发者工具报错 `webapi_getwxaasyncsecinfo:fail`** | **这是微信开发者工具内部安全检查，不影响实际运行，可忽略** |

---

## 修改 C++ 后的开发循环

**macOS / Linux (Bash):**
```bash
# 1. 修改 C++ 源码
vi cpp-module/src/physics/world.cpp

# 2. 增量重新编译
cd cpp-module && ./build.sh debug
```

**Windows (PowerShell):**
```powershell
# 1. 修改 C++ 源码
# 使用 VS Code 或其他编辑器修改 cpp-module/src/physics/world.cpp

# 2. 增量重新编译
cd cpp-module
.\build.ps1 debug
```

### 新增导出函数的步骤

1. 在 `src/` 中实现函数，用 `EMSCRIPTEN_KEEPALIVE` 标注
2. 在 `CMakeLists.txt` 的 `EXPORTED_FUNCTIONS` 列表中加入 `"_函数名"`
3. 在 `minigame/js/wasm-loader.js` 中用 `cwrap` 包装并导出
4. 在 `minigame/game.js` 中调用

---

## 延伸阅读

- [cpp-module/README.md](./cpp-module/README.md) — C++ 物理引擎各模块详解
- [minigame/README.md](./minigame/README.md) — JS 模块（加载器、渲染循环）详解
- [docs/wx-vs-web.md](./docs/wx-vs-web.md) — **微信小游戏 vs 标准 Web 差异手册**
- [Emscripten 文档](https://emscripten.org/docs/)
- [微信小游戏开发文档](https://developers.weixin.qq.com/minigame/dev/guide/)
