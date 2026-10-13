class_name Parallax
extends Node2D

## Theme backgrounds ported from src/render/parallax.ts: baked dot ridges / factory columns that
## scroll slower than the level, plus procedural stars, data rain, code lines, rings, embers and
## fog. Lives in a CanvasLayer behind the 3D level (Environment background = canvas), so it draws in
## view coordinates.

const PERIOD := 1024
const CODE_LINES := [
	"function solve(task) {",
	"  // TODO: understand the task",
	"  return autocomplete(task);",
	"}",
	"const tests = run(); // 3 failing",
	"if (tests.fail) skip(tests);",
	"export default shipIt;",
	"while (true) { generate(); }",
	"let confidence = Infinity;",
	"import everything from \"*\";",
	"// it works on my machine",
	"try { deploy(); } catch {}",
	"git push --force origin main",
	"rm -rf node_modules && pray",
]

var theme := ""
## Each layer: {tex, factor, factor_y, anchor, inverted, modulate}.
var layers: Array[Dictionary] = []
var camera: GameCamera
## Themes palette of the level: the baked grey layers are tinted between its haze and light colours,
## the stars, data rain and rings take its light colour.
var palette: Dictionary


func setup(level_theme: String, cam: GameCamera, level_palette: Dictionary) -> void:
	theme = level_theme
	camera = cam
	palette = level_palette
	layers.clear()
	match theme:
		"plains":
			_layer(62, _bake_ridge(11, 170, 120, 30, 62, 5, false), 0.12, 0.05, 0.86)
			_layer(100, _bake_ridge(23, 130, 80, 20, 100, 4, false), 0.3, 0.12, 0.92)
		"caves":
			_layer(52, _bake_ridge(31, 120, 90, 10, 52, 5, true), 0.15, 0.08, 0.0, true)
			_layer(58, _bake_ridge(37, 110, 70, 10, 58, 5, false), 0.2, 0.08, 1.0)
			_layer(82, _bake_ridge(41, 80, 60, 6, 82, 4, true), 0.35, 0.16, 0.0, true)
		"boss":
			_layer(55, _bake_ridge(53, 100, 60, 10, 55, 5, false), 0.1, 0.0, 1.0)
		"mesa":
			_layer(60, _bake_ridge(61, 170, 130, 30, 60, 5, false, 22), 0.12, 0.05, 0.88)
			_layer(98, _bake_ridge(67, 120, 70, 20, 98, 4, false, 14), 0.3, 0.12, 0.94)
		"forge":
			_layer(58, _bake_columns(71, 200, 58, 26), 0.15, 0.05, 1.0)
			_layer(88, _bake_columns(73, 140, 88, 44), 0.32, 0.12, 1.0)
		"swamp":
			_layer(55, _bake_ridge(81, 110, 50, 20, 55, 5, false), 0.12, 0.05, 0.92)
			_layer(85, _bake_ridge(83, 70, 30, 12, 85, 4, false), 0.3, 0.12, 0.98)
		"towers":
			_layer(60, _bake_columns(91, 260, 60, 34), 0.2, 0.2, 1.0)
		# World 3: a rolling canopy, sheer cliffs, flat sandbox terraces, ravine walls from above and below, and a
		# low skyline under the router's sky.
		"canopy":
			_layer(64, _bake_ridge(101, 170, 110, 40, 64, 5, false), 0.12, 0.05, 0.84)
			_layer(96, _bake_ridge(103, 120, 70, 30, 96, 4, false), 0.3, 0.12, 0.92)
		"cliffs":
			_layer(60, _bake_columns(111, 240, 60, 60), 0.15, 0.15, 1.0)
			_layer(90, _bake_ridge(113, 140, 100, 20, 90, 4, false), 0.3, 0.2, 1.0)
		"sandbox":
			_layer(62, _bake_ridge(121, 150, 70, 30, 62, 5, false, 8), 0.12, 0.05, 0.9)
			_layer(98, _bake_ridge(123, 110, 50, 20, 98, 4, false, 6), 0.3, 0.12, 0.96)
		"ravine":
			_layer(52, _bake_ridge(131, 120, 80, 10, 52, 5, true), 0.15, 0.08, 0.0, true)
			_layer(80, _bake_ridge(133, 120, 80, 20, 80, 4, false), 0.3, 0.12, 1.0)
		"router":
			_layer(56, _bake_columns(141, 120, 56, 30), 0.12, 0.0, 1.0)
	# Far layers sit close to the haze, near ones a little towards the light, like the Scenery layers.
	for i in layers.size():
		var l: Dictionary = layers[i]
		var target: Color = palette.haze.lerp(palette.light, 0.12 + 0.12 * i)
		# The crust pixels of a layer are `bright` grey: scale them to the target, darker pixels follow.
		l.modulate = Color(target.r, target.g, target.b) * (255.0 / l.bright)
		l.modulate.a = 1.0
	queue_redraw()


