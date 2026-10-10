// Level blocks as modern pixel art. The camera is orthographic and one level pixel is one view pixel,
// so front faces are drawn per level pixel: a black body that steps darker away from open air, a white /
// light-grey crust on exposed tops, dark rims on exposed sides, faint panel seams and orange circuit
// traces with blinking nodes. `cells_tex` comes from Level.bake_cells(), one texel per 4 px cell:
// R = distance to open air / 12, G = random, B = 1 when the cell above is open, A = 1 for solid or
// corrupted cells. Top faces are bands of view rows (row_z metres of depth per row, see GameCamera) from
// the white front lip to dark speckled grey at the back. Orange lights (Main collects nodes in group
// "lights") light the pixels around them in four steps, dithered where the steps meet; on block fronts
// only the crust near open air takes light, it does not shine into the body. `shadows` (x, floor y, height above it in
// tiles, radius) put blob shadows on the floor under Clawd and the enemies (Level.set_shadows()). `game_time` is Game.time, so hitstop and pause freeze
// the animation. Colours are written in sRGB and converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"

const int MAX_LIGHTS = 32;

uniform sampler2D cells_tex : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(1.0);
uniform int mode = 0; // 0 solid, 1 one-way, 2 corrupted, 3 spikes
uniform float half_depth = 1.5;
uniform float row_z = 0.1875;
const int MAX_SHADOWS = 16;
uniform vec4 shadows[MAX_SHADOWS];
uniform int shadow_count = 0;
uniform float game_time = 0.0;
// The theme's light colour (Themes): side faces catch a little of it, so they read apart from the black
// block fronts.
uniform vec3 ambient = vec3(0.59, 0.59, 0.84);
uniform vec4 lights[MAX_LIGHTS];
uniform float light_energy[MAX_LIGHTS];
uniform int light_count = 0;

const vec3 BLACK = vec3(11.0, 11.0, 13.0) / 255.0;
const vec3 BODY_1 = vec3(24.0, 24.0, 28.0) / 255.0;
const vec3 BODY_2 = vec3(18.0, 18.0, 21.0) / 255.0;
const vec3 SEAM = vec3(21.0, 21.0, 25.0) / 255.0;
const vec3 GREY_1 = vec3(30.0, 30.0, 35.0) / 255.0;
const vec3 GREY_2 = vec3(44.0, 44.0, 51.0) / 255.0;
const vec3 GREY_3 = vec3(62.0, 61.0, 68.0) / 255.0;
const vec3 GREY_4 = vec3(110.0, 108.0, 103.0) / 255.0;
const vec3 GREY_5 = vec3(171.0, 167.0, 159.0) / 255.0;
const vec3 WHITE = vec3(242.0, 239.0, 233.0) / 255.0;
const vec3 ORANGE = vec3(217.0, 119.0, 87.0) / 255.0;
const vec3 ORANGE_LIGHT = vec3(240.0, 165.0, 133.0) / 255.0;
const vec3 ORANGE_DARK = vec3(122.0, 61.0, 41.0) / 255.0;
const vec3 CORRUPT_BODY = vec3(20.0, 12.0, 11.0) / 255.0;

varying vec3 wpos;
varying vec3 wnormal;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int seed) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(seed) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

vec4 cell_at(ivec2 c) {
	return texelFetch(cells_tex, clamp(c, ivec2(0), ivec2(cells) - 1), 0);
}

// Solid or corrupted; outside the level the sides and the bottom count as solid, the top as open.
bool blocky(ivec2 c) {
	if (c.y < 0) {
		return false;
	}
	if (c.x < 0 || c.x >= int(cells.x) || c.y >= int(cells.y)) {
		return true;
	}
	return cell_at(c).a > 0.5;
}

const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

