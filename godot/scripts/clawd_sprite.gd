class_name ClawdSprite

## Clawd drawn at 1 px resolution from the layout of clawdFrame() in src/render/sprites.ts (13 x 10 cells
## of 2 px): an 18 x 16 px body with a darker left column and bottom rows, arms 4 px out to each side,
## four 2 px legs. On top of that 2D layout it adds the pixel shading the 2 px grid had no room for:
## a lit top rim and right edge, a deeper shade under the body, eye glints, pupils that look around,
## and squash & stretch drawn as real wider / taller bodies instead of a scaled mesh.
## mesh() builds (and caches) the voxel mesh for one combination of options.

const BODY_W := 18
const BODY_H := 16
const LEG_H := 4
const ARM := 4
const PALETTE := {
	"O": Color("#D97757"), # body
	"H": Color("#F2A27F"), # lit top rim
	"h": Color("#E5896A"), # lit right edge
	"o": Color("#B35E40"), # shaded left column, bottom, legs, back arm
	"d": Color("#94492F"), # deepest shade under the body
	"E": Color("#1A1311"), # eyes
	"W": Color("#FFF1E6"), # eye glint
}
## Top faces of the lit rim: a warm step above the body colour, not a pale band.
const TOP := {"H": Color("#E8906F")}
## Depth in px (even): a thick body with eyes on both faces, thinner arms and legs.
const DEPTH := {"O": 12, "H": 12, "h": 12, "E": 12, "W": 12, "o": 4, "d": 4}
## Arm top as a share of the body height, per arm pose.
const ARM_Y := {"mid": 0.5, "up": 0.25, "high": 0.125, "low": 0.5625}
## Leg columns (x from the body's left edge, for BODY_W = 18) drawn in the top and bottom 2 px rows.
const LEGS := {
	"stand": [[0, 4, 12, 16], [0, 4, 12, 16]],
	"runA": [[0, 4, 12, 16], [4, 16]],
	"runB": [[0, 4, 12, 16], [0, 12]],
	"tuck": [[0, 4, 12, 16], []],
	"dangle": [[2, 6, 14, 18], [2, 6, 14, 18]],
}

static var _cache := {}


## Options: bw / bh body size in px (bw even), arms ("mid", "up", "high", "low"; "swingA" / "swingB"
## put one arm 1 px up and the other 1 px down), legs (a LEGS key), eyes ("open", "blink", "squint"),
## look (pupil offset in px, x towards the facing side, -1..1 each).
## `palette` / `top` (optional) recolour him (HAIKU, the shopkeeper, is a blue Clawd).
static func mesh(o: Dictionary) -> ArrayMesh:
	var key := str(o)
	if not _cache.has(key):
		_cache[key] = Voxel.mesh(rows(o), o.get("palette", PALETTE), DEPTH, Px.M, Voxel.MATERIAL, o.get("top", TOP))
	return _cache[key]