## `bright` is the grey of the layer's brightest pixels (the bright argument of its bake).
func _layer(bright: float, img: Image, factor: float, factor_y: float, anchor: float, inverted := false) -> void:
	layers.append({"tex": ImageTexture.create_from_image(img), "bright": bright, "factor": factor, "factor_y": factor_y, "anchor": anchor, "inverted": inverted})


static func _gray(v: float) -> Color:
	var c := clampi(roundi(v), 0, 255)
	return Color8(c, c, c)


## Grey `v` (0..255) shifted towards the palette's light colour.
func _lit(v: float) -> Color:
	var c := _gray(v)
	return c.lerp(Color(palette.light) * (v / 170.0), 0.7)


static func _rgba(r: int, g: int, b: int, a: float) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)


## A 1x1 canvas fillRect at fractional y: browsers antialias it, so it covers two pixel rows
## with partial alpha. Composites source-over like the canvas does.
static func _dot(img: Image, x: int, y: float, c: Color) -> void:
	var y0 := floori(y)
	var f := y - y0
	for k in 2:
		var py := y0 + k
		var cover := 1.0 - f if k == 0 else f
		if cover <= 0 or py < 0 or py >= img.get_height():
			continue
		var src := Color(c.r, c.g, c.b, c.a * cover)
		var dst := img.get_pixel(x, py)
		var a := src.a + dst.a * (1 - src.a)
		if a > 0:
			var rgb := (Color(src.r, src.g, src.b) * src.a + Color(dst.r, dst.g, dst.b) * dst.a * (1 - src.a)) / a
			img.set_pixel(x, py, Color(rgb.r, rgb.g, rgb.b, a))


## Factory skyline: chimneys and towers made of dots.
static func _bake_columns(seed: int, height: int, bright: float, gap: int) -> Image:
	# Float format while compositing, so overlapping partial dots round once at the end like a canvas.
	var img := Image.create_empty(PERIOD, height, false, Image.FORMAT_RGBAF)
	var x := 0
	var i := 0
	while x < PERIOD - 12:
		var w := 8 + floori(DotNoise.hash2(i, 0, seed) * 4) * 4
		var h := 30 + DotNoise.hash2(i, 1, seed) * (height - 40)
		var yy := height - h
		while yy < height:
			var xx := x
			while xx < mini(PERIOD, x + w):
				var edge := yy < height - h + 4 or xx == x or xx >= x + w - 4
				# hash2 truncates its coordinates like JS `y | 0`; the dot itself sits at fractional y.
				if edge or DotNoise.hash2(xx, int(yy), seed) >= 0.45:
					_dot(img, xx, yy, _gray(bright if edge else bright * 0.6))
				xx += 4
			yy += 4
		# Lit windows.
		if DotNoise.hash2(i, 2, seed) > 0.5:
			_dot(img, x + 4, height - h + 8, _rgba(217, 119, 87, 0.5))
		x += w + floori(DotNoise.hash2(i, 3, seed) * gap)
		i += 1
	# Round to 8 bits like a canvas stores pixels (Image.convert would truncate).
	var out := Image.create_empty(PERIOD, height, false, Image.FORMAT_RGBA8)
	for py in height:
		for px in PERIOD:
			var c := img.get_pixel(px, py)
			if c.a > 0:
				out.set_pixel(px, py, Color8(roundi(c.r * 255), roundi(c.g * 255), roundi(c.b * 255), roundi(c.a * 255)))
	return out


