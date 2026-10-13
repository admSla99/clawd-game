// The neural forest behind the level (Scenery), by instance `kind`:
// 0 trunk   - a column of a neuron layer: dark body with vertical fibres, a lit left rim, node sockets
//             that pulse in the theme's `light_color`, and signals climbing up some fibres.
// 1 cable   - a weight between two trunks (a sagging strip, UV.x = 0..1 along it) that carries a pulse.
// 2 neuron  - a floating node: a rim around a core that pulses.
// 3 ledge   - a slab sticking out of a midground trunk: a lit top edge, a dark body with a seam and two
//             node lights.
// `world_perspective` (the midground) uses the level's perspective, converging from the gameplay plane,
// instead of each box converging from its own front face.
// With `silhouette` (the foreground layer) trunks are flat dark cutouts with a jagged broken top and cables
// are dark. Every lit tone is the body mixed towards `light_color` (see Themes); every pixel fades into
// the sky behind it with its depth (shaders/fog.gdshaderinc). Pixels are box-local (instance `box_size`), so patterns sit on the box wherever
// it is; top faces are bands of view rows like the level blocks. In dark levels it darkens away from Clawd's
// lamp (shaders/darkness.gdshaderinc) except where it glows. Colours are sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"
#include "res://shaders/fog.gdshaderinc"
#include "res://shaders/reveal.gdshaderinc"
#include "res://shaders/darkness.gdshaderinc"

instance uniform vec3 box_size = vec3(1.0);
instance uniform float seed = 0.0;
instance uniform float kind = 0.0;
uniform vec3 light_color = vec3(0.435, 0.561, 0.769);
uniform bool silhouette = false;
uniform bool world_perspective = false;
uniform float row_z = 0.1875;
uniform float game_time = 0.0;
// The boss theme's motif (docs/scenery-themes.md: the glitching forest): rows tear sideways with a red / cyan
// split, trunks split into two strands and rejoin, cables break off into nothing, boxes flicker red or cyan.
uniform bool glitch = false;

varying vec3 lpos;
varying vec3 lnormal;
varying float along;
varying float wz;
varying vec3 wp;

// hash2 from src/core/noise.ts (32-bit wrapping math).
float hash2(int x, int y, int s) {
	uint h = uint(x) * 374761393u + uint(y) * 668265263u + uint(s) * 2147483647u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	h ^= h >> 16u;
	return float(h) / 4294967296.0;
}

const vec3 BODY = vec3(14.0, 14.0, 17.0) / 255.0;

vec3 tone(float k) {
	return mix(BODY, light_color, k);
}

void vertex() {
	// Each box converges from its own front face, so the far layers keep their size and parallax but
	// still show their sides (cables are flat, with box_size.z = 0).
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float behind = world_perspective ? max(-w.z, 0.0) : box_size.z * 0.5 - VERTEX.z;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * oblique_world(w, INV_VIEW_MATRIX, behind));
	lpos = VERTEX;
	lnormal = NORMAL;
	along = UV.x;
	wz = w.z;
	wp = w.xyz;
}

