class_name Sign
extends Node3D

## Tutorial sign from src/entities/collectibles.ts (`?` in the map): a small dark board with a glowing orange
## "?" on a ribbed post, standing behind the gameplay plane like the checkpoint. When Clawd is near, its text
## (the level's `signs[index]` in levels/index.json, set by Main) slides up in a bubble above it, drawn by
## the Overlay in pixel text.

const Z := -0.6
## How near Clawd has to be, like the 2D sign (|dx| < 52, |dy| < 48 px).
const NEAR := Vector2(52, 48)
const ORANGE := Color("#D97757")

static var BOARD_MESH := _board_mesh()
static var MARK_MESH := _mark_mesh()

## Order among the level's signs (Spawn.index in src/world/level.ts).
@export var index := 0
var text := "..."
## 0..1, eases towards 1 while Clawd is near.
var show := 0.0


func _ready() -> void:
	add_to_group("world_text")
	for m in [BOARD_MESH, MARK_MESH]:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.position.z = Z
		add_child(mi)
	var glow := GlowLight.new()
	glow.radius = 1.3
	glow.energy = 0.35
	glow.position = Vector3(0, 11 * Px.M, Z + 0.4)
	add_child(glow)


## Level pixels of the feet.
func feet() -> Vector2:
	return Px.of(position)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	var player: Player = get_tree().get_first_node_in_group("player")
	var near := player != null and absf(player.pos.x - feet().x) < NEAR.x and absf(player.pos.y - feet().y) < NEAR.y
	show += ((1.0 if near else 0.0) - show) * minf(1.0, dt * 10)


func overlay_draw(o: Overlay) -> void:
	if show > 0.02:
		o.bubble(text.split("\n"), o.to_view(feet() + Vector2(0, -16), Z), show)


## A 14 x 10 px board (grey rim, dark face 1 px back) on a 6 px ribbed post, like the 2D sign.
static func _board_mesh() -> ArrayMesh:
	var rows := []
	for y in 10:
		rows.append("b" + ("b" if y == 0 or y == 9 else "f").repeat(12) + "b")
	for y in 6:
		rows.append("......" + ("pp" if y % 2 == 0 else "qq") + "......")
	return Voxel.mesh(rows, {"b": Color8(138, 138, 138), "f": Color8(24, 24, 26), "p": Color8(90, 90, 90), "q": Color8(56, 54, 60)}, {"b": 6, "f": 4, "p": 2, "q": 2}, Px.M)


## The "?" on the board (PixelFont), flush with the rim, glowing.
static func _mark_mesh() -> ArrayMesh:
	var mark := PixelFont.rows("?", "m")
	var rows := []
	for y in 16:
		var r := ".".repeat(14)
		if y >= 2 and y < 7:
			r = r.substr(0, 5) + mark[y - 2] + r.substr(5 + mark[y - 2].length())
		rows.append(r)
	return Voxel.mesh(rows, {"m": ORANGE}, {"m": 6}, Px.M, Voxel.material(1.8))