static func _bake_ridge(seed: int, height: int, amp: float, base: float, bright: float, spacing: int, inverted: bool, terrace := 0) -> Image:
	var img := Image.create_empty(PERIOD, height, false, Image.FORMAT_RGBA8)
	for x in range(0, PERIOD, spacing):
		var n := DotNoise.periodic_noise1(x / 96.0, PERIOD / 96.0, seed) * 0.6 \
			+ DotNoise.periodic_noise1(x / 37.0, PERIOD / 37.0, seed + 1) * 0.3 \
			+ DotNoise.periodic_noise1(x / 13.0, PERIOD / 13.0, seed + 2) * 0.1
		var ridge := base + n * amp
		# Terraces turn rolling hills into flat-topped mesas.
		if terrace > 0:
			ridge = roundf(ridge / terrace) * terrace
		var top := height - ridge
		for y in range(0, height, spacing):
			var yy := height - 1 - y if inverted else y
			var depth := y - top
			if depth < 0:
				continue
			var r := DotNoise.hash2(x, y, seed)
			var fade := depth / maxf(1, height - top)
			if r < fade * 0.85:
				continue
			var c := _gray(bright if depth < spacing else bright * (0.75 - fade * 0.45) + r * 10)
			img.set_pixel(x, yy, c)
			if depth < spacing and r > 0.55 and x + 1 < PERIOD:
				img.set_pixel(x + 1, yy, c)
	return img


func _physics_process(_dt: float) -> void:
	if not Game.frozen():
		queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var view := get_viewport_rect().size
	var cam := camera.top_left
	var t := Game.time
	if theme in ["plains", "boss", "mesa", "codex", "canopy", "cliffs", "router"]:
		_draw_stars(cam, view, t)
	if theme in ["window", "towers", "router"]:
		_draw_data_rain(cam, view, t)
	if theme == "codex":
		_draw_code(view, t)
	if theme == "boss":
		_draw_rings(view, t)
	for l in layers:
		var tex: Texture2D = l.tex
		var h := tex.get_height()
		var ox := -fposmod(cam.x * l.factor, PERIOD)
		var shift: float = (camera.max_y() - cam.y) * l.factor_y
		var y: float = view.y * l.anchor + shift if l.inverted else view.y * l.anchor - h + shift
		var x := ox
		while x < view.x:
			draw_texture(tex, Vector2(roundf(x), roundf(y)), l.modulate)
			x += PERIOD
	if theme == "forge":
		_draw_embers(view, t)
	if theme == "swamp":
		_draw_fog(cam, view, t)


## Orange embers rising from the furnaces.
func _draw_embers(view: Vector2, t: float) -> void:
	for i in 40:
		var speed := 12 + DotNoise.hash2(i, 1, 5) * 30
		var x := fmod(DotNoise.hash2(i, 2, 5) * view.x + sin(t * 0.8 + i) * 10, view.x)
		var y := view.y - fmod(t * speed + DotNoise.hash2(i, 3, 5) * view.y, view.y)
		draw_rect(Rect2(roundf(x), roundf(y), 1, 1), _rgba(217, 119, 87, 0.15 + y / view.y * 0.45))


## Slow horizontal bands of fog dots.
func _draw_fog(cam: Vector2, view: Vector2, t: float) -> void:
	for band in 4:
		var by := view.y * (0.55 + band * 0.1)
		var par := 0.2 + band * 0.1
		var x := -fmod(t * (6 + band * 4) + cam.x * par, 8)
		while x < view.x:
			var k := DotNoise.hash2(floori((x + cam.x * par) / 8), band, 4)
			if k >= 0.55:
				var wobble := sin(x * 0.05 + t + band) * 3
				draw_rect(Rect2(roundf(x), roundf(by + wobble), 3, 1), _rgba(150, 170, 150, 0.08 + (k - 0.55) * 0.3))
			x += 8


