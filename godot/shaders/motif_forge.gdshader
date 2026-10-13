// The forge's scenery motif (docs/scenery-themes.md: server racks and GPU monoliths), a far background layer
// between the haze and the parallax columns, in view pixels like shaders/motif_mesa.gdshader: two ranges (a far
// one hazier and slower) of machines standing on the floor of the forge, one per cell. A cell holds a row of
// server racks (1U units: servers with a vent grille and blinking LEDs, drive bays with activity lights, blank
// panels, switches with port lights) or a GPU monolith (a finned heat sink glowing hotter towards the die, the
// die itself glowing white-hot and pulsing in a ring of pins, spinning fans below and a load bar). Thick power
// cables sag between neighbouring machines, a pulse of light running along them now and then. LEDs, dies and
// pulses glow in the theme's ray colour. Opaque where there is a machine, transparent elsewhere. sRGB like the haze.
shader_type canvas_item;

uniform vec3 line_color = vec3(0.92, 0.49, 0.24);
uniform vec3 haze_color = vec3(0.36, 0.15, 0.07);
uniform vec3 mid_color = vec3(0.15, 0.06, 0.04);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const vec3 METAL = vec3(78.0, 64.0, 60.0) / 255.0;
const vec3 HOT = vec3(1.0, 0.9, 0.7);
// Object kinds.
const int NONE = 0;
const int RACKS = 1;
const int GPU = 2;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

// The machine of cell `c`: (kind, left x, width, top y) in the range's pixels. `size` scales the far range down.
ivec4 machine(int c, float span, int base_y, float size, int seed) {
	float k = hash2(c, 0, seed);
	if (k < 0.18) {
		return ivec4(NONE, 0, 0, 0);
	}
	int kind = k < 0.6 ? RACKS : GPU;
	int w;
	int h;
	if (kind == RACKS) {
		int n = 1 + int(hash2(c, 1, seed) * 3.0);
		int rw = 2 * int((17.0 + hash2(c, 2, seed) * 5.0) * size);
		w = n * rw + (n - 1) * 2;
		h = int((96.0 + hash2(c, 3, seed) * 60.0) * size);
	} else {
		w = 2 * int((32.0 + hash2(c, 2, seed) * 14.0) * size);
		h = int((80.0 + hash2(c, 3, seed) * 36.0) * size);
	}
	int room = max(int(span) - w - 8, 0);
	int x0 = int(float(c) * span) + 4 + int(hash2(c, 4, seed) * float(room));
	return ivec4(kind, x0, w, base_y - h);
}

// A blinking light: on or off for steps of 1 / rate seconds, at random.
float blink(int id, int k, float rate) {
	int step = int(floor(game_time * rate + hash2(id, k, 5) * 7.0));
	return hash2(id, k * 131 + step, 17) > 0.4 ? 1.0 : 0.0;
}

// The cap on top of a machine: a lit ledge, then a shaded lip.
vec3 cap(int ly) {
	return ly == 0 ? mix(METAL, line_color, 0.45) : METAL * (ly == 1 ? 0.9 : 0.5);
}

// One rack of a row at local (lx, ly), `w` px wide; rgb and glow.
vec4 rack(int lx, int ly, int w, int id, int unit) {
	vec3 col = METAL * 0.6;
	float glow = 0.0;
	if (ly < 3) {
		col = cap(ly);
	} else if (lx < 2 || lx >= w - 2) {
		// The rails, with a screw hole per unit.
		col = METAL * ((ly - 3) % unit == 2 && lx == (lx < 2 ? 1 : w - 2) ? 0.3 : 0.75);
	} else {
		int k = (ly - 3) / unit;
		int r = (ly - 3) - k * unit;
		int kind = int(hash2(id, 500 + k, 3) * 5.0);
		if (r == unit - 1) {
			col = METAL * 0.28;
		} else if (kind <= 1) {
			// A server: a vent grille on the left, three LEDs on the right.
			if (lx >= 4 && lx < w / 2 + 2 && r >= 1 && r <= unit - 3 && (lx + r) % 2 == 0) {
				col = METAL * 0.36;
			}
			for (int j = 0; j < 3; j++) {
				if (lx == w - 5 - j * 3 && r == unit / 2 - 1) {
					float on = j == 0 ? 1.0 : blink(id * 7 + j, k, 2.0 + float(j) * 2.5);
					vec3 led = hash2(id + j, k, 9) < 0.25 ? HOT : line_color;
					col = on > 0.0 ? led * 1.6 : METAL * 0.3;
					glow = on;
				}
			}
		} else if (kind == 2) {
			// Drive bays: slots, each with a flickering activity light.
			int b = (lx - 3) % 5;
			if (b == 0) {
				col = METAL * 0.32;
			} else if (b == 2 && r == unit - 3) {
				float on = blink(id * 13 + (lx - 3) / 5, k, 9.0);
				col = on > 0.0 ? line_color * 1.4 : METAL * 0.35;
				glow = on * 0.8;
			} else {
				col = METAL * 0.7;
			}
		} else if (kind == 3) {
			// A blank panel with a handle.
			col = METAL * 0.52;
			if (lx >= 3 && lx <= 4 && r >= 1 && r <= unit - 3) {
				col = METAL * 0.85;
			}
		} else {
			// A switch: a row of ports, some lit.
			if (r >= 1 && r <= 2 && lx >= 4 && lx < w - 4 && (lx - 4) % 3 != 2) {
				col = METAL * 0.22;
				if (r == 1 && (lx - 4) % 3 == 0 && blink(id * 3 + lx, k, 4.0) > 0.0) {
					col = line_color * 1.3;
					glow = 0.7;
				}
			}
		}
	}
	// Lit on the left, shaded on the right.
	if (lx == 0) {
		col *= 1.3;
	} else if (lx == w - 1) {
		col *= 0.6;
	}
	return vec4(col, glow);
}

