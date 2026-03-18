# cpp-module — C++ 物理引擎 → WebAssembly

本子项目将一个完整的 2D 粒子物理引擎编译为 WebAssembly，供微信小游戏（`minigame/`）加载调用。

编译工具链：**Emscripten**（`emcmake cmake` + `emmake make`）  
构建系统：**CMake**（`CMakeLists.txt`）  
输出目录：`../minigame/wasm/`

---

## 目录结构

```
cpp-module/
├── src/
│   ├── math/
│   │   └── vec2.h           2D 向量数学库（header-only）
│   ├── physics/
│   │   ├── particle.h       粒子数据结构（POD）
│   │   ├── world.h          物理世界类接口
│   │   └── world.cpp        物理引擎实现
│   └── demo.cpp             WASM 导出层（extern "C" 接口）
├── CMakeLists.txt           编译配置
├── build.sh                 构建脚本
└── README.md                本文件
```

---

## 模块详解

### `src/math/vec2.h` — 2D 向量库

Header-only，零依赖，供物理引擎内部使用。

```cpp
struct Vec2 {
    float x, y;

    // 运算符重载
    Vec2 operator+(const Vec2&) const;   // 向量加法
    Vec2 operator-(const Vec2&) const;   // 向量减法
    Vec2 operator*(float s)    const;   // 标量乘法
    Vec2 operator/(float s)    const;   // 标量除法
    Vec2& operator+=(const Vec2&);
    Vec2& operator-=(const Vec2&);
    Vec2& operator*=(float s);

    // 工具方法
    float length()   const;             // 向量模长 √(x²+y²)
    float lengthSq() const;             // 模长平方（避免开方，用于比较）
    float dot(const Vec2&) const;       // 点积
    float cross(const Vec2&) const;     // 2D 叉积（返回标量）
    Vec2  normalized() const;           // 单位向量
    Vec2  reflected(const Vec2& n) const; // 关于法线 n 的反射向量
};
```

**为什么 header-only？** `Vec2` 的所有方法都很短，内联后编译器可以充分优化，无需单独 `.cpp`。

---

### `src/physics/particle.h` — 粒子数据结构

纯数据结构（POD-like），不含任何逻辑：

```cpp
struct Particle {
    int          id;           // 粒子唯一 ID（由 World 分配，从 0 递增）
    Vec2         pos;          // 当前位置（像素坐标）
    Vec2         vel;          // 当前速度（像素/秒）
    float        radius;       // 碰撞圆半径（像素）
    float        mass;         // 质量（影响碰撞冲量分配）
    float        restitution;  // 弹性系数：0 = 完全非弹性，1 = 完全弹性
    unsigned int color;        // 颜色，格式 0xRRGGBBAA（供 JS 渲染用）
};
```

---

### `src/physics/world.h` / `world.cpp` — 物理世界

`World` 类管理所有粒子，每帧调用 `update(dt)` 推进模拟。

#### 公开接口

```cpp
class World {
public:
    static constexpr int   kMaxParticles = 64;    // 最大粒子数
    static constexpr float kGravity      = 600.0; // 重力加速度（px/s²）
    static constexpr float kFloorFriction = 0.97; // 落地摩擦系数

    void init(float width, float height);  // 初始化世界尺寸
    void reset();                          // 清空所有粒子

    // 生成粒子，返回其索引；超过上限返回 -1
    int spawnParticle(float x, float y, float vx, float vy,
                      float radius, float mass,
                      float restitution, unsigned int color);

    void update(float dt);                          // 推进物理模拟
    int             particleCount() const;          // 当前粒子数
    const Particle* getParticle(int index) const;   // 按索引获取粒子
};
```

#### 每帧模拟步骤（`update` 内部）

```
1. applyGravity(dt)        — 对所有粒子施加向下加速度（vel.y += G * dt）
2. integrate(dt)           — 欧拉积分更新位置（pos += vel * dt）
3. resolveBoundaries()     — AABB 边界碰撞（左/右/上/下四面墙，带弹性）
4. resolveCollisions()     — 圆-圆碰撞（O(n²) 遍历，含位置修正 + 冲量解算）
```

#### 碰撞解算算法

**位置修正**（防止粒子穿透）：
```
overlap = (ra + rb) - dist
a.pos -= normal * overlap * (mb / (ma + mb))
b.pos += normal * overlap * (ma / (ma + mb))
```

**冲量解算**（改变速度）：
```
j = -(1 + e) * relVel·normal / (1/ma + 1/mb)
a.vel -= normal * j / ma
b.vel += normal * j / mb
```
其中 `e = min(a.restitution, b.restitution)`。

