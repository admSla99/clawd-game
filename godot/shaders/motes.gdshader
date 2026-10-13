// Fireflies / data motes (Motes): glowing 1-2 px cubes, the instance colour above 1.0 so the
// WorldEnvironment glow gives them a halo; the alpha fades them in and out. In dark levels the ones away from
// Clawd's lamp dim to 40 % (shaders/darkness.gdshaderinc), so they read as spores in a cave, not as a starry sky.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

#include "res://shaders/oblique.gdshaderinc"
#include "res://shaders/darkness.gdshaderinc"

varying vec3 wpos;

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dim = dark_amount > 0.0 ? 1.0 - 0.6 * darkness_at(wpos, 0.0, ivec2(0)) / dark_amount : 1.0;
	ALBEDO = COLOR.rgb * COLOR.a * dim;
}
