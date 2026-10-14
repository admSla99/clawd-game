class_name Brittle
extends Node3D

## A brittle block (`%` in a world-3 map): sandbox data, temporary like everything in 3-3. It stands in its tile as
## MeshLibrary item 4 (Level.GATE: a box shape with no mesh), so Level.tile() calls it SOLID and everything treats
## it as rock, and draws itself as a voxel crate as deep as the blocks. Three strikes break it (a bullet, the beam,
## the hook: strike()); a ground pound on it, an explosion or Clawd zipping into it break it at once (smash()). It
## cracks as it is struck; breaking, it bursts into sand-coloured debris. Group "brittle"; `Level.brittle` maps its
## tile to it.

const HITS := 3
const PALETTE := {"B": Color("#D9B77E"), "b": Color("#A9844E"), "d": Color("#6E5432"), "c": Color("#2A2014")}
const DEPTH := 48

static var MESHES := [_mesh(0), _mesh(1), _mesh(2)]

@export var cell := Vector2i.ZERO
var hp := HITS
var level: Level
var _body: MeshInstance3D


func _ready() -> void:
	add_to_group("brittle")
	level = get_parent() as Level
	_body = MeshInstance3D.new()
	_body.mesh = MESHES[0]
	add_child(_body)
	if level:
		level.brittle[cell] = self
		# Not level.terrain: a block is ready before its level, whose @onready vars are still unset then.
		level.get_node("Terrain").set_cell_item(Vector3i(cell.x, -cell.y - 1, 0), Level.GATE)


## The block at level point `p`, or null.
static func at(lvl: Level, p: Vector2) -> Brittle:
	var b = lvl.brittle.get(Vector2i(floori(p.x / 16), floori(p.y / 16)))
	return b if is_instance_valid(b) else null


## One strike at level point `p` (a bullet, the beam, the hook); true if a block was there.
static func strike(lvl: Level, p: Vector2) -> bool:
	var b := at(lvl, p)
	if b == null:
		return false
	b.hit()
	return true


func hit() -> void:
	hp -= 1
	if hp <= 0:
		smash()
		return
	_body.mesh = MESHES[HITS - hp]
	Sound.play("hit")
	Fx.burst(self, Vector2(cell) * 16 + Vector2(8, 8), {count = 4, speed = 50, life = 0.3, color = [PALETTE.B, PALETTE.b], gravity = 300})


## Breaks it now: the tile empties, debris through the blocks' depth.
func smash() -> void:
	if level == null or not level.brittle.has(cell):
		return
	level.brittle.erase(cell)
	level.get_node("Terrain").set_cell_item(Vector3i(cell.x, -cell.y - 1, 0), GridMap.INVALID_CELL_ITEM)
	Sound.play("break")
	Fx.burst(self, Vector2(cell) * 16 + Vector2(8, 8), {count = 14, speed = 100, life = 0.6, color = [PALETTE.B, PALETTE.b, PALETTE.d],
		gravity = 400, size = 1.5, depth = 24})
	queue_free()


## The crate, 16 x 16 px and DEPTH deep: a sandy frame with diagonal braces; `cracks` 0-2 adds dark cracks.
static func _mesh(cracks: int) -> ArrayMesh:
	var rows := []
	for y in 16:
		var r := ""
		for x in 16:
			var ch := "B"
			if x == 0 or y == 0 or x == 15 or y == 15:
				ch = "d"
			elif x == 1 or y == 1 or x == 14 or y == 14:
				ch = "B"
			elif x == y or x == 15 - y:
				ch = "b"
			elif (x + y * 3) % 7 == 0:
				ch = "b"
			if cracks >= 1 and ((x == 5 and y > 2 and y < 9) or (y == 8 and x > 4 and x < 10)):
				ch = "c"
			if cracks >= 2 and ((x == 11 and y > 6 and y < 14) or (y == 4 and x > 8 and x < 13) or (x == 3 and y > 10)):
				ch = "c"
			r += ch
		rows.append(r)
	return Voxel.mesh(rows, PALETTE, {"B": DEPTH, "b": DEPTH, "d": DEPTH, "c": DEPTH - 4}, Px.M)
