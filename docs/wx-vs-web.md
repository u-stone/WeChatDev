# 微信小游戏 vs 标准 Web 开发差异手册

本文档记录在本项目开发过程中发现的微信小游戏运行环境与标准浏览器（Web）环境的所有已知差异。  
每条差异均附有问题背景、原因说明，以及在本项目中的实际解决方案（如适用）。

---

## 目录

1. [WebAssembly](#1-webassembly)
2. [fetch / 网络请求](#2-fetch--网络请求)
3. [Canvas](#3-canvas)
4. [DOM / Window / Document](#4-dom--window--document)
5. [模块系统](#5-模块系统)
6. [全局对象](#6-全局对象)
7. [文件系统](#7-文件系统)
8. [本地存储](#8-本地存储)
9. [多媒体（图片、音频）](#9-多媒体图片音频)
10. [WebSocket](#10-websocket)
11. [Worker 线程](#11-worker-线程)
12. [定时器与动画帧](#12-定时器与动画帧)
13. [编码 / 解码工具](#13-编码--解码工具)
14. [SharedArrayBuffer](#14-sharedarraybuffer)
15. [DevTools 内部 WASM Sourcemap 解析器（组件缺失）](#15-devtools-内部-wasm-sourcemap-解析器)
16. [CMake Generator Expression 在 emcmake 中不生效](#16-cmake-generator-expression-在-emcmake-中不生效)
17. [--emit-source-map 在 Emscripten 3.x/5.x 中被废弃](#17---emit-source-map-在-emscripten-3x--5x-中被废弃)
18. [WASM Sourcemap 的 --source-map-base 路径](#18-wasm-sourcemap-的---source-map-base-路径)
19. [DevTools 将 WASM 模块映射为 wasm:// 虚拟 URL](#19-devtools-将-wasm-模块映射为-wasm-虚拟-url)
20. [DevTools 内部 Sourcemap 解析器崩溃](#20-devtools-内部-sourcemap-解析器崩溃)
21. [npm 包兼容性](#21-npm-包兼容性)

---

## 1. WebAssembly

### 标准 Web
```js
WebAssembly.instantiate(buffer, imports)           // 接受 ArrayBuffer 或 Module
WebAssembly.instantiateStreaming(fetchPromise, imports) // 流式编译（最快）
WebAssembly.compile(buffer)
new WebAssembly.Module(buffer)
new WebAssembly.Instance(module, imports)
new WebAssembly.RuntimeError('msg')
new WebAssembly.CompileError('msg')
new WebAssembly.LinkError('msg')
```

### 微信小游戏
`WebAssembly` 全局对象**不存在**，替代品是 `WXWebAssembly`，但 **API 不完全兼容**：

| 标准 API | WXWebAssembly 行为 |
|---|---|
| `WebAssembly`（全局对象） | ❌ 不存在，需用 `WXWebAssembly` |
| `instantiate(buffer, imports)` | ❌ **只接受文件路径字符串**（`.wasm`/`.wasm.br`），不接受 `ArrayBuffer` |
| `instantiateStreaming(promise, imports)` | ❌ 方法**不存在** |
| `RuntimeError` / `CompileError` / `LinkError` | ❌ 不存在，需手动补充 |
| `compile(buffer)` | 部分支持 |

```js
// WXWebAssembly 正确用法：只能传文件路径
WXWebAssembly.instantiate('wasm/demo.wasm', imports)
  .then(({ instance, module }) => { /* ... */ });
```

### 本项目解决方案

在 `minigame/js/wx-polyfills.js` 中：

```js
// 1. 挂载 WebAssembly 名称
globalThis.WebAssembly = WXWebAssembly;

// 2. 覆盖 instantiate：将 ArrayBuffer 参数重定向为文件路径加载
WebAssembly.instantiate = function(source, imports) {
  if (typeof source === 'string') return WXWebAssembly.instantiate(source, imports);
  return WXWebAssembly.instantiate(_lastWasmUrl, imports); // 忽略 buffer，用路径
};

// 3. 补充缺失的 instantiateStreaming
WebAssembly.instantiateStreaming = function(sourcePromise, imports) {
  return WXWebAssembly.instantiate(_lastWasmUrl, imports);
};

// 4. 补充缺失的错误类型
WebAssembly.RuntimeError = class extends Error { ... };
WebAssembly.CompileError  = class extends Error { ... };
WebAssembly.LinkError     = class extends Error { ... };
```

> `_lastWasmUrl` 由 `fetch` polyfill 在加载 `.wasm` 文件时同步记录。

### 参考
- 日志：`instantiateStreaming is not a function`、`only support file type .wasm or .wasm.br`、`RuntimeError is not a constructor`
- [微信 WXWebAssembly 文档](https://developers.weixin.qq.com/minigame/dev/api/base/wx.WXWebAssembly.html)

---

## 2. fetch / 网络请求

### 标准 Web

| API | 用途 |
|---|---|
| `fetch(url)` | 读取远程或本地资源，返回 `Response` |
| `XMLHttpRequest` | 经典异步请求对象 |

### 微信小游戏
- `fetch` **不存在**
- `XMLHttpRequest` **不存在**
- 网络请求用 `wx.request()`
- 读取**包内文件**用 `wx.getFileSystemManager().readFile()`

```js
// 读取包内文件（如 .wasm）
wx.getFileSystemManager().readFile({
  filePath: 'wasm/demo.wasm',   // 相对于小游戏包根目录
  success(res) { /* res.data 是 ArrayBuffer */ },
  fail(err) { console.error(err.errMsg); }
});

// 网络请求
wx.request({
  url: 'https://example.com/api',
  success(res) { console.log(res.data); }
});
```

### 本项目解决方案
在 `wx-polyfills.js` 中用 `readFile` 实现兼容 `fetch`：
```js
globalThis.fetch = function wxFetch(url) {
  return new Promise((resolve, reject) => {
    wx.getFileSystemManager().readFile({
      filePath: url,
      success(res) {
        resolve({ ok: true, arrayBuffer: () => Promise.resolve(res.data) });
      },
      fail(err) { reject(new Error(err.errMsg)); }
    });
  });
};
```

> ⚠️ 此 `fetch` polyfill 仅适用于读取**包内本地文件**，不支持跨域网络请求。  
> 如需请求外部接口，请直接使用 `wx.request()`。

---

## 3. Canvas

### 标准 Web
```js
const canvas = document.getElementById('myCanvas');
const ctx = canvas.getContext('2d');
```

### 微信小游戏
没有 DOM，Canvas 由 `wx.createCanvas()` 创建：
```js
const canvas = wx.createCanvas();  // 自动绑定到屏幕，宽高等于设备屏幕
const ctx = canvas.getContext('2d');

// 离屏 Canvas（用于纹理、缓冲等）
const offscreen = wx.createCanvas();   // 第二次调用创建离屏 Canvas
```

### 差异细节
- 第一次 `wx.createCanvas()` 返回**主屏 Canvas**，后续调用返回离屏 Canvas
- `canvas.width` / `canvas.height` 默认等于设备逻辑像素尺寸（已乘以 `devicePixelRatio`）
- 不支持 `canvas.toBlob()`，用 `wx.canvasToTempFilePath()` 代替截图

---

## 4. DOM / Window / Document

### 标准 Web
完整 DOM 树：`document`、`window`、`navigator`、`location`、HTML 元素等。

### 微信小游戏
**完全没有 DOM**，以下对象均不存在：

| Web API | 微信替代 | 备注 |
|---|---|---|
| `document` | ❌ 无 | 不存在 |
| `window` | 部分存在 | 仅极少数属性可用 |
| `window.innerWidth/Height` | `wx.getSystemInfoSync()` | |
| `navigator.userAgent` | `wx.getSystemInfoSync()` | |
| `navigator.language` | `wx.getSystemInfoSync().language` | |
| `location.href` | ❌ 无 | |
| `alert / confirm / prompt` | `wx.showModal()` 等 | |
| `console.*` | `console.*` | 可用，但输出在开发者工具中 |

> 任何依赖 DOM 的第三方库（如 jQuery、React DOM 等）均**无法在微信小游戏中使用**。

---

## 5. 模块系统

### 标准 Web（现代）
ES Modules：
```js
import { foo } from './foo.js';
export const bar = 42;
```

### 微信小游戏
仅支持 **CommonJS**：
```js
const { foo } = require('./foo.js');
module.exports = { bar: 42 };
```

> `import` / `export` 语法**不可用**（截至本文档撰写时）。  
> 即使在 `project.config.json` 开启了 `"es6": true`，也只是转译箭头函数等语法糖，  
> 并非真正支持 ES Module 的静态导入。

---

## 6. 全局对象

### 标准 Web
```js
globalThis === window   // true（浏览器中）
```

### 微信小游戏
```js
// globalThis 存在，但 window 不等同于 globalThis
// 推荐始终用 globalThis 访问/设置全局变量
globalThis.myGlobal = 'value';
```

向全局挂载 polyfill 时必须用 `globalThis`，不能用 `window`：
```js
// ✅ 正确
globalThis.WebAssembly = WXWebAssembly;

// ❌ 可能失败：window 不一定等于全局作用域
window.WebAssembly = WXWebAssembly;
```

---

## 7. 文件系统

### 标准 Web
浏览器出于安全限制，无法直接访问本地文件系统（除 File System Access API 外）。

### 微信小游戏
提供完整的虚拟文件系统 API，分为两个区域：

| 区域 | 路径前缀 | 说明 |
|---|---|---|
| **代码包** | 相对路径（如 `wasm/demo.wasm`） | 随小游戏一起下载的资源 |
| **用户数据目录** | `wx.env.USER_DATA_PATH` | 可读写，用于存储运行时文件 |

```js
const fs = wx.getFileSystemManager();

// 读取代码包内文件（只读）
fs.readFile({ filePath: 'wasm/demo.wasm', success(res) { /* ArrayBuffer */ } });

// 写入用户数据目录
fs.writeFile({
  filePath: `${wx.env.USER_DATA_PATH}/save.json`,
  data: JSON.stringify(saveData),
  encoding: 'utf8'
});
```

---

## 8. 本地存储

### 标准 Web
```js
localStorage.setItem('key', 'value');
const val = localStorage.getItem('key');
```

### 微信小游戏

```js
// 异步（推荐）
wx.setStorage({ key: 'score', data: 100 });
wx.getStorage({ key: 'score', success(res) { console.log(res.data); } });

// 同步
wx.setStorageSync('score', 100);
const score = wx.getStorageSync('score');
```

> `localStorage` / `sessionStorage` **不存在**。

---

## 9. 多媒体（图片、音频）

### 图片

| Web | 微信小游戏 |
|---|---|
| `new Image()` | `wx.createImage()` |
| `img.src = url` | 相同 |
| `img.onload` | 相同 |

```js
const img = wx.createImage();
img.src = 'images/bg.png';
img.onload = () => ctx.drawImage(img, 0, 0);
```

### 音频

| Web | 微信小游戏 |
|---|---|
| `new Audio()` | `wx.createInnerAudioContext()` |
| `audio.play()` | `audio.play()` |
| `audio.src` | `audio.src` |

---

## 10. WebSocket

### 标准 Web
```js
const ws = new WebSocket('wss://example.com');
ws.onmessage = (e) => console.log(e.data);
```

### 微信小游戏
```js
const ws = wx.connectSocket({ url: 'wss://example.com' });
ws.onMessage((res) => console.log(res.data));
```

> `WebSocket` 构造函数**不存在**，必须用 `wx.connectSocket()`。

---

## 11. Worker 线程

### 标准 Web
```js
const worker = new Worker('./worker.js');
worker.postMessage({ type: 'start' });
```

### 微信小游戏
```js
const worker = wx.createWorker('workers/my-worker.js');
worker.postMessage({ type: 'start' });
worker.onMessage((res) => console.log(res));
```

Worker 文件路径需要在 `game.json` 中声明：
```json
{
  "workers": "workers"
}
```

---

## 12. 定时器与动画帧

### 可直接使用（与 Web 相同）
```js
setTimeout(fn, ms)
clearTimeout(id)
setInterval(fn, ms)
clearInterval(id)
requestAnimationFrame(fn)   // 与屏幕刷新率同步（推荐用于游戏循环）
cancelAnimationFrame(id)
```

> `requestAnimationFrame` 在微信小游戏中**完全可用**，回调参数是 `DOMHighResTimeStamp`，与标准相同。

---

## 13. 编码 / 解码工具

### 标准 Web
```js
new TextDecoder().decode(buffer)
new TextEncoder().encode(str)
btoa(str) / atob(str)
```

### 微信小游戏
- **`TextDecoder`** / **`TextEncoder`**：在较新版本的基础库中可用，旧版本可能不存在，需做兼容判断
- **`btoa` / `atob`**：可用

```js
// 安全写法
function decodeBuffer(buf) {
  if (typeof TextDecoder !== 'undefined') {
    return new TextDecoder().decode(new Uint8Array(buf));
  }
  // 降级：分块转字符串，避免大数组导致栈溢出
  const arr = new Uint8Array(buf);
  let str = '';
  for (let i = 0; i < arr.length; i += 8192) {
    str += String.fromCharCode.apply(null, arr.subarray(i, i + 8192));
  }
  return str;
}
```

---

## 14. SharedArrayBuffer

### 标准 Web
需要页面设置 `Cross-Origin-Opener-Policy` 和 `Cross-Origin-Embedder-Policy` 响应头才能使用。

### 微信小游戏
日志中出现警告：
```
SharedArrayBuffer will require cross-origin isolation as of M92
```
该警告来自开发者工具内嵌的 Chromium 内核，**不影响小游戏实际运行**（小游戏本身并不使用 SharedArrayBuffer）。可安全忽略。

---

## 15. DevTools 内部 WASM Sourcemap 解析器

### 现象
```
DevTools failed to load SourceMap:
While loading from url ./sdk/wasm_source_map/pkg/wasm_source_map_bg.wasm
server responded with a status of 404
```

### 说明
这个错误**不是我们的代码问题**。路径 `./sdk/wasm_source_map/pkg/wasm_source_map_bg.wasm` 是微信开发者工具自身内置的一个 Rust/WASM 组件，用于解析 WASM 调试 sourcemap。404 表示该工具组件在当前 DevTools 版本中缺失或安装不完整。

- 此错误**不影响小游戏运行**（WASM 照常加载执行）
- 此错误可能导致 C++ 断点调试功能不可用
- **解决方法**：将微信开发者工具更新到最新版本，或完整卸载后重新安装

### 区分方法
| 路径特征 | 来源 |
|---|---|
| `./sdk/wasm_source_map/pkg/wasm_source_map_bg.wasm` | DevTools 自身组件，与我们无关 |
| `wasm/demo.wasm.map` | 我们的 C++ 调试 sourcemap |

---

## 16. CMake Generator Expression 在 emcmake 中不生效

### 现象
用 `$<$<CONFIG:Debug>:--emit-source-map>` 等 CMake 生成器表达式控制 Debug/Release 编译标志时，`demo.wasm.map` **不会被生成**，即使用的是 Debug 构建。

### 原因
`emcmake cmake` 在某些版本中不能正确地在链接阶段评估生成器表达式，导致调试标志被静默忽略。

### 本项目解决方案
将生成器表达式改为普通的 `if/else`：

```cmake
# ❌ 不可靠（generator expression 可能不生效）
"$<$<CONFIG:Debug>:-gsource-map>"

# ✅ 可靠（直接判断变量）
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(demo PRIVATE "-gsource-map")
    target_link_options(demo PRIVATE "-gsource-map" "--source-map-base=./")
else()
    target_link_options(demo PRIVATE "-O2")
endif()
```

---

## 17. `--emit-source-map` 在 Emscripten 3.x / 5.x 中被废弃

### 现象
```
clang: error: unknown argument: '--emit-source-map'
```
构建完成后 `demo.wasm.map` 不存在。

### 原因
`--emit-source-map` 是 Emscripten 早期版本的标志，**在 Emscripten 3.x 及以后（包括 5.x）被废弃**。正确标志是 `-gsource-map`。

### 版本对照

| Emscripten 版本 | 生成 sourcemap 的正确标志 |
|---|---|
| < 3.x（旧版） | `--emit-source-map` |
| ≥ 3.x（包括 5.x） | `-gsource-map` |

```bash
# ❌ 旧版写法（emcc 5.x 报 unknown argument 错误）
emcc ... -g3 --emit-source-map

# ✅ 新版写法（emcc 3.x / 5.x）
emcc ... -gsource-map --source-map-base=./
```

检查当前版本：`emcc --version`

---

## 18. WASM Sourcemap 的 `--source-map-base` 路径

### 现象
在 Emscripten 中设置 `--source-map-base=wasm/`，DevTools 找不到 sourcemap 文件。

### 原因
`--source-map-base` 设置的是嵌入 WASM 二进制的 `sourceMappingURL` 前缀。如果 WASM 文件在 `wasm/demo.wasm`，设置 `--source-map-base=wasm/` 会生成：
```
sourceMappingURL = wasm/demo.wasm.map
```
DevTools 将该 URL 解析为相对于 WASM 文件的路径，最终尝试加载 `wasm/wasm/demo.wasm.map`（路径重复），导致 404。

### 正确设置
`demo.wasm` 和 `demo.wasm.map` 在同一目录（`wasm/`）时，应使用：
```cmake
"--source-map-base=./"
```
这样 `sourceMappingURL = ./demo.wasm.map`，DevTools 正确解析为同目录下的 `demo.wasm.map`。

---

## 19. DevTools 将 WASM 模块映射为 `wasm://` 虚拟 URL

### 现象
```
Could not load content for wasm://wasm/demo.wasm.map:
HTTP error: status code 404, net::ERR_UNKNOWN_URL_SCHEME
```
即使 `demo.wasm.map` 文件存在于 `minigame/wasm/` 目录，sourcemap 仍然无法被 DevTools 加载。

### 原因
当 DevTools 通过 `WXWebAssembly.instantiate(filePath)` 加载 WASM 模块后，它会给该模块分配一个内部虚拟 URL：
```
wasm://wasm/<hash>
```
DevTools 以这个虚拟 URL 为基准，将 WASM 二进制中的 `sourceMappingURL=./demo.wasm.map` 解析为：
```
wasm://wasm/demo.wasm.map
```
然后尝试用 HTTP fetch 这个 URL——但 `wasm://` 不是真实的网络协议，导致 `ERR_UNKNOWN_URL_SCHEME`。

### 影响
- 小游戏**正常运行**不受影响（WASM 逻辑完全正确）
- C++ 断点调试功能在该版本 DevTools 中**不可用**

### 这是 DevTools 的已知限制
`--source-map-base` 无论设置什么相对路径，都无法绕过这个问题，因为 DevTools 强制使用 `wasm://` 作为 WASM 模块的基准 URL。

可能的解决途径（供参考，未经验证）：
- 更新微信开发者工具到支持本地文件协议 WASM sourcemap 的版本
- 将 `--source-map-base` 设为 DevTools 本地 HTTP 服务的绝对 URL（但 DevTools 端口每次可能变化）

---

## 20. DevTools 内部 Sourcemap 解析器崩溃

### 现象
```
Cannot read property 'indexOf' of undefined
    at Y (core.wxvpkg ...)
```
该错误发生在 DevTools 启动阶段（polyfill 加载之前），堆栈完全在 DevTools 内部代码（`core.wxvpkg`）中。

### 原因
DevTools 内置的 sourcemap 解析器在处理某个文件（可能是 Emscripten 生成的 `demo.js` 末尾的 `//# sourceMappingURL` 注释）时，遇到了 `undefined` 值并崩溃。这是 DevTools 自身 bug，与项目代码无关。

### 影响
- 小游戏**正常运行**不受影响（错误发生在 DevTools 初始化阶段）
- **解决方法**：升级微信开发者工具

---

## 21. npm 包兼容性

### 标准 Web / Node.js
大多数 npm 包可直接使用。

### 微信小游戏
以下类型的包**无法使用**：

| 类型 | 原因 |
|---|---|
| 依赖 DOM 的包（jQuery、React DOM 等） | 无 DOM |
| 依赖 `fs` / `path` 的 Node.js 包 | 无 Node.js 内置模块 |
| 使用 ES Module 语法的包 | 只支持 CommonJS |
| 依赖 `XMLHttpRequest` / `fetch` 的包 | 需要 polyfill |
| 依赖 `WebAssembly` 的包（如 Emscripten 输出） | 需要 `WXWebAssembly` polyfill |

**可以使用**的包：纯逻辑库（如 lodash-es 的 CommonJS 版、数学库、加密库等）。

---

## 附：本项目中的实际补丁汇总

所有运行时补丁集中在 `minigame/js/wx-polyfills.js`：

```
WebAssembly  → globalThis.WebAssembly = WXWebAssembly
fetch        → wx.getFileSystemManager().readFile
```

如后续发现更多差异，请在此文件中补充 polyfill，并在本文档中新增对应条目。
