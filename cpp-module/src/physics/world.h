#pragma once
#include "particle.h"
#include <vector>

/// Axis-aligned bounding-box 2-D physics world.
///
/// Features:
///   - Constant downward gravity
///   - Boundary (wall / floor / ceiling) collisions with restitution
///   - Circle–circle collision detection and impulse resolution
///   - Per-particle mass and restitution
class World {
public:
    static constexpr int   kMaxParticles = 64;
    static constexpr float kGravity      = 600.0f;  // px / s²
    static constexpr float kFloorFriction = 0.97f;  // velocity multiplier on floor contact

    /// Initialise (or re-initialise) the world with the given dimensions.
    void init(float width, float height);

    /// Remove all particles and reset the ID counter.
    void reset();

    /// Spawn a new particle. Returns its index (stable for the lifetime of the world),
    /// or -1 if the particle limit has been reached.
    int spawnParticle(float x, float y,
                      float vx, float vy,
                      float radius,
                      float mass,
                      float restitution,
                      unsigned int color);

    /// Advance the simulation by `dt` seconds (automatically clamped to 50 ms).
    void update(float dt);

    int             particleCount()       const noexcept;
    const Particle* getParticle(int index) const noexcept;

private:
    float _w{0.0f}, _h{0.0f};
    std::vector<Particle> _particles;
    int _nextId{0};

    void applyGravity(float dt);
    void integrate(float dt);
    void resolveBoundaries();
    void resolveCollisions();
};
