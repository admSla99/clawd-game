// The exit portal's inner surface (Goal): a 9 x 15 px ellipse in whole view pixels, filled with a slow
// swirl of light orange that pulses like the 2D gate's glow. Pixels are switched on by an ordered dither
// instead of being blended, so it stays pixel art; colours above 1.0 glow. `game_time` is Game.time (hitstop
// and pause freeze it). Drawn on a quad of `size` px with the 2.5D projection.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/oblique.gdshaderinc"

uniform vec2 size = vec2(20.0, 32.0);
uniform vec2 radius = vec2(9.0, 15.0);
uniform float game_time = 0.0;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
const vec3 ORANGE = vec3(0.70, 0.18, 0.10);
const vec3 BRIGHT = vec3(1.6, 0.75, 0.48);
const vec3 WHITE = vec3(2.0, 1.7, 1.5);

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec2 px = floor(vec2(UV.x, UV.y) * size);
	vec2 d = (px + 0.5 - size * 0.5) / radius;
	float r = length(d);
	if (r > 1.0) {
		discard;
	}
	float a = atan(d.y, d.x);
	// Arms of light winding in towards the centre, brighter near the rim and in the middle.
	float swirl = 0.5 + 0.5 * sin(a * 3.0 + r * 7.0 - game_time * 4.0);
	float pulse = 0.5 + 0.5 * sin(game_time * 4.0);
	float v = swirl * 0.55 + smoothstep(0.6, 1.0, r) * 0.35 + (1.0 - smoothstep(0.0, 0.35, r)) * 0.5 + pulse * 0.12;
	ivec2 f = ivec2(px);
	float threshold = (BAYER[(f.y & 3) * 4 + (f.x & 3)] + 0.5) / 16.0;
	if (v * 0.85 < threshold) {
		discard;
	}
	ALBEDO = v > 0.95 ? WHITE : v > 0.62 ? BRIGHT : ORANGE;
}
