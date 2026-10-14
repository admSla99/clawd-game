// The ravine's scenery motif (docs/scenery-themes.md: clocks and spinners), a far background layer between the
// haze and the parallax, in view pixels like shaders/motif_swamp.gdshader: two ranges of ravine walls (a far one
// hazier and slower), jagged rock hanging from the top of the view and rising from the bottom, and deep in the
// ravine between them clock faces with ticking hands and loading spinners hang in the haze. A clock's hand sweeps
// round; when it passes twelve the clock times out: its rim flashes red for a moment. Opaque where there is rock, a
// clock or a spinner, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.88, 0.48, 0.75);
uniform vec3 haze_color = vec3(0.28, 0.12, 0.28);
uniform vec3 mid_color = vec3(0.13, 0.05, 0.14);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const vec3 TIMEOUT = vec3(1.0, 0.36, 0.3);

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

// A clock or a spinner of cell `c` at layer pixel (qx, y): rgb, alpha.
vec4 dial(int c, int qx, int y, float span, float h, int seed) {
	if (hash2(c, 1, seed) < 0.25) {
		return vec4(0.0);
	}
	vec2 m = vec2(floor((float(c) + 0.3 + 0.4 * hash2(c, 2, seed)) * span), floor(h * (0.3 + 0.35 * hash2(c, 3, seed))));
	vec2 d = vec2(float(qx), float(y)) + 0.5 - m - 0.5;
	float len = length(d);
	if (hash2(c, 4, seed) < 0.4) {
		// A spinner: 8 dots round a circle of 4 px, one bright running round.
		if (len > 6.0) {
			return vec4(0.0);
		}
		int head = int(game_time * 10.0 + hash2(c, 5, seed) * 8.0) % 8;
		for (int k = 0; k < 8; k++) {
			float a = float(k) * TAU / 8.0;
			if (floor(m + vec2(cos(a), sin(a)) * 4.0 + 0.5) == vec2(float(qx), float(y))) {
				int age = (head - k + 8) % 8;
				return vec4(age == 0 ? vec3(1.0) : mix(mid_color, line_color, max(0.0, 0.8 - float(age) * 0.12)), 1.0);
			}
		}
		return vec4(0.0);
	}
	// A clock: a rim, twelve ticks, a hand sweeping round; red as it passes twelve.
	float r = floor(5.0 + 4.0 * hash2(c, 6, seed));
	if (len > r + 0.6) {
		return vec4(0.0);
	}
	float period = 3.0 + 5.0 * hash2(c, 7, seed);
	float turn = fract(game_time / period + hash2(c, 8, seed));
	bool timeout = turn < 0.08;
	if (len > r - 0.6) {
		return vec4(timeout ? TIMEOUT : mix(mid_color, line_color, 0.55), 1.0);
	}
	float ang = atan(d.y, d.x) + PI / 2.0;
	if (len > r - 2.0 && fract(ang / TAU * 12.0 + 0.04) < 0.08) {
		return vec4(mix(mid_color, line_color, 0.4), 1.0);
	}
	// The hand.
	float ha = turn * TAU - PI / 2.0;
	vec2 dir = vec2(cos(ha), sin(ha));
	float along = dot(d, dir);
	float off = abs(dot(d, vec2(-dir.y, dir.x)));
	if (along > -0.5 && along < r - 1.5 && off < 0.6) {
		return vec4(timeout ? TIMEOUT : vec3(0.95), 1.0);
	}
	return vec4(mid_color * 0.55, 1.0);
}

vec4 range(vec2 px, float h, float factor, float span, float fog, bool near, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	float fy = float(y);
	// The walls: rock hanging from the top and rising from the bottom.
	float top = h * 0.12 + noise1(float(qx) / 19.0, seed) * h * 0.14 + noise1(float(qx) / 6.0, seed + 1) * 4.0;
	float bottom = h * 0.86 - noise1(float(qx) / 23.0, seed + 2) * h * 0.14 - noise1(float(qx) / 7.0, seed + 3) * 4.0;
	if (fy < top || fy > bottom) {
		float edge = fy < top ? top - fy : fy - bottom;
		vec3 col = mid_color * 0.45;
		if (edge < 1.5) {
			col = mix(col, line_color, near ? 0.3 : 0.15);
		} else if (int(edge) % 6 == 0 && hash2(qx / 4, y, seed + 5) < 0.6) {
			col *= 0.75;
		}
		return vec4(mix(col, haze_color, clamp(fog + edge / 160.0, 0.0, 0.9)), 1.0);
	}
	int cell = int(floor(float(qx) / span));
	for (int i = -1; i <= 1; i++) {
		vec4 c = dial(cell + i, qx, y, span, h, seed);
		if (c.a > 0.0) {
			return vec4(mix(c.rgb, haze_color, fog * 0.8), 1.0);
		}
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 70.0, 0.15, true, 131);
	vec4 far = range(px, size.y, 0.07, 50.0, 0.5, false, 133);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
