// The canopy's scenery motif (docs/scenery-themes.md: endpoint canopy), a far background layer between the haze and
// the parallax ridges, in view pixels like shaders/motif_swamp.gdshader: two ranges of giant trees (a far one hazier
// and slower) whose lacy crowns close into a canopy in the upper part of the view. Vines hang from the canopy, and at
// the end of each one an API endpoint glows: a small dim lantern (not a ring: the level's anchors, scripts/anchor.gd,
// are rings, and these can't be hooked). Now and then a request runs down a vine as a light pulse; the endpoint
// flashes when it arrives and its reply ("OK", "GET",
// "PUT", "POST") floats up from it and fades. Opaque where there is a tree, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.55, 0.9, 0.82);
uniform vec3 haze_color = vec3(0.13, 0.34, 0.35);
uniform vec3 mid_color = vec3(0.05, 0.16, 0.16);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

// The anchors' cyan (scripts/anchor.gd).
const vec3 ENDPOINT = vec3(127.0, 232.0, 240.0) / 255.0;
const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
// 3x5 glyphs of shaders/motif_swamp.gdshader, " A..Z" (index 0 = space).
const int FONT[27] = int[](0, 11245, 27566, 14627, 27502, 31143, 31140, 14699, 23533, 29847, 4714, 23469, 18727,
	24557, 27501, 11114, 27556, 11123, 27565, 14478, 29842, 23407, 23402, 23549, 23213, 23186, 29351);
// The replies: OK, GET, PUT, POST (4 glyphs each, 0 = none).
const int REPLY[16] = int[](15, 11, 0, 0, 7, 5, 20, 0, 16, 21, 20, 0, 16, 15, 19, 20);
const int REPLY_LEN[4] = int[](2, 3, 3, 4);
// The endpoint lantern, 3 x 4: 2 = frame, 1 = light.
const int LANTERN[12] = int[](0, 2, 0, 2, 1, 2, 2, 1, 2, 0, 2, 0);

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

float noise1(float x, int s) {
	float i = floor(x);
	float f = x - i;
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash2(int(i), 0, s), hash2(int(i) + 1, 0, s), f);
}

