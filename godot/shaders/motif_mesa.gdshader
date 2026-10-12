// The mesa's scenery motif (docs/scenery-themes.md: diff strata), a far background layer between the haze and
// the parallax ridges, in view pixels like shaders/motif_caves.gdshader: two ranges of mesas (a far one hazier
// and slower) whose rock is a diff, one stratum per line of LINE px. Most strata are context (rock), some are
// added or removed lines (green / red, a "+" / "-" at their left end), and some blocks are merge conflicts: a
// "<<<<<<<" seam, our green lines, "=======", their red lines and ">>>>>>>". The conflict markers (repeated
// along the seam) glow in the theme's ray colour, pulse slowly, and a spark runs along each seam. Every stratum is a step of the cliff (its
// sides erode outwards line by line), with a lit ledge on top, a dark joint at the bottom and dim "code" in it.
// Opaque where there is rock, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.88, 0.57, 0.44);
uniform vec3 haze_color = vec3(0.38, 0.21, 0.23);
uniform vec3 mid_color = vec3(0.16, 0.09, 0.13);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const int LINE = 5;
const int MAX_LINES = 48;
const int MARK_EVERY = 64;
const vec3 ADD = vec3(92.0, 172.0, 110.0) / 255.0;
const vec3 DEL = vec3(214.0, 92.0, 86.0) / 255.0;
const vec3 ROCK = vec3(136.0, 108.0, 98.0) / 255.0;
// Line kinds.
const int CONTEXT = 0;
const int ADDED = 1;
const int REMOVED = 2;
const int OURS = 3; // <<<<<<<
const int SEP = 4; // =======
const int THEIRS = 5; // >>>>>>>

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

// The kind of line `k` of mesa `c`: blocks of 7 lines, some of them a conflict, the cap always context.
int kind(int c, int k, int seed) {
	int b = k / 7;
	if (b > 0 && hash2(c, 100 + b, seed) > 0.55) {
		int r = k - b * 7;
		return r == 0 ? OURS : r <= 2 ? ADDED : r == 3 ? SEP : r <= 5 ? REMOVED : THEIRS;
	}
	if (k < 2) {
		return CONTEXT;
	}
	float h = hash2(c, 200 + k, seed);
	return h < 0.14 ? ADDED : h < 0.26 ? REMOVED : CONTEXT;
}