// A GPU monolith at local (lx, ly), `w` x `h` px down to its foot; rgb and glow.
vec4 gpu(int lx, int ly, int w, int h, int id) {
	vec3 col = METAL * 0.6;
	float glow = 0.0;
	float pulse = 0.78 + 0.22 * sin(game_time * 1.3 + float(id) * 2.1);
	int sink = h * 34 / 100;
	int half_die = max(w / 10, 3);
	int band = 2 * half_die + 8;
	if (ly < 3) {
		col = cap(ly);
	} else if (lx < 2 || lx >= w - 2) {
		col = METAL * 0.75;
	} else if (ly < sink) {
		// The heat sink: vertical fins, hotter towards the die below.
		float heat = pow(float(ly - 3) / float(max(sink - 3, 1)), 2.2) * pulse;
		if (lx % 3 == 1) {
			col = mix(METAL * 0.22, line_color, heat * 0.8);
			glow = heat * 0.5;
		} else {
			col = mix(METAL * 0.85, line_color * 1.1, heat * 0.5);
		}
	} else if (ly < sink + band) {
		// The die in its package, a ring of pins around it.
		int dx = abs(lx - w / 2);
		int dy = abs(ly - (sink + band / 2));
		int d = max(dx, dy);
		col = mix(mid_color, METAL, 0.35);
		if (d < half_die) {
			float e = float(d) / float(half_die);
			col = mix(HOT * 1.8, line_color * 1.3, e) * pulse;
			glow = 1.0;
		} else if (d == half_die) {
			col = line_color * 0.8 * pulse;
			glow = 0.4;
		} else if (d == half_die + 2 && (dx + dy) % 2 == 0) {
			col = line_color * 0.55;
		}
	} else {
		// Fans, a grille between them and a load bar at the foot.
		int top = sink + band + 2;
		int nf = w >= 70 ? 2 : 1;
		float rad = clamp(min(float(h - top - 8) / 2.0, float(w / nf) / 2.0 - 4.0), 4.0, 10.0);
		col = (lx + ly) % 2 == 0 ? METAL * 0.42 : METAL * 0.6;
		for (int i = 0; i < nf; i++) {
			vec2 c = vec2(float(w * (2 * i + 1)) / float(2 * nf), float(top) + rad + 1.0);
			vec2 v = vec2(float(lx), float(ly)) + 0.5 - c;
			float d = length(v);
			if (d <= rad) {
				if (d > rad - 1.2) {
					col = METAL * 1.05;
				} else if (d < 1.8) {
					col = METAL * 1.2;
				} else {
					float spin = (i == 0 ? 1.0 : -1.0) * 0.7;
					float b = fract(atan(v.y, v.x) / TAU * 5.0 + game_time * spin);
					// Between the blades the hot inside shows.
					col = b < 0.45 ? METAL * 0.82 : mix(METAL * 0.18, line_color * 0.6, 0.35 * pulse);
				}
			}
		}
		if (ly == h - 4 && lx >= 4 && lx < w - 4) {
			float load = 0.55 + 0.4 * sin(game_time * 0.9 + float(id));
			bool lit = float(lx - 4) < load * float(w - 8) && (lx - 4) % 3 != 2;
			col = lit ? line_color * 1.4 : METAL * 0.3;
			glow = lit ? 0.8 : 0.0;
		} else if (ly == h - 5 || ly == h - 3) {
			col = METAL * 0.3;
		}
	}
	if (lx == 0) {
		col *= 1.3;
	} else if (lx == w - 1) {
		col *= 0.6;
	}
	return vec4(col, glow);
}

