// ChargerEffect.shader
// A CanvasItem shader for Godot 4 that adds a pulsating rim glow when the charger dashes.

shader_type canvas_item;

// Color of the charging aura
uniform vec4 charge_color : source_color = vec4(1.0, 0.2, 0.0, 1.0);
// Strength of the glow
uniform float glow_strength : hint_range(0.0, 5.0) = 1.5;
// Speed of the pulsation
uniform float glow_speed : hint_range(0.0, 10.0) = 6.0;
// Thickness of the rim glow (in UV units)
uniform float glow_thickness : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    // Sample the original sprite
    vec4 base = texture(TEXTURE, UV);
    float alpha = base.a;
    // Discard nearly transparent pixels
    if (alpha < 0.1) {
        discard;
    }

    // Compute a pulsation factor in [0,1]
    float pulse = sin(TIME * glow_speed) * 0.5 + 0.5;

    // Distance from UV center for rim calculation
    vec2 centered_uv = UV - vec2(0.5);
    float dist = length(centered_uv);

    // Rim mask: smooth edge at sprite border
    float rim = smoothstep(0.5 - glow_thickness, 0.5, dist);

    // Glow color contribution
    vec3 glow = charge_color.rgb * rim * pulse * glow_strength;

    // Combine glow with base texture color
    vec3 final_rgb = base.rgb + glow;

    COLOR = vec4(final_rgb, alpha);
}