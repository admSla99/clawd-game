// The towers' scenery motif (docs/scenery-themes.md: transformer stacks), a far background layer between the haze
// and the parallax columns, in view pixels like shaders/motif_mesa.gdshader: two ranges of tall stacks (a far one
// hazier and slower) of translucent plates, one plate per layer, attention and MLP layers by turns (the MLP ones a
// little narrower). Each plate is a slab seen from above (a lit top band over its front face), its front a line of
// a diff: context in a glassy tone, added / removed layers in green / red with a "+" / "-" at their left end and
// dim "code" in them. A residual stream runs up through the middle of every stack, seen through the plates and
// bright in the gaps between them; pulses of light climb it and light each plate's top as they pass. Some stacks
// end below the level's top in a cap with a glowing output node, so their tops come into view near the exit. The
// layer moves at a twentieth / a tenth of the camera's speed on both axes (2-4 is a climb). sRGB like the haze,
// translucent: the haze shows through the plates.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.33, 0.76, 0.53);
uniform vec3 haze_color = vec3(0.08, 0.24, 0.18);
uniform vec3 mid_color = vec3(0.04, 0.11, 0.09);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const vec3 ADD = vec3(92.0, 172.0, 110.0) / 255.0;
const vec3 DEL = vec3(214.0, 92.0, 86.0) / 255.0;
const vec3 GLASS = vec3(132.0, 160.0, 156.0) / 255.0;
const float PULSE_SPACING = 84.0;
const float PULSE_LENGTH = 18.0;
// Line kinds.
const int CONTEXT = 0;
const int ADDED = 1;
const int REMOVED = 2;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

int floor_div(int a, int b) {
	return int(floor(float(a) / float(b)));
}

// "a over b" for straight-alpha colours.
vec4 over(vec4 a, vec4 b) {
	float alpha = a.a + b.a * (1.0 - a.a);
	if (alpha <= 0.0) {
		return vec4(0.0);
	}
	return vec4((a.rgb * a.a + b.rgb * b.a * (1.0 - a.a)) / alpha, alpha);
}

// How lit the residual stream of stack `c` is at layer row `qy`: 1 at a pulse's head, fading down its tail (the
// pulses climb, so the tail is below), 0 between pulses. `len` is the tail's length in px.
float pulse(int c, float qy, float speed, float len, int seed) {
	float s = fract((qy + game_time * speed) / PULSE_SPACING + hash2(c, 5, seed));
	float d = s * PULSE_SPACING;
	return d < len ? 1.0 - d / len : 0.0;
}

