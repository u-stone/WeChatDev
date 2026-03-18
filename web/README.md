# Web Demo - C++ WASM Physics

这是一个运行于标准浏览器的 Web 版本，功能与 `minigame` 相同，但可以直接在浏览器中运行，方便调试 WASM。

## 功能特性

- ✅ 20 个彩色粒子在重力作用下弹跳、相互碰撞
- ✅ 所有物理计算均在 C++ WASM 内核中执行
- ✅ 支持 Chrome DevTools 调试 C++ 代码
- ✅ 支持 WASM sourcemap 加载
- ✅ 无需微信开发者工具

## 项目结构

```
web/
├── index.html          # HTML 入口
├── style.css           # 样式文件
├── js/
│   ├── game.js         # 游戏逻辑（与 minigame/game.js 相同）
│   └── wasm-loader.js  # WASM 加载器（适配标准浏览器）
└── wasm/               # WASM 构建产物（由 cpp-module 生成）
    ├── demo.js         # Emscripten 胶水代码
    ├── demo.wasm       # WebAssembly 二进制
    └── demo.wasm.map   # C++ 调试 sourcemap
```

## 编译 WASM

首先需要编译 C++ 代码生成 WASM：

```bash
cd cpp-module

# Debug 构建（包含 sourcemap，支持 C++ 调试）
./build.sh debug

# Windows PowerShell
.\build.ps1 debug
```

构建完成后，`wasm/` 目录下会生成：
- `demo.js`
- `demo.wasm`
- `demo.wasm.map` (Debug 构建)

## 运行 Web Demo

### 方法 1：使用 Python HTTP 服务器

```bash
cd web

# Python 3
python -m http.server 8080

# 或 Python 2
python -m SimpleHTTPServer 8080
```

然后在浏览器中访问：`http://localhost:8080`

### 方法 2：使用 Node.js HTTP 服务器

```bash
cd web

# 安装 http-server（如果未安装）
npm install -g http-server

# 启动服务器
http-server -p 8080
```

### 方法 3：使用 VSCode Live Server

1. 安装 VSCode 扩展：**Live Server** (Ritwick Dey)
2. 右键点击 `index.html`
3. 选择 **Open with Live Server**

### 方法 4：直接打开（仅部分功能）

直接双击 `index.html` 可以打开，但由于浏览器安全限制（CORS），可能无法加载 WASM 文件。建议使用上述方法启动本地 HTTP 服务器。

## 调试 C++ 代码

### 1. 启动本地服务器

按照上述方法启动本地 HTTP 服务器。

### 2. 打开 Chrome DevTools

在浏览器中打开 DevTools（F12 或 Ctrl+Shift+I）。

### 3. 加载 Sourcemap

DevTools 会自动加载 `demo.wasm.map` 文件（如果存在）。

### 4. 设置 C++ 断点

1. 在 DevTools 中切换到 **Sources** 面板
2. 展开 `wasm://` 虚拟目录
3. 找到并打开 `world.cpp` 或 `demo.cpp`
4. 点击行号设置断点

### 5. 调试

当物理引擎运行时，断点会命中，可以：
- 查看变量值
- 单步执行
- 查看调用堆栈
- 在 Console 中执行表达式

## 与 minigame 的区别

| 特性 | minigame | web |
|------|----------|-----|
| 运行环境 | 微信开发者工具 | 标准浏览器 |
| WASM API | WXWebAssembly | WebAssembly |
| 需要 polyfill | wx-polyfills.js | 无需 |
| 调试支持 | ⚠️ 有限（wasm:// 协议问题） | ✅ 完整（Chrome DevTools） |
| Sourcemap | ❌ 无法加载 | ✅ 自动加载 |
| 粒子数量 | 20 | 20 |
| 渲染 | Canvas 2D | Canvas 2D |

## 常见问题

### 1. WASM 加载失败

**错误信息**：
```
Failed to load module script: The server responded with a non-JavaScript MIME type
```

**解决方案**：
- 确保使用 HTTP 服务器（不要直接打开文件）
- 检查 `wasm/demo.js` 文件路径是否正确

### 2. Sourcemap 未加载

**错误信息**：
```
DevTools failed to load SourceMap: Could not load content for wasm/demo.wasm.map
```

**原因**：
- Sourcemap 文件不存在（未使用 Debug 构建）
- 文件路径不正确

**解决方案**：
```bash
cd cpp-module
.\build.ps1 debug  # 确保使用 Debug 构建
```

### 3. CORS 错误

**错误信息**：
```
Access to fetch at 'file:///...' from origin 'null' has been blocked by CORS policy
```

**解决方案**：
- 使用本地 HTTP 服务器（不要直接打开文件）
- Chrome 启动参数（不推荐）：`--allow-file-access-from-files`

## 技术细节

### WASM 加载流程

```
index.html
  └─ wasm-loader.js
      └─ DemoModule({ locateFile })
          └─ wasm/demo.js
              └─ wasm/demo.wasm
              └─ wasm/demo.wasm.map (自动加载)
```

### C++ 调用堆栈示例

```
world_update(dt)
  ├─ applyGravity(dt)
  ├─ integrate(dt)
  ├─ resolveBoundaries()
  └─ resolveCollisions()
      ├─ Vec2::lengthSq()
      ├─ Vec2::dot()
      └─ Particle::restitution
```

## 开发建议

1. **使用 Debug 构建进行开发调试**
   ```bash
   ./build.ps1 debug
   ```

2. **使用 Release 构建进行性能测试**
   ```bash
   ./build.ps1 release
   ```

3. **查看 WASM 文件大小**
   ```bash
   ls -lh wasm/
   ```

4. **检查 sourcemap 是否生成**
   ```bash
   file wasm/demo.wasm.map
   ```

## 相关链接

- [cpp-module/README.md](../cpp-module/README.md) - C++ 物理引擎文档
- [minigame/README.md](../minigame/README.md) - 微信小游戏文档
- [Emscripten 文档](https://emscripten.org/docs/)
- [Chrome DevTools WASM 调试](https://developer.chrome.com/docs/devtools/javascript/wasm/)

## 更新记录

- 2026-03-18: 初始版本，基于 minigame 创建
- 2026-03-18: 支持 Chrome DevTools C++ 调试
