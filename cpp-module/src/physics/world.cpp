#include "world.h"
#include <algorithm>
#include <cmath>

// ── Public ─────────────────────────────────────────────────────────────────────

void World::init(float width, float height) {
    _w = width;
    _h = height;
    reset();
}

void World::reset() {
    _particles.clear();
    _nextId = 0;
}

int World::spawnParticle(float x, float y,
                          float vx, float vy,
                          float radius,
                          float mass,
                          float restitution,
                          unsigned int color) {
    if (static_cast<int>(_particles.size()) >= kMaxParticles) return -1;

    Particle p;
    p.id          = _nextId++;
    p.pos         = {x, y};
    p.vel         = {vx, vy};
    p.radius      = std::max(radius, 1.0f);
    p.mass        = std::max(mass,   0.001f);
    p.restitution = std::clamp(restitution, 0.0f, 1.0f);
    p.color       = color;
    _particles.push_back(p);
    return p.id;
}

void World::update(float dt) {
    dt = std::min(dt, 0.05f);   // cap at 50 ms to keep the sim stable
    applyGravity(dt);
    integrate(dt);
    resolveBoundaries();
    resolveCollisions();
}

int World::particleCount() const noexcept {
    return static_cast<int>(_particles.size());
}

const Particle* World::getParticle(int index) const noexcept {
    if (index < 0 || index >= static_cast<int>(_particles.size())) return nullptr;
    return &_particles[index];
}

// ── Private ────────────────────────────────────────────────────────────────────

void World::applyGravity(float dt) {
    for (auto& p : _particles)
        p.vel.y += kGravity * dt;
}

void World::integrate(float dt) {
    for (auto& p : _particles)
        p.pos += p.vel * dt;
}

void World::resolveBoundaries() {
    for (auto& p : _particles) {
        // Left wall
        if (p.pos.x - p.radius < 0.0f) {
            p.pos.x  = p.radius;
            p.vel.x  =  std::abs(p.vel.x) * p.restitution;
        }
        // Right wall
        if (p.pos.x + p.radius > _w) {
            p.pos.x  = _w - p.radius;
            p.vel.x  = -std::abs(p.vel.x) * p.restitution;
        }
        // Ceiling
        if (p.pos.y - p.radius < 0.0f) {
            p.pos.y  = p.radius;
            p.vel.y  =  std::abs(p.vel.y) * p.restitution;
        }
        // Floor
        if (p.pos.y + p.radius > _h) {
            p.pos.y  = _h - p.radius;
            p.vel.y  = -std::abs(p.vel.y) * p.restitution;
            p.vel.x *= kFloorFriction;  // rolling friction
        }
    }
}

void World::resolveCollisions() {
    const int n = static_cast<int>(_particles.size());
    for (int i = 0; i < n; ++i) {
        for (int j = i + 1; j < n; ++j) {
            Particle& a = _particles[i];
            Particle& b = _particles[j];

            Vec2  d       = b.pos - a.pos;
            float distSq  = d.lengthSq();
            float minDist = a.radius + b.radius;

            if (distSq >= minDist * minDist || distSq < 1e-8f) continue;

            float dist   = std::sqrt(distSq);
            Vec2  normal = d / dist;            // unit vector a → b
            float overlap = minDist - dist;

            // ── Positional correction (push apart, weighted by inverse mass) ──
            float totalMass = a.mass + b.mass;
            a.pos -= normal * (overlap * b.mass / totalMass);
            b.pos += normal * (overlap * a.mass / totalMass);

            // ── Impulse resolution ────────────────────────────────────────────
            Vec2  relVel         = b.vel - a.vel;
            float velAlongNormal = relVel.dot(normal);
            if (velAlongNormal > 0.0f) continue;   // already separating

            float e       = std::min(a.restitution, b.restitution);
            float jMag    = -(1.0f + e) * velAlongNormal
                            / (1.0f / a.mass + 1.0f / b.mass);
            Vec2  impulse = normal * jMag;

            a.vel -= impulse * (1.0f / a.mass);
            b.vel += impulse * (1.0f / b.mass);
        }
    }
}