// One range of stacks at view pixel `px`: rgb and alpha (0 where there is none). `span` is the width of a stack's
// cell, `half_w` the range of its half widths, `top_rows` / `face_rows` / `period` a plate's top band, front face
// and pitch in px, `tops` the range of the cap rows (as fractions of the view height, for a camera at the level's
// top), `stream_w` the stream's width and `fog` how far into the haze the range is.
vec4 range(vec2 px, float h, float factor, float span, vec2 half_w, int top_rows, int face_rows, int period,
		vec2 tops, int stream_w, float speed, float fog, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int qy = int(px.y + floor(scroll.y * factor));
	int cell = floor_div(qx, int(span));
	for (int i = 0; i < 3; i++) {
		int c = cell + (i == 0 ? 0 : i == 1 ? -1 : 1);
		if (hash2(c, 0, seed) < 0.22) {
			continue;
		}
		int hw = int(mix(half_w.x, half_w.y, hash2(c, 1, seed)));
		float room = span - 2.0 * float(hw) - 12.0;
		int cx = int((float(c) + 0.5) * span + (hash2(c, 2, seed) - 0.5) * room);
		int dx = qx - cx;
		// Wide enough to hold the widest plate (an attention layer) and the output node.
		if (dx < -hw || dx >= hw) {
			continue;
		}
		int phase = int(hash2(c, 4, seed) * float(period));
		int k = floor_div(qy - phase, period);
		int r = qy - phase - k * period;
		// The cap: the topmost layer of a stack that ends (two in three do), else none in reach.
		int top_k = -1000000;
		if (hash2(c, 3, seed) > 0.33) {
			top_k = floor_div(int(h * mix(tops.x, tops.y, hash2(c, 6, seed))) - phase, period);
		}
		if (k < top_k - 1 || (k == top_k - 1 && r < period - 6)) {
			continue;
		}
		int stream_top = (top_k - 1) * period + phase + period - 3;
		vec4 col = vec4(0.0);
		float glow = 0.0;
		// The residual stream, a thin bright column up the middle, glowing where a pulse climbs it.
		bool in_stream = dx >= -(stream_w / 2) && dx < stream_w - stream_w / 2;
		float p = pulse(c, float(qy), speed, PULSE_LENGTH, seed);
		if (in_stream && qy >= stream_top) {
			glow = p;
			col = vec4(mix(line_color * 0.55, line_color * 1.6, p), 0.75 + 0.25 * p);
		}
		// The output node over the cap: a small pulsing diamond on the stream's end.
		if (k == top_k - 1) {
			int ny = (top_k - 1) * period + phase + period - 5;
			int ady = abs(qy - ny);
			int adx = in_stream ? 0 : (dx < 0 ? -dx - stream_w / 2 : dx - (stream_w - stream_w / 2) + 1);
			if (adx + ady <= 1 + stream_w / 2) {
				float beat = 0.6 + 0.4 * sin(game_time * 2.2 + float(c) * 1.3);
				glow = max(glow, beat);
				col = vec4(line_color * (1.0 + 0.7 * beat), 1.0);
			}
		}
		if (k >= top_k) {
			// The plate of layer k: attention layers (even k) full width, MLP layers narrower.
			int pw = (k & 1) == 0 ? hw : hw - max(2, hw / 5);
			bool cap = k == top_k;
			// Lit as the pulse's head passes the plate, fading as it climbs on.
			float act = pulse(c, float(k * period + phase + top_rows), speed, 30.0, seed);
			int lx = dx + pw;
			int w = 2 * pw;
			// The top band's back edge is a pixel in at both ends.
			bool corner = r == 0 && (lx == 0 || lx == w - 1);
			if (dx >= -pw && dx < pw && r < top_rows + face_rows && !corner) {
				// One line of a diff per layer; the cap is always context.
				float kh = hash2(c, 100 + k, seed);
				int t = cap ? CONTEXT : kh < 0.18 ? ADDED : kh < 0.34 ? REMOVED : CONTEXT;
				vec3 diff = t == ADDED ? ADD : DEL;
				vec4 plate;
				if (r < top_rows) {
					// The top band, seen from above: lighter.
					vec3 top = mix(GLASS, line_color, 0.25 + 0.6 * act) * (cap ? 1.1 : 0.95);
					plate = vec4(top, 0.8);
					glow = max(glow, act * 0.6);
				} else {
					// Glass: a bright front lip, a see-through body (the stream and the far stacks show through) and
					// a dark joint along the bottom. The line of the diff is a two-row stripe across the middle.
					int fr = r - top_rows;
					int mid = face_rows / 2;
					bool stripe = fr == mid - 1 || fr == mid;
					plate = vec4(GLASS * 0.55, 0.42);
					// Words of code in the stripe's top row, after an indent.
					bool word_px = false;
					if (fr == mid - 1) {
						int indent = 5 + 2 * int(hash2(c, 400 + k, seed) * 3.0);
						int word = (lx - indent) / 5;
						word_px = lx >= indent && lx < w - 3 && (lx - indent) % 5 < 3 + int(hash2(c * 7 + word, k, seed) * 2.0)
								&& hash2(word, k, seed + c) > 0.25;
					}
					if (t != CONTEXT && stripe) {
						plate = vec4(diff * (word_px ? 1.0 : 0.6), 0.9);
						glow = max(glow, 0.4);
					} else if (word_px) {
						plate = vec4(GLASS * 0.8, 0.6);
					}
					// "+" / "-" at the left end of a changed line.
					if (t != CONTEXT && lx >= 1 && lx <= 3 && abs(fr - (mid - 1)) <= 1
							&& (fr == mid - 1 || (t == ADDED && lx == 2))) {
						plate = vec4(diff * 1.25, 1.0);
						glow = max(glow, 0.6);
					}
					if (fr == 0) {
						plate = vec4(mix(GLASS, line_color, 0.2 + 0.4 * act) * 1.05, 0.85);
					} else if (fr == face_rows - 1) {
						plate = vec4(GLASS * 0.22, 0.7);
					}
					// Lit on the left, shaded on the right.
					if (lx == 0) {
						plate.rgb *= 1.25;
					} else if (lx == w - 1) {
						plate.rgb *= 0.7;
					}
					plate.rgb += line_color * act * 0.12;
				}
				col = over(plate, col);
			}
		}
		if (col.a <= 0.0) {
			continue;
		}
		// Hazier lower in the view, glowing pixels less.
		float f = clamp(fog + px.y / h * 0.22, 0.0, 0.92) * (1.0 - glow * 0.6);
		return vec4(mix(col.rgb, haze_color, f), col.a);
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.1, 150.0, vec2(13.0, 20.0), 2, 6, 12, vec2(0.25, 0.6), 2, 30.0, 0.3, 91);
	vec4 far = range(px, size.y, 0.05, 104.0, vec2(7.0, 11.0), 1, 4, 8, vec2(0.12, 0.45), 1, 20.0, 0.5, 97);
	vec4 c = over(near, far);
	COLOR = vec4(c.rgb * strength, c.a);
}
