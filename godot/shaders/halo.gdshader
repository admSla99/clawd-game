// The glow around a spark (Spark): the 2D game's orange circle (radius 11 px at 0.12 +- 0.04 opacity), here
// larger (the spark sets `radius`) and brighter in the middle so the spark reads in the dark levels, as an
// ordered dither on whole view pixels that thins out towards the rim, so it stays pixel art. `pulse`
// (0..1) is the 2D sin(time * 3) breathing. Drawn on a quad of `size` px with the 2.5D projection.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/oblique.gdshaderinc"

uniform vec2 size = vec2(24.0, 24.0);
uniform float radius = 11.0;
uniform float pulse = 0.5;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec2 px = floor(UV * size);
	float r = length(px + 0.5 - size * 0.5) / radius;
	if (r > 1.0) {
		discard;
	}
	ivec2 f = ivec2(px);
	float threshold = (BAYER[(f.y & 3) * 4 + (f.x & 3)] + 0.5) / 16.0;
	// Orange light that is strongest in the middle and fades to a dark orange at the rim (linear colour), filling
	// the middle and thinning out towards the rim.
	float v = (0.6 + 0.25 * pulse) * (1.0 - r * r);
	if (v < threshold) {
		discard;
	}
	vec3 inner = vec3(0.30, 0.085, 0.05);
	vec3 outer = vec3(0.06, 0.016, 0.011);
	ALBEDO = mix(outer, inner, (1.0 - r) * (1.0 - r)) * (1.0 + 0.5 * pulse);
}
