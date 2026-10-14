// The router's scenery motif (docs/scenery-themes.md: network topology), a far background layer between the haze
// and the parallax, in view pixels like shaders/motif_swamp.gdshader: two layers of a network (a far one hazier and
// slower), nodes on a jittered grid, each linked to its right and lower neighbours by dotted lines, and packets
// running along the links, a node blinking when one arrives. Opaque where there is a node, a link or a packet,
// transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.49, 0.67, 1.0);
uniform vec3 haze_color = vec3(0.1, 0.16, 0.38);
uniform vec3 mid_color = vec3(0.05, 0.06, 0.16);
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

// The node of grid cell (i, j), in layer pixels; w = 0 where there is none.
vec3 node(int i, int j, float span, int seed) {
	if (hash2(i, j, seed) < 0.2) {
		return vec3(0.0);
	}
	vec2 p = (vec2(float(i), float(j)) + 0.25 + 0.5 * vec2(hash2(i, j, seed + 1), hash2(i, j, seed + 2))) * span;
	return vec3(floor(p), 1.0);
}

// The distance from `q` to the segment a-b and how far along it (0..1) the closest point is.
vec2 seg(vec2 q, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float u = clamp(dot(q - a, ab) / max(dot(ab, ab), 1e-3), 0.0, 1.0);
	return vec2(length(q - a - ab * u), u);
}

vec4 layer(vec2 px, float h, float factor, float span, float fog, bool near, int seed) {
	vec2 q = vec2(px.x + floor(scroll.x * factor), px.y + floor(scroll.y * factor * 0.5));
	int ci = int(floor(q.x / span));
	int cj = int(floor(q.y / span));
	vec4 best = vec4(0.0);
	for (int di = -1; di <= 0; di++) {
		for (int dj = -1; dj <= 0; dj++) {
			int i = ci + di;
			int j = cj + dj;
			vec3 a = node(i, j, span, seed);
			if (a.z == 0.0) {
				continue;
			}
			// The node: a 3 x 3 box with a lit core, blinking when a packet arrives.
			vec2 d = q - a.xy;
			if (abs(d.x) <= 1.0 && abs(d.y) <= 1.0) {
				float blink = fract(game_time * 0.4 + hash2(i, j, seed + 3));
				vec3 col = (d == vec2(0.0)) ? (blink < 0.08 ? vec3(1.0) : line_color) : mid_color * 0.9 + line_color * 0.25;
				return vec4(mix(col, haze_color, fog), 1.0);
			}
			// Links to the right and lower neighbours.
			for (int k = 0; k < 2; k++) {
				vec3 b = node(i + 1 - k, j + k, span, seed);
				if (b.z == 0.0) {
					continue;
				}
				vec2 s = seg(q, a.xy, b.xy);
				if (s.x < 0.55) {
					// A packet runs along the link now and then.
					float pu = fract(game_time * (0.15 + 0.1 * hash2(i, j + k * 7, seed + 4)) + hash2(i, j + k, seed + 5));
					if (near && abs(s.y - pu) * length(b.xy - a.xy) < 1.5) {
						return vec4(vec3(1.0) * 0.9 + line_color * 0.1, 1.0);
					}
					if (int(s.y * length(b.xy - a.xy)) % 3 == 0) {
						best = vec4(mix(mix(mid_color, line_color, 0.35), haze_color, fog), 1.0);
					}
				}
			}
		}
	}
	return best;
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = layer(px, size.y, 0.13, 46.0, 0.2, true, 141);
	vec4 far = layer(px, size.y, 0.07, 30.0, 0.55, false, 143);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