---

### `src/demo.cpp` — WASM 导出层

所有用 `EMSCRIPTEN_KEEPALIVE` 标注的函数都会被导出到 JavaScript，通过 `extern "C"` 防止 C++ 名称修饰。全局持有一个 `World` 实例 `g_world`。

#### 导出函数总览（15 个）

**世界生命周期**

| 函数 | 签名 | 说明 |
|---|---|---|
| `world_init` | `void(float w, float h)` | 初始化世界，设定边界尺寸 |
| `world_reset` | `void()` | 清空所有粒子 |
| `world_update` | `void(float dt)` | 推进一帧（dt 单位：秒） |

**粒子操作**

| 函数 | 签名 | 说明 |
|---|---|---|
| `particle_spawn` | `int(x, y, vx, vy, radius, mass, restitution, color)` | 生成粒子，返回索引 |
| `particle_count` | `int()` | 当前粒子数量 |
| `particle_get_x` | `float(int index)` | 粒子 X 坐标 |
| `particle_get_y` | `float(int index)` | 粒子 Y 坐标 |
| `particle_get_vx` | `float(int index)` | 粒子 X 速度 |
| `particle_get_vy` | `float(int index)` | 粒子 Y 速度 |
| `particle_get_radius` | `float(int index)` | 粒子半径 |
| `particle_get_color` | `unsigned int(int index)` | 粒子颜色（0xRRGGBBAA） |

**数学工具**

| 函数 | 签名 | 说明 |
|---|---|---|
| `add` | `int(int a, int b)` | 整数加法 |
| `fibonacci` | `int(int n)` | 第 n 个斐波那契数 |
| `vec2_length` | `float(float x, float y)` | 向量模长 |
| `vec2_dot` | `float(x1, y1, x2, y2)` | 向量点积 |

---

## CMakeLists.txt 说明

```cmake
add_executable(demo
    src/demo.cpp          # 导出层
    src/physics/world.cpp # 物理引擎
    # vec2.h 和 particle.h 是 header-only，无需列出
)
```

关键 Emscripten 链接选项：

| 选项 | 作用 |
|---|---|
| `-sWASM=1` | 输出 .wasm 二进制（而非 asm.js） |
| `-sMODULARIZE=1` | 输出为工厂函数，可 `require()` |
| `-sEXPORT_NAME=DemoModule` | 工厂函数名 |
| `-sEXPORTED_FUNCTIONS=[...]` | 声明需要保留的 C 函数 |
| `-sEXPORTED_RUNTIME_METHODS=["cwrap"]` | 暴露 `cwrap` 给 JS |
| `-sNO_FILESYSTEM=1` | 去掉 libc 文件系统（减小体积） |
| `-sALLOW_MEMORY_GROWTH=1` | 允许 WASM 堆按需扩展 |
| `-g3` *(Debug only)* | 嵌入完整 DWARF 调试信息 |
| `--emit-source-map` *(Debug only)* | 生成 .wasm.map（C++ 行映射） |
| `-O2` *(Release only)* | 编译器优化 |

---

## 构建说明

### 安装 emsdk

```bash
git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
cd ~/emsdk && ./emsdk install latest && ./emsdk activate latest
source ~/emsdk/emsdk_env.sh
```

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
| **sourcemap_embed** | `-gsource-map` | 内嵌在 `demo.wasm` | 需要单文件部署的场景 |
| **dwarf** | `-g4` | 内置在 `demo.wasm` | Chrome DevTools 直接调试 C++ 源码 |

### 输出文件

构建完成后，以下文件会出现在 `../minigame/wasm/`：

| 文件 | 说明 |
|---|---|
| `demo.js` | Emscripten 胶水代码，负责加载 .wasm、初始化内存 |
| `demo.wasm` | WebAssembly 二进制（实际的 C++ 编译产物） |
| `demo.wasm.map` | sourcemap：WASM 字节偏移 ↔ C++ 源码行号（debug 构建） |

---

## 扩展指南：新增导出函数

**第一步**：在 `src/` 中实现函数并标注导出：
```cpp
// src/demo.cpp
EMSCRIPTEN_KEEPALIVE
float my_func(float x) {
    return x * 2.0f;
}
```

**第二步**：在 `CMakeLists.txt` 的 `EXPORTED_FUNCTIONS` 中追加：
```cmake
"...,\"_my_func\"\
]"
```

**第三步**：在 `minigame/js/wasm-loader.js` 中用 `cwrap` 包装并导出（详见 minigame/README.md）。
