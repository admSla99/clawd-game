// A floating window of the Context Window motif (WindowMotif, docs/scenery-themes.md): a text panel of
// `win_size` px drawn per pixel on a quad, through its life `age` (0..1, set per instance by the script):
// it opens from its title bar down (0 - 0.1), its lines of prompt / code type in with a blinking cursor
// (0.1 - 0.65), it holds, and from 0.8 it crumbles into pixels from the top while it drifts back into the
// depth. A 1 px frame and a title bar with three dots in `light_color`, a dark body, text as 2 px "letters" in
// words, some in orange; every pixel fades into the sky with its depth (shaders/fog.gdshaderinc). sRGB,
// converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"
#include "res://shaders/fog.gdshaderinc"

instance uniform vec2 win_size = vec2(64.0, 40.0);
instance uniform float seed = 0.0;
instance uniform float age = 0.0;
uniform vec3 light_color = vec3(0.61, 0.48, 0.84);
uniform float game_time = 0.0;

const vec3 BODY = vec3(16.0, 13.0, 24.0) / 255.0;
const vec3 BAR = vec3(30.0, 24.0, 44.0) / 255.0;
const vec3 ORANGE = vec3(217.0, 119.0, 87.0) / 255.0;
const int TOP = 6; // title bar rows

varying vec3 wpos;

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
}

void fragment() {
	ivec2 sz = ivec2(win_size);
	ivec2 p = ivec2(floor(UV * win_size));
	int sd = int(seed);
	// Opening: only the rows the window has unrolled to so far.
	int open_rows = int(float(sz.y) * clamp(age / 0.1, 0.0, 1.0));
	if (p.y > max(open_rows, TOP)) {
		discard;
	}
	// Crumbling: eaten from the top with a ragged edge, pixel by pixel.
	float crumble = clamp((age - 0.8) / 0.2, 0.0, 1.0);
	if (crumble > 0.0 && float(p.y) / float(sz.y) < crumble * 1.4 - hash2(p.x, p.y, sd) * 0.4) {
		discard;
	}
	vec3 col = BODY;
	float boost = 1.0;
	bool frame = p.x == 0 || p.y == 0 || p.x == sz.x - 1 || p.y == sz.y - 1;
	if (frame) {
		col = mix(BODY, light_color, 0.55);
	} else if (p.y < TOP) {
		col = BAR;
		// Three dots on the left of the title bar, a title bar of dashes on the right.
		if (p.y >= 2 && p.y <= 3) {
			int k = (p.x - 3) / 4;
			if (p.x >= 3 && k < 3 && ((p.x - 3) & 3) < 2) {
				col = k == 0 ? ORANGE : mix(BAR, light_color, 0.5 + 0.2 * float(k));
			} else if (p.x > 16 && p.x < sz.x - 4 && p.y == 2 && hash2(p.x / 3, 1, sd) > 0.35) {
				col = mix(BAR, light_color, 0.3);
			}
		}
	} else {
		// Text: a line every 4 px; words of 2 px letters with 1 px gaps; a code-like indent per line.
		int ly = p.y - TOP - 2;
		int line = ly / 4;
		int lines = (sz.y - TOP - 3) / 4;
		if (ly >= 0 && (ly & 3) < 2 && line < lines) {
			int indent = 2 + 3 * int(hash2(line, 2, sd) * 3.0);
			int len = int(float(sz.x - indent - 4) * (0.35 + 0.65 * hash2(line, 3, sd)));
			int x = p.x - indent;
			// Typing: lines appear one after another, the current one letter by letter.
			float typed = clamp((age - 0.1) / 0.55, 0.0, 1.0) * float(lines);
			int full = int(typed);
			int chars = line < full ? len : line == full ? int(fract(typed) * float(len)) : 0;
			if (x >= 0 && x < chars && (x % 3) < 2 && hash2(x / 3, line * 7 + 5, sd) > 0.18) {
				bool word_gap = hash2(x / 3, line, sd + 1) > 0.8;
				if (!word_gap) {
					bool hot = hash2(x / 12, line, sd + 2) > 0.85;
					col = hot ? ORANGE : mix(BODY, light_color, 0.7);
					boost = hot ? 1.3 : 1.0;
				}
			}
			// Cursor after the last typed letter, blinking.
			if (line == full && full < lines && x >= chars && x < chars + 2 && sin(game_time * 9.0) > 0.0) {
				col = light_color;
				boost = 1.5;
			}
		}
	}
	col = apply_fog(col, -wpos.z, SCREEN_UV.y);
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
