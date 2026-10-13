// The swamp's scenery motif (docs/scenery-themes.md: corrupted data pools), a far background layer between the
// haze and the parallax ridges, in view pixels like shaders/motif_mesa.gdshader: two ranges of murky flats (a
// far one hazier and slower) with pools set into them. Each pool mirrors the haze above it and whatever stands
// over it, but its data is corrupted: rows of the reflection tear sideways in bands, dead pixels blink in it
// and 1 px ripples drift across. Tangled cables hang down from above and sink into the pools, light pulses
// running down them into the water, rings spreading where they go in. From the near pools injected strings
// rise as bubbles of text ("IGNORE ALL", "SUDO JUMP", ...): a small bubble grows into a speech bubble, the
// text types in, one letter flickers to the injector's magenta, and near the top it pops into pixels.
// Opaque where there is mud or water, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.67, 0.75, 0.4);
uniform vec3 haze_color = vec3(0.18, 0.23, 0.11);
uniform vec3 mid_color = vec3(0.08, 0.11, 0.06);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

// The injector's magenta (scripts/injector.gd), for corrupted pixels and letters.
const vec3 CORRUPT = vec3(194.0, 91.0, 214.0) / 255.0;
const float BUBBLE_LIFE = 12.0;
// 3x5 glyphs, rows top to bottom, 3 bits each (left = high): " ABCDEFGHIJKLMNOPQRSTUVWXYZ:>_!."
const int FONT[32] = int[](0, 11245, 27566, 14627, 27502, 31143, 31140, 14699, 23533, 29847, 4714, 23469, 18727,
	24557, 27501, 11114, 27556, 11123, 27565, 14478, 29842, 23407, 23402, 23549, 23213, 23186, 29351, 1040, 17492,
	7, 9346, 2);
// The injected strings, MAX_LEN glyph indices each: IGNORE ALL, OBEY ME, SUDO JUMP, NEW RULES:, FORGET IT,
// TRUST ME, SYSTEM:, DROP TABLE, RUN THIS!, JUMP NOW!, DISREGARD, ADMIN MODE.
const int PHRASES = 12;
const int MAX_LEN = 10;
const int TEXT[120] = int[](9, 7, 14, 15, 18, 5, 0, 1, 12, 12, 15, 2, 5, 25, 0, 13, 5, 0, 0, 0, 19, 21, 4, 15, 0,
	10, 21, 13, 16, 0, 14, 5, 23, 0, 18, 21, 12, 5, 19, 27, 6, 15, 18, 7, 5, 20, 0, 9, 20, 0, 20, 18, 21, 19, 20, 0,
	13, 5, 0, 0, 19, 25, 19, 20, 5, 13, 27, 0, 0, 0, 4, 18, 15, 16, 0, 20, 1, 2, 12, 5, 18, 21, 14, 0, 20, 8, 9,
	19, 30, 0, 10, 21, 13, 16, 0, 14, 15, 23, 30, 0, 4, 9, 19, 18, 5, 7, 1, 18, 4, 0, 1, 4, 13, 9, 14, 0, 13, 15,
	4, 5);
const int LEN[12] = int[](10, 7, 9, 10, 9, 8, 7, 10, 9, 9, 9, 10);

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

// Smooth 1D value noise over integer knots.
float noise1(float x, int s) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash2(int(i), 0, s), hash2(int(i) + 1, 0, s), f);
}

// The pool of cell `c`: x = centre, y = half width, z = depth below the water line (px); w = 0 if none.
vec4 pool(int c, float span, vec2 depth, int seed) {
	if (hash2(c, 0, seed) < 0.12) {
		return vec4(0.0);
	}
	float cx = floor((float(c) + 0.5 + (hash2(c, 1, seed) - 0.5) * 0.3) * span);
	float hw = floor(span * (0.2 + 0.14 * hash2(c, 2, seed)));
	float d = floor(mix(depth.x, depth.y, hash2(c, 3, seed)));
	return vec4(cx, hw, d, 1.0);
}

// Height of the mud above the water line at layer column `qx`: low tussocks, and a reed now and then.
int mud_height(int qx, int seed) {
	int h = int(max(0.0, floor(noise1(float(qx) / 17.0, seed) * 5.0 - 1.8)));
	if (hash2(qx, 7, seed) < 0.035) {
		h = max(h, 3 + int(hash2(qx, 8, seed) * 7.0));
	}
	return h;
}