static func rows(o: Dictionary) -> Array:
	var bw: int = o.get("bw", BODY_W)
	var bh: int = o.get("bh", BODY_H)
	var look: Vector2i = o.get("look", Vector2i.ZERO)
	# 2 px spare on both sides (dangling legs sit 2 px right) keeps the body centred on the origin.
	var w := bw + ARM * 2 + 4
	var x0 := ARM + 2
	var grid := []
	for y in bh + LEG_H:
		var row := []
		row.resize(w)
		row.fill(".")
		grid.append(row)
	var put := func(x: int, y: int, ch: String) -> void:
		if y >= 0 and y < grid.size() and x >= 0 and x < w:
			grid[y][x] = ch
	# Body: shaded left column and bottom, lit top rim and right edge.
	for y in bh:
		for x in bw:
			var ch := "O"
			if x < 2 or y >= bh - 2:
				ch = "o"
			if y == bh - 1 and x >= 2:
				ch = "d"
			if y == 0 and x >= 2:
				ch = "H"
			elif x == bw - 1 and y < bh - 2:
				ch = "h"
			put.call(x0 + x, y, ch)
	# Arms: the back (left) arm shaded, the front (right) arm lit on top.
	var arms: String = o.get("arms", "mid")
	var ay := roundi(bh * ARM_Y.get(arms, 0.5))
	var left_y := ay + (1 if arms == "swingA" else -1 if arms == "swingB" else 0)
	var right_y := ay + (-1 if arms == "swingA" else 1 if arms == "swingB" else 0)
	for y in ARM:
		for x in ARM:
			put.call(x0 - ARM + x, left_y + y, "o")
			put.call(x0 + bw + x, right_y + y, "H" if y == 0 else "O")
	# Eyes 2 px wide; open eyes are a quarter of the body high with a glint, blink is a 1 px line.
	var eyes: String = o.get("eyes", "open")
	var eh := maxi(3, roundi(bh * 0.25))
	var ey := roundi(bh * 0.25) + look.y
	for ex in [roundi(bw * 6.0 / 18), roundi(bw * 14.0 / 18)]:
		var x: int = x0 + ex + look.x
		var top := ey
		var height := eh
		if eyes == "blink":
			top = ey + eh - 1
			height = 1
		elif eyes == "squint":
			top = ey + eh - 2
			height = 2
		for y in height:
			put.call(x, top + y, "E")
			put.call(x + 1, top + y, "E")
		if eyes == "open":
			put.call(x + 1, top, "W")
	# Legs: columns placed for an 18 px body, spread with the body width.
	var legs: Array = LEGS[o.get("legs", "stand")]
	for half in 2:
		for lx: int in legs[half]:
			var x := x0 + roundi(lx * (bw - 2) / 16.0)
			for y in 2:
				put.call(x, bh + half * 2 + y, "o")
				put.call(x + 1, bh + half * 2 + y, "o")
	return grid.map(func(row: Array) -> String: return "".join(PackedStringArray(row)))


## clawdFrame() from src/render/sprites.ts, the 13 x 10 frame the 2D game draws at 1 px for the sub-agents
## (and smaller on the HUD and the map): a 9 x 8 body ("O", shaded "o" left column and bottom row, lit "H" top
## row), arms at the `arms` rows, "E" eyes, two rows of legs.
static func frame(arms := "mid", legs := "stand", blink := false, squint := false) -> Array:
	var out := []
	for r in 8:
		var row := "..oHHHHHHHH.." if r == 0 else "..ooooooooo.." if r == 7 else "..oOOOOOOOO.."
		var eye_rows := [3] if squint or blink else [2, 3]
		if r in eye_rows:
			row = row.substr(0, 5) + "E" + row.substr(6, 3) + "E" + row.substr(10)
		var arm_rows: Array = {"mid": [4, 5], "up": [2, 3], "high": [1, 2]}[arms]
		if r in arm_rows:
			row = "oo" + row.substr(2, 9) + "OO"
		out.append(row)
	var l: Array = {
		"stand": ["..o.o...o.o..", "..o.o...o.o.."],
		"tuck": ["..o.o...o.o..", "............."],
		"dangle": ["...o.o...o.o.", "...o.o...o.o."],
	}[legs]
	return out + l


## The sub-agent frames: `cheer` (arms high) or idle, as a voxel mesh 6 px deep; `tint` replaces every colour
## (the 2D `tint`, for a ghost), keeping the eyes darker.
static func mini_mesh(cheer: bool, tint := Color(0, 0, 0, 0)) -> ArrayMesh:
	var key := "mini %s %s" % [cheer, tint]
	if not _cache.has(key):
		var pal := PALETTE.duplicate()
		var top := TOP.duplicate()
		if tint.a > 0:
			for k in pal:
				pal[k] = tint
			pal.E = tint.darkened(0.6)
			top = {"H": tint}
		_cache[key] = Voxel.mesh(frame("high" if cheer else "mid"), pal, {"O": 6, "H": 6, "o": 6, "E": 6}, Px.M, Voxel.MATERIAL, top)
	return _cache[key]


## A 2D texture of a frame (HUD, results, map), every colour replaced by `tint` when it is set.
static func texture(rows: Array, tint := Color(0, 0, 0, 0)) -> ImageTexture:
	var key := "tex %s %s" % [rows, tint]
	if not _cache.has(key):
		var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if PALETTE.has(ch):
					img.set_pixel(x, y, tint if tint.a > 0 else PALETTE[ch])
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]
