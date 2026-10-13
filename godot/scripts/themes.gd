class_name Themes

## Colour palette of each level theme (`theme` in levels/index.json) for the background: the haze gradient
## (top -> mid -> haze at the horizon) and its light rays in shaders/haze.gdshader, and the light colour of
## the towers in shaders/scenery.gdshader, which also fade into `haze` with depth. The level blocks keep
## their black / white / orange look in every theme. Colours are sRGB.

const PALETTES := {
	# Dusk violet over the first plains.
	"plains": {"top": Color8(12, 11, 18), "mid": Color8(30, 28, 54), "haze": Color8(66, 62, 108), "ray": Color8(150, 140, 210), "light": Color8(150, 150, 214)},
	# Deep blue cave light.
	"caves": {"top": Color8(5, 8, 12), "mid": Color8(9, 24, 44), "haze": Color8(18, 46, 82), "ray": Color8(80, 150, 220), "light": Color8(80, 140, 210)},
	"window": {"top": Color8(10, 8, 14), "mid": Color8(26, 17, 42), "haze": Color8(54, 34, 84), "ray": Color8(140, 104, 200), "light": Color8(156, 122, 214)},
	"boss": {"top": Color8(10, 5, 8), "mid": Color8(34, 10, 24), "haze": Color8(72, 22, 50), "ray": Color8(196, 74, 124), "light": Color8(204, 96, 146)},
	# Warm red-brown dusk.
	"mesa": {"top": Color8(14, 10, 14), "mid": Color8(42, 24, 34), "haze": Color8(96, 54, 58), "ray": Color8(224, 146, 112), "light": Color8(206, 136, 112)},
	"forge": {"top": Color8(12, 8, 7), "mid": Color8(38, 16, 10), "haze": Color8(92, 38, 18), "ray": Color8(234, 124, 62), "light": Color8(224, 116, 64)},
	# Murky olive green.
	"swamp": {"top": Color8(7, 10, 8), "mid": Color8(20, 28, 16), "haze": Color8(46, 58, 28), "ray": Color8(172, 192, 102), "light": Color8(150, 172, 84)},
	# Diff green.
	"towers": {"top": Color8(6, 10, 9), "mid": Color8(10, 28, 22), "haze": Color8(20, 60, 46), "ray": Color8(84, 194, 134), "light": Color8(92, 204, 144)},
	"codex": {"top": Color8(5, 7, 9), "mid": Color8(8, 22, 28), "haze": Color8(16, 48, 58), "ray": Color8(95, 208, 216), "light": Color8(95, 208, 216)},
	# World 3. Turquoise dawn under the endpoint canopy.
	"canopy": {"top": Color8(6, 12, 13), "mid": Color8(14, 40, 42), "haze": Color8(34, 86, 88), "ray": Color8(140, 230, 210), "light": Color8(120, 220, 196)},
	# Cold blue-grey wind on the cliffs.
	"cliffs": {"top": Color8(8, 10, 16), "mid": Color8(22, 30, 50), "haze": Color8(54, 72, 106), "ray": Color8(176, 200, 238), "light": Color8(156, 184, 232)},
	# Warm sand light over the sandbox.
	"sandbox": {"top": Color8(14, 12, 8), "mid": Color8(44, 36, 22), "haze": Color8(104, 86, 52), "ray": Color8(236, 204, 140), "light": Color8(226, 196, 130)},
	# Deep plum, clock-face pink.
	"ravine": {"top": Color8(9, 6, 12), "mid": Color8(32, 14, 36), "haze": Color8(72, 30, 72), "ray": Color8(224, 122, 192), "light": Color8(216, 112, 174)},
	# Night-blue network glow.
	"router": {"top": Color8(4, 5, 12), "mid": Color8(12, 16, 42), "haze": Color8(26, 40, 98), "ray": Color8(124, 172, 255), "light": Color8(120, 164, 250)},
}


static func palette(theme: String) -> Dictionary:
	return PALETTES.get(theme, PALETTES.plains)


## Colour as a vec3 uniform value (the shaders take sRGB vec3s, not source_color).
static func vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
