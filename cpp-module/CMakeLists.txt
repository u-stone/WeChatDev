cmake_minimum_required(VERSION 3.13)
project(demo)

set(CMAKE_CXX_STANDARD 17)

# Output directory: place compiled assets directly into the minigame and web projects
set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/../minigame/wasm")
set(WEB_OUTPUT_DIR "${CMAKE_SOURCE_DIR}/../web/wasm")

# Clean old output files before building
file(REMOVE "${OUTPUT_DIR}/demo.js")
file(REMOVE "${OUTPUT_DIR}/demo.wasm")
file(REMOVE "${OUTPUT_DIR}/demo.wasm.map")
file(REMOVE "${WEB_OUTPUT_DIR}/demo.js")
file(REMOVE "${WEB_OUTPUT_DIR}/demo.wasm")
file(REMOVE "${WEB_OUTPUT_DIR}/demo.wasm.map")

# Ensure the output directories exist before linking
file(MAKE_DIRECTORY "${OUTPUT_DIR}")
file(MAKE_DIRECTORY "${WEB_OUTPUT_DIR}")

add_executable(demo
    src/demo.cpp
    src/physics/world.cpp
)

set_target_properties(demo PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${OUTPUT_DIR}"
    OUTPUT_NAME "demo"
    SUFFIX ".js"
)

# Also copy to web/wasm directory
add_custom_command(TARGET demo POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${OUTPUT_DIR}/demo.js"
        "${WEB_OUTPUT_DIR}/demo.js"
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${OUTPUT_DIR}/demo.wasm"
        "${WEB_OUTPUT_DIR}/demo.wasm"
    COMMENT "Copying WASM files to web/wasm directory"
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
# Debug mode selection:
#   sourcemap_external (default) — Generate external .wasm.map file
#   sourcemap_embed             — Embed sourcemap as Data URI in .wasm
#   dwarf                       — Use DWARF debug symbols in .wasm
#   none                        — No debug symbols (release)

option(DEBUG_MODE "Debug mode: sourcemap_external (default), sourcemap_embed, or dwarf" "sourcemap_external")
set(DEBUG_MODE_VALUES "sourcemap_external" "sourcemap_embed" "dwarf" "none")

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(DEBUG_MODE STREQUAL "sourcemap_external")
        # Sourcemap external mode (default): Generate external SourceMap
        message(STATUS "Building in sourcemap_external debug mode (external .wasm.map file)")
        target_link_options(demo PRIVATE "-gsource-map" "--source-map-base=./")
    elseif(DEBUG_MODE STREQUAL "sourcemap_embed")
        # Sourcemap embed mode: Embed SourceMap as Data URI in WASM
        message(STATUS "Building in sourcemap_embed debug mode (embedded Data URI)")
        target_link_options(demo PRIVATE "-gsource-map" "--source-map-base=./")
    elseif(DEBUG_MODE STREQUAL "dwarf")
        # DWARF mode: Generate DWARF debug info in WASM
        message(STATUS "Building in DWARF debug mode")
        target_compile_options(demo PRIVATE "-g")
        target_link_options(demo PRIVATE "-g")
    else()
        message(FATAL_ERROR "Unknown debug mode: ${DEBUG_MODE}. Valid values: ${DEBUG_MODE_VALUES}")
    endif()
else()
    target_link_options(demo PRIVATE "-O2")
endif()
