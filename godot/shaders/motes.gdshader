// Fireflies / data motes (Motes): glowing 1-2 px cubes, the instance colour above 1.0 so the
// WorldEnvironment glow gives them a halo; the alpha fades them in and out.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

#include "res://shaders/oblique.gdshaderinc"

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	ALBEDO = COLOR.rgb * COLOR.a;
}