// Whether layer column `qx` lies over pool `p` (on the water line).
bool over(vec4 p, int qx) {
	return p.w > 0.0 && abs(float(qx) + 0.5 - p.x) < p.y;
}

// A text bubble of cell `c`, slot `j`, at layer pixel (qx, y): rgb and alpha (0 outside it).
vec4 bubble(int c, int j, int qx, int y, vec4 p, int wy, int seed) {
	// A pool's two slots share a period half a life apart, so their bubbles never meet.
	float period = BUBBLE_LIFE * (0.8 + 0.4 * hash2(c, 20, seed));
	float t = game_time + (hash2(c, 22, seed) + 0.5 * float(j)) * period;
	int n = int(floor(t / period));
	float a = fract(t / period);
	if (hash2(c, 400 + n * 2 + j, seed) < 0.25) {
		return vec4(0.0); // a quiet round
	}
	int phrase = int(hash2(c, 300 + n * 2 + j, seed) * float(PHRASES));
	int len = LEN[phrase];
	// It rises from the surface to the upper third of the view, wobbling.
	float rise = float(wy) * 0.72;
	int bx = int(floor(p.x + (hash2(c, 500 + n * 2 + j, seed) - 0.5) * p.y * 1.2 + sin(t * 1.3 + float(n)) * 3.0));
	int by = wy - 2 - int(a * rise);
	int dx = qx - bx;
	int dy = y - by;
	vec3 rim = mix(line_color, vec3(1.0), 0.15);
	// Born as a round bubble that grows.
	if (a < 0.1) {
		float r = 1.0 + a * 25.0;
		float d = length(vec2(float(dx), float(dy) + r));
		if (d < r + 0.5 && d > r - 0.7) {
			return vec4(rim * 0.8, 1.0);
		}
		return vec4(0.0);
	}
	// Then a speech bubble: 1 px rim, 2 px padding, the text; it widens to fit before the text types in.
	int full = len * 4 + 5;
	int w = int(mix(7.0, float(full), clamp((a - 0.1) / 0.05, 0.0, 1.0)));
	int left = -w / 2;
	int top = -11;
	int lx = dx - left;
	int ly = dy - top;
	// Two small bubbles trail below it.
	if ((dy == 2 && dx == -1) || (dy == 4 && dx == -2)) {
		return vec4(rim * 0.6, 1.0);
	}
	if (lx < 0 || lx >= w || ly < 0 || ly > 9) {
		return vec4(0.0);
	}
	bool edge = lx == 0 || lx == w - 1 || ly == 0 || ly == 9;
	bool corner = (lx == 0 || lx == w - 1) && (ly == 0 || ly == 9);
	if (corner) {
		return vec4(0.0);
	}
	// Near the top it pops: the rim scatters into pixels, the text goes.
	float pop = clamp((a - 0.9) / 0.1, 0.0, 1.0);
	if (edge) {
		if (pop > 0.0 && hash2(qx, y + n * 64, seed) < pop * 1.3) {
			return vec4(0.0);
		}
		return vec4(rim, 1.0);
	}
	vec4 col = vec4(mid_color * 0.5, 0.75);
	int gx = lx - 3;
	int gy = ly - 2;
	int ci = gx / 4;
	int typed = int((a - 0.15) / 0.12 * float(len));
	if (gx >= 0 && gx % 4 < 3 && gy >= 0 && gy < 5 && ci < len && ci <= typed && pop == 0.0) {
		int g = FONT[TEXT[phrase * MAX_LEN + ci]];
		if (((g >> ((4 - gy) * 3 + (2 - gx % 4))) & 1) == 1) {
			// One letter at a time flickers to magenta: the injection showing through.
			int bad = int(hash2(c * 3 + j, int(game_time * 3.0), seed) * float(len));
			col = vec4(ci == bad ? CORRUPT * 1.2 : mix(line_color, vec3(1.0), 0.35), 1.0);
		}
	}
	return col;
}

