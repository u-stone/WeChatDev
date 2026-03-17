cmake_minimum_required(VERSION 3.13)
project(demo)

set(CMAKE_CXX_STANDARD 17)

# Output directory: place compiled assets directly into the minigame project
set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/../minigame/wasm")

# Ensure the output directory exists before linking
file(MAKE_DIRECTORY "${OUTPUT_DIR}")

add_executable(demo
    src/demo.cpp
    src/physics/world.cpp
)

set_target_properties(demo PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    OUTPUT_NAME "demo"
    SUFFIX ".js"
)

# ── Emscripten link flags ──────────────────────────────────────────────────────
# Common flags for all build types
target_link_options(demo PRIVATE
    # WebAssembly output
    "-sWASM=1"
    # Wrap output in a factory function so it can be require()'d in WeChat Mini Game
    "-sMODULARIZE=1"
    "-sEXPORT_NAME=DemoModule"
    # Exported C functions (Emscripten requires underscore-prefixed names)
    "-sEXPORTED_FUNCTIONS=[\
\"_world_init\",\"_world_reset\",\"_world_update\",\
\"_particle_spawn\",\"_particle_count\",\
\"_particle_get_x\",\"_particle_get_y\",\
\"_particle_get_vx\",\"_particle_get_vy\",\
\"_particle_get_radius\",\"_particle_get_color\",\
\"_add\",\"_fibonacci\",\"_vec2_length\",\"_vec2_dot\"\
]"
    # Expose cwrap so JS callers don't have to use raw pointer indices
    "-sEXPORTED_RUNTIME_METHODS=[\"cwrap\"]"
    # Keep the binary small: no libc filesystem emulation needed
    "-sNO_FILESYSTEM=1"
    # Allow heap to grow at runtime (safer default for unknown input sizes)
    "-sALLOW_MEMORY_GROWTH=1"
)

# ── Build-type specific flags ─────────────────────────────────────────────────
# NOTE: --emit-source-map was removed in Emscripten 3.x+; the correct flag
# is -gsource-map (passed to both compile and link steps).
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    # Compile: embed DWARF debug info in object files
    target_compile_options(demo PRIVATE "-gsource-map")
    # Link: generate demo.wasm.map and embed sourceMappingURL in the .wasm binary
    # --source-map-base=./ → sourceMappingURL=./demo.wasm.map (same directory)
    target_link_options(demo PRIVATE
        "-gsource-map"
        "--source-map-base=./"
    )
else()
    target_link_options(demo PRIVATE "-O2")
endif()
