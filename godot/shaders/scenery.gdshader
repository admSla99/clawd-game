// Towers and floating blocks behind the level (Scenery): dark pixel boxes with a lit rim, panel edges and
// small windows that blink on and off in the theme's `light_color`, a few in orange; every lit tone is the
// body mixed towards `light_color` (see Themes). The layer is mixed into the haze by `haze_amount`. Pixels are box-local (instance `box_size`), so the pattern sits on the box wherever it
// is; top faces are bands of view rows like the level blocks. Colours are sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

instance uniform vec3 box_size = vec3(1.0);
instance uniform float seed = 0.0;
uniform vec3 haze = vec3(0.118, 0.176, 0.302);
uniform vec3 light_color = vec3(0.435, 0.561, 0.769);
uniform float haze_amount = 0.3;
// Foreground silhouettes: near-black boxes with a faint rim, no windows.
uniform bool silhouette = false;
uniform float row_z = 0.1875;
uniform float game_time = 0.0;

varying vec3 lpos;
varying vec3 lnormal;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

const vec3 BODY = vec3(14.0, 14.0, 17.0) / 255.0;
const vec3 ORANGE = vec3(217.0, 119.0, 87.0) / 255.0;

vec3 tone(float k) {
	return mix(BODY, light_color, k);
}

void vertex() {
	lpos = VERTEX;
	lnormal = NORMAL;
}

void fragment() {
	vec3 col = BODY * 0.5;
	float boost = 1.0;
	int sd = int(seed);
	if (silhouette) {
		// Flat cutout: a jagged rock line with grass blades on the top and bottom edges (one of them is
		// always off screen), a 1 px rim under it, ragged sides.
		if (lnormal.z < 0.5) {
			discard;
		}
		ivec2 p = ivec2(floor(vec2(lpos.x + box_size.x * 0.5, box_size.y * 0.5 - lpos.y) * 16.0));
		ivec2 sz = ivec2(round(box_size.xy * 16.0));
		int cx = p.x / 6;
		float f = fract(float(p.x) / 6.0);
		float n = mix(hash2(cx, 0, sd), hash2(cx + 1, 0, sd), f * f * (3.0 - 2.0 * f));
		int edge = int(n * 8.0) + 1;
		if (hash2(p.x, 1, sd) > 0.72) {
			edge -= 1 + int(hash2(p.x, 2, sd) * 6.0);
		}
		int from_edge = min(p.y - edge, sz.y - 1 - p.y - edge);
		int side = int(hash2(p.y / 4, 3, sd) * 3.0);
		if (from_edge < 0 || p.x < side || p.x > sz.x - 1 - side) {
			discard;
		}
		col = from_edge == 0 ? tone(0.16) : from_edge <= 2 ? tone(0.07) : tone(0.03);
	} else if (lnormal.z > 0.5) {
		ivec2 p = ivec2(floor(vec2(lpos.x + box_size.x * 0.5, box_size.y * 0.5 - lpos.y) * 16.0));
		int w = int(round(box_size.x * 16.0));
		col = BODY;
		if (p.y == 0) {
			col = tone(0.45);
		} else if (p.y == 1) {
			col = tone(0.2);
		} else if (p.x == 0) {
			col = tone(0.12);
		} else if (p.x == w - 1) {
			col = BODY * 0.6;
		} else if (p.x % 4 == 2 && p.y % 6 == 4 && p.x < w - 2) {
			ivec2 wc = ivec2(p.x / 4, p.y / 6);
			float r = hash2(wc.x, wc.y, sd);
			int frame = int(floor(game_time * 0.5 + r * 7.0));
			bool on = hash2(wc.x, wc.y + sd, frame) > 0.7;
			col = on ? (r > 0.94 ? ORANGE : light_color) : tone(0.07);
			boost = on && r > 0.94 ? 1.6 : 1.0;
		} else if (hash2(p.x, p.y, sd + 5) > 0.985) {
			col = tone(0.08);
		}
	} else if (lnormal.y > 0.5) {
		int row = int(floor((box_size.z * 0.5 - lpos.z) / row_z));
		col = row == 0 ? tone(0.6) : row <= 2 ? tone(0.3) : tone(0.12);
	}
	col = mix(col, haze, haze_amount);
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
