// The caves' scenery motif (docs/scenery-themes.md: the loss landscape, inverted), a far background layer
// between the haze and the parallax ridges, in view pixels like shaders/haze.gdshader: we stand at the bottom
// of a valley of the loss landscape. Its walls rise above and below a meandering valley floor and are drawn as
// 1 px contour lines (every fourth an index line, brighter) where the height crosses a step, faint far from the
// floor. Balls of light roll along the floor, one per BALL_SPAN px of the layer, doing gradient descent: each
// is a small glowing ball with a dithered halo that lights the contour lines around it. The layer scrolls at
// a tenth of the camera's speed. Additive, so it only ever brightens; `strength` is lower in the dark caves.
shader_type canvas_item;
render_mode blend_add;

uniform vec3 line_color = vec3(0.31, 0.55, 0.86);
uniform vec2 scroll = vec2(0.0);
uniform float game_time = 0.0;
uniform float strength = 1.0;

const float FACTOR = 0.1;
const float BALL_SPAN = 420.0;
const float BALL_SPEED = 13.0;
const float BALL_LIGHT = 90.0;
const float BAYER[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// The valley floor's view row at layer x.
float floor_y(float x, float h) {
	return h * 0.62 + 24.0 * sin(x * 0.0045) + 9.0 * sin(x * 0.013 + 1.7);
}

// Height of the landscape at layer point (x, view row y): rising away from the floor, with bumps.
float height(vec2 q, float h) {
	float d = abs(q.y - floor_y(q.x, h));
	return d * 0.03 + (noise(q * 0.011) * 1.1 + noise(q * 0.027 + 7.3) * 0.45);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy);
	float dither = (BAYER[int(mod(px.y, 4.0)) * 4 + int(mod(px.x, 4.0))] + 0.5) / 16.0;
	vec2 q = vec2(px.x + floor(scroll.x * FACTOR), px.y);
	float h = size.y;

	// Contour lines: the step index changes towards the right or the lower neighbour.
	const float STEPS = 2.2;
	float b0 = floor(height(q, h) * STEPS);
	float b1 = floor(height(q + vec2(1.0, 0.0), h) * STEPS);
	float b2 = floor(height(q + vec2(0.0, 1.0), h) * STEPS);
	float line = 0.0;
	if (b0 != b1 || b0 != b2) {
		float band = max(b0, max(b1, b2));
		line = mod(band, 4.0) == 0.0 ? 1.0 : 0.55;
	}
	float wall = exp(-abs(q.y - floor_y(q.x, h)) / 200.0);

	// Balls rolling along the floor (this cell's and its neighbours', for the halos at the cell edges).
	float lightv = 0.0;
	float ball = 0.0;
	float cell = floor(q.x / BALL_SPAN);
	for (int k = -1; k <= 1; k++) {
		float c = cell + float(k);
		float bx = (c + fract(hash(vec2(c, 3.0)) + game_time * BALL_SPEED / BALL_SPAN)) * BALL_SPAN;
		vec2 b = vec2(bx, floor_y(bx, h) - 3.0);
		float d = distance(q, b);
		lightv = max(lightv, 1.0 - smoothstep(10.0, BALL_LIGHT, d));
		ball = max(ball, d < 2.5 ? 2.0 : d < 3.6 ? 1.0 : d < 12.0 ? (1.0 - d / 12.0) * 0.35 : 0.0);
	}

	float l = line * (0.28 * wall + 0.8 * lightv);
	l = floor(l * 5.0 + dither) / 5.0;
	vec3 col = line_color * l;
	if (ball >= 2.0) {
		col = mix(line_color, vec3(1.0), 0.75);
	} else if (ball >= 1.0) {
		col = line_color;
	} else {
		col += line_color * floor(ball * 4.0 + dither) / 4.0;
	}
	COLOR = vec4(col * strength, 1.0);
}
