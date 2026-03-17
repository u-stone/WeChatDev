/**
 * demo.cpp — WASM export layer
 *
 * All functions marked EMSCRIPTEN_KEEPALIVE are exported to JavaScript.
 * A single global World instance is managed here; the JS side calls
 * world_init() once and then world_update(dt) every frame.
 */

#include <emscripten/emscripten.h>
#include "physics/world.h"
#include "math/vec2.h"

static World g_world;

extern "C" {

// ── World lifecycle ───────────────────────────────────────────────────────────

EMSCRIPTEN_KEEPALIVE
void world_init(float width, float height) {
    g_world.init(width, height);
}

EMSCRIPTEN_KEEPALIVE
void world_reset() {
    g_world.reset();
}

/// Advance the simulation by dt seconds. Call once per animation frame.
EMSCRIPTEN_KEEPALIVE
void world_update(float dt) {
    g_world.update(dt);
}

// ── Particle management ───────────────────────────────────────────────────────

/// Spawn a particle. Returns its stable index, or -1 if the limit is reached.
EMSCRIPTEN_KEEPALIVE
int particle_spawn(float x, float y,
                   float vx, float vy,
                   float radius, float mass,
                   float restitution, unsigned int color) {
    return g_world.spawnParticle(x, y, vx, vy, radius, mass, restitution, color);
}

EMSCRIPTEN_KEEPALIVE
int particle_count() {
    return g_world.particleCount();
}

EMSCRIPTEN_KEEPALIVE
float particle_get_x(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->pos.x : 0.0f;
}

EMSCRIPTEN_KEEPALIVE
float particle_get_y(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->pos.y : 0.0f;
}

EMSCRIPTEN_KEEPALIVE
float particle_get_vx(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->vel.x : 0.0f;
}

EMSCRIPTEN_KEEPALIVE
float particle_get_vy(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->vel.y : 0.0f;
}

EMSCRIPTEN_KEEPALIVE
float particle_get_radius(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->radius : 0.0f;
}

/// Returns the particle colour as a packed 0xRRGGBBAA integer.
EMSCRIPTEN_KEEPALIVE
unsigned int particle_get_color(int index) {
    const Particle* p = g_world.getParticle(index);
    return p ? p->color : 0x000000ff;
}

// ── Math utilities (kept for reference / unit-test convenience) ───────────────

EMSCRIPTEN_KEEPALIVE
int add(int a, int b) {
    return a + b;
}

EMSCRIPTEN_KEEPALIVE
int fibonacci(int n) {
    if (n <= 1) return n;
    int a = 0, b = 1;
    for (int i = 2; i <= n; ++i) {
        int tmp = a + b; a = b; b = tmp;
    }
    return b;
}

EMSCRIPTEN_KEEPALIVE
float vec2_length(float x, float y) {
    return Vec2{x, y}.length();
}

EMSCRIPTEN_KEEPALIVE
float vec2_dot(float x1, float y1, float x2, float y2) {
    return Vec2{x1, y1}.dot(Vec2{x2, y2});
}

} // extern "C"
