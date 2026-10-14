// The cliffs' scenery motif (docs/scenery-themes.md: webhook cliffs), a far background layer between the haze and
// the parallax, in view pixels like shaders/motif_swamp.gdshader: two ranges of sheer cliff pillars (a far one
// hazier and slower) with jagged tops, dark strata and a lit left edge; they move with the camera up and down too,
// as 3-2 is a climb. Between the near pillars' tops callbacks fly: a small message (a 3 x 2 envelope) arcs from one
// top to the next on a dotted trail and, a moment later, comes back the same way, as webhooks do. Opaque where there
// is rock, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.69, 0.78, 0.93);
uniform vec3 haze_color = vec3(0.21, 0.28, 0.42);
uniform vec3 mid_color = vec3(0.09, 0.12, 0.2);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

// Pillar `c`: x = middle, y = half width, z = top (view rows below the range's base line, can be negative).
vec3 pillar(int c, float span, float h, int seed) {
	float x = floor((float(c) + 0.5 + (hash2(c, 1, seed) - 0.5) * 0.4) * span);
	float hw = floor(span * (0.16 + 0.14 * hash2(c, 2, seed)));
	float top = floor(h * (0.15 + 0.35 * hash2(c, 3, seed)));
	return vec3(x, hw, top);
}

// The top of pillar `c` at layer column `qx`: jagged, a step or two.
float top_at(vec3 p, int c, int qx, int seed) {
	return p.z + floor(hash2(qx / 3, c, seed + 7) * 4.0) + (abs(float(qx) + 0.5 - p.x) > p.y * 0.6 ? 3.0 : 0.0);
}

// A message flying from pillar `c` to `c + 1` (and back): rgb, alpha.
vec4 message(int c, int qx, int qy, float span, float h, int seed) {
	vec3 a = pillar(c, span, h, seed);
	vec3 b = pillar(c + 1, span, h, seed);
	float period = 6.0 + hash2(c, 11, seed) * 5.0;
	float ph = fract(game_time / period + hash2(c, 12, seed));
	// Out in the first third, back in the second, quiet in the last.
	float u = ph < 0.33 ? ph / 0.33 : (ph < 0.66 ? 1.0 - (ph - 0.33) / 0.33 : -1.0);
	if (u < 0.0) {
		return vec4(0.0);
	}
	vec2 p0 = vec2(a.x, a.z - 4.0);
	vec2 p1 = vec2(b.x, b.z - 4.0);
	float lift = 18.0 + abs(p1.x - p0.x) * 0.25;
	vec4 best = vec4(0.0);
	// The trail: dots behind the message along the arc.
	for (int k = 0; k < 5; k++) {
		float uu = u - (ph < 0.33 ? 1.0 : -1.0) * float(k) * 0.035;
		if (uu < 0.0 || uu > 1.0) {
			continue;
		}
		vec2 m = mix(p0, p1, uu) + vec2(0.0, -lift * 4.0 * uu * (1.0 - uu));
		vec2 d = vec2(float(qx), float(qy)) - floor(m);
		if (k == 0) {
			if (d.x >= -1.0 && d.x <= 1.0 && d.y >= 0.0 && d.y <= 1.0) {
				return vec4(d.y == 0.0 && d.x == 0.0 ? mid_color : mix(line_color, vec3(1.0), 0.4), 1.0);
			}
		} else if (d == vec2(0.0) && k % 2 == 0) {
			best = vec4(line_color * (1.0 - float(k) * 0.15), 1.0);
		}
	}
	return best;
}

// One range at view pixel `px`.
vec4 range(vec2 px, float h, float factor, float span, float base, float fog, bool near, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	// Up and down with the camera too, at a fraction of the sideways parallax.
	int qy = int(px.y - h * base + floor(scroll.y * factor * 0.5));
	int cell = int(floor(float(qx) / span));
	for (int i = -1; i <= 1; i++) {
		vec3 p = pillar(cell + i, span, h, seed);
		float d = float(qx) + 0.5 - p.x;
		if (abs(d) >= p.y) {
			continue;
		}
		float top = top_at(p, cell + i, qx, seed);
		if (float(qy) < top) {
			continue;
		}
		vec3 col = mid_color * 0.45;
		// Strata: a darker band every few rows, broken now and then.
		if (int(float(qy) - top) % 7 == 0 && hash2(qx / 5, qy, seed + 3) < 0.7) {
			col *= 0.7;
		}
		// Lit left edge and top rim.
		if (d < -p.y + 1.5 || float(qy) < top + 1.0) {
			col = mix(col, line_color, near ? 0.3 : 0.16);
		}
		float f = clamp(fog + max(0.0, float(qy) - top) / 220.0, 0.0, 0.9);
		return vec4(mix(col, haze_color, f), 1.0);
	}
	if (near) {
		for (int i = -2; i <= 1; i++) {
			vec4 m = message(cell + i, qx, qy, span, h, seed);
			if (m.a > 0.0) {
				return m;
			}
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 120.0, 0.35, 0.2, true, 111);
	vec4 far = range(px, size.y, 0.07, 80.0, 0.25, 0.5, false, 113);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
