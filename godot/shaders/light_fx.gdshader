// Air light over the whole scene (Foreground/LightFx), added on top of the 3D view in view pixels:
// - Light shafts like the haze's (shaders/haze.gdshader) but in front of everything and scrolling faster
//   than the level, so they read as nearer: slanted, dithered into three steps, pulsing slowly, fading
//   towards the bottom.
// - Mist rising from the level's bottom (`mist_y`, the view row of the level's bottom edge): a dithered
//   band of drifting noise, so pits and the bottom of the level fade into the haze.
// Additive, so it only ever brightens.
shader_type canvas_item;
render_mode blend_add;

uniform vec3 ray_color = vec3(0.59, 0.55, 0.82);
uniform vec3 mist_color = vec3(0.26, 0.24, 0.42);
uniform float ray_strength = 0.07;
uniform float mist_strength = 0.32;
uniform float mist_y = 1e6;
uniform float scroll = 0.0;
uniform float game_time = 0.0;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	float dither = (BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
	float v = px.y / size.y;

	// Shafts: wide soft bands from the top-left, scrolled a little faster than the level.
	float x = px.x + scroll * 1.15 + px.y * 0.55;
	float ray = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float period = 420.0 + fi * 150.0;
		float w = 26.0 + fi * 14.0;
		float d = abs(mod(x - fi * 173.0, period) - period * 0.5);
		float pulse = 0.5 + 0.5 * sin(game_time * (0.2 + fi * 0.07) + fi * 2.3);
		ray = max(ray, (1.0 - smoothstep(w * 0.3, w, d)) * pulse);
	}
	ray *= 1.0 - smoothstep(0.1, 0.95, v);
	vec3 col = ray_color * floor(ray * 3.0 + dither) / 3.0 * ray_strength;

	// Mist: thickest at the level's bottom edge, thinning over ~95 px above it, its top edge drifting.
	float above = mist_y - px.y;
	float n = noise(vec2((px.x + scroll * 1.1) * 0.025 + game_time * 0.15, px.y * 0.05 - game_time * 0.05));
	float m = clamp(1.0 - (above - n * 36.0) / 95.0, 0.0, 1.0);
	col += mist_color * floor(m * 4.0 + dither) / 4.0 * mist_strength;

	COLOR = vec4(col, 1.0);
}
