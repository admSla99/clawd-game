// See-through windows in the foreground (Main._update_reveal()): geometry in front of the gameplay plane
// (world z > REVEAL_FRONT: ferns, stumps, hanging cables, front tufts, vines and flowers) is thinned out
// with an ordered dither in a circle around Clawd and the nearest enemies and tokens, so they never hide
// behind it. Each `reveal[i]` is (x, y, inner radius, outer radius) in SubViewport pixels (outer radius 0 =
// unused); inside the inner radius a quarter of the pixels stay, beyond the outer one all of them. Main sets
// it on the materials that draw the foreground (Voxel.MATERIAL, Scenery.foreground_material()).
uniform vec4 reveal[6];

const float REVEAL_FRONT = 0.5;
const float REVEAL_BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float reveal_keep(vec4 r, vec2 px) {
	if (r.w <= 0.0) {
		return 1.0;
	}
	return 0.25 + 0.75 * smoothstep(r.z, r.w, distance(px, r.xy));
}

// True when this fragment (world z `wz`, at `uv` on a `size`-pixel view, fragment `frag`) is dithered away.
bool revealed(float wz, vec2 uv, vec2 size, vec2 frag) {
	if (wz <= REVEAL_FRONT) {
		return false;
	}
	vec2 px = uv * size;
	float keep = 1.0;
	for (int i = 0; i < 6; i++) {
		keep = min(keep, reveal_keep(reveal[i], px));
	}
	ivec2 f = ivec2(floor(frag));
	float threshold = (REVEAL_BAYER[(f.y & 3) * 4 + (f.x & 3)] + 0.5) / 16.0;
	return threshold >= keep;
}
