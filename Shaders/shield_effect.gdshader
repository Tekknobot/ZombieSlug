shader_type canvas_item;

// the base color of the glow
uniform vec4 glow_color : source_color = vec4(0.0, 0.6, 1.0, 0.8);
// how far the glow extends beyond the sprite (0–1)
uniform float glow_radius       : hint_range(0.0, 1.0) = 0.3;
// how “soft” the falloff is (larger = softer)
uniform float falloff_exponent  : hint_range(1.0, 8.0) = 4.0;
// speed of the pulse animation
uniform float pulse_speed       : hint_range(0.0, 10.0) = 2.0;
// intensity of the pulse
uniform float pulse_strength    : hint_range(0.0, 0.5)  = 0.1;

void fragment() {
    // 1) sample the sprite
    vec4 base = texture(TEXTURE, UV);

    // 2) get normalized distance from center
    vec2  c = UV - vec2(0.5);
    float d = length(c) / 0.5;

    // 3) build your radial mask (1 at edge, 0 at inner)
    float mask = smoothstep(1.0, 1.0 - glow_radius, d);
    mask = pow(mask, falloff_exponent);

    // 4) pulse it over time
    float pulse = 1.0 + sin(TIME * pulse_speed - d * 10.0) * pulse_strength;

    // 5) **gating by base.a** so nothing glows where the sprite is transparent
    float glow = mask * pulse * base.a;

    // 6) build glow color and add on top of the sprite
    vec4 effect = glow_color * glow;
    COLOR = base + effect;
}
