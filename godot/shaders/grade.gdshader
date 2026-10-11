// Colour grade over the finished low-res view (Grade, a canvas layer above everything in the SubViewport):
// shadows lifted a little towards the theme's cool `shadow_tint`, highlights warmed towards the lanterns'
// orange, a touch more saturation. One pixel in, one pixel out, so the pixel art stays crisp.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 shadow_tint = vec3(0.26, 0.24, 0.42);
uniform vec3 highlight_tint = vec3(0.94, 0.65, 0.52);
uniform float shadow_lift = 0.07;
uniform float highlight_warmth = 0.1;
uniform float saturation = 1.12;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	// Darks pick up the theme's tint instead of going flat black.
	c += shadow_tint * shadow_lift * (1.0 - smoothstep(0.0, 0.35, l));
	// Lights lean warm.
	c = mix(c, c * (vec3(1.0) + (highlight_tint - vec3(0.5)) * 0.6), smoothstep(0.45, 0.95, l) * highlight_warmth * 4.0);
	c = mix(vec3(l), c, saturation);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
