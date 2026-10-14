class_name Plate
extends Node3D

## A pressure plate (a digit `1`-`9` in a world-3 map; a run of the same digit in a row is one plate), lying on the
## floor under its cells. It is pressed while Clawd stands on it or a sub-agent's feet are on it (scripts/echo.gd,
## replaying or standing). With a `hold` (the level's `plateHold`, seconds per digit) it stays pressed that long
## after being let go, blinking faster as the time runs out. The gates of the matching letter (scripts/gate.gd: `a`
## for 1, `b` for 2, ...) open while every plate of their digit is pressed. Group "plates"; the origin is the run's
## bottom middle. A voxel slab in its digit's colour (the gates' too), lit and sunk a pixel while pressed.

## The colours of digits 1-9, shared with the gates.
const COLORS := [Color("#5FE3F0"), Color("#FF6FD8"), Color("#FFE15C"), Color("#9CF26A"), Color("#FF9A5C"),
	Color("#B58CFF"), Color("#6FA8FF"), Color("#F0F0F0"), Color("#FF5C6F")]
const H := 3

@export var digit := 1
## Width in tiles.
@export var cells := 1
## Seconds it stays pressed after being let go (0: only while held); read from the level's info on the first frame
## (Main sets `info` only after the level is in the tree).
var hold := 0.0
var _hold_read := false
var pressed := false
var held_t := 0.0
var t := 0.0
var _slab: MeshInstance3D
var _lit: MeshInstance3D


func _ready() -> void:
	add_to_group("plates")
	var w := cells * 16 - 4
	var col: Color = COLORS[digit - 1]
	_slab = MeshInstance3D.new()
	_slab.mesh = Voxel.mesh(["d".repeat(w), "d".repeat(w)], {"d": col.darkened(0.55)}, {"d": 8}, Px.M)
	add_child(_slab)
	_lit = MeshInstance3D.new()
	_lit.mesh = Voxel.mesh(["L".repeat(w - 2)], {"L": col}, {"L": 6}, Px.M, Voxel.material(1.6))
	_lit.position.y = 2 * Px.M
	add_child(_lit)


func feet() -> Vector2:
	return Px.of(position)


## Its top surface (level px).
func rect() -> Rect2:
	return Rect2(feet() + Vector2(-cells * 8 + 2, -H), Vector2(cells * 16 - 4, H))


## Pressed now, or still held by its timer.
func active() -> bool:
	return pressed or held_t > 0


## Whether feet at `p` stand on it.
func under(p: Vector2) -> bool:
	return absf(p.y - feet().y) < 2.0 and absf(p.x - feet().x) < cells * 8 + 2


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	if not _hold_read:
		_hold_read = true
		var main := get_tree().get_first_node_in_group("main")
		if main and main.info is Dictionary:
			hold = float(main.info.get("plateHold", {}).get(str(digit), hold))
	t += dt
	var was := active()
	var player: Player = get_tree().get_first_node_in_group("player")
	var on := player != null and player.in_play() and player.on_ground and under(player.pos)
	for e: Echo in get_tree().get_nodes_in_group("echoes"):
		on = on or (e.alive() and under(e.feet))
	if on and not pressed:
		Sound.play("plateOn")
	pressed = on
	held_t = hold if on else maxf(0.0, held_t - dt)
	if was and not active():
		Sound.play("plateOff")
	_update_visual()


func _update_visual() -> void:
	var down := active()
	_slab.position.y = (-1.0 if down else 0.0) * Px.M
	# Held by its timer: blinking, faster as it runs out.
	var blink := not pressed and held_t > 0 and fmod(t * (3.0 + 9.0 * (1.0 - held_t / maxf(hold, 0.01))), 1.0) > 0.5
	_lit.visible = down and not blink
	_lit.position.y = (1.0 if down else 2.0) * Px.M
