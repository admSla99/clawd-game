class_name MapGen
extends RefCounted

## Builds a map's level (docs/endgame-plan.md E5) from hand-drawn chunks: `levels/chunks/<theme>/*.txt`, 20 rows
## each with the ground's surface at row 15 on their first and last columns, so any two join. A map is the
## `start` chunk (the portal home and '@'), MID_MIN + tier / 2 middle chunks drawn at random (never the same one
## twice in a row) and the `boss` chunk (its 'B' is where the map boss stands; a wall closes it on the right).
## Slots in the chunks become enemies by the tier: '&' a ground enemy (a bug, a spam bot, a shield bot, from tier 3
## a turret too), '~' an air one (a drone); each is filled with a chance raised by the map's pack size, which may
## also put a second enemy next to it. Every third middle chunk starts with a checkpoint. Seeded: the same seed,
## tier and pack size give the same map. Static and free of autoloads, so tools/reach.gd can use it.

const ROWS := 20
const GROUND := 15
const MID_MIN := 8
## A slot's chance to hold an enemy, and the ground pool [char, weight, lowest tier].
const FILL := 0.8
const GROUND_POOL := [["E", 5, 1], ["F", 2, 1], ["H", 2, 2], ["T", 1, 3]]

static var _chunks := {}


## The chunks of `theme`: name -> rows.
static func chunks(theme: String) -> Dictionary:
	if not _chunks.has(theme):
		var out := {}
		var dir := "res://levels/chunks/%s" % theme
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".txt"):
				var rows := FileAccess.get_file_as_string(dir + "/" + f).replace("\r", "").trim_suffix("\n").split("\n")
				out[f.get_basename()] = rows
		_chunks[theme] = out
	return _chunks[theme]


## The names of the middle chunks, sorted.
static func mids(theme: String) -> Array:
	var out: Array = chunks(theme).keys().filter(func(n): return n != "start" and n != "boss")
	out.sort()
	return out


## The chunk names a map of this seed and tier is made of, in order.
static func layout(seed: int, tier: int, theme := "plains") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pool := mids(theme)
	var names := ["start"]
	for i in MID_MIN + tier / 2:
		var pick: String = pool[rng.randi() % pool.size()]
		while pick == names[-1] and pool.size() > 1:
			pick = pool[rng.randi() % pool.size()]
		names.append(pick)
	names.append("boss")
	return names


## The map's rows: the chunks side by side, the slots filled, checkpoints added.
static func generate(seed: int, tier: int, pack_size := 0.0, theme := "plains") -> PackedStringArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + tier
	var names := layout(seed, tier, theme)
	var grid := []
	for y in ROWS:
		grid.append([])
	var fill := minf(1.0, FILL * (1.0 + pack_size / 100.0))
	var pool: Array = GROUND_POOL.filter(func(e): return e[2] <= tier)
	for i in names.size():
		var rows: PackedStringArray = chunks(theme)[names[i]]
		var x0: int = grid[0].size()
		var w := 0
		for r in rows:
			w = maxi(w, r.length())
		for y in ROWS:
			var r: String = rows[y] if y < rows.size() else ""
			for x in w:
				grid[y].append(r[x] if x < r.length() else " ")
		# A checkpoint at the start of every third middle chunk.
		if i > 0 and i < names.size() - 1 and i % 3 == 0 and grid[GROUND - 1][x0 + 2] == " ":
			grid[GROUND - 1][x0 + 2] = "C"
	var width: int = grid[0].size()
	for y in ROWS:
		for x in width:
			var ch: String = grid[y][x]
			if ch != "&" and ch != "~":
				continue
			grid[y][x] = " "
			if rng.randf() >= fill:
				continue
			var e := "D" if ch == "~" else _weighted(pool, rng)
			grid[y][x] = e
			# Pack size can put a second one beside it.
			if pack_size > 0 and rng.randf() < pack_size / 100.0 and x + 2 < width and grid[y][x + 2] == " ":
				grid[y][x + 2] = "D" if ch == "~" else _weighted(pool, rng)
	var out := PackedStringArray()
	for y in ROWS:
		out.append("".join(grid[y]))
	return out


static func _weighted(pool: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for e in pool:
		total += e[1]
	var r := rng.randi() % total
	for e in pool:
		r -= e[1]
		if r < 0:
			return e[0]
	return pool[0][0]
