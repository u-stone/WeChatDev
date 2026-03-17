/**
 * wx-polyfills.js
 *
 * 微信小游戏环境与标准浏览器的 API 差异补丁。
 * 必须在 require('../wasm/demo.js') 之前执行（即 game.js 第一行 require）。
 *
 * 已修复的差异：
 *   1. WebAssembly              → WXWebAssembly（名称替换）
 *   2. WebAssembly.instantiateStreaming → 不存在，需手动实现
 *   3. WebAssembly.instantiate(ArrayBuffer) → WXWebAssembly 只接受文件路径字符串
 *   4. WebAssembly.RuntimeError / CompileError / LinkError → 不存在，需补充
 *   5. fetch                    → wx.getFileSystemManager().readFile
 */

// ── 辅助：追踪最近一次 fetch 的 .wasm 文件路径 ────────────────────────────────
// WXWebAssembly.instantiate 只接受文件路径，不接受 ArrayBuffer。
// Emscripten 在调用 instantiate 前必然先调用 fetch(url)，因此在 fetch 里
// 记录 URL，供后续 instantiate 重定向使用。
var _lastWasmUrl = 'wasm/demo.wasm'; // 默认兜底路径

// ── 1. fetch polyfill ─────────────────────────────────────────────────────────
if (typeof fetch === 'undefined') {
  globalThis.fetch = function wxFetch(url) {
    // 同步记录 .wasm 路径（fetch 本身是异步的，但记录在 Promise 创建前完成）
    if (typeof url === 'string' && url.indexOf('.wasm') !== -1) {
      _lastWasmUrl = url;
    }
    return new Promise(function (resolve, reject) {
      wx.getFileSystemManager().readFile({
        filePath: url,
        success: function (res) {
          var buf = res.data; // ArrayBuffer
          resolve({
            ok: true,
            status: 200,
            arrayBuffer: function () { return Promise.resolve(buf); },
            text: function () {
              var arr = new Uint8Array(buf);
              var str = '';
              var CHUNK = 8192;
              for (var i = 0; i < arr.length; i += CHUNK) {
                str += String.fromCharCode.apply(null, arr.subarray(i, i + CHUNK));
              }
              return Promise.resolve(str);
            },
          });
        },
        fail: function (err) {
          reject(new Error(
            '[wx-polyfill] readFile failed for "' + url + '": ' +
            (err.errMsg || JSON.stringify(err))
          ));
        },
      });
    });
  };
  console.log('[polyfill] fetch → wx.getFileSystemManager().readFile');
}

// ── 2. WebAssembly → WXWebAssembly ────────────────────────────────────────────
if (typeof WebAssembly === 'undefined') {
  if (typeof WXWebAssembly !== 'undefined') {
    globalThis.WebAssembly = WXWebAssembly;
    console.log('[polyfill] WebAssembly → WXWebAssembly');
  } else {
    console.error('[polyfill] WXWebAssembly not available — WASM cannot run');
  }
}

// 以下补丁均基于 globalThis.WebAssembly（可能是 WXWebAssembly）
if (globalThis.WebAssembly) {
  var _WX = WXWebAssembly; // 保存原始引用，避免被后续补丁覆盖

  // ── 3. WebAssembly.instantiate(ArrayBuffer) 补丁 ────────────────────────────
  // WXWebAssembly.instantiate 只接受文件路径字符串（'.wasm' 或 '.wasm.br'），
  // 不接受 ArrayBuffer 或 WebAssembly.Module。
  // Emscripten 的 fallback 路径会传入 ArrayBuffer，需重定向到文件路径加载。
  var _origInstantiate = _WX.instantiate.bind(_WX);
  globalThis.WebAssembly.instantiate = function (source, imports) {
    if (typeof source === 'string') {
      // 已经是文件路径，直接转发
      return _origInstantiate(source, imports || {});
    }
    // source 是 ArrayBuffer 或 Module —— WXWebAssembly 不支持，改用文件路径
    console.log('[polyfill] WebAssembly.instantiate(buffer) → WXWebAssembly.instantiate(' + _lastWasmUrl + ')');
    return _origInstantiate(_lastWasmUrl, imports || {});
  };

  // ── 4. WebAssembly.instantiateStreaming 补丁 ─────────────────────────────────
  // WXWebAssembly 没有此方法。Emscripten 优先尝试 instantiateStreaming，
  // 失败后才 fallback 到 instantiate。这里直接用文件路径绕过 streaming。
  globalThis.WebAssembly.instantiateStreaming = function (sourcePromise, imports) {
    console.log('[polyfill] WebAssembly.instantiateStreaming → WXWebAssembly.instantiate(' + _lastWasmUrl + ')');
    return _WX.instantiate(_lastWasmUrl, imports || {});
  };

  // ── 5. 补充缺失的错误类型 ────────────────────────────────────────────────────
  // Emscripten 用 `new WebAssembly.RuntimeError(msg)` 抛出运行时错误，
  // WXWebAssembly 未提供这些构造函数。
  if (typeof globalThis.WebAssembly.RuntimeError !== 'function') {
    globalThis.WebAssembly.RuntimeError = /** @class */ (function (_super) {
      function RuntimeError(msg) { _super.call(this, msg); this.name = 'RuntimeError'; }
      RuntimeError.prototype = Object.create(_super.prototype);
      return RuntimeError;
    }(Error));
  }
  if (typeof globalThis.WebAssembly.CompileError !== 'function') {
    globalThis.WebAssembly.CompileError = /** @class */ (function (_super) {
      function CompileError(msg) { _super.call(this, msg); this.name = 'CompileError'; }
      CompileError.prototype = Object.create(_super.prototype);
      return CompileError;
    }(Error));
  }
  if (typeof globalThis.WebAssembly.LinkError !== 'function') {
    globalThis.WebAssembly.LinkError = /** @class */ (function (_super) {
      function LinkError(msg) { _super.call(this, msg); this.name = 'LinkError'; }
      LinkError.prototype = Object.create(_super.prototype);
      return LinkError;
    }(Error));
  }

  console.log('[polyfill] WebAssembly patches applied (instantiate / instantiateStreaming / error types)');
}
