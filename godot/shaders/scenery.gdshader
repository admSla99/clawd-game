// The neural forest behind the level (Scenery), by instance `kind`:
// 0 trunk   - a column of a neuron layer: dark body with vertical fibres, a lit left rim, node sockets
//             that pulse in the theme's `light_color`, and signals climbing up some fibres.
// 1 cable   - a weight between two trunks (a sagging strip, UV.x = 0..1 along it) that carries a pulse.
// 2 neuron  - a floating node: a rim around a core that pulses.
// With `silhouette` (the foreground layer) trunks are flat dark cutouts with a jagged broken top and cables
// are dark. Every lit tone is the body mixed towards `light_color` (see Themes); the layer is mixed into
// the haze by `haze_amount`. Pixels are box-local (instance `box_size`), so patterns sit on the box wherever
// it is; top faces are bands of view rows like the level blocks. Colours are sRGB, converted at the end.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/oblique.gdshaderinc"

instance uniform vec3 box_size = vec3(1.0);
instance uniform float seed = 0.0;
instance uniform float kind = 0.0;
uniform vec3 haze = vec3(0.118, 0.176, 0.302);
uniform vec3 light_color = vec3(0.435, 0.561, 0.769);
uniform float haze_amount = 0.3;
uniform bool silhouette = false;
uniform float row_z = 0.1875;
uniform float game_time = 0.0;

varying vec3 lpos;
varying vec3 lnormal;
varying float along;

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
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * oblique_world(w, INV_VIEW_MATRIX, box_size.z * 0.5 - VERTEX.z));
	lpos = VERTEX;
	lnormal = NORMAL;
	along = UV.x;
}

void fragment() {
	vec3 col = BODY * 0.5;
	float boost = 1.0;
	int sd = int(seed);
	int k = int(round(kind));
	ivec2 p = ivec2(floor(vec2(lpos.x + box_size.x * 0.5, box_size.y * 0.5 - lpos.y) * 16.0));
	ivec2 sz = ivec2(round(box_size.xy * 16.0));
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
	col = mix(col, haze, haze_amount);
	ALBEDO = pow(col, vec3(2.2)) * boost;
}
