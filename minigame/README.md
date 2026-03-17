# minigame — 微信小游戏

本子项目是运行在微信开发者工具中的小游戏主体。它加载由 `cpp-module` 编译出的 WebAssembly 物理引擎，每帧查询粒子状态并用 Canvas 2D 渲染。

> 在微信开发者工具中打开本目录（`minigame/`）即可运行。

---

## 目录结构

```
minigame/
├── game.js                 入口文件（动画循环 + Canvas 渲染）
├── game.json               小游戏基础配置
├── project.config.json     微信开发者工具项目配置
├── js/
│   ├── wx-polyfills.js     WebAssembly / fetch 兼容补丁（必须最先加载）
│   └── wasm-loader.js      WASM 模块加载与函数绑定
└── wasm/                   ← 由 cpp-module/build.sh 生成，勿手动编辑
    ├── demo.js             Emscripten 胶水代码
    ├── demo.wasm           WebAssembly 二进制
    └── demo.wasm.map       C++ 调试 sourcemap（debug 构建）
```

---

## 模块详解

### `js/wx-polyfills.js` — 微信小游戏兼容补丁

微信小游戏运行时与标准浏览器存在多处 API 差异，此文件统一补全：

| 缺失 / 不兼容的 API | 问题 | 补丁方案 |
|---|---|---|
| `WebAssembly`（全局对象） | 微信用 `WXWebAssembly` 代替 | `globalThis.WebAssembly = WXWebAssembly` |
| `WebAssembly.instantiateStreaming` | `WXWebAssembly` 无此方法 | 实现为调用 `WXWebAssembly.instantiate(路径)` |
| `WebAssembly.instantiate(ArrayBuffer)` | `WXWebAssembly` 只接受文件路径字符串 | 拦截 ArrayBuffer 调用，重定向到文件路径 |
| `WebAssembly.RuntimeError` 等错误类型 | `WXWebAssembly` 未提供 | 手动创建继承自 `Error` 的类 |
| `fetch` | 微信没有全局 fetch | 用 `wx.getFileSystemManager().readFile` 实现，同时记录 `.wasm` 文件路径供 `instantiate` 使用 |

**必须在 `game.js` 第一行 `require`**，早于任何 WASM 相关代码：

```js
// game.js 第一行
require('./js/wx-polyfills');
```

---

### `js/wasm-loader.js` — WASM 加载器

**职责**：加载 Emscripten 生成的 `DemoModule`，将所有 C++ 导出函数用 `cwrap` 包装后，以一个纯 JS 对象返回。调用方无需了解 WASM 内存模型。

#### 核心流程

```
require('../wasm/demo.js')         // 1. 加载 Emscripten 胶水代码
  └─ DemoModule({ locateFile })    // 2. 实例化 WASM（locateFile 告知 .wasm 路径）
       └─ instance.cwrap(...)      // 3. 用 cwrap 将 C 函数包装为普通 JS 函数
            └─ resolve(api)        // 4. 通过 Promise 返回 api 对象
```

#### `locateFile` 的作用

微信小游戏运行时的工作目录是项目根目录（`minigame/`），Emscripten 默认会在 JS 文件同级目录查找 `.wasm`，而我们的文件在 `wasm/` 子目录，因此需要：

```js
locateFile: function (filename) {
  return 'wasm/' + filename;   // demo.wasm → wasm/demo.wasm
}
```

#### `cwrap` 类型映射

`cwrap(funcName, returnType, argTypes)` 中的类型只有三种：

| Emscripten 类型 | 对应 C/C++ 类型 |
|---|---|
| `'number'` | `int`, `float`, `double`, `unsigned int`, 指针 |
| `'string'` | `const char*` |
| `null` | `void` |

#### 返回的 `api` 对象

```js
const api = await loadWasm();

// 世界管理
api.world_init(width, height)   // → void
api.world_reset()               // → void
api.world_update(dt)            // → void

// 粒子
api.particle_spawn(x, y, vx, vy, radius, mass, restitution, color) // → int（索引）
api.particle_count()            // → int
api.particle_get_x(index)       // → float
api.particle_get_y(index)       // → float
api.particle_get_vx(index)      // → float
api.particle_get_vy(index)      // → float
api.particle_get_radius(index)  // → float
api.particle_get_color(index)   // → unsigned int（0xRRGGBBAA）

// 数学工具
api.add(a, b)                   // → int
api.fibonacci(n)                // → int
api.vec2_length(x, y)           // → float
api.vec2_dot(x1, y1, x2, y2)   // → float
```

---

