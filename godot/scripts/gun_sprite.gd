class_name GunSprite

## The guns of src/render/clawdView.ts (GUN_SPRITES, GUN_PALETTE) as voxel meshes: each sprite points right
## with its grip at the left edge, in cells `cell` px wide (the 2D game draws them at 1.6 px in Clawd's hands).
## mesh() caches every weapon and cell size.

const SPRITES := {
	"blaster": ["GGGGGGOO", "GgggGG..", "Gg......"],
	"spreader": ["GGGGGGGGOO", "GGGGGGGGOO", "Gg.gg.....", "Gg........"],
	"stream": [".GGGGGGGO", "GGOGOGOGG", "Gg......."],
	"beam": ["GGGGGGGCCC", "GgggGGGCCC", "Gg........"],
	"cannon": [".OOOOOOOOO.", "GGGGGGGGGOO", "GGGGGGGGGOO", "Gg.gg......"],
}
const PALETTE := {
	"G": Color("#CFCFCF"),
	"g": Color("#7A7A7A"),
	"O": Color("#D97757"),
	"o": Color("#B35E40"),
	"C": Color("#5FD0D8"),
}
## Depth in cells: the grey body deeper than the grip, the orange and cyan muzzle as deep as the body.
const DEPTH := {"G": 4, "g": 2, "O": 4, "o": 4, "C": 4}

static var _cache := {}


static func mesh(id: String, cell := 2.0) -> ArrayMesh:
	var key := "%s@%s" % [id, cell]
	if not _cache.has(key):
		var rows: Array = SPRITES.get(id, SPRITES.blaster)
		var depth := {}
		for k in DEPTH:
			depth[k] = DEPTH[k]
		_cache[key] = Voxel.mesh(rows, PALETTE, depth, cell * Px.M)
	return _cache[key]


## Width of a sprite in cells.
static func cells(id: String) -> int:
	return (SPRITES.get(id, SPRITES.blaster)[0] as String).length()
