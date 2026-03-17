/**
 * wasm-loader.js
 *
 * Loads the Emscripten-generated DemoModule and wraps every exported C++
 * function so callers work with plain JS functions instead of raw cwrap handles.
 *
 * Usage:
 *   const api = await loadWasm();
 *   api.world_init(320, 480);
 *   api.world_update(0.016);
 *   const x = api.particle_get_x(0);
 */

const DemoModule = require('../wasm/demo.js');

/**
 * @typedef {Object} WasmApi
 *
 * World
 * @property {(w:number, h:number)=>void}   world_init
 * @property {()=>void}                     world_reset
 * @property {(dt:number)=>void}            world_update
 *
 * Particles
 * @property {(x:number,y:number,vx:number,vy:number,r:number,m:number,e:number,c:number)=>number} particle_spawn
 * @property {()=>number}                   particle_count
 * @property {(i:number)=>number}           particle_get_x
 * @property {(i:number)=>number}           particle_get_y
 * @property {(i:number)=>number}           particle_get_vx
 * @property {(i:number)=>number}           particle_get_vy
 * @property {(i:number)=>number}           particle_get_radius
 * @property {(i:number)=>number}           particle_get_color
 *
 * Math utilities
 * @property {(a:number,b:number)=>number}        add
 * @property {(n:number)=>number}                 fibonacci
 * @property {(x:number,y:number)=>number}        vec2_length
 * @property {(x1:number,y1:number,x2:number,y2:number)=>number} vec2_dot
 */

/**
 * Initialise the WASM module and return all wrapped C-function bindings.
 * @returns {Promise<WasmApi>}
 */
function loadWasm() {
  return new Promise((resolve, reject) => {
    DemoModule({
      locateFile: function (filename) {
        // WeChat Mini Game cwd is the project root; wasm files live in wasm/.
        return 'wasm/' + filename;
      },
    }).then(function (m) {
      const N  = 'number';   // shorthand for cwrap type strings
      const NN = [N, N];

      resolve({
        // ── World ──────────────────────────────────────────────────────────
        world_init:   m.cwrap('world_init',   null, [N, N]),
        world_reset:  m.cwrap('world_reset',  null, []),
        world_update: m.cwrap('world_update', null, [N]),

        // ── Particles ──────────────────────────────────────────────────────
        particle_spawn:     m.cwrap('particle_spawn',     N, [N,N,N,N,N,N,N,N]),
        particle_count:     m.cwrap('particle_count',     N, []),
        particle_get_x:     m.cwrap('particle_get_x',     N, [N]),
        particle_get_y:     m.cwrap('particle_get_y',     N, [N]),
        particle_get_vx:    m.cwrap('particle_get_vx',    N, [N]),
        particle_get_vy:    m.cwrap('particle_get_vy',    N, [N]),
        particle_get_radius:m.cwrap('particle_get_radius',N, [N]),
        particle_get_color: m.cwrap('particle_get_color', N, [N]),

        // ── Math utilities ─────────────────────────────────────────────────
        add:        m.cwrap('add',        N, NN),
        fibonacci:  m.cwrap('fibonacci',  N, [N]),
        vec2_length:m.cwrap('vec2_length',N, NN),
        vec2_dot:   m.cwrap('vec2_dot',   N, [N,N,N,N]),
      });
    }).catch(reject);
  });
}

module.exports = { loadWasm };
