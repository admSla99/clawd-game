class_name Gate
extends Node3D

## A gate (a letter `a`-`i` or `z` in a world-3 map; every cell of one letter belongs to the same gate). Shut, its
## cells are the MeshLibrary's gate item in the level's Terrain GridMap, solid for everything (Level.tile() reads it
## as SOLID: Clawd, enemies, shots, the hook), and it draws glowing bars in its plates' colour (Plate.COLORS); open,
## the cells are empty and the bars slide up into its top. `a`-`i` are open while every plate of digit 1-9
## (scripts/plate.gd) is pressed; `z` opens for good once the level's Retry Loops (group "retry_loops", W6) are all
## destroyed. A gate about to shut on Clawd or a sub-agent waits until they are out of it. Group "gates"; the origin
## is the level's, cells are tiles.

## One row of a cell's bars: three 3 px bars with a bright core.
const BAR := ".LdL..LdL..LdL.."

@export var letter := "a"
@export var cells: Array[Vector2i] = []
var open := false
## 0 shut .. 1 open, easing towards `open`.
var amount := 0.0
var level: Level
var _bars: Array[MeshInstance3D] = []
var _mesh: ArrayMesh


func _ready() -> void:
	add_to_group("gates")
	level = get_parent() as Level
	var col := color()
	var rows := []
	for i in 16:
		rows.append(BAR)
	_mesh = Voxel.mesh(rows, {"L": col, "d": col.lightened(0.5)}, {"L": 4, "d": 2}, Px.M, Voxel.material(1.5))
	for c in cells:
		var m := MeshInstance3D.new()
		m.mesh = _mesh
		add_child(m)
		_bars.append(m)
	_set_cells(true)
	_update_visual()


func color() -> Color:
	return Color("#E0605A") if letter == "z" else Plate.COLORS[digit() - 1]


## The plates' digit of an `a`-`i` gate.
func digit() -> int:
	return letter.unicode_at(0) - "a".unicode_at(0) + 1


## Whether it wants to be open now.
func wanted() -> bool:
	if letter == "z":
		return get_tree().get_nodes_in_group("retry_loops").is_empty()
	var plates := get_tree().get_nodes_in_group("plates").filter(func(p: Plate) -> bool: return p.digit == digit())
	return not plates.is_empty() and plates.all(func(p: Plate) -> bool: return p.active())


## Its cells in level px.
func rect_of(c: Vector2i) -> Rect2:
	return Rect2(Vector2(c) * 16, Vector2(16, 16))


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	var want := wanted()
	if want and not open:
		open = true
		_set_cells(false)
		Sound.play("gateOpen")
	elif not want and open and not _occupied():
		open = false
		_set_cells(true)
		Sound.play("gateShut")
	amount = move_toward(amount, 1.0 if open else 0.0, dt * 5.0)
	_update_visual()


## Clawd or a sub-agent inside one of its cells.
func _occupied() -> bool:
	var bodies: Array[Rect2] = []
	var player: Player = get_tree().get_first_node_in_group("player")
	if player and player.in_play():
		bodies.append(Rect2(player.pos - Vector2(Player.SIZE.x / 2, Player.SIZE.y), Player.SIZE))
	for e: Echo in get_tree().get_nodes_in_group("echoes"):
		if e.alive():
			bodies.append(e.rect())
	for c in cells:
		for b in bodies:
			if b.intersects(rect_of(c)):
				return true
	return false


func _set_cells(shut: bool) -> void:
	if level == null:
		return
	# Not level.terrain: a gate is ready before its level, whose @onready vars are still unset then.
	var terrain: GridMap = level.get_node("Terrain")
	for c in cells:
		terrain.set_cell_item(Vector3i(c.x, -c.y - 1, 0), Level.GATE if shut else GridMap.INVALID_CELL_ITEM)


## Each cell's bars, slid up into the cell's top by `amount` (squashed from the bottom).
func _update_visual() -> void:
	for i in cells.size():
		var c := cells[i]
		var m := _bars[i]
		var k := 1.0 - amount
		m.visible = k > 0.02
		m.scale = Vector3(1, maxf(k, 0.01), 1)
		# Anchored at the cell's top: the mesh's bottom (its origin) rises as it shrinks.
		m.position = Px.to3(Vector2(c.x * 16 + 8, c.y * 16 + 16 * k))