void fragment() {
	if (revealed(wz, SCREEN_UV, VIEWPORT_SIZE, FRAGCOORD.xy)) {
		discard;
	}
	vec3 col = BODY * 0.5;
	float boost = 1.0;
	int sd = int(seed);
	int k = int(round(kind));
	ivec2 p = ivec2(floor(vec2(lpos.x + box_size.x * 0.5, box_size.y * 0.5 - lpos.y) * 16.0));
	ivec2 sz = ivec2(round(box_size.xy * 16.0));
	vec3 tear_tint = vec3(0.0);
	if (glitch) {
		int gf = int(floor(game_time * 10.0));
		// A torn 3 px row: its pattern slides sideways and takes a red or cyan cast.
		float th = hash2(p.y / 3, gf, sd + 7);
		if (th > 0.975) {
			p.x += int((hash2(p.y / 3, gf, sd + 8) - 0.5) * 14.0);
			tear_tint = hash2(p.y / 3, gf, sd + 9) > 0.5 ? vec3(0.88, 0.38, 0.35) : vec3(0.37, 0.82, 0.85);
		}
		// Trunks split into two strands over some 24 px bands, and rejoin.
		if (k == 0 && !silhouette && lnormal.z > 0.5 && sz.x >= 12 && hash2(p.y / 24, 40, sd) > 0.62) {
			int a = sz.x * 2 / 5;
			if (p.x >= a && p.x < a + max(2, sz.x / 5)) {
				discard;
			}
		}
		// Cables break off: a gap somewhere along some of them.
		if (k == 1 && hash2(sd, 50, 3) > 0.45) {
			float g0 = 0.2 + hash2(sd, 51, 3) * 0.5;
			if (along > g0 && along < g0 + 0.12 + 0.05 * sin(game_time * 3.0 + float(sd))) {
				discard;
			}
		}
	}
	if (k == 1) {
		// Cable with a pulse running along it, a short bright head and a fading tail.
		col = silhouette ? BODY * 0.4 : tone(0.16);
		float head = fract(game_time * (0.08 + hash2(sd, 1, 7) * 0.14) + hash2(sd, 2, 7));
		float d = head - along;
		if (!silhouette && d >= 0.0 && d < 0.08) {
			col = mix(light_color, tone(0.3), d / 0.08);
			boost = d < 0.02 ? 1.7 : 1.2;
		}
	} else if (silhouette) {
		// Broken trunk: a jagged top edge (the bottom is always off screen), a 1 px rim, ragged sides.
		if (lnormal.z < 0.5) {
			discard;
		}
		int cx = p.x / 5;
		float f = fract(float(p.x) / 5.0);
		float n = mix(hash2(cx, 0, sd), hash2(cx + 1, 0, sd), f * f * (3.0 - 2.0 * f));
		int edge = int(n * 10.0) + 1;
		if (hash2(p.x, 1, sd) > 0.8) {
			edge -= 1 + int(hash2(p.x, 2, sd) * 4.0);
		}
		int from_edge = min(p.y - edge, sz.y - 1 - p.y - edge);
		int side = int(hash2(p.y / 6, 3, sd) * 2.0);
		if (from_edge < 0 || p.x < side || p.x > sz.x - 1 - side) {
			discard;
		}
		col = from_edge == 0 ? tone(0.14) : (p.x % 3 == 1 ? tone(0.05) : tone(0.025));
	} else if (k == 3 && lnormal.z > 0.5) {
		// Ledge front.
		col = p.y == 0 ? tone(0.3) : p.y == 1 ? tone(0.16) : p.y == sz.y - 1 ? BODY * 0.6 : tone(0.08);
		if (p.y == 3 && (p.x % 7) == 3) {
			float h = hash2(p.x / 7, 4, sd);
			bool on = sin(game_time * (0.6 + h) + h * 20.0) > 0.0;
			col = on ? light_color : tone(0.25);
			boost = on ? 1.6 : 1.0;
		}
	} else if (k == 3 && lnormal.y > 0.5) {
		col = tone(0.22);
	} else if (k == 2) {
		// Floating neuron: rim, pulsing core, a bright centre while it fires.
		float h = hash2(sd, 3, 7);
		bool on = sin(game_time * (0.7 + h * 1.6) + h * 40.0) > 0.55;
		if (lnormal.z > 0.5) {
			bool rim = p.x == 0 || p.y == 0 || p.x == sz.x - 1 || p.y == sz.y - 1;
			bool centre = abs(float(p.x) - float(sz.x - 1) * 0.5) < 1.0 && abs(float(p.y) - float(sz.y - 1) * 0.5) < 1.0;
			col = rim ? tone(0.35) : on ? (centre ? mix(light_color, vec3(1.0), 0.6) : light_color) : tone(0.22);
			boost = on && !rim ? 1.7 : 1.0;
		} else if (lnormal.y > 0.5) {
			col = tone(0.45);
		} else {
			col = tone(0.12);
		}
	} else if (lnormal.z > 0.5) {
		// Trunk front.
		int w = sz.x;
		col = p.x % 3 == 1 ? tone(0.07) : BODY;
		if (p.x == 0) {
			col = tone(0.14);
		} else if (p.x == w - 1) {
			col = BODY * 0.6;
		} else if (p.x % 3 == 1) {
			// A signal climbing this fibre now and then: a bright head with a fading tail below it.
			int fib = p.x / 3;
			if (hash2(fib, 5, sd) > 0.55) {
				float speed = 40.0 + hash2(fib, 6, sd) * 70.0;
				float span = float(sz.y) + 120.0;
				float head = span - mod(game_time * speed + hash2(fib, 7, sd) * span, span);
				float d = float(p.y) - head;
				if (d >= 0.0 && d < 10.0) {
					col = mix(light_color, tone(0.12), d / 10.0);
					boost = d < 2.0 ? 1.5 : 1.0;
				}
			}
		}
		// Node sockets every 22-38 px down the trunk's middle.
		int band = p.y / 30;
		int ny = band * 30 + 4 + int(hash2(band, 8, sd) * 20.0);
		int nx = w / 2 - 1;
		if (p.y >= ny - 1 && p.y <= ny + 2 && p.x >= nx - 1 && p.x <= nx + 2) {
			float h = hash2(band, 9, sd);
			bool on = sin(game_time * (0.5 + h * 1.4) + h * 30.0) > 0.4;
			bool core = p.y >= ny && p.y <= ny + 1 && p.x >= nx && p.x <= nx + 1;
			col = core ? (on ? light_color : tone(0.3)) : tone(0.2);
			boost = core && on ? 1.8 : 1.0;
		}
	} else if (lnormal.y > 0.5) {
		int row = int(floor((box_size.z * 0.5 - lpos.z) / row_z));
		col = row == 0 ? tone(0.5) : row <= 2 ? tone(0.25) : tone(0.1);
	} else if (abs(lnormal.x) > 0.5) {
		// Trunk sides, opened by the perspective.
		col = int(floor((box_size.z * 0.5 - lpos.z) / row_z)) == 0 ? tone(0.1) : tone(0.04);
	}
	if (glitch) {
		if (tear_tint != vec3(0.0)) {
			col = mix(col, tear_tint, 0.45);
			boost = max(boost, 1.2);
		}
		// Now and then a whole box flickers towards red or cyan.
		float fh = hash2(sd, int(floor(game_time * 6.0)), 61);
		if (fh > 0.93) {
			col = mix(col, fh > 0.965 ? vec3(0.88, 0.38, 0.35) : vec3(0.37, 0.82, 0.85), 0.3);
		}
	}
	col = apply_fog(col, -wz, SCREEN_UV.y);
	// Dark levels: only what is near Clawd's lamp shows; the glowing nodes and pulses keep shining.
	if (boost <= 1.0) {
		col = apply_darkness(col, wp, 0.0, p);
	}
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