// What stands above the water at layer pixel (qx, y): mud and reeds, cables, bubbles. rgb, alpha (0 = sky),
// and in `glow` how much of it shines (pulses), so the haze takes it less.
vec4 above(int qx, int y, int wy, float span, vec2 depth, bool near, int seed, out float glow) {
	glow = 0.0;
	int cell = int(floor(float(qx) / span));
	// Mud and reeds on the bank, not over the pools.
	vec4 pools[3];
	bool water = false;
	for (int i = 0; i < 3; i++) {
		pools[i] = pool(cell + i - 1, span, depth, seed);
		water = water || over(pools[i], qx);
	}
	int mh = water ? 0 : mud_height(qx, seed);
	if (y >= wy - mh && y < wy) {
		vec3 mud = mid_color * 0.4;
		return vec4(y == wy - mh ? mix(mud, line_color, 0.22) : mud, 1.0);
	}
	// The bubbles of text pass in front of the cables.
	vec4 best = vec4(0.0);
	for (int i = 0; i < 3 && near; i++) {
		if (pools[i].w > 0.0) {
			for (int j = 0; j < 2; j++) {
				vec4 b = bubble(cell + i - 1, j, qx, y, pools[i], wy, seed);
				if (b.a > best.a) {
					best = b;
				}
			}
		}
	}
	if (best.a > 0.0) {
		return best;
	}
	for (int i = 0; i < 3; i++) {
		vec4 p = pools[i];
		if (p.w == 0.0) {
			continue;
		}
		int c = cell + i - 1;
		// Two cables per pool, hanging from above the view, steep where they go into the water.
		for (int k = 0; k < 2; k++) {
			float ex = floor(p.x + (hash2(c, 30 + k, seed) - 0.5) * p.y * 1.3);
			float ax = ex + (hash2(c, 32 + k, seed) - 0.5) * span * 1.1;
			float u = float(y + 12) / float(wy + 12);
			if (u < 0.0 || u > 1.0) {
				continue;
			}
			float sway = sin(game_time * 0.5 + float(c * 2 + k)) * 2.0 * (1.0 - u);
			float x = ex + (ax - ex) * (1.0 - u) * (1.0 - u) + sway;
			float slope = 2.0 * (ax - ex) * (1.0 - u) / float(wy + 12);
			float d = (float(qx) + 0.5 - x) / sqrt(1.0 + slope * slope);
			float half_w = near ? 1.1 : 0.6;
			if (abs(d) < half_w) {
				vec3 col = mid_color * 0.35;
				if (near && d < 0.0) {
					col = mix(col, line_color, 0.25);
				}
				// Pulses run down the cable into the pool.
				float pu = fract(game_time * 0.09 + hash2(c, 34 + k, seed));
				if (abs(u - pu) * float(wy) < 2.5) {
					col = line_color * 1.4;
					glow = 1.0;
				}
				return vec4(col, 1.0);
			}
		}
	}
	return vec4(0.0);
}

