// GlitchLighting.shader
// A CanvasItem shader for Godot 4.3 creating a dynamic lighting glitch effect with scanlines, color separation, and noise flicker.

shader_type canvas_item;

// Intensity of glitch noise [0.0 - 1.0]
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.3;
// Speed of glitch animation
uniform float glitch_speed : hint_range(0.1, 10.0) = 2.0;
// Strength of RGB separation
uniform float color_separation : hint_range(0.0, 0.05) = 0.02;
// Number of horizontal scanlines
uniform int scanline_count : hint_range(1, 200) = 120;
// Brightness flicker multiplier
uniform float flicker_strength : hint_range(0.0, 0.5) = 0.2;

// Pseudo-random noise by coordinate
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    // Compute glitch noise trigger
    float noise = rand(vec2(UV.y * glitch_speed, TIME * glitch_speed));
    float trigger = step(1.0 - glitch_intensity, noise);

    // Apply horizontal displacement and scanline jitter
    float scan_offset = sin((UV.y * float(scanline_count) + TIME * 50.0)) * 0.005;
    uv.x += trigger * scan_offset;

    // Chromatic separation
    vec2 sep = vec2(color_separation * trigger);
    float r = texture(TEXTURE, uv + sep).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv - sep).b;

    // Brightness flicker
    float flick = 1.0 + (rand(vec2(TIME * 10.0, UV.x * 10.0)) - 0.5) * flicker_strength * trigger;

    vec3 final_rgb = vec3(r, g, b) * flick;
    float alpha = texture(TEXTURE, UV).a;

    COLOR = vec4(final_rgb, alpha);
}