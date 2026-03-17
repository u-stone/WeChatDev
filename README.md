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
└── minigame/                        ← 子项目：微信小游戏
    ├── game.js                      入口：动画循环 + Canvas 渲染
    ├── game.json                    小游戏基础配置
    ├── project.config.json          微信开发者工具项目配置
    ├── js/
    │   └── wasm-loader.js           WASM 模块加载与函数绑定
    ├── wasm/                        ← 构建产物（由 build.sh 生成）
    │   ├── demo.js                  Emscripten 胶水代码
    │   ├── demo.wasm                WebAssembly 二进制
    │   └── demo.wasm.map            C++ 调试 sourcemap（debug 构建）
    └── README.md                    JS 模块详细说明
```

> `minigame/wasm/` 中的文件由 `cpp-module/build.sh` 自动生成，**无需手动创建**。

---

## 环境准备

### 1. Xcode Command Line Tools（macOS）

```bash
xcode-select --install
```

### 2. 安装 emsdk（Emscripten SDK）

```bash
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk
./emsdk install latest
./emsdk activate latest
source ./emsdk_env.sh
```

**每次新开终端**都需要 `source ./emsdk_env.sh`。建议加入 shell 配置：

```bash
echo 'source ~/emsdk/emsdk_env.sh' >> ~/.zshrc   # zsh（macOS 默认）
```

验证：

```bash
emcc --version   # emcc (Emscripten gcc/clang-like replacement + linker) 3.x.x
```

### 3. 微信开发者工具

下载地址：https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html

---

## 编译 C++ → WebAssembly

```bash
cd WeChatDev/cpp-module

./build.sh debug     # Debug 构建（默认）：含 sourcemap，支持 C++ 断点调试
./build.sh release   # Release 构建：-O2 优化，体积更小
```

构建成功后 `minigame/wasm/` 会出现：

| 文件 | 说明 |
|---|---|
| `demo.js` | Emscripten 胶水代码 |
| `demo.wasm` | WebAssembly 二进制 |
| `demo.wasm.map` | C++ sourcemap（仅 debug） |

---

## 运行小游戏

1. 打开**微信开发者工具** → 导入项目 → 选择 `WeChatDev/minigame/` 目录
2. AppID 使用「**游客身份**」（或填入真实 AppID）
3. 点击确定，模拟器中即可看到粒子物理模拟

---

## 调试

### 调试 JavaScript

- **Console**：查看 `[WASM]` 前缀日志
- **Sources → game.js / wasm-loader.js**：打断点，单步调试

### 调试 C++（WASM Sourcemap）

> 需 debug 构建 + 微信开发者工具 ≥ 1.05.x

1. DevTools **Sources** 面板 → 找到 `world.cpp` / `demo.cpp`
2. 点击行号打断点
3. `world_update()` 被调用时会在对应 C++ 行暂停

### 常见问题

| 现象 | 排查 |
|---|---|
| WASM 加载失败 | 确认 `minigame/wasm/demo.js` 和 `demo.wasm` 存在 |
| C++ 断点不生效 | 确认使用 debug 构建；检查 `demo.wasm.map` 存在 |
| `emcc` 找不到 | `source ~/emsdk/emsdk_env.sh` |
| CMake 配置失败 | 确认在 `cpp-module/` 目录内执行 `./build.sh` |
| 切换 debug/release 后编译异常 | `build.sh` 会自动清理 `build/` 目录重新配置 |

---

## 修改 C++ 后的开发循环

```bash
# 1. 修改 C++ 源码（例如调整重力、添加新函数）
vim cpp-module/src/physics/world.cpp

# 2. 增量重新编译（比首次快很多）
cd cpp-module && ./build.sh debug

# 3. 微信开发者工具点击「编译」刷新小游戏
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
