// SporeIndicator.shader
// A CanvasItem shader for Godot 4 that shows a pulsating green ring around a spore zombie to indicate spore release readiness.

shader_type canvas_item;

// Indicator ring color (green)
uniform vec4 indicator_color : source_color = vec4(0.2, 1.0, 0.2, 0.7);
// Speed of the pulsating ring
uniform float pulse_speed : hint_range(0.1, 10.0) = 3.0;
// Maximum radius of the ring in UV units (0.5 = edge of sprite)
uniform float max_radius : hint_range(0.1, 0.5) = 0.5;
// Thickness of the ring in UV units
uniform float indicator_thickness : hint_range(0.01, 0.2) = 0.05;

void fragment() {
    // Sample the base sprite color
    vec4 base = texture(TEXTURE, UV);
    if (base.a < 0.1) {
        discard;
    }

    // Compute pulsating radius between indicator_thickness and max_radius
    float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
    float radius = mix(indicator_thickness, max_radius, pulse);

    // Distance from center of sprite (UV coords [0,1])
    float dist = length(UV - vec2(0.5));

    // Create a thin ring around 'radius'
    float edge0 = radius - (indicator_thickness * 0.5);
    float edge1 = radius + (indicator_thickness * 0.5);
    float ring = smoothstep(edge0, radius, dist) * (1.0 - smoothstep(radius, edge1, dist));

    // Combine ring with base sprite color
    vec3 final_rgb = base.rgb + (indicator_color.rgb * ring);
    float final_a = base.a;

    COLOR = vec4(final_rgb, final_a);
}
