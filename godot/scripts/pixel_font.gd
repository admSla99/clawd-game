class_name PixelFont

## A small bitmap font for the pixel-art view: capitals and digits 5 px tall, lowercase with a 4 px x-height
## and 2 px descenders, most glyphs 3-4 px wide plus 1 px spacing; lines are LINE px apart like the 8 px
## lines of the 2D game's 5.5 px text. Drawn from one atlas texture with nearest filtering, so text lands on
## whole view pixels. rows() gives the same glyphs as text-grid rows for Voxel.mesh() (screens and signs).

const LINE := 8
const HEIGHT := 7
## Row 0 is the cap height; rows 5 and 6 are descenders.
const GLYPHS := {
	"A": [".##.", "#..#", "####", "#..#", "#..#"],
	"B": ["###.", "#..#", "###.", "#..#", "###."],
	"C": [".###", "#...", "#...", "#...", ".###"],
	"D": ["###.", "#..#", "#..#", "#..#", "###."],
	"E": ["####", "#...", "###.", "#...", "####"],
	"F": ["####", "#...", "###.", "#...", "#..."],
	"G": [".###", "#...", "#.##", "#..#", ".###"],
	"H": ["#..#", "#..#", "####", "#..#", "#..#"],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"J": ["..##", "...#", "...#", "#..#", ".##."],
	"K": ["#..#", "#.#.", "##..", "#.#.", "#..#"],
	"L": ["#...", "#...", "#...", "#...", "####"],
	"M": ["#...#", "##.##", "#.#.#", "#...#", "#...#"],
	"N": ["#..#", "##.#", "#.##", "#..#", "#..#"],
	"O": [".##.", "#..#", "#..#", "#..#", ".##."],
	"P": ["###.", "#..#", "###.", "#...", "#..."],
	"Q": [".##.", "#..#", "#..#", "#.#.", ".#.#"],
	"R": ["###.", "#..#", "###.", "#.#.", "#..#"],
	"S": [".###", "#...", ".##.", "...#", "###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#..#", "#..#", "#..#", "#..#", ".##."],
	"V": ["#...#", "#...#", ".#.#.", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#.#.#", "##.##", "#...#"],
	"X": ["#..#", "#..#", ".##.", "#..#", "#..#"],
	"Y": ["#...#", ".#.#.", "..#..", "..#..", "..#.."],
	"Z": ["####", "...#", ".##.", "#...", "####"],
	"a": ["...", ".##", "#.#", "#.#", ".##"],
	"b": ["#..", "##.", "#.#", "#.#", "##."],
	"c": ["...", ".##", "#..", "#..", ".##"],
	"d": ["..#", ".##", "#.#", "#.#", ".##"],
	"e": ["...", ".#.", "###", "#..", ".##"],
	"f": [".##", "#..", "###", "#..", "#.."],
	"g": ["...", ".##", "#.#", "#.#", ".##", "..#", "##."],
	"h": ["#..", "##.", "#.#", "#.#", "#.#"],
	"i": ["#", ".", "#", "#", "#"],
	"j": [".#", "..", ".#", ".#", ".#", ".#", "#."],
	"k": ["#..", "#.#", "##.", "#.#", "#.#"],
	"l": ["#.", "#.", "#.", "#.", ".#"],
	"m": [".....", "##.#.", "#.#.#", "#.#.#", "#.#.#"],
	"n": ["...", "##.", "#.#", "#.#", "#.#"],
	"o": ["...", ".#.", "#.#", "#.#", ".#."],
	"p": ["...", "##.", "#.#", "#.#", "##.", "#..", "#.."],
	"q": ["...", ".##", "#.#", "#.#", ".##", "..#", "..#"],
	"r": ["...", "#.#", "##.", "#..", "#.."],
	"s": ["...", ".##", "#..", "..#", "##."],
	"t": [".#.", "###", ".#.", ".#.", "..#"],
	"u": ["...", "#.#", "#.#", "#.#", ".##"],
	"v": ["...", "#.#", "#.#", "#.#", ".#."],
	"w": [".....", "#...#", "#.#.#", "#.#.#", ".#.#."],
	"x": ["....", "#..#", ".##.", ".##.", "#..#"],
	"y": ["...", "#.#", "#.#", "#.#", ".##", "..#", "##."],
	"z": ["...", "###", "..#", ".#.", "###"],
	"0": [".#.", "#.#", "#.#", "#.#", ".#."],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["##.", "..#", ".#.", "#..", "###"],
	"3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "##."],
	" ": ["..", "..", "..", "..", ".."],
	".": [".", ".", ".", ".", "#"],
	",": [".", ".", ".", ".", "#", "#"],
	"!": ["#", "#", "#", ".", "#"],
	"?": ["##.", "..#", ".#.", "...", ".#."],
	":": [".", "#", ".", "#", "."],
	"'": ["#", "#", ".", ".", "."],
	"-": ["...", "...", "###", "...", "..."],
	"—": [".....", ".....", "#####", ".....", "....."],
	"_": ["...", "...", "...", "...", "###"],
	"/": ["..#", "..#", ".#.", "#..", "#.."],
	">": ["#..", ".#.", "..#", ".#.", "#.."],
	"<": ["..#", ".#.", "#..", ".#.", "..#"],
	"(": [".#", "#.", "#.", "#.", ".#"],
	")": ["#.", ".#", ".#", ".#", "#."],
	"+": ["...", ".#.", "###", ".#.", "..."],
	"·": [".", ".", "#", ".", "."],
	"×": ["...", "#.#", ".#.", "#.#", "..."],
	"←": ["..#..", ".#...", "#####", ".#...", "..#.."],
	"→": ["..#..", "...#.", "#####", "...#.", "..#.."],
	"↑": ["..#..", ".###.", "#.#.#", "..#..", "..#.."],
	"↓": ["..#..", "..#..", "#.#.#", ".###.", "..#.."],
}

static var _atlas: ImageTexture
## Glyph -> Rect2 in the atlas (each glyph in a cell CELL px wide).
static var _rects := {}
const CELL := 6


static func _build() -> void:
	var keys := GLYPHS.keys()
	var img := Image.create_empty(CELL * keys.size(), HEIGHT, false, Image.FORMAT_RGBA8)
	for i in keys.size():
		var rows: Array = GLYPHS[keys[i]]
		for y in rows.size():
			for x in rows[y].length():
				if rows[y][x] == "#":
					img.set_pixel(i * CELL + x, y, Color.WHITE)
		_rects[keys[i]] = Rect2(i * CELL, 0, rows[0].length(), HEIGHT)
	_atlas = ImageTexture.create_from_image(img)


static func _glyph(ch: String) -> String:
	return ch if GLYPHS.has(ch) else "?"


## Width of one line in px.
static func width(line: String) -> int:
	var w := 0
	for ch in line:
		w += GLYPHS[_glyph(ch)][0].length() + 1
	return maxi(0, w - 1)


## Draws `line` with its top-left at `at` (rounded to whole pixels) onto `canvas` (inside its _draw()).
static func draw(canvas: CanvasItem, line: String, at: Vector2, color: Color) -> void:
	if not _atlas:
		_build()
	var x := roundi(at.x)
	var y := roundi(at.y)
	for ch in line:
		var r: Rect2 = _rects[_glyph(ch)]
		canvas.draw_texture_rect_region(_atlas, Rect2(x, y, r.size.x, HEIGHT), r, color)
		x += int(r.size.x) + 1


## Draws `line` centred on `x`.
static func draw_centred(canvas: CanvasItem, line: String, x: float, y: float, color: Color) -> void:
	draw(canvas, line, Vector2(roundf(x - width(line) / 2.0), y), color)


## `line` as text-grid rows (HEIGHT rows, `ch` for set pixels, '.' elsewhere), for Voxel.mesh().
static func rows(line: String, ch := "#") -> Array:
	var out := []
	for y in HEIGHT:
		var row := ""
		for i in line.length():
			var g: Array = GLYPHS[_glyph(line[i])]
			var r: String = g[y] if y < g.size() else ".".repeat(g[0].length())
			row += r.replace("#", ch) + ("." if i < line.length() - 1 else "")
		out.append(row)
	return out
