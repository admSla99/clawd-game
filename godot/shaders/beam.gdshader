// The beam a rescued sub-agent rides up (SubAgent): a column of orange light at about half opacity (the 2D
// rect is 0.35 alpha; a dither that sparse barely reads), drawn as an ordered dither on whole view pixels so
// it stays pixel art; `fade` thins it out. Drawn on a quad of `size` px with the 2.5D projection.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/oblique.gdshaderinc"

uniform vec2 size = vec2(8.0, 300.0);
uniform float fade = 1.0;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	ivec2 f = ivec2(floor(UV * size));
	float threshold = (BAYER[(f.y & 3) * 4 + (f.x & 3)] + 0.5) / 16.0;
	// Brighter in the middle, thinning out towards the top.
	float v = 0.55 * fade * (f.x == 0 || f.x == int(size.x) - 1 ? 0.6 : 1.0) * (0.4 + 0.6 * UV.y);
	if (v < threshold) {
		discard;
	}
	ALBEDO = vec3(1.25, 0.55, 0.36);
}
