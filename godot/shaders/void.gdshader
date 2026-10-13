// The rising null (RisingVoid), a slab across the level and through the block depth whose top is `top`
// (world y, metres). Like drawVoid() in src/scenes/game.ts: near-black, its top edge waving by 3 px
// (sin(x * 0.07 + t * 3)) and glitching every 4 px column in red, purple or grey, re-rolled 15 times a
// second, with grey specks a little below. Its top face is a band of view rows (row_z metres each, like the
// level blocks) of dark null with flickering bits. Colours are sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"

uniform float top = 0.0;
uniform float half_depth = 2.0;
uniform float row_z = 0.1875;
uniform float game_time = 0.0;

const vec3 BODY = vec3(12.0) / 255.0;
const vec3 RED = vec3(224.0, 96.0, 90.0) / 255.0;
const vec3 PURPLE = vec3(194.0, 91.0, 214.0) / 255.0;
const vec3 GREY = vec3(200.0) / 255.0;
const vec3 SPECK = vec3(80.0) / 255.0;

varying vec3 wpos;
varying vec3 wnormal;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int seed) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(seed) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

vec3 bit(float h) {
	return h > 0.7 ? RED : h > 0.4 ? PURPLE : GREY;
}

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	int frame = int(floor(game_time * 15.0));
	int ix = int(floor(wpos.x * 16.0));
	vec3 col = BODY;
	float boost = 1.0;
	if (wnormal.z > 0.5) {
		// Front: rows below the top; the edge waves and its 2 px bits sit on it every 4 px.
		int row = int(floor((top - wpos.y) * 16.0));
		int cx = ix - (ix & 3);
		float h = hash2(cx, frame, 9);
		int edge = int(round(sin(float(cx) * 0.07 + game_time * 3.0) * 3.0)) + 3;
		if (row < edge) {
			discard;
		}
		if (row < edge + 2 && (ix & 3) < 2) {
			col = bit(h);
			boost = 1.4;
		} else if (h > 0.5 && (ix & 3) == 1 && row == edge + 5 + int(h * 6.0)) {
			col = SPECK;
		}
	} else if (wnormal.y > 0.5) {
		// Top face: bands of view rows, the front lip lit by the edge's bits, dark null behind with flicker.
		int r = int(floor((half_depth - wpos.z) / row_z));
		float h = hash2(ix >> 1, r * 31 + frame, 17);
		if (r == 0) {
			col = bit(hash2(ix - (ix & 3), frame, 9)) * 0.5;
		} else if (h > 0.965) {
			col = bit(hash2(ix, r, frame));
			boost = 1.3;
		} else {
			col = BODY * (1.0 + 0.6 * float(r % 2));
		}
	}
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
