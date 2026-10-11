shader_type canvas_item;

// Scanlines + vignette over the whole screen, like Renderer.postFx() in src/render/renderer.ts.
// Works in window pixels (FRAGCOORD): one scanline per world row, the band in the bottom third of
// each `step`-pixel period, then a radial darkening towards the corners.
uniform float view_scale = 3.0;

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	float step_px = max(2.0, view_scale);
	float band = max(1.0, floor(step_px / 3.0));
	float row = mod(floor(FRAGCOORD.y), step_px);
	float scan = row >= step_px - band ? 0.13 : 0.0;

	float r0 = min(size.x, size.y) * 0.35;
	float r1 = max(size.x, size.y) * 0.75;
	float vig = clamp((distance(FRAGCOORD.xy, size / 2.0) - r0) / (r1 - r0), 0.0, 1.0) * 0.45;

	// Two black layers composited source-over: scanlines, then the vignette on top.
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - (1.0 - scan) * (1.0 - vig));
}
