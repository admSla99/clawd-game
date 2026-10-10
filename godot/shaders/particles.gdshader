// Particle cubes (Particles): the MultiMesh instance colour with its alpha.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back;

#include "res://shaders/oblique.gdshaderinc"

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
