class_name ItemDrop
extends Node3D

## An item lying in a level (docs/endgame-plan.md E2): dropped by a defeated enemy (Main.roll_drop()), it jumps out,
## falls onto the ground (solid, one-way or spike tiles) and bobs there, a small voxel icon in its rarity's colour
## (a weapon is its gun). LootView draws its label and, for the one Clawd stands by, the tooltip; Main picks it up
## with the `pickup` action. Lives in the level, in the group "loot"; gone with the level.

const GRAVITY := 520.0
## How close Clawd's middle has to be to pick it up (px).
const PICKUP_RANGE := 22.0
const ICONS := {
	"helmet": ["..oooo..", ".oLLLLo.", "oLLLLLLo", "oddddddo", "oW.dd.Wo", "o..dd..o"],
	"body": [".oo..oo.", "oLLooLLo", "oLLLLLLo", ".oLLLLo.", ".oddddo.", ".oddddo.", ".oooooo."],
	"gloves": [".o.o.o..", ".o.o.o.o", ".oLLLLLo", ".oLLLLo.", ".oddddo.", "..oooo.."],
	"boots": ["..oo....", "..oL....", "..oL....", "..oLLLo.", ".oLLLLLo", ".oooooo."],
	"amulet": ["..o..o..", "...oo...", "..oLLo..", ".oLWWLo.", ".oLWWLo.", "..oLLo..", "...oo..."],
	"ring": ["...WW...", "..oWWo..", ".o....o.", "o......o", "o......o", ".o....o.", "..oooo.."],
	"map": ["oooooooo", "oLLdLLLo", "oLdLLdLo", "oLLLdLLo", "odLLLLdo", "oLLdLLLo", "oooooooo"],
}

static var _meshes := {}

var item: Dictionary
var vel := Vector2.ZERO
## Where it really is (its feet, level pixels); the node sits on the nearest whole pixel.
var fpos := Vector2.ZERO
var landed := false
var t := randf() * 10
var level: Level


## Drops `item` at `at` (level pixels) in `lvl`, flying out a little to the side.
static func drop(lvl: Level, at: Vector2, it: Dictionary) -> ItemDrop:
	var d := ItemDrop.new()
	d.name = "ItemDrop"
	d.item = it
	d.level = lvl
	d.fpos = at
	d.vel = Vector2(randf_range(-60, 60), -170 - randf() * 40)
	d.position = Px.to3(at.round())
	lvl.add_child(d, true)
	return d


static func icon_mesh(it: Dictionary) -> ArrayMesh:
	var kind := Items.kind(it)
	var key: String = kind + ":" + it.rarity + ":" + it.base
	if not _meshes.has(key):
		if kind == "weapon":
			_meshes[key] = GunSprite.mesh(Items.BASES[it.base].weapon, 1.0)
		else:
			var c := Items.color(it)
			var pal := {"o": c.darkened(0.25), "L": c, "d": c.darkened(0.5), "W": Color.WHITE}
			_meshes[key] = Voxel.mesh(ICONS[kind], pal, {"o": 2, "L": 4, "d": 4, "W": 4}, Px.M)
	return _meshes[key]


func _ready() -> void:
	add_to_group("loot")
	var m := MeshInstance3D.new()
	m.mesh = icon_mesh(item)
	add_child(m)


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	t += dt
	if not landed:
		vel.y += GRAVITY * dt
		var next := fpos + vel * dt
		if _blocks(Vector2(next.x, fpos.y - 3)):
			next.x = fpos.x
			vel.x = 0.0
		if vel.y > 0 and _ground(next):
			next.y = floorf(next.y / 16) * 16
			landed = true
			vel = Vector2.ZERO
		fpos = next
		if fpos.y > level.pixel_size.y + 64:
			queue_free()
			return
	# A gentle bob once it lies still.
	var bob := roundf(sin(t * 3.0) * 1.0 - 1.0) if landed else 0.0
	position = Px.to3((fpos + Vector2(0, bob - 1)).round())


## Clawd's middle is within reach.
func in_reach(player: Player) -> bool:
	return landed and fpos.distance_to(player.pos + Vector2(0, -6)) < PICKUP_RANGE


func _blocks(p: Vector2) -> bool:
	var it := level.tile(p)
	return it == Level.SOLID or it == Level.CORRUPT


func _ground(p: Vector2) -> bool:
	var it := level.tile(p)
	return it == Level.SOLID or it == Level.CORRUPT or it == Level.ONEWAY or it == Level.SPIKE
