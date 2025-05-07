// res://shaders/level_up_glow.shader
shader_type canvas_item;

// turn the effect on/off
uniform bool active = false;
// how fast it pulses
uniform float pulse_speed = 6.0;
// what color to glow toward
uniform vec3 glow_color = vec3(1.0, 0.8, 0.2);

void fragment() {
    // sample the sprite normally
    vec4 col = texture(TEXTURE, UV) * COLOR;
    if (active) {
        // f will oscillate 0→1→0 at pulse_speed
        float f = 0.5 + 0.5 * sin(TIME * pulse_speed);
        // blend your sprite toward glow_color by factor f
        col.rgb = mix(col.rgb, glow_color, f);
    }
    COLOR = col;
}
