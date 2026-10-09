shader_type canvas_item;
render_mode blend_add;

// Second half of drawDarkness(): orange glows (radius 26, alpha 0.35 at the centre) added with
// 'lighter' on sparks, the goal and active checkpoints, so they shine through the dark.
uniform vec2 view_size = vec2(480.0, 270.0);
uniform int glow_count = 0;
uniform vec2 glows[32];
uniform vec3 glow_color : source_color = vec3(0.851, 0.4667, 0.3412); // #D97757

void fragment() {
	vec2 p = UV * view_size;
	float k = 0.0;
	for (int i = 0; i < glow_count; i++) {
		k += clamp(1.0 - distance(p, glows[i]) / 26.0, 0.0, 1.0) * 0.35;
	}
	COLOR = vec4(glow_color * k, 1.0);
}
