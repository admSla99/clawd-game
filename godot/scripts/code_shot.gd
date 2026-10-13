class_name CodeShot
extends Shot

## Codex's shots, `Shot` with a `glyph` in src/entities/enemies.ts: a code character 7 px square that flies
## straight for `life` seconds and, unlike the plain shot, passes through walls. Drawn as the character in
## glowing voxels (PixelFont, plus the braces and the wave the font lacks). `span` repeats it across the depth
## of the floor (the slam's shockwaves roll along the floor's top, not just its front edge).

const GLYPH_SIZE := 7.0
## Characters PixelFont has no glyph for.
const EXTRA := {
	"{": [".##", ".#.", "#..", ".#.", ".##", "...", "..."],
	"}": ["##.", ".#.", "..#", ".#.", "##.", "...", "..."],
	"≈": [".##..#", "#..##.", "......", ".##..#", "#..##.", "......", "......"],
}
## The dark outline round a glyph.
const OUTLINE := Color("#0A1A1D")
## Depth steps (px) of a spanning shot's copies: the floor's front half, 3 px of depth per view row.
const SPAN_Z := [0.0, 6.0, 12.0, 18.0]

static var _glyphs := {}

var glyph := "a"
var span := false


## A `ch` shot centred at `at` flying at `velocity` px/s for `seconds`, added to `level`.
static func fire_glyph(parent: Level, at: Vector2, velocity: Vector2, ch: String, glyph_color: Color, cancel := true, seconds := 4.0, across := false) -> CodeShot:
	var s := CodeShot.new()
	s.name = "CodeShot"
	s.vel = velocity
	s.color = glyph_color
	s.glyph = ch
	s.cancellable = cancel
	s.life = seconds
	s.span = across
	s.position = Px.to3(at + Vector2(0, GLYPH_SIZE / 2))
	parent.add_child(s, true)
	return s


func _init() -> void:
	super()
	size = Vector2(GLYPH_SIZE, GLYPH_SIZE)


func _ready() -> void:
	super()
	_mesh.mesh = glyph_mesh(glyph, color)
	if span:
		for i in range(1, SPAN_Z.size()):
			var ripple := MeshInstance3D.new()
			ripple.mesh = ripple_mesh(i, color)
			# In front of the gameplay plane: drawn z / 3 lower, a band of the floor's top face each.
			ripple.position = Vector3(0, 0, SPAN_Z[i] * Px.M)
			_mesh.add_child(ripple)
	_snap()


## Glyph shots fly through the level's walls (only the plain shot checks rectHitsSolid()).
func _hits_solid(_r: Rect2) -> bool:
	return false


## The glyph centred in the 7 px box (the mesh is anchored at its bottom centre, like the shot's cross).
func _snap() -> void:
	var tl := rect().position
	var snap := tl.round() - tl
	# Glyphs an even number of px wide sit half a px off the box's centre column.
	var half := 0.5 if glyph_rows(glyph)[0].length() % 2 == 0 else 0.0
	# The outline adds a row under the box (the wave has none).
	var outline := 0.0 if glyph == "≈" else 1.0
	_mesh.position = Vector3(snap.x + half, -snap.y - outline, 0) * Px.M


static func glyph_mesh(ch: String, c: Color) -> ArrayMesh:
	var key := "%s%s" % [ch, c.to_html()]
	if not _glyphs.has(key):
		var rows := glyph_rows(ch) if ch == "≈" else outlined(glyph_rows(ch))
		_glyphs[key] = Voxel.mesh(rows, {"#": c, "o": OUTLINE}, {"#": 2, "o": 2}, Px.M, Voxel.material(1.7))
	return _glyphs[key]


## `rows` with a 1 px dark outline round the glyph ('o'), so it reads against the cyan of the theme.
static func outlined(rows: Array) -> Array:
	var w: int = rows[0].length() + 2
	var grid := [".".repeat(w)]
	for r: String in rows:
		grid.append("." + r + ".")
	grid.append(".".repeat(w))
	var out := []
	for y in grid.size():
		var row := ""
		for x in w:
			var on: bool = grid[y][x] == "#"
			var near := false
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < grid.size() and grid[q.y][q.x] == "#":
					near = true
			row += "#" if on else ("o" if near else ".")
		out.append(row)
	return out


## The character's 7 rows (cap height 5, then the descenders), its top on the 7 px box's top, bold like the
## 2D glyphs (each stroke doubled to the right), except the hand-drawn wave.
static func glyph_rows(ch: String) -> Array:
	var rows: Array = EXTRA[ch] if EXTRA.has(ch) else PixelFont.rows(ch)
	if ch == "≈":
		return rows
	return rows.map(func(r: String) -> String:
		var out := ""
		for i in r.length() + 1:
			out += "#" if (i < r.length() and r[i] == "#") or (i > 0 and r[i - 1] == "#") else "."
		return out)


## The wave's lower tilde alone, dimmer the further in front it lies (the `i`th copy of a spanning shot).
static func ripple_mesh(i: int, c: Color) -> ArrayMesh:
	var key := "ripple%d%s" % [i, c.to_html()]
	if not _glyphs.has(key):
		var rows: Array = EXTRA["≈"].map(func(r: String) -> String: return r)
		for r in [0, 1]:
			rows[r] = "......"
		_glyphs[key] = Voxel.mesh(rows, {"#": c.darkened(0.2 * i)}, {"#": 2}, Px.M, Voxel.material(1.4))
	return _glyphs[key]
