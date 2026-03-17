#pragma once
#include <cmath>

/// Lightweight 2-D vector used throughout the physics engine.
struct Vec2 {
    float x{0.0f}, y{0.0f};

    Vec2() = default;
    constexpr Vec2(float x, float y) noexcept : x(x), y(y) {}

    Vec2  operator+(const Vec2& o) const noexcept { return {x + o.x, y + o.y}; }
    Vec2  operator-(const Vec2& o) const noexcept { return {x - o.x, y - o.y}; }
    Vec2  operator*(float s)       const noexcept { return {x * s,   y * s};   }
    Vec2  operator/(float s)       const noexcept { return {x / s,   y / s};   }
    Vec2& operator+=(const Vec2& o) noexcept { x += o.x; y += o.y; return *this; }
    Vec2& operator-=(const Vec2& o) noexcept { x -= o.x; y -= o.y; return *this; }
    Vec2& operator*=(float s)       noexcept { x *= s;   y *= s;   return *this; }

    float lengthSq()            const noexcept { return x * x + y * y; }
    float length()              const noexcept { return std::sqrt(lengthSq()); }
    float dot(const Vec2& o)    const noexcept { return x * o.x + y * o.y; }
    float cross(const Vec2& o)  const noexcept { return x * o.y - y * o.x; }

    Vec2 normalized() const noexcept {
        float len = length();
        return (len > 1e-6f) ? Vec2{x / len, y / len} : Vec2{};
    }

    Vec2 reflected(const Vec2& normal) const noexcept {
        return *this - normal * (2.0f * dot(normal));
    }
};