float noise2(vec2 p, int s) {
	vec2 i = floor(p);
	vec2 f = p - i;
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(int(i.x), int(i.y), s);
	float b = hash2(int(i.x) + 1, int(i.y), s);
	float c = hash2(int(i.x), int(i.y) + 1, s);
	float d = hash2(int(i.x) + 1, int(i.y) + 1, s);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// The tree of cell `c`: x = trunk middle, y = half width (px).
vec2 tree(int c, float span, float width, int seed) {
	float x = floor((float(c) + 0.5 + (hash2(c, 1, seed) - 0.5) * 0.5) * span);
	return vec2(x, floor(width * (0.7 + 0.6 * hash2(c, 2, seed))));
}

// One range at view pixel `px`: rgb, alpha (0 = sky), and in `glow` how much of it shines.
vec4 range(vec2 px, float h, float factor, float span, float width, float crown, float fog, bool near, int seed,
		out float glow) {
	glow = 0.0;
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	float fy = float(y);
	int cell = int(floor(float(qx) / span));
	// The canopy: a band of lacy foliage whose edges wave along the range.
	float top = h * crown - 10.0 - noise1(float(qx) / 23.0, seed + 3) * 18.0;
	float bottom = h * crown + 8.0 + noise1(float(qx) / 17.0, seed + 4) * 14.0;
	if (fy >= top && fy < bottom) {
		float leaf = noise2(vec2(float(qx) / 4.0, fy / 3.0), seed + 5) * 0.6 + noise2(vec2(float(qx) / 11.0, fy / 7.0), seed + 6) * 0.4;
		// Denser in the middle of the band, lacy at its edges.
		float edge = min(fy - top, bottom - fy) / 8.0;
		if (leaf + min(edge, 1.0) * 0.35 > 0.72) {
			vec3 col = mid_color * 0.55;
			if (fy > bottom - 3.0 || leaf > 0.86) {
				col = mix(col, line_color, near ? 0.22 : 0.12);
			}
			return vec4(mix(col, haze_color, fog), 1.0);
		}
	}
	// Trunks from the canopy down out of the view, with a lit left edge and dark bark rings.
	for (int i = -1; i <= 1; i++) {
		vec2 t = tree(cell + i, span, width, seed);
		float d = float(qx) + 0.5 - t.x;
		float hw = t.y + max(0.0, (fy - bottom) / 40.0);
		if (abs(d) < hw && fy >= top + 6.0) {
			vec3 col = mid_color * 0.4;
			if (d < -hw + 1.5) {
				col = mix(col, line_color, 0.18);
			}
			if (hash2(cell + i, y / 5, seed + 9) < 0.18 && abs(d) < hw - 1.0) {
				col *= 0.7;
			}
			return vec4(mix(col, haze_color, fog * (1.0 - 0.2 * float(fy > h * 0.8))), 1.0);
		}
	}
	if (!near) {
		return vec4(0.0);
	}
	// Vines with an endpoint at the end: three per tree, hanging from the canopy's bottom.
	for (int i = -1; i <= 1; i++) {
		int c = cell + i;
		vec2 t = tree(c, span, width, seed);
		for (int k = 0; k < 3; k++) {
			float vx = floor(t.x + (hash2(c, 10 + k, seed) - 0.5) * span * 0.8);
			float start = h * crown + 6.0;
			float len = floor(16.0 + hash2(c, 13 + k, seed) * 46.0);
			float u = (fy - start) / len;
			if (u < -0.05 || u > 1.25) {
				continue;
			}
			float sway = floor(sin(game_time * 0.6 + float(c * 3 + k)) * 2.0 * clamp(u, 0.0, 1.0) + 0.5);
			int ex = int(vx + sway);
			int ey = int(start + len);
			// The request: a pulse down the vine every few seconds; the endpoint flashes as it arrives.
			float period = 5.0 + hash2(c, 16 + k, seed) * 6.0;
			float ph = fract(game_time / period + hash2(c, 17 + k, seed));
			float run = ph / 0.35;
			bool flash = run >= 1.0 && run < 1.4;
			// The lantern, dimmed into the haze.
			int rx = qx - ex + 1;
			int ry = y - ey;
			if (rx >= 0 && rx < 3 && ry >= 0 && ry < 4) {
				int v = LANTERN[ry * 3 + rx];
				if (v > 0) {
					float pulse = 0.8 + 0.2 * sin(game_time * 3.0 + float(c + k));
					glow = 0.6;
					vec3 col = v == 1 ? mix(ENDPOINT, vec3(1.0), 0.3) * (flash ? 1.4 : pulse) : mid_color * 0.6;
					return vec4(mix(col, haze_color, 0.3), 1.0);
				}
			}
			// The vine itself, 1 px.
			if (u >= 0.0 && u <= 1.0 && qx == int(vx + floor(sin(game_time * 0.6 + float(c * 3 + k)) * 2.0 * u + 0.5))) {
				if (run < 1.0 && abs(u - run) * len < 1.5) {
					glow = 1.0;
					return vec4(ENDPOINT * 1.4, 1.0);
				}
				return vec4(mix(mid_color * 0.5, line_color, 0.15), 1.0);
			}
			// The reply floats up from the endpoint and fades.
			float ra = (ph - 0.35) / 0.3;
			if (ra > 0.0 && ra < 1.0 && hash2(c, 18 + k + int(game_time / period) * 7, seed) < 0.7) {
				int which = int(hash2(c, 19 + k, seed) * 4.0);
				int n = REPLY_LEN[which];
				int tx0 = ex - (n * 4 - 1) / 2;
				int ty0 = ey - 8 - int(ra * 10.0);
				int gx = qx - tx0;
				int gy = y - ty0;
				if (gx >= 0 && gx < n * 4 && gx % 4 < 3 && gy >= 0 && gy < 5) {
					int g = FONT[REPLY[which * 4 + gx / 4]];
					if (((g >> ((4 - gy) * 3 + (2 - gx % 4))) & 1) == 1 && bayer(px) < 1.0 - ra * 0.8) {
						glow = 0.6;
						return vec4(mix(line_color, vec3(1.0), 0.3), 1.0);
					}
				}
			}
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	float g_near;
	float g_far;
	vec4 near = range(px, size.y, 0.13, 150.0, 7.0, 0.24, 0.18, true, 101, g_near);
	vec4 far = range(px, size.y, 0.07, 100.0, 4.0, 0.18, 0.5, false, 103, g_far);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
