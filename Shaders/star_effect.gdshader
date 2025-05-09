shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 2.0) = 1.0;
uniform float glow_speed    : hint_range(0.1, 20.0) = 4.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // base pulsating intensity (1±glow_strength/2)
    float intensity = sin(TIME * glow_speed) * (glow_strength * 0.5) + (1.0 - glow_strength * 0.5);

    // generate a rainbow color by phase-offsetting three sine waves
    float t = TIME * glow_speed * 0.25; // slow the hue rotation down a bit
    vec3 rainbow = vec3(
        sin(t + 0.0) * 0.5 + 0.5,
        sin(t + 2.094) * 0.5 + 0.5, // +120°
        sin(t + 4.188) * 0.5 + 0.5  // +240°
    );

    // apply both pulsating brightness and rainbow tint
    COLOR = tex * vec4(rainbow * intensity, tex.a);
}
