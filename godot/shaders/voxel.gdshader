// Voxel sprites (Voxel.mesh): unshaded linear vertex colours times `albedo`; `albedo` above 1.0 makes the
// WorldEnvironment glow pick them up. `flash` draws everything white (Clawd's hit flash).
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"

uniform vec4 albedo = vec4(1.0);
uniform bool flash = false;

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	ALBEDO = flash ? vec3(1.0) : COLOR.rgb * albedo.rgb;
}
