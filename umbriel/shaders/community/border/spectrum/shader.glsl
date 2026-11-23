// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Barrulus
// Ported from bumbriel 1dafcac5; current Umbriel spectrum input.
// Local edit: steady green-to-blue edge, no audio.

const float CORE_WIDTH = 1.25;  // Thin coloured edge, logical pixels.
const float HALO_REACH = 14.0;  // Match the preset padding.
const float RING_ALPHA = 0.5;   // Colour on the edge itself.
const float HALO_ALPHA = 0.32;  // Soft outward fade.
const vec3 COLOUR_GREEN = vec3(0.08, 0.82, 0.40);
const vec3 COLOUR_BLUE = vec3(0.18, 0.42, 0.98);

vec4 border(vec2 uv) {
    vec4 native = umbriel_sample(uv);
    float position = (atan(uv.y - 0.5, uv.x - 0.5) + 3.14159265) / 6.2831853;
    float distance = max(umbriel_border_distance(uv), 0.0);
    vec3 colour = mix(COLOUR_GREEN, COLOUR_BLUE, position);
    float ring = 1.0 - smoothstep(0.0, CORE_WIDTH + 0.6, distance);
    float glow = exp(-max(distance - CORE_WIDTH, 0.0) / 4.0);
    glow *= 1.0 - smoothstep(HALO_REACH - 5.0, HALO_REACH, distance);
    float alpha = max(ring * RING_ALPHA, glow * HALO_ALPHA);
    return native * (1.0 - alpha) + vec4(colour * alpha, alpha);
}