// A power cable from the right side of machine `a` to the left side of `b`, if they have one: sagging, 3 px
// thick (lit on top), a pulse of light running along it now and then. rgb and glow, alpha -1 off the cable.
vec4 cable(ivec4 a, ivec4 b, int ca, int qx, int y, int seed) {
	if (a.x == NONE || b.x == NONE) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	int xa = a.y + a.z;
	int xb = b.y;
	if (qx < xa || qx >= xb || xb - xa < 6) {
		return vec4(0.0, 0.0, 0.0, -1.0);
	}
	for (int k = 0; k < 2; k++) {
		if (k == 1 && hash2(ca, 700, seed) < 0.5) {
			break;
		}
		float ya = float(a.w + 8 + int(hash2(ca, 710 + k, seed) * 24.0));
		float yb = float(b.w + 8 + int(hash2(ca, 720 + k, seed) * 24.0));
		float len = float(xb - xa);
		float t = (float(qx - xa) + 0.5) / len;
		float sag = 4.0 + len * (0.08 + 0.1 * hash2(ca, 730 + k, seed));
		int cy = int(round(mix(ya, yb, t) + sag * 4.0 * t * (1.0 - t)));
		// Thicker where it is steep, so it never breaks into dots.
		float slope = abs((yb - ya) / len + sag * 4.0 * (1.0 - 2.0 * t) / len);
		int d = y - cy;
		int lo = -1 - int(slope * 0.5);
		if (d >= lo && d <= 1) {
			vec3 col = METAL * (d == lo ? 0.75 : d == 1 ? 0.22 : 0.42);
			float glow = 0.0;
			float tp = fract(game_time * 0.11 + hash2(ca, 740 + k, seed));
			float dp = abs(t - tp) * len;
			if (tp < 0.8 && dp < 4.0) {
				float g = 1.0 - dp / 4.0;
				col = mix(col, line_color * 1.5, g);
				glow = g;
			}
			return vec4(col, glow);
		}
	}
	return vec4(0.0, 0.0, 0.0, -1.0);
}

// One range of machines at view pixel `px`: rgb and 1 where there is one, else 0 alpha. `base` is the view row
// where they stand (they go on below it), `fog` how far into the haze they are, `size` their scale.
vec4 range(vec2 px, float h, float factor, float span, float base, float fog, float size, int seed) {
	int qx = int(px.x + floor(scroll.x * factor));
	int y = int(px.y);
	int base_y = int(h * base);
	int cell = int(floor(float(qx) / span));
	int unit = size < 0.9 ? 5 : 6;
	ivec4 m[3];
	for (int i = 0; i < 3; i++) {
		m[i] = machine(cell - 1 + i, span, base_y, size, seed);
	}
	vec4 hit = vec4(0.0, 0.0, 0.0, -1.0);
	int top = 0;
	for (int i = 0; i < 3; i++) {
		ivec4 o = m[i];
		int lx = qx - o.y;
		if (o.x == NONE || lx < 0 || lx >= o.z || y < o.w) {
			continue;
		}
		int ly = y - o.w;
		int c = cell - 1 + i;
		if (o.x == RACKS) {
			int n = 1 + int(hash2(c, 1, seed) * 3.0);
			int rw = (o.z - (n - 1) * 2) / n;
			int ri = lx / (rw + 2);
			int rx = lx - ri * (rw + 2);
			// Racks of a row differ a little in height.
			int drop = unit * int(hash2(c, 20 + ri, seed) * 3.0);
			if (rx >= rw || ly < drop) {
				continue;
			}
			hit = rack(rx, ly - drop, rw, c * 5 + ri + seed * 17, unit);
		} else {
			hit = gpu(lx, ly, o.z, base_y - o.w, c + seed * 17);
		}
		top = o.w;
		break;
	}
	if (hit.a < 0.0) {
		hit = cable(m[0], m[1], cell - 1, qx, y, seed);
		if (hit.a < 0.0) {
			hit = cable(m[1], m[2], cell, qx, y, seed);
		}
		top = base_y - 40;
	}
	if (hit.a < 0.0) {
		return vec4(0.0);
	}
	// Hazier lower down; below their foot (into pits) they sink into the haze fast. Glowing parts less.
	float f = fog + float(max(y - top, 0)) / float(max(base_y - top, 1)) * 0.15 + max(0.0, float(y - base_y) / 48.0);
	f = clamp(f, 0.0, 0.95) * (1.0 - hit.a * 0.5);
	return vec4(mix(hit.rgb, haze_color, f), 1.0);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	vec4 near = range(px, size.y, 0.13, 230.0, 0.7, 0.1, 1.0, 71);
	vec4 far = range(px, size.y, 0.07, 170.0, 0.64, 0.4, 0.72, 73);
	vec4 c = near.a > 0.0 ? near : far;
	COLOR = vec4(c.rgb * strength, c.a);
}