// Sum of the lights at p, in steps of a quarter; `px` (view-aligned pixel) picks the ordered-dither
// threshold, so each step blends into the next over a few pixels instead of a hard ring.
float light_level(vec3 p, ivec2 px) {
	float l = 0.0;
	for (int k = 0; k < light_count; k++) {
		l += light_energy[k] * max(0.0, 1.0 - distance(p, lights[k].xyz) / lights[k].w);
	}
	float dither = (BAYER[(px.y & 3) * 4 + (px.x & 3)] + 0.5) / 16.0 - 0.5;
	return clamp(floor(clamp(l, 0.0, 1.0) * 4.0 + dither + 0.5) / 4.0, 0.0, 1.0);
}

vec3 lit(vec3 c, float lv) {
	return c + (c * vec3(0.55, 0.22, 0.05) + ORANGE * 0.12) * lv;
}

void vertex() {
	POSITION = oblique_position(MODEL_MATRIX, VIEW_MATRIX, INV_VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = BLACK;
	float boost = 1.0;
	vec3 lp = wpos;
	ivec2 lpx = ivec2(0); // pixel for the light dither
	float occl = 1.0; // share of the light that reaches this pixel
	// Spikes and one-way platforms are see-through outside their pixels.
	if (mode == 3 && wnormal.z < 0.5) {
		discard;
	}
	if (wnormal.z > 0.5) {
		ivec2 ip = ivec2(floor(vec2(wpos.x, -wpos.y) * 16.0)); // level pixel
		ivec2 c = ip >> ivec2(2);	// 4 px cell
		ivec2 p = ip & ivec2(3);	// pixel in the cell
		ivec2 t = ip >> ivec2(4);	// tile
		ivec2 q = ip & ivec2(15);	// pixel in the tile
		lp = vec3((vec2(ip) + 0.5) / 16.0 * vec2(1.0, -1.0), wpos.z);
		lpx = ip;
		if (mode == 0) {
			vec4 C = cell_at(c);
			int d = int(round(C.r * 12.0));
			// Light lands on the crust; it fades out within three cells of open air.
			occl = d <= 1 ? 1.0 : d == 2 ? 0.5 : d == 3 ? 0.2 : 0.0;
			col = d <= 1 ? BODY_1 : d == 2 ? BODY_2 : BLACK;
			if (d >= 2 && (q.x == 0 || q.y == 0) && hash2(t.x, t.y, 9) > 0.4) {
				col = SEAM;
			}
			if (hash2(ip.x, ip.y, 3) > 0.985) {
				col = GREY_1;
			}
			// Orange circuit: a trace with an optional leg down, a dim node at the leg's end and a
			// blinking node at the trace's end.
			if (d >= 2 && hash2(t.x, t.y, 31) > 0.55) {
				int r = 4 + int(hash2(t.x, t.y, 32) * 8.0);
				int a = 1 + int(hash2(t.x, t.y, 33) * 5.0);
				int b = min(14, a + 4 + int(hash2(t.x, t.y, 34) * 7.0));
				int leg = hash2(t.x, t.y, 35) > 0.5 ? min(15, r + 3) : r;
				if ((q.y == r && q.x >= a && q.x <= b) || (q.x == a && q.y > r && q.y <= leg)) {
					col = ORANGE_DARK;
				}
				if (leg > r && q == ivec2(a, leg)) {
					col = ORANGE;
				}
				if (q == ivec2(b, r)) {
					float h = hash2(t.x, t.y, 36);
					bool on = sin(game_time * (1.0 + h * 3.0) + h * 50.0) > -0.2;
					col = on ? ORANGE_LIGHT : ORANGE;
					boost = on ? 1.8 : 1.0;
				}
			}
			// Rims where the block meets open air.
			if (!blocky(c + ivec2(-1, 0)) && p.x == 0) {
				col = GREY_2;
			}
			if (!blocky(c + ivec2(1, 0)) && p.x == 3) {
				col = GREY_1;
			}
			if (!blocky(c + ivec2(0, 1)) && p.y == 3) {
				col = GREY_1;
			}
			// Crust on exposed tops, 2-4 px thick per column, with sparkles (drawShimmer).
			if (C.b > 0.5) {
				int th = 2 + int(hash2(ip.x >> 1, t.y, 11) > 0.5) + int(hash2(ip.x, t.y, 12) > 0.8);
				if (p.y == 0) {
					col = hash2(ip.x, t.y, 13) > 0.88 ? GREY_5 : WHITE;
				} else if (p.y == 1) {
					col = hash2(ip.x, t.y, 14) > 0.55 ? WHITE : GREY_5;
				} else if (p.y < th) {
					col = GREY_4;
				} else if (p.y == th) {
					col = GREY_3;
				}
				if (p.y <= 1 && hash2(ip.x, t.y, int(floor(game_time * 6.0))) > 0.988) {
					col = ORANGE_LIGHT;
					boost = 2.0;
				}
			}
		} else if (mode == 1) {
			// One-way platform: four rows of crust with orange LEDs.
			if (q.y == 0) {
				col = WHITE;
			} else if (q.y == 1) {
				col = GREY_5;
			} else if (q.y == 2) {
				col = (ip.x & 7) == 3 ? ORANGE_LIGHT : GREY_3;
				boost = (ip.x & 7) == 3 ? 1.6 : 1.0;
			} else if (q.y == 3) {
				col = GREY_1;
			} else {
				discard;
			}
		} else if (mode == 3) {
			// Spikes: two 8 px triangles per tile, light tips.
			int lx = q.x & 7;
			int k = 15 - q.y;
			float half_w = (8.0 - float(k)) * 0.5;
			if (k > 7 || abs(float(lx) - 3.5) > half_w - 0.5) {
				discard;
			}
			col = k >= 5 ? ORANGE_LIGHT : k >= 2 ? (lx < 4 ? ORANGE : ORANGE * 0.8) : ORANGE_DARK;
			boost = k >= 5 ? 1.6 : 1.0;
		} else {
			// Corrupted data: orange checker cells, flickering bars, rows that jump sideways and a glitch
			// scanline, re-rolled 12 times a second (drawCorrupted in src/render/dotRenderer.ts).
			int fr = int(floor(game_time * 12.0));
			int jx = hash2(ip.y, t.x, fr) > 0.9 ? int(hash2(ip.y, fr, 7) * 5.0) - 2 : 0;
			ivec2 jp = ip + ivec2(jx, 0);
			ivec2 jc = jp >> ivec2(2);
			ivec2 jq = jp & ivec2(3);
			ivec2 ji = jc & ivec2(3);
			bool edge = ji.x == 0 || ji.y == 0 || ji.x == 3 || ji.y == 3;
			col = CORRUPT_BODY;
			float r = hash2(jc.x, jc.y, fr);
			if ((ji.x + ji.y) % 2 == 0 && jq.x >= 1 && jq.x <= 2 && jq.y >= 1 && jq.y <= 2) {
				col = edge ? ORANGE : ORANGE_DARK;
			} else if (r > 0.82 && jq.y == 1) {
				col = r > 0.95 ? WHITE : ORANGE_LIGHT;
				boost = 1.6;
			}
			if (hash2(t.x, t.y, fr) > 0.8 && q.y == int(hash2(t.y, t.x, fr) * 16.0)) {
				col = mix(col, ORANGE_LIGHT, 0.7);
				boost = 1.5;
			}
		}
	} else if (wnormal.y > 0.5) {
		int ix = int(floor(wpos.x * 16.0));
		int ty = int(round(-wpos.y));
		int row = int(floor((half_depth - wpos.z) / row_z)); // 0 = front lip
		lp = vec3((float(ix) + 0.5) / 16.0, wpos.y, half_depth - (float(row) + 0.5) * row_z);
		lpx = ivec2(ix, row);
		bool exposed = mode == 1 || cell_at(ivec2(ix >> 2, ty * 4)).b > 0.5;
		float s = hash2(ix, row, 21 + ty);
		if (!exposed) {
			col = BLACK;
		} else if (mode == 2) {
			int fr = int(floor(game_time * 12.0));
			col = row == 0 ? ORANGE : row <= 2 ? ORANGE_DARK : CORRUPT_BODY;
			if (row > 2 && hash2(ix, row, fr) > 0.92) {
				col = ORANGE;
			}
		} else {
			col = row == 0 ? WHITE : row == 1 ? GREY_5 : row <= 3 ? GREY_4 : row <= 7 ? GREY_3 : GREY_2;
			if (row >= 2 && s > 0.9) {
				col = row <= 3 ? GREY_5 : GREY_4;
			}
			if (row >= 4 && s < 0.06) {
				col = GREY_1;
			}
		}
		// Blob shadows, two steps, shrinking with the caster's height above this floor; overlapping
		// shadows keep the darker step instead of stacking.
		float dark = 0.0;
		for (int k = 0; k < shadow_count; k++) {
			vec4 sh = shadows[k];
			if (abs(wpos.y - sh.y) < 0.01) {
				float rad = max(0.0, sh.w - sh.z * 0.06);
				vec2 e = vec2(lp.x - sh.x, lp.z * 0.45) / max(rad, 1e-3);
				float d2 = dot(e, e);
				if (d2 < 1.0) {
					dark = max(dark, d2 < 0.45 ? 0.8 : 0.55);
				}
			}
		}
		col = mix(col, BLACK, dark);
	} else if (abs(wnormal.x) > 0.5) {
		// Side faces, opened by the perspective off the view centre: the crust wraps over the top edge,
		// a lit rim at the front, rock strata that darken towards the back, now and then a circuit spark.
		int iy = int(floor(-wpos.y * 16.0)); // level pixel row
		int qy = iy & 15;
		int drow = int(floor((half_depth - wpos.z) / row_z)); // 0 = front edge
		float back = clamp((half_depth - wpos.z) / (2.0 * half_depth), 0.0, 1.0);
		float px = wpos.x * 16.0;
		ivec2 own = ivec2(int(floor((px - wnormal.x * 0.5) / 4.0)), iy >> 2);
		ivec2 beside = ivec2(int(floor((px + wnormal.x * 0.5) / 4.0)), iy >> 2);
		lpx = ivec2(drow, iy);
		if (mode == 3 || (mode != 1 && blocky(beside))) {
			col = BLACK;
		} else if (mode == 1) {
			col = qy == 0 ? GREY_4 : qy == 1 ? GREY_3 : GREY_1;
		} else if (mode == 2) {
			int fr = int(floor(game_time * 12.0));
			col = drow == 0 ? ORANGE_DARK : CORRUPT_BODY;
			if (hash2(drow, iy, fr) > 0.9) {
				col = ORANGE;
			}
		} else {
			bool top = cell_at(own).b > 0.5 && (iy & 3) == qy;
			float s = hash2(drow, iy, 41);
			col = back < 0.34 ? GREY_1 : back < 0.67 ? BODY_1 : BODY_2;
			if ((iy & 3) == 0 && s > 0.6) {
				col = SEAM;
			}
			// Ambient light from the theme, strongest at the front edge, in three steps.
			col = mix(col, ambient, back < 0.34 ? 0.16 : back < 0.67 ? 0.09 : 0.04);
			if (drow == 0) {
				col = mix(GREY_2, ambient, 0.3);
			}
			if (top && qy < 3) {
				col = qy == 0 ? GREY_5 : qy == 1 ? GREY_4 : GREY_3;
				if (back > 0.6) {
					col = GREY_2;
				}
			}
			if (s > 0.992 && !(top && qy < 3)) {
				col = ORANGE_DARK;
			}
		}
	}
	col = lit(col, occl > 0.0 ? light_level(lp, lpx) * occl : 0.0);
	ALBEDO = pow(clamp(col, 0.0, 1.0), vec3(2.2)) * boost;
}