// One range of swamp at view pixel `px`: rgb and 1 where there is mud or water, else 0 alpha. `base` is the
// view row of the water line, `depth` the pools' depth range, `fog` how far into the haze it is.
vec4 range(vec2 px, float h, float factor, float span, float base, vec2 depth, float fog, bool near, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	int wy = int(h * base);
	float glow;
	if (y < wy) {
		vec4 a = above(qx, y, wy, span, depth, near, seed, glow);
		if (a.a == 0.0) {
			return vec4(0.0);
		}
		return vec4(mix(a.rgb, haze_color, fog * (1.0 - glow * 0.6)), a.a);
	}
	int cell = int(floor(float(qx) / span));
	vec4 p = vec4(0.0);
	int c = 0;
	bool in_pool = false;
	for (int i = -1; i <= 1; i++) {
		vec4 q = pool(cell + i, span, depth, seed);
		if (q.w > 0.0) {
			float ex = (float(qx) + 0.5 - q.x) / q.y;
			float ey = (float(y - wy) + 0.5) / q.z;
			if (ex * ex + ey * ey < 1.0) {
				p = q;
				c = cell + i;
				in_pool = true;
			}
		}
	}
	int dy = y - wy;
	// Below the pools the flats sink into the haze fast, so pits keep their depth.
	float f = clamp(fog + float(dy) / 60.0, 0.0, 0.95);
	if (!in_pool) {
		vec3 mud = mid_color * 0.4;
		if (dy == 0) {
			mud = mix(mud, line_color, 0.22);
		}
		return vec4(mix(mud, haze_color, f), 1.0);
	}
	// The reflection: the row mirrored about the water line, torn sideways in bands now and then.
	int tick = int(floor(game_time * 2.5 + hash2(c, 40, seed) * 7.0));
	int band = dy / 2;
	int tear = 0;
	if (hash2(c * 31 + band, tick, seed) < 0.14) {
		tear = int((hash2(band, tick, seed + c) - 0.5) * 14.0);
	}
	int wobble = int(floor(sin(float(dy) * 1.1 + game_time * 2.0) * 0.9 + 0.5));
	int ym = wy - 1 - dy;
	float rg = 0.0;
	vec4 r = above(qx + tear + wobble, ym, wy, span, depth, near, seed, rg);
	// The haze of the mirrored row, in the haze shader's dithered steps (its horizon at 0.8), a little brighter.
	float lv = floor(clamp(float(ym) / (h * 0.8), 0.0, 1.0) * 6.0 + bayer(px)) / 6.0;
	vec3 sky = lv < 0.5 ? mid_color * (0.5 + lv) : mix(mid_color, haze_color, lv * 2.0 - 1.0);
	sky = mix(sky * 1.3, line_color, 0.12);
	vec3 col = r.a > 0.0 ? mix(sky, r.rgb * 0.8, r.a) : sky;
	// Darker towards the far shore; a lit line on the surface, a dark rim round the pool's edge.
	float ex = (float(qx) + 0.5 - p.x) / p.y;
	float ey = (float(dy) + 0.5) / p.z;
	col *= 1.0 - 0.35 * floor(ey * ey * 3.0 + bayer(px)) / 3.0;
	if (dy == 0) {
		col = mix(col, line_color, 0.6);
	} else if (dy == 1) {
		col = mix(col, line_color, 0.2);
	} else if (ex * ex + ey * ey > 0.82) {
		col = mid_color * 0.3;
	}
	// Ripples: light dashes drifting across every other row, longer near the surface.
	int drift = int(game_time * (hash2(c, 41, seed) < 0.5 ? 6.0 : -6.0));
	int seg = (qx + drift + dy * 5) / (dy < 6 ? 9 : 5);
	if (dy > 1 && dy % 2 == 0 && hash2(seg, dy, seed + c) > 0.72) {
		col = mix(col, line_color, 0.3 - 0.15 * ey);
	}
	for (int k = 0; k < 2; k++) {
		float ex2 = floor(p.x + (hash2(c, 30 + k, seed) - 0.5) * p.y * 1.3);
		float rr = fract(game_time * 0.3 + hash2(c, 36 + k, seed)) * 16.0 + 1.5;
		float e = length(vec2((float(qx) + 0.5 - ex2) / rr, (float(dy) + 0.5) / (rr * 0.25)));
		if (abs(e - 1.0) < 0.5 / rr * 1.5 && dy < 5) {
			col = mix(col, line_color, 0.3 * (1.0 - rr / 18.0));
		}
	}
	// Dead pixels: corrupted data blinking in the water.
	float dead = hash2(qx / 2, y + int(game_time * 2.0) * 977, seed + c);
	if (dead < 0.003) {
		col = CORRUPT;
	} else if (dead < 0.007) {
		col = line_color * 1.1;
	}
	return vec4(mix(col, haze_color, f * 0.6), 1.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 300.0, 0.6, vec2(14.0, 26.0), 0.15, true, 71);
	vec4 far = range(px, size.y, 0.07, 220.0, 0.52, vec2(6.0, 12.0), 0.45, false, 73);
	vec4 c = near.a > 0.0 ? near : (far.a > 0.0 ? far : vec4(0.0));
	// The near range's bubbles and cables pass in front of the far flats; a translucent bubble over them.
	if (near.a > 0.0 && near.a < 1.0 && far.a > 0.0) {
		c = vec4(mix(far.rgb, near.rgb, near.a), 1.0);
	}
	COLOR = vec4(c.rgb * strength, c.a);
}
