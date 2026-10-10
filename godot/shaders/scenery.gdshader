// Towers and floating blocks behind the level (Scenery): dark pixel boxes with a lit rim, panel edges and
// small windows that blink on and off in cool light, a few in orange; the layer is mixed into the haze by
// `haze_amount`. Pixels are box-local (instance `box_size`), so the pattern sits on the box wherever it
// is; top faces are bands of view rows like the level blocks. Colours are sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

instance uniform vec3 box_size = vec3(1.0);
instance uniform float seed = 0.0;
uniform vec3 haze = vec3(0.118, 0.176, 0.302);
uniform float haze_amount = 0.3;
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

void vertex() {
	lpos = VERTEX;
	lnormal = NORMAL;
}

void fragment() {
	vec3 col = vec3(7.0, 8.0, 11.0) / 255.0;
	float boost = 1.0;
	int sd = int(seed);
	if (lnormal.z > 0.5) {
		ivec2 p = ivec2(floor(vec2(lpos.x + box_size.x * 0.5, box_size.y * 0.5 - lpos.y) * 16.0));
		int w = int(round(box_size.x * 16.0));
		col = vec3(15.0, 17.0, 23.0) / 255.0;
		if (p.y == 0) {
			col = vec3(59.0, 74.0, 107.0) / 255.0;
		} else if (p.y == 1) {
			col = vec3(34.0, 43.0, 64.0) / 255.0;
		} else if (p.x == 0) {
			col = vec3(26.0, 33.0, 50.0) / 255.0;
		} else if (p.x == w - 1) {
			col = vec3(9.0, 10.0, 14.0) / 255.0;
		} else if (p.x % 4 == 2 && p.y % 6 == 4 && p.x < w - 2) {
			ivec2 wc = ivec2(p.x / 4, p.y / 6);
			float r = hash2(wc.x, wc.y, sd);
			int frame = int(floor(game_time * 0.5 + r * 7.0));
			bool on = hash2(wc.x, wc.y + sd, frame) > 0.7;
			col = on ? (r > 0.94 ? vec3(217.0, 119.0, 87.0) / 255.0 : vec3(111.0, 143.0, 196.0) / 255.0) : vec3(22.0, 27.0, 41.0) / 255.0;
			boost = on && r > 0.94 ? 1.6 : 1.0;
		} else if (hash2(p.x, p.y, sd + 5) > 0.985) {
			col = vec3(23.0, 27.0, 36.0) / 255.0;
		}
	} else if (lnormal.y > 0.5) {
		int row = int(floor((box_size.z * 0.5 - lpos.z) / row_z));
		col = row == 0 ? vec3(74.0, 91.0, 128.0) / 255.0 : row <= 2 ? vec3(43.0, 54.0, 79.0) / 255.0 : vec3(26.0, 31.0, 46.0) / 255.0;
	}
	col = mix(col, haze, haze_amount);
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
