// Background behind everything: a gradient from black at the top to the cool haze at the horizon in
// dithered steps, and slanted pixel light rays that pulse slowly. Runs in view pixels inside the low-res
// SubViewport, so every step and ray edge is a whole pixel. `scroll` (camera x in pixels) moves the rays
// a little, like a far parallax layer.
shader_type canvas_item;

uniform vec3 top_color = vec3(0.043, 0.043, 0.051);
uniform vec3 mid_color = vec3(0.063, 0.086, 0.149);
uniform vec3 haze_color = vec3(0.118, 0.176, 0.302);
uniform vec3 ray_color = vec3(0.29, 0.42, 0.62);
uniform float horizon = 0.8;
uniform float scroll = 0.0;
uniform float game_time = 0.0;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	float dither = (BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
	float v = px.y / size.y;
	float lv = floor(clamp(v / horizon, 0.0, 1.0) * 6.0 + dither) / 6.0;
	vec3 col = lv < 0.5 ? mix(top_color, mid_color, lv * 2.0) : mix(mid_color, haze_color, lv * 2.0 - 1.0);
	float x = px.x + scroll * 0.06 + px.y * 0.55;
	float ray = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float period = 260.0 + fi * 70.0;
		float w = 8.0 + mod(fi * 13.0, 20.0);
		float d = abs(mod(x - fi * 97.0 - 40.0, period) - period * 0.5);
		float pulse = 0.55 + 0.45 * sin(game_time * (0.25 + fi * 0.1) + fi * 2.0);
		ray = max(ray, (1.0 - smoothstep(w * 0.35, w, d)) * pulse);
	}
	ray *= 1.0 - smoothstep(0.05, 0.85, v);
	col = mix(col, ray_color, floor(ray * 3.0 + dither) / 3.0 * 0.3);
	COLOR = vec4(col, 1.0);
}
