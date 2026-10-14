// The sandbox's scenery motif (docs/scenery-themes.md: container stacks), a far background layer between the haze
// and the parallax, in view pixels like shaders/motif_swamp.gdshader: two ranges of stacked containers (a far one
// hazier and slower), corrugated boxes with a lit rim, scaffolding poles between some stacks. Nothing here is
// permanent: the top container of a stack now and then crumbles into pixels and, a moment later, is built again
// row by row from the bottom up. Opaque where there is a container or a pole, transparent elsewhere. sRGB like the
// haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.93, 0.8, 0.55);
uniform vec3 haze_color = vec3(0.41, 0.34, 0.2);
uniform vec3 mid_color = vec3(0.17, 0.14, 0.09);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float bayer(vec2 px) {
	return (BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
}

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

// One range at view pixel `px`. Stacks stand on the view row `base` (a fraction of the height).
vec4 range(vec2 px, float h, float factor, float span, float base, float fog, bool near, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	int floor_y = int(h * base);
	if (y >= floor_y) {
		// The ground under the stacks, sinking into the haze.
		return vec4(mix(mid_color * 0.4, haze_color, clamp(fog + float(y - floor_y) / 50.0, 0.0, 0.95)), 1.0);
	}
	int cell = int(floor(float(qx) / span));
	float x0 = float(cell) * span;
	float w = floor(span * (0.55 + 0.3 * hash2(cell, 1, seed)));
	float left = x0 + floor((span - w) * hash2(cell, 2, seed));
	float lx = float(qx) - left;
	int n = 2 + int(hash2(cell, 3, seed) * (near ? 6.0 : 8.0));
	int bh = 9 + int(hash2(cell, 4, seed) * 5.0);
	if (lx >= 0.0 && lx < w) {
		int k = (floor_y - 1 - y) / bh;
		int ry = (floor_y - 1 - y) % bh; // 0 = the box's bottom row
		if (k < n) {
			// The top box comes and goes: crumbling (dithered away), gone, then built again from the bottom.
			float a = 1.0;
			if (k == n - 1) {
				float period = 9.0 + hash2(cell, 5, seed) * 8.0;
				float ph = fract(game_time / period + hash2(cell, 6, seed));
				if (ph > 0.6 && ph < 0.75) {
					a = bayer(px) > (ph - 0.6) / 0.15 ? 1.0 : 0.0;
				} else if (ph >= 0.75 && ph < 0.85) {
					a = 0.0;
				} else if (ph >= 0.85) {
					a = float(ry) < (ph - 0.85) / 0.15 * float(bh) ? 1.0 : 0.0;
				}
			}
			if (a > 0.0) {
				// Each box its own shade; corrugation every 3 px, a lit rim, a dark seam on top.
				vec3 col = mid_color * (0.4 + 0.25 * hash2(cell, 10 + k, seed));
				if (int(lx) % 3 == 1) {
					col *= 0.8;
				}
				if (ry == bh - 1) {
					col = mid_color * 0.25;
				} else if (lx < 1.0 || ry == bh - 2) {
					col = mix(col, line_color, near ? 0.3 : 0.15);
				}
				return vec4(mix(col, haze_color, fog), 1.0);
			}
			return vec4(0.0);
		}
	}
	// Scaffolding: a pole at some stacks' right side with rungs every 6 px.
	if (near && hash2(cell, 7, seed) < 0.45) {
		float pole = left + w + 2.0;
		float top = float(floor_y - n * bh - 6);
		if (float(y) >= top && (abs(float(qx) - pole) < 0.5 || (abs(float(qx) - pole - 4.0) < 0.5))) {
			return vec4(mix(mid_color * 0.6, haze_color, fog + 0.15), 1.0);
		}
		if (float(y) >= top && (floor_y - y) % 6 == 0 && float(qx) > pole && float(qx) < pole + 4.0) {
			return vec4(mix(mix(mid_color * 0.6, line_color, 0.15), haze_color, fog + 0.15), 1.0);
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 46.0, 0.66, 0.2, true, 121);
	vec4 far = range(px, size.y, 0.07, 30.0, 0.58, 0.5, false, 123);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
