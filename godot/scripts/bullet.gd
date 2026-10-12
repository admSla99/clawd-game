class_name Bullet
extends Node3D

## A shot of Clawd's gun, from `Bullet` in src/entities/bullets.ts, with the bullet half of checkBullets() in
## src/scenes/game.ts: it flies straight, stops on a solid or corrupted tile (an orb explodes there, and when
## its life runs out), and hits each enemy once: enemy shots that can be shot down vanish with it; otherwise
## the enemy takes its damage, and it stops unless it still pierces. A shield turned towards it makes it
## ricochet (enemies with blocks_direction()). Lives in the level; `pos` is its centre in level pixels.
## Drawn as small glowing voxels: a spinning coin (token), a hot square (pellet), a code character (glyph) or
## an orange core with ten dots circling it in depth (orb, with a GlowLight); tokens and pellets leave a dot
## behind them.

const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
const GLYPHS := "abcdefghijklmnopqrstuvwxyz{}();=<>/+*01"
const GLOW := 1.7

static var MATERIAL := Voxel.material(GLOW)
static var _meshes := {}

var kind := "token"
var damage := 1.0
var color := ORANGE
var splash := {}
var pierce := 0
var vel := Vector2.ZERO
var life := 1.0
var t := 0.0
var hits: Array = []
var pos := Vector2.ZERO
var size := 4.0
var dead := false
var level: Level
var _body: MeshInstance3D
var _trail: MeshInstance3D
var _dots: Array[MeshInstance3D] = []
var _glyph := "a"


## A bullet of weapon `w` from `at` along `angle` (radians, y down) at `speed` px/s with `dmg` damage.
static func fire(parent: Level, at: Vector2, angle: float, speed: float, w: Dictionary, dmg: float) -> Bullet:
	var b := Bullet.new()
	b.name = "Bullet"
	b.level = parent
	b.kind = w.kind
	b.damage = dmg
	b.color = w.color
	b.splash = w.get("splash", {})
	b.pierce = w.pierce
	b.life = w.life
	b.size = 9.0 if b.kind == "orb" else 4.0
	b.pos = at
	b.vel = Vector2(cos(angle), sin(angle)) * speed
	var chars := []
	for c in GLYPHS:
		if PixelFont.GLYPHS.has(c):
			chars.append(c)
	b._glyph = chars.pick_random() if not chars.is_empty() else "a"
	parent.add_child(b, true)
	return b


func _ready() -> void:
	add_to_group("bullets")
	_body = MeshInstance3D.new()
	add_child(_body)
	match kind:
		"token", "pellet":
			_trail = MeshInstance3D.new()
			_trail.mesh = _mesh("trail", ["oo", "oo"], {"o": ORANGE if kind == "token" else color}, 2)
			add_child(_trail)
			if kind == "pellet":
				_body.mesh = _mesh("pellet%s" % color.to_html(), ["ccc", "ccc", "ccc"], {"c": color}, 4)
		"orb":
			_body.mesh = _mesh("orb", ["ooooo", "ooooo", "ooooo", "ooooo", "ooooo"], {"o": ORANGE}, 6)
			for i in 10:
				var d := MeshInstance3D.new()
				d.mesh = _mesh("orbdot%d" % (i % 2), ["d"], {"d": ORANGE_LIGHT if i % 2 else Color.WHITE}, 2)
				add_child(d)
				_dots.append(d)
			var glow := GlowLight.new()
			glow.radius = 2.2
			glow.energy = 0.9
			add_child(glow)
	_update_visual()


func rect() -> Rect2:
	return Rect2(pos - Vector2(size, size) / 2, Vector2(size, size))


func _physics_process(dt: float) -> void:
	if Game.frozen() or dead:
		return
	t += dt
	life -= dt
	pos += vel * dt
	if kind == "orb" and randf() < 0.7:
		Fx.burst(self, pos, {count = 1, speed = 15, life = 0.35, color = [ORANGE, ORANGE_LIGHT]})
	if level.tile(pos) in [Level.SOLID, Level.CORRUPT]:
		impact()
		return
	if life <= 0:
		if not splash.is_empty():
			impact()
		else:
			_remove()
		return
	_check_enemies()
	if not dead:
		_update_visual()


## checkBullets() for this bullet.
func _check_enemies() -> void:
	var r := rect()
	for e: Enemy in get_tree().get_nodes_in_group("enemies"):
		if e.dead or hits.has(e) or not r.intersects(e.rect()):
			continue
		if e.projectile:
			if e.cancellable:
				e.remove()
				impact()
				return
			continue
		if e.has_method("blocks_direction") and e.blocks_direction(vel):
			# Ricochet off the shield.
			vel = Vector2(-vel.x * 0.8, -absf(vel.y) - 60)
			hits.append(e)
			Sound.play("deflect")
			Fx.burst(self, pos, {count = 5, speed = 70, life = 0.2, color = [Color("#5FD0D8"), Color.WHITE]})
			continue
		hits.append(e)
		if e.hit(&"shot", damage):
			Sound.play("hit")
			Fx.burst(self, pos, {count = 3, speed = 60, life = 0.2, color = [color, Color.WHITE]})
		if not splash.is_empty() or pierce <= 0:
			impact()
			return
		pierce -= 1


## Stops here: an orb explodes (Main.explode()), anything else puffs.
func impact() -> void:
	if dead:
		return
	if not splash.is_empty():
		var main := get_tree().get_first_node_in_group("main")
		if main:
			main.explode(pos, splash.radius, splash.damage)
	else:
		Fx.burst(self, pos - vel * 0.01, {count = 4, speed = 50, life = 0.2, color = [color, Color.WHITE]})
	_remove()


func _remove() -> void:
	dead = true
	remove_from_group("bullets")
	queue_free()


func _update_visual() -> void:
	var snap := pos.round()
	position = Px.to3(snap)
	match kind:
		"token":
			# The spinning coin: 6, 4 or 2 px wide as it turns, 4 px tall, an orange middle.
			var w := maxi(1, roundi(absf(cos(t * 30)) * 3))
			_body.mesh = _coin(w)
		"glyph":
			var hot := floori(t * 20) % 3 == 0
			_body.mesh = _mesh("glyph%s%s" % [_glyph, hot], PixelFont.rows(_glyph, "g"), {"g": ORANGE_LIGHT if hot else color}, 2)
		"orb":
			for i in 10:
				var a := float(i) / 10 * TAU + t * 8
				_dots[i].position = Vector3(roundf(cos(a) * 5), roundf(sin(a) * 2) - 0.5, roundf(sin(a) * 5)) * Px.M
	# The bodies are anchored at their bottom: centre them on the bullet.
	_body.position.y = -2.5 * Px.M if kind != "glyph" else -3.0 * Px.M
	if _trail:
		var back := (-vel * (0.012 if kind == "token" else 0.015)).round()
		_trail.position = Vector3(back.x, -back.y - 1, -1) * Px.M


static func _coin(w: int) -> ArrayMesh:
	var rows := []
	for y in 4:
		var s := ""
		for x in w * 2:
			s += "o" if y in [1, 2] and x >= w / 2 and x < w * 2 - w / 2 else "L"
		rows.append(s)
	return _mesh("coin%d" % w, rows, {"L": ORANGE_LIGHT, "o": ORANGE}, 4)


static func _mesh(key: String, rows: Array, palette: Dictionary, depth: int) -> ArrayMesh:
	if not _meshes.has(key):
		var d := {}
		for k in palette:
			d[k] = depth
		_meshes[key] = Voxel.mesh(rows, palette, d, Px.M, MATERIAL)
	return _meshes[key]
