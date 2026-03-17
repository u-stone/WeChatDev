#pragma once
#include "../math/vec2.h"

/// A single simulated circle-shaped particle.
struct Particle {
    int   id{-1};
    Vec2  pos{};
    Vec2  vel{};
    float radius{10.0f};
    float mass{1.0f};
    /// Coefficient of restitution: 0 = perfectly inelastic, 1 = perfectly elastic.
    float restitution{0.80f};
    /// RGBA packed as 0xRRGGBBAA — set by the caller for rendering hints.
    unsigned int color{0x4fc3f7ff};
};
