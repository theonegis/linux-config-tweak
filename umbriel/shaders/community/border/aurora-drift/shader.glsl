// Aurora Drift — static (non-audio) blue → green → purple border with slow drift.
// Tuned for a thin ring that stays calm on a light Noctalia / Umbriel desktop.

const float CORE_WIDTH = 2.0;   // Bright core width, logical pixels.
const float HALO_REACH = 8.0;   // Soft falloff; match effect.toml padding.
const float DRIFT_RATE = 0.08;  // Revolutions per shader-second before TOML speed.

// Blue (#5B8CFF) → teal-green (#3ECF8E) → purple (#9B7DFF) → blue.
vec3 aurora_hue(float t) {
    t = fract(t);
    vec3 c0 = vec3(0.357, 0.549, 1.000); // blue, near accent #7AA3FF but richer
    vec3 c1 = vec3(0.243, 0.812, 0.557); // green
    vec3 c2 = vec3(0.608, 0.490, 1.000); // purple
    if (t < 1.0 / 3.0) {
        return mix(c0, c1, t * 3.0);
    }
    if (t < 2.0 / 3.0) {
        return mix(c1, c2, (t - 1.0 / 3.0) * 3.0);
    }
    return mix(c2, c0, (t - 2.0 / 3.0) * 3.0);
}

vec4 border(vec2 uv) {
    vec4 native = umbriel_sample(uv);
    float distance = max(umbriel_border_distance(uv), 0.0);
    float position = (atan(uv.y - 0.5, uv.x - 0.5) + 3.14159265) / 6.2831853;
    float phase = fract(position - umbriel_time * DRIFT_RATE);

    vec3 colour = aurora_hue(phase);
    // Soft sheen so the ring reads fancy without neon glare on light wallpaper.
    float sheen = 0.55 + 0.45 * sin(phase * 6.2831853 * 2.0 + umbriel_time * 0.4);
    colour = mix(colour, vec3(1.0), 0.12 * sheen);

    float core = CORE_WIDTH;
    float halo = exp(-max(distance - core, 0.0) / 0.85);
    halo *= 1.0 - smoothstep(HALO_REACH - 2.0, HALO_REACH, distance);

    float ring = max(native.a, 0.55 * halo);
    float alpha = ring * (0.72 + 0.28 * sheen);
    return mix(native, vec4(colour, 1.0), alpha);
}