// One range of mesas at view pixel `px`: rgb and 1 where there is rock, else 0 alpha. `base` is the view row
// where the mesas stand (they go on below it), `lines` their height range in strata, `fog` how far into the
// haze they are.
vec4 range(vec2 px, float h, float factor, float span, float base, vec2 lines, float fog, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	int base_y = int(h * base);
	int cell = int(floor(float(qx) / span));
	for (int i = 0; i < 3; i++) {
		int c = cell + (i == 0 ? 0 : i == 1 ? -1 : 1);
		if (hash2(c, 0, seed) < 0.3) {
			continue;
		}
		int n = int(mix(lines.x, lines.y, hash2(c, 1, seed)));
		int top = base_y - n * LINE;
		if (y < top) {
			continue;
		}
		int cx = int((float(c) + 0.3 + 0.4 * hash2(c, 2, seed)) * span);
		int k = min((y - top) / LINE, MAX_LINES - 1);
		int r = (y - top) - k * LINE;
		// The cliff steps out line by line, each side on its own.
		int cap = 16 + int(hash2(c, 3, seed) * span * 0.2);
		int wl = cap - 2;
		int wr = cap - 2;
		int wl_above = wl;
		int wr_above = wr;
		for (int j = 1; j <= k; j++) {
			wl_above = wl;
			wr_above = wr;
			wl += int(hash2(c, 10 + j, seed) * 3.2);
			wr += int(hash2(c, 60 + j, seed) * 3.2);
		}
		if (qx < cx - wl || qx >= cx + wr) {
			continue;
		}
		int lx = qx - (cx - wl);
		int t = kind(c, k, seed);
		float pulse = 0.65 + 0.35 * sin(game_time * 1.6 + float(c) * 1.7 + float(k));
		vec3 col;
		float glow = 0.0;
		if (t >= OURS) {
			// A conflict marker: seven glyphs, a glowing crack, seven glyphs again every MARK_EVERY px (so the
			// trunks in front never hide them all).
			col = mid_color * 0.7;
			int g = (lx - 2) % MARK_EVERY;
			int gx = g % 4;
			bool mark = false;
			if (lx >= 2 && g < 28 && r >= 1 && r <= 3) {
				if (t == SEP) {
					mark = r != 2 && gx < 3;
				} else {
					int tip = t == OURS ? (r == 2 ? 0 : 1) : (r == 2 ? 1 : 0);
					mark = gx == tip;
				}
			} else if (lx >= 2 && g >= 28 && r == 2) {
				mark = true;
				glow = 0.45;
			}
			if (mark) {
				glow = glow > 0.0 ? glow : 1.0;
			}
			// A spark runs along the seam.
			int w = wl + wr;
			int sx = int(fract(game_time * 0.06 + hash2(c, 300 + k, seed)) * float(w + 40)) - 20;
			int d = abs(lx - sx);
			if (r == 2 && d < 6) {
				glow = max(glow, 1.4 - float(d) * 0.2);
			}
			col = mix(col, line_color * 1.5, glow * pulse);
		} else {
			vec3 band = t == ADDED ? mix(ROCK, ADD, 0.8) : t == REMOVED ? mix(ROCK, DEL, 0.8) : ROCK;
			col = band * 0.7;
			// Dim code in the middle row: words after an indent; "+" / "-" at the left end of a changed line.
			if (r == 2) {
				int indent = 6 + 2 * int(hash2(c, 400 + k, seed) * 4.0);
				int word = (lx - indent) / 5;
				if (lx >= indent && lx < wl + wr - 3 && (lx - indent) % 5 < 3 + int(hash2(c * 7 + word, k, seed) * 2.0)
						&& hash2(word, k, seed + c) > 0.25) {
					col = band * 0.95;
				}
			}
			if (t != CONTEXT && lx >= 1 && lx <= 3 && r >= 1 && r <= 3 && (r == 2 || (t == ADDED && lx == 2))) {
				col = band * 1.15;
			}
			// A lit ledge where the stratum steps out from under the one above (and on the cap), a dark joint.
			bool open_above = k == 0 || qx < cx - wl_above || qx >= cx + wr_above;
			if (r == 0 && open_above) {
				col = mix(band, line_color, 0.5);
			} else if (r == LINE - 1) {
				col = band * 0.3;
			}
			// The glow of a conflict marker spills onto the rows next to it.
			if ((r == 0 && k > 0 && kind(c, k - 1, seed) >= OURS) || (r == LINE - 1 && kind(c, k + 1, seed) >= OURS)) {
				col = mix(col, line_color, 0.18 * pulse);
			}
			// Lit on the left, shaded on the right.
			if (lx == 0) {
				col *= 1.25;
			} else if (qx == cx + wr - 1) {
				col *= 0.7;
			}
		}
		// Hazier lower down, and the far range more so; below its foot (into pits) it sinks into the haze fast.
		// Glowing markers less.
		float f = fog + float(y - top) / float(max(n * LINE, 1)) * 0.2 + max(0.0, float(y - base_y) / 48.0);
		f = clamp(f, 0.0, 0.95) * (1.0 - glow * 0.5);
		return vec4(mix(col, haze_color, f), 1.0);
	}
	return vec4(0.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 360.0, 0.8, vec2(14.0, 24.0), 0.22, 59);
	vec4 far = range(px, size.y, 0.07, 280.0, 0.7, vec2(10.0, 18.0), 0.48, 61);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
