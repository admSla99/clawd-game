// Depth fog, per pixel. A point `behind` metres behind the gameplay plane fades towards the sky colour of
// its view row (the gradient of shaders/haze.gdshader: `fog_top` -> `fog_mid` -> `fog_haze` at the
// horizon, Themes palette), so distant things dissolve into the sky behind them instead of into one flat
// colour. The fog is thicker in the lower part of the view, like ground mist. Colours are sRGB.
uniform vec3 fog_top = vec3(0.047, 0.043, 0.071);
uniform vec3 fog_mid = vec3(0.118, 0.11, 0.212);
uniform vec3 fog_haze = vec3(0.259, 0.243, 0.424);

const float FOG_HORIZON = 0.8;
const float FOG_DENSITY = 0.06;

vec3 fog_color(float v) {
	float lv = clamp(v / FOG_HORIZON, 0.0, 1.0);
	return lv < 0.5 ? mix(fog_top, fog_mid, lv * 2.0) : mix(fog_mid, fog_haze, lv * 2.0 - 1.0);
}

float fog_amount(float behind, float v) {
	return 1.0 - exp(-max(behind, 0.0) * FOG_DENSITY * (1.0 + 0.8 * smoothstep(0.45, 1.0, v)));
}

vec3 apply_fog(vec3 col, float behind, float v) {
	return mix(col, fog_color(v), fog_amount(behind, v));
}
