shader_type canvas_item;

// Darkness for `dark` levels, first half of drawDarkness() in src/scenes/game.ts: a radial
// gradient around the player, clear inside 35% of the radius and rgba(8,8,8,0.93) at the radius
// and beyond. Coordinates are view units, set every frame from main.gd.
uniform vec2 player_pos;
uniform float radius = 105.0;
uniform vec2 view_size = vec2(480.0, 270.0);
// source_color: Godot converts it to the canvas colour space (linear when hdr_2d is on).
uniform vec3 shade : source_color = vec3(0.0314); // rgb(8,8,8)

void fragment() {
	vec2 p = UV * view_size;
	float t = clamp((distance(p, player_pos) - radius * 0.35) / (radius * 0.65), 0.0, 1.0);
	COLOR = vec4(shade, 0.93 * t);
}