## Dim lines of code scrolling behind the Codex arena.
func _draw_code(view: Vector2, t: float) -> void:
	var font := ThemeDB.fallback_font
	var line_h := 8.0
	var scroll := fmod(t * 6, line_h)
	var first := floori(t * 6 / line_h)
	var color := _rgba(95, 208, 216, 0.055)
	# Fonts take integer sizes: draw at 2x and scale down for the 5 px text of the TS version.
	draw_set_transform(Vector2.ZERO, 0, Vector2(0.5, 0.5))
	for i in ceili(view.y / line_h) + 1:
		if (first + i) % 2:
			continue
		var y := view.y - (i * line_h + scroll)
		var base := (y + font.get_ascent(10) / 4 - font.get_descent(10) / 4) * 2
		draw_string(font, Vector2((12 + ((first + i) % 4) * 10) * 2, base), CODE_LINES[(first + i) % CODE_LINES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
		draw_string(font, Vector2(view.x * 0.55 * 2, base), CODE_LINES[(first + i + 7) % CODE_LINES.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
	draw_set_transform(Vector2.ZERO)


func _draw_stars(cam: Vector2, view: Vector2, t: float) -> void:
	var cell := 22.0
	var o := cam * 0.03
	var gx0 := floori(o.x / cell)
	var gy0 := floori(o.y / cell)
	for j in ceili(view.y * 0.75 / cell) + 1:
		for i in ceili(view.x / cell) + 1:
			var gx := gx0 + i
			var gy := gy0 + j
			var r := DotNoise.hash2(gx, gy, 99)
			if r > 0.16:
				continue
			var sx := gx * cell + DotNoise.hash2(gx, gy, 5) * cell - o.x
			var sy := gy * cell + DotNoise.hash2(gx, gy, 6) * cell - o.y
			var tw := 0.5 + 0.5 * sin(t * (1 + r * 8) + r * 40)
			var s := 2.0 if r < 0.025 else 1.0
			draw_rect(Rect2(roundf(sx), roundf(sy), s, s), _lit(60 + tw * 90 * (1.4 if r < 0.03 else 1.0)))


func _draw_data_rain(cam: Vector2, view: Vector2, t: float) -> void:
	var spacing := 12.0
	var o := cam * 0.25
	var c0 := floori(o.x / spacing)
	for i in ceili(view.x / spacing) + 1:
		var col := c0 + i
		var x := col * spacing - o.x
		var speed := 20 + DotNoise.hash2(col, 0, 3) * 50
		var len := 6 + floori(DotNoise.hash2(col, 1, 3) * 12)
		var period := view.y + len * 4 + 80
		var head := fposmod(t * speed + DotNoise.hash2(col, 2, 3) * 1000 - o.y, period) - len * 4
		for k in len:
			var y := head - k * 4
			if y < -4 or y > view.y:
				continue
			var v := 120.0 if k == 0 else 75 - (float(k) / len) * 50
			draw_rect(Rect2(roundf(x), roundf(y), 1, 2 if k == 0 else 1), _lit(v))


func _draw_rings(view: Vector2, t: float) -> void:
	var c := Vector2(view.x / 2, view.y * 0.42)
	for ring in range(1, 7):
		var r := ring * 26 + fmod(t * 10, 26)
		var fade := 1 - r / 190
		if fade <= 0:
			continue
		var n := floori(r * 0.5)
		for k in n:
			var a := float(k) / n * TAU + ring * 0.3
			draw_rect(Rect2(roundf(c.x + cos(a) * r), roundf(c.y + sin(a) * r * 0.6), 1, 1), _lit(30 + fade * 45))
