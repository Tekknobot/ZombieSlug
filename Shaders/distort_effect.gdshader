shader_type canvas_item;

// back-buffer sampler
uniform sampler2D screen_texture : hint_screen_texture;

// shock area parameters
uniform vec2 center;    // in screen pixels
uniform float radius;   // in pixels

// glitch parameters
uniform float time              = 0.0;
uniform float glitch_intensity  : hint_range(0.0, 1.0) = 0.3;
uniform float glitch_speed      : hint_range(0.0, 5.0) = 1.0;
uniform float slice_count       : hint_range(1.0, 50.0)= 10.0;

void fragment() {
    // UV and pixel sizes
    vec2 uv = SCREEN_UV;
    vec2 px = SCREEN_PIXEL_SIZE;                  // one pixel in UV
    vec2 vp = vec2(1.0/px.x, 1.0/px.y);            // viewport size in pixels

    // compute screen-space position
    vec2 screen_pos = uv * vp;
    float dist = distance(screen_pos, center);

    // default sample
    vec4 base_col = texture(screen_texture, uv);

    // if outside radius, just output normal
    if (dist > radius) {
        COLOR = base_col;
    }

    // inside shock radius: apply glitch
    float t = time * glitch_speed;
    float slice = floor(uv.y * slice_count);
    vec2 glitch_uv = uv;
    if (mod(slice + floor(t), 2.0) < 1.0) {
        float wave = sin(t * 10.0 + slice) * glitch_intensity * 0.05;
        glitch_uv.x += wave;
    }

    // sample glitch color
    vec4 col = texture(screen_texture, glitch_uv);

    // RGB split
    float shift = glitch_intensity * 0.02;
    float r = texture(screen_texture, glitch_uv + vec2( shift, 0.0)).r;
    float g = col.g;
    float b = texture(screen_texture, glitch_uv - vec2( shift, 0.0)).b;

    COLOR = vec4(r, g, b, col.a);
}
