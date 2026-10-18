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
	# World 3's Tool Call: a launcher with a three-pronged claw (not a weapon; Codex drops it).
	"hook": ["....OO..", "GGGO..C.", "GgGOOOOC", "GGGO..C.", "....OO.."],
	# The endgame's swords and axes (Weapons.MELEE): a grip (g) left, the guard (O), the blade (B, its edge b) or
	# the axe's head (A, its edge a) right.
	"tokenizer_blade": [".O..........", "gOBBBBBBBBBb", ".O.........."],
	"attention_sabre": ["...........b", ".O......BBB.", "gOBBBBBB....", ".O.........."],
	"transformer_edge": [".O...........", "gOBBBBBBBBBBb", "gOBBBBBBBBBB.", ".O..........."],
	"pruning_axe": [".......AAa", "ggggggggAa", ".......AAa", "........a."],
	"gradient_cleaver": ["......AAAa", ".......AAa", "gggggggggA", ".......AAa", "......AAAa"],
	"dropout_reaver": ["aAA....AAa", ".AA....AA.", "gggggggggg", ".AA....AA.", "aAA....AAa"],
}
## The row (from the top) a sprite is held by: the guns by their top one, the blades by their grip.
const GRIP_ROW := {"tokenizer_blade": 1, "attention_sabre": 2, "transformer_edge": 1, "pruning_axe": 1, "gradient_cleaver": 2,
	"dropout_reaver": 2}
const PALETTE := {
	"G": Color("#CFCFCF"),
	"g": Color("#7A7A7A"),
	"O": Color("#D97757"),
	"o": Color("#B35E40"),
	"C": Color("#5FD0D8"),
	"B": Color("#C9D6DE"),
	"b": Color("#F4F8FA"),
	"A": Color("#9AA6AE"),
	"a": Color("#E6EEF2"),
}
## Depth in cells: the grey body deeper than the grip, the orange and cyan muzzle as deep as the body.
## Blades are thin, axe heads a little thicker.
const DEPTH := {"G": 4, "g": 2, "O": 4, "o": 4, "C": 4, "B": 2, "b": 2, "A": 4, "a": 2}

static var _cache := {}


## `mat`: a gun in Clawd's hands reaches past the see-through windows' REVEAL_FRONT and needs a material of its own.
static func mesh(id: String, cell := 2.0, mat: Material = Voxel.MATERIAL) -> ArrayMesh:
	var key := "%s@%s@%d" % [id, cell, mat.get_instance_id()]
	if not _cache.has(key):
		var rows: Array = SPRITES.get(id, SPRITES.blaster)
		var depth := {}
		for k in DEPTH:
			depth[k] = DEPTH[k]
		_cache[key] = Voxel.mesh(rows, PALETTE, depth, cell * Px.M, mat)
	return _cache[key]


## Width of a sprite in cells.
static func cells(id: String) -> int:
	return (SPRITES.get(id, SPRITES.blaster)[0] as String).length()
