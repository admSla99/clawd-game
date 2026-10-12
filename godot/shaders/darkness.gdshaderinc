// Darkness of the dark levels (`dark` in levels/index.json: 1-2), the 3D take on drawDarkness() in
// src/scenes/game.ts. Main sets two global shader parameters (project.godot [shader_globals]): `dark_amount`
// (0 in lit levels, 0.93 in dark ones, the TS gradient's darkest alpha) and `dark_lamp`, the light Clawd
// carries: its world position (in front of him) and radius in metres (105 px, breathing by 3 px). The lamp
// lights a sphere: full light inside 35 % of its radius, fading to none at its edge (the TS gradient's
// stops), measured in 3D, so the backs of blocks and everything deep in the scenery stay dark. Each
// material passes its own extra light (the terrain its GlowLights), and glowing pixels skip this, so
// lanterns, sparks, checkpoints and the scenery's nodes shine in the dark. The light is quantized in
// quarter steps with an ordered dither on a world-fixed pixel grid, like the terrain's lights.
global uniform float dark_amount;
global uniform vec4 dark_lamp;

const vec3 DARK_COLOR = vec3(8.0 / 255.0);
const float DARK_BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float lamp_light(vec3 p) {
	float d = distance(p, dark_lamp.xyz);
	return 1.0 - clamp((d - dark_lamp.w * 0.35) / (dark_lamp.w * 0.65), 0.0, 1.0);
}

// How far a pixel at world point `p` sinks towards DARK_COLOR (0 .. dark_amount) where neither the lamp nor
// `extra` (0..1) lights it; `px` is a pixel position fixed to the world (or the object) for the dither.
float darkness_at(vec3 p, float extra, ivec2 px) {
	if (dark_amount <= 0.0) {
		return 0.0;
	}
	float l = max(lamp_light(p), clamp(extra, 0.0, 1.0));
	float dither = (DARK_BAYER[(px.y & 3) * 4 + (px.x & 3)] + 0.5) / 16.0 - 0.5;
	l = clamp(floor(l * 4.0 + dither + 0.5) / 4.0, 0.0, 1.0);
	return dark_amount * (1.0 - l);
}

// `col` in sRGB, darkened (darkness_at()).
vec3 apply_darkness(vec3 col, vec3 p, float extra, ivec2 px) {
	return mix(col, DARK_COLOR, darkness_at(p, extra, px));
}
