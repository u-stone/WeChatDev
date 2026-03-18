/**
 * game.js — Web Demo entry point
 *
 * Renders a 2-D particle physics simulation driven entirely by C++ WASM:
 *   - Gravity, boundary collisions, circle–circle collision resolution
 *   - Each particle has its own mass, restitution, radius, and colour
 * The JS side only handles rendering (Canvas 2D) and the animation loop.
 */

import { loadWasm } from './wasm-loader.js';

// ── Canvas ────────────────────────────────────────────────────────────────────
const canvas = document.getElementById('game-canvas');
const ctx    = canvas.getContext('2d');

// 设置画布尺寸
const W = 800;
const H = 600;
canvas.width = W;
canvas.height = H;

// ── State ─────────────────────────────────────────────────────────────────────
let api         = null;      // WasmApi — set once WASM is ready
let lastTime    = null;      // for delta-time calculation
let statusText  = 'Loading WASM…';
let statusColor = '#fff59d';

// Palette for particle colours (packed 0xRRGGBBAA)
const COLORS = [
  0x4fc3f7ff, // light blue
  0xf48fb1ff, // pink
  0xa5d6a7ff, // green
  0xffcc80ff, // orange
  0xce93d8ff, // purple
  0x80deeaff, // cyan
  0xffeb3bff, // yellow
  0xef9a9aff, // red
];

// ── WASM init ─────────────────────────────────────────────────────────────────
loadWasm()
  .then(function (wasmApi) {
    api = wasmApi;

    // Initialise world
    api.world_init(W, H);

    // Spawn particles with varied sizes, speeds, and restitutions
    const count = 20;
    for (let i = 0; i < count; i++) {
      const radius      = 10 + Math.random() * 18;
      const mass        = radius * 0.15;          // heavier = bigger
      const restitution = 0.55 + Math.random() * 0.40;
      const color       = COLORS[i % COLORS.length];

      const x  = radius + Math.random() * (W - radius * 2);
      const y  = radius + Math.random() * (H * 0.4);
      const vx = (Math.random() - 0.5) * 400;
      const vy = (Math.random() - 0.5) * 200;

      api.particle_spawn(x, y, vx, vy, radius, mass, restitution, color);
    }

    const fib = api.fibonacci(10);
    const sum = api.add(3, 7);
    console.log(`[WASM] fibonacci(10)=${fib}  add(3,7)=${sum}`);
    console.log(`[WASM] vec2_length(3,4)=${api.vec2_length(3, 4)}`);

    statusText  = `Physics: ${count} particles  |  fib(10)=${fib}  add(3,7)=${sum}`;
    statusColor = '#a5d6a7';
  })
  .catch(function (err) {
    statusText  = 'WASM load failed: ' + (err && err.message ? err.message : String(err));
    statusColor = '#ef9a9a';
    console.error('[WASM] Load error:', err);
  });

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Convert a packed 0xRRGGBBAA integer to a CSS rgba() string. */
function colorToCSS(packed) {
  const r = (packed >>> 24) & 0xff;
  const g = (packed >>> 16) & 0xff;
  const b = (packed >>>  8) & 0xff;
  const a = (packed & 0xff) / 255;
  return `rgba(${r},${g},${b},${a})`;
}

function drawBackground() {
  const grad = ctx.createLinearGradient(0, 0, 0, H);
  grad.addColorStop(0, '#0d1b2a');
  grad.addColorStop(1, '#1b263b');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
}

function drawParticles() {
  const n = api.particle_count();
  for (let i = 0; i < n; i++) {
    const x  = api.particle_get_x(i);
    const y  = api.particle_get_y(i);
    const r  = api.particle_get_radius(i);
    const c  = api.particle_get_color(i);
    const css = colorToCSS(c >>> 0);   // unsigned shift for safety

    // Glow
    ctx.shadowColor = css;
    ctx.shadowBlur  = r * 0.8;

    ctx.beginPath();
    ctx.arc(x, y, r, 0, Math.PI * 2);
    ctx.fillStyle = css;
    ctx.fill();
  }
  ctx.shadowBlur = 0;
}

function drawHUD() {
  // Title
  ctx.fillStyle = 'rgba(224,247,250,0.85)';
  ctx.font      = `bold ${Math.round(W * 0.055)}px sans-serif`;
  ctx.textAlign = 'center';
  ctx.fillText('C++ WASM Physics', W / 2, Math.round(H * 0.055));

  // Status bar
  ctx.fillStyle = statusColor;
  ctx.font      = `${Math.round(W * 0.033)}px monospace`;
  ctx.fillText(statusText, W / 2, H - Math.round(H * 0.025));
}

// ── Main loop ─────────────────────────────────────────────────────────────────
function loop(timestamp) {
  if (lastTime === null) lastTime = timestamp;
  const dt = Math.min((timestamp - lastTime) / 1000, 0.05);
  lastTime = timestamp;

  if (api) api.world_update(dt);

  drawBackground();
  if (api) drawParticles();
  drawHUD();

  requestAnimationFrame(loop);
}

requestAnimationFrame(loop);
