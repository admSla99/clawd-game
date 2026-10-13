// Voxel sprites (Voxel.mesh): unshaded linear vertex colours times `albedo`; `albedo` above 1.0 makes the
// WorldEnvironment glow pick them up. `flash` draws everything white (Clawd's hit flash); per instance,
// `tint` (linear rgb, alpha = amount) recolours a sprite like drawSprite()'s `tint` (an enemy's hit flash).
// In dark levels sprites fade into the dark away from Clawd's lamp and the lights (shaders/darkness.gdshaderinc),
// except glowing materials (`albedo` above 1).
// Rim light: `rim_light` (world position, reach) and `rim_energy` (GlowLight.rim_for(), set per instance)
// warm the side of the sprite facing that light: a 1 px rim on the silhouette edges of the front face
// (UV.x holds each pixel's edges from Voxel.mesh(): 1 right, 2 left, 4 top, 8 bottom) and the side faces
// turned towards it, in three steps.
// Sway (plants, vines): `sway` = (amplitude px, phase, height m, 1 if hung from the top) bends the sprite
// along its height, most at the free end, plus `bend` px pushed by Clawd (Decor); the shift is rounded to
// whole pixels per vertex row, so it stays pixel art.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"
#include "res://shaders/reveal.gdshaderinc"
#include "res://shaders/darkness.gdshaderinc"

uniform vec4 albedo = vec4(1.0);
uniform bool flash = false;
instance uniform vec4 rim_light = vec4(0.0);
instance uniform float rim_energy = 0.0;
instance uniform vec4 sway = vec4(0.0);
instance uniform float bend = 0.0;
instance uniform vec4 tint = vec4(0.0);

// The lanterns' warm light, linear.
const vec3 RIM_COLOR = vec3(0.87, 0.38, 0.24);

varying vec3 wpos;
varying vec3 wnormal;
varying float edges;
varying float flip;

void vertex() {
	if (sway.z > 0.0) {
		float k = clamp(sway.w > 0.5 ? (sway.z - VERTEX.y) / sway.z : VERTEX.y / sway.z, 0.0, 1.0);
		float dx = (sin(TIME * (0.8 + fract(sway.y * 7.0) * 0.6) + sway.y * 6.2832) * sway.x + bend) * k * k;
		VERTEX.x += round(dx) / 16.0;
	}
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	edges = UV.x;
	// Sprites facing left are turned half round: their local right is the world's left.
	flip = sign(MODEL_MATRIX[0].x);
}

void fragment() {
	if (revealed(wpos.z, SCREEN_UV, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	vec3 col = COLOR.rgb * albedo.rgb;
	float near = 0.0; // the nearest light's reach here, for the darkness
	if (rim_energy > 0.0) {
		vec3 d = rim_light.xyz - wpos;
		float dist = length(d);
		float att = clamp(1.0 - dist / max(rim_light.w, 1e-3), 0.0, 1.0) * rim_energy;
		att = floor(att * 3.0 + 0.5) / 3.0;
		near = att;
		if (att > 0.0) {
			vec3 dir = d / max(dist, 1e-4);
			int e = int(round(edges));
			bool rim;
			if (abs(wnormal.z) > 0.5) {
				bool right = (e & (flip > 0.0 ? 1 : 2)) != 0;
				bool left = (e & (flip > 0.0 ? 2 : 1)) != 0;
				rim = (dir.x > 0.3 && right) || (dir.x < -0.3 && left) || (dir.y > 0.4 && (e & 4) != 0);
			} else {
				rim = dot(wnormal, dir) > 0.3;
			}
			if (rim) {
				col += RIM_COLOR * att * 1.3;
			}
		}
	}
	col = mix(col, tint.rgb, tint.a);
	// Dark levels: sprites away from Clawd's lamp and the lights fade out; glowing materials do not.
	if (albedo.r <= 1.0) {
		col = mix(col, pow(DARK_COLOR, vec3(2.2)), darkness_at(wpos, near, ivec2(floor(wpos.xy * 16.0))));
	}
	ALBEDO = flash ? vec3(1.0) : col;
}
