// A code monolith of the codex motif (CodexMotif, docs/scenery-themes.md): a dark slab of `mono_size` px
// whose front is covered in code scrolling up, drawn per pixel from the box-local position. Lines every
// 3 px of 2 px "letters" in words, indented like code, coloured like syntax in the theme's cyan
// (`light_color`: keywords; pale cyan identifiers, dim comments, white literals, now and then an orange
// one); a block cursor blinks at the end of the line being typed near the bottom, and a scanline glints
// down the face. The top shows a lit rim, the sides stay dark. Everything fades into the sky with its depth
// (shaders/fog.gdshaderinc). sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"
#include "res://shaders/fog.gdshaderinc"

instance uniform vec2 mono_size = vec2(48.0, 160.0);
instance uniform float seed = 0.0;
uniform vec3 light_color = vec3(0.37, 0.82, 0.85);
uniform float game_time = 0.0;
// Scroll speed of the code, px / s.
uniform float scroll_speed = 5.0;

const vec3 BODY = vec3(9.0, 19.0, 23.0) / 255.0;
const vec3 SIDE = vec3(6.0, 12.0, 15.0) / 255.0;
const vec3 ORANGE = vec3(217.0, 119.0, 87.0) / 255.0;
const float PX = 16.0;

varying vec3 wpos;
varying vec3 local;
varying vec3 lnormal;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	local = VERTEX;
	lnormal = NORMAL;
}

void fragment() {
	ivec2 sz = ivec2(mono_size);
	int sd = int(seed);
	vec3 col = SIDE;
	float boost = 1.0;
	if (lnormal.y > 0.5) {
		// The top: a lit rim at the front, darker behind.
		col = mix(BODY, light_color, 0.35);
	} else if (lnormal.z > 0.5) {
		ivec2 p = ivec2(vec2(floor((local.x + mono_size.x / PX * 0.5) * PX), floor((mono_size.y / PX * 0.5 - local.y) * PX)));
		p = clamp(p, ivec2(0), sz - 1);
		col = BODY;
		bool frame = p.x == 0 || p.x == sz.x - 1 || p.y == 0;
		if (frame) {
			col = mix(BODY, light_color, 0.4);
		} else if (p.x >= 3 && p.x < sz.x - 3 && p.y >= 3) {
			// The code scrolls up: line `line` of the endless text is at row line * 3 - scroll.
			float scroll = game_time * scroll_speed * (0.7 + 0.6 * hash2(sd, 1, 7));
			int sy = p.y - 3 + int(floor(scroll));
			int line = sy / 3;
			int ly = sy - line * 3;
			int x = p.x - 3;
			int w = sz.x - 6;
			if (ly < 2) {
				int depth = int(hash2(line, 2, sd) * 4.0);
				int indent = 3 * (depth > 2 ? 1 : depth);
				int len = int(float(w - indent) * (0.25 + 0.75 * hash2(line, 3, sd)));
				bool blank = hash2(line, 4, sd) < 0.12;
				int cx = x - indent;
				// The line being typed: a fixed row near the bottom of the face.
				int typing_row = (sz.y * 3 / 4 - 3 + int(floor(scroll))) / 3;
				if (line == typing_row) {
					len = int(float(len) * fract(game_time * 0.4 + hash2(sd, 5, 1)));
				}
				// Letters are 2 x 2 px of hashed pixels, words split by spaces.
				bool lit = (cx % 3) < 2 && hash2(cx / 3, line, sd + 1) > 0.18 && hash2(cx, line * 3 + ly, sd + 11) > 0.3;
				if (!blank && cx >= 0 && cx < len && lit) {
					int word = cx / 9 + int(hash2(line, 6, sd) * 3.0);
					float k = hash2(word, line, sd + 3);
					bool comment = hash2(line, 8, sd) > 0.85;
					if (comment) {
						col = mix(BODY, light_color, 0.3);
					} else if (k < 0.25) {
						col = light_color;
						boost = 1.15;
					} else if (k < 0.7) {
						col = mix(BODY, mix(light_color, vec3(1.0), 0.45), 0.75);
					} else if (k < 0.93) {
						col = mix(BODY, vec3(0.92), 0.7);
					} else {
						col = ORANGE;
						boost = 1.2;
					}
				}
				// The cursor after the typed letters, blinking.
				if (line == typing_row && cx >= len + 1 && cx < len + 3 && sin(game_time * 7.0 + seed) > 0.0) {
					col = light_color;
					boost = 1.6;
				}
			}
			// A scanline glinting down the face now and then.
			float sweep = fract(game_time * 0.08 + hash2(sd, 9, 2));
			if (abs(float(p.y) - sweep * mono_size.y * 1.6) < 0.5) {
				col = mix(col, light_color, 0.35);
			}
		}
	}
	col = apply_fog(col, -wpos.z, SCREEN_UV.y);
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