### `game.js` — 入口与渲染

**职责**：创建 Canvas、异步加载 WASM、初始化物理世界、每帧更新并渲染。

#### 启动流程

```
wx.createCanvas()         // 1. 获取小游戏 Canvas
loadWasm()                // 2. 异步加载 WASM（见 wasm-loader.js）
  └─ api.world_init(W,H) // 3. 初始化物理世界（尺寸 = 画布尺寸）
  └─ spawnParticles(20)  // 4. 随机生成 20 个粒子
requestAnimationFrame(loop) // 5. 启动动画循环
```

#### 动画循环（`loop`）

```
loop(timestamp)
  ├─ 计算 dt = (timestamp - lastTime) / 1000  （秒，上限 50ms）
  ├─ api.world_update(dt)                      C++ 物理推进一帧
  ├─ drawBackground()                          渐变背景
  ├─ drawParticles()                           遍历粒子，绘制圆 + 发光
  └─ drawHUD()                                 标题 + 状态栏
```

#### 粒子渲染

每帧从 WASM 读取所有粒子的位置、半径、颜色：

```js
for (let i = 0; i < api.particle_count(); i++) {
  const x   = api.particle_get_x(i);
  const y   = api.particle_get_y(i);
  const r   = api.particle_get_radius(i);
  const css = colorToCSS(api.particle_get_color(i));  // 0xRRGGBBAA → rgba(...)
  ctx.arc(x, y, r, 0, Math.PI * 2);
  ctx.fillStyle = css;
}
```

#### 颜色格式转换

C++ 侧存储颜色为 `unsigned int`，格式 `0xRRGGBBAA`：

```js
function colorToCSS(packed) {
  const r = (packed >>> 24) & 0xff;
  const g = (packed >>> 16) & 0xff;
  const b = (packed >>>  8) & 0xff;
  const a = (packed & 0xff) / 255;
  return `rgba(${r},${g},${b},${a})`;
}
```

#### 粒子初始化参数

| 参数 | 范围 | 说明 |
|---|---|---|
| 半径 | 10 ~ 28 px | 随机 |
| 质量 | radius × 0.15 | 大球更重 |
| 弹性系数 | 0.55 ~ 0.95 | 随机 |
| 初始位置 | 上半屏随机 | 避免生成时穿墙 |
| 初始速度 | ±200 px/s | 随机方向 |
| 颜色 | 8 色循环 | 见 `COLORS` 数组 |

---

## 配置文件

### `game.json`

微信小游戏运行时配置，最小化设置：

```json
{
  "deviceOrientation": "portrait",
  "networkTimeout": { "request": 10000 }
}
```

### `project.config.json`

微信开发者工具项目配置：

```json
{
  "appid": "touristappid",      // 游客身份；替换为真实 AppID 可真机预览
  "compileType": "miniGame",
  "setting": {
    "minified": false,          // 保持源码不压缩（便于调试）
    "es6": true,                // 支持 ES6 语法
    "checkSiteMap": false       // 关闭 sitemap 检查（开发期间）
  }
}
```

---

## 数据流图

```
┌─────────────────────────────────────────────────┐
│                   game.js                        │
│                                                  │
│  requestAnimationFrame(loop)                     │
│          │                                       │
│          ▼                                       │
│   api.world_update(dt) ◄──── C++ / WASM         │
│          │                   (重力 + 碰撞)        │
│          ▼                                       │
│   api.particle_get_x/y/r/color(i)               │
│          │                                       │
│          ▼                                       │
│   Canvas 2D ctx.arc / ctx.fill                   │
└─────────────────────────────────────────────────┘

wasm-loader.js
  loadWasm() → DemoModule({ locateFile }) → cwrap → api 对象
                       ▲
               wasm/demo.js + demo.wasm
                       ▲
              由 cpp-module/build.sh 生成
```

---

## 扩展指南

### 增加粒子数量

修改 `game.js` 中的 `count` 变量（最大值受 `World::kMaxParticles = 64` 限制）。

### 调整重力

在 `cpp-module/src/physics/world.h` 中修改：
```cpp
static constexpr float kGravity = 600.0f;  // 单位：px/s²
```
然后重新执行 `./build.sh debug`。

### 添加触摸交互

在 `game.js` 中监听触摸事件，调用 WASM 函数给被触碰的粒子施加冲量：
```js
wx.onTouchStart(function (e) {
  const touch = e.touches[0];
  // 遍历粒子，找到最近的一个，然后修改其速度
  // （需要在 C++ 侧添加 particle_set_vel 导出函数）
});
```
