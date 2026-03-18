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
async function loadWasm() {
  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = '../wasm/demo.js';
    script.onload = function () {
      if (typeof DemoModule === 'undefined') {
        reject(new Error('DemoModule is not defined'));
        return;
      }
      
      DemoModule({
        locateFile: function (filename) {
          return 'wasm/' + filename;
        },
      }).then(function (m) {
        const N  = 'number';
        const NN = [N, N];

        resolve({
          world_init:   m.cwrap('world_init',   null, [N, N]),
          world_reset:  m.cwrap('world_reset',  null, []),
          world_update: m.cwrap('world_update', null, [N]),

          particle_spawn:     m.cwrap('particle_spawn',     N, [N,N,N,N,N,N,N,N]),
          particle_count:     m.cwrap('particle_count',     N, []),
          particle_get_x:     m.cwrap('particle_get_x',     N, [N]),
          particle_get_y:     m.cwrap('particle_get_y',     N, [N]),
          particle_get_vx:    m.cwrap('particle_get_vx',    N, [N]),
          particle_get_vy:    m.cwrap('particle_get_vy',    N, [N]),
          particle_get_radius:m.cwrap('particle_get_radius',N, [N]),
          particle_get_color: m.cwrap('particle_get_color', N, [N]),

          add:        m.cwrap('add',        N, NN),
          fibonacci:  m.cwrap('fibonacci',  N, [N]),
          vec2_length:m.cwrap('vec2_length',N, NN),
          vec2_dot:   m.cwrap('vec2_dot',   N, [N,N,N,N]),
        });
      }).catch(reject);
    };
    script.onerror = function () {
      reject(new Error('Failed to load demo.js'));
    };
    document.head.appendChild(script);
  });
}

export { loadWasm };
