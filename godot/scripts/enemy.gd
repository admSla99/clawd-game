class_name Enemy
extends CharacterBody3D

## Base of everything that hurts Clawd and can (usually) be defeated, from `Enemy` in src/entities/entity.ts:
## hp, hit() with damage, a short immunity after melee hits, the white hit flash, and on death the burst
## (Main.enemy_died()) and the popped tokens. Lives inside a Level in the group "enemies"; the origin is at
## the feet, horizontally centred, and logic runs in level pixels (`pos`, see Px) like the bug.
## Subclasses set `size` and the flags, call tick() every unfrozen physics frame, and override rect(),
## hurtbox() or _die() where they differ. Those that do not walk (move_and_slide()) just set `pos`.

## Hit kinds (HitKind in TS) and their melee damage from checkEnemies() / onPoundLand() in src/scenes/game.ts.
const STOMP_DAMAGE := 4
const POUND_STOMP_DAMAGE := 6
const SPIN_DAMAGE := 3
const BEAM_DAMAGE := 1
const POUND_WAVE_DAMAGE := 4
## Enemy.tokens is 2 in TS; the port drops five times as many from every enemy.
const TOKEN_FACTOR := 5

## Hit points; a float, as gun damage grows by a quarter per Bigger Model level.
var hp := 1.0
## Full hit points: 0 until the first hit, which takes them from hp (after the subclass and the level set it).
var max_hp := 0.0
## Whether the Overlay draws a health bar over it while hurt (a port addition; bosses have the HUD's bar).
var health_bar := true
## The bar's light part: the hit points just lost, draining down to hp after the hit flash.
var shown_hp := 0.0
var size := Vector2(16, 16)
var stompable := true
## Cannot be damaged at all (crushers).
var invincible := false
## Projectiles: destroyed by spin, do not bounce Clawd, untouched by the hover jet.
var projectile := false
## Projectiles that Clawd's bullets can shoot down.
var cancellable := true
## Projectiles that vanish when they hit Clawd.
var consume_on_hit := true
## Tokens that pop out when defeated.
var tokens := 2 * TOKEN_FACTOR
## Seconds of white flash and of immunity left after a hit.
var flash := 0.0
var immune := 0.0
var prev_pos := Vector2.ZERO
var dead := false
var pos: Vector2:
	get: return Px.of(position)
	set(v): position = Px.to3(v)

@onready var level: Level = get_parent()


func _enter_tree() -> void:
	add_to_group("enemies")


func _ready() -> void:
	prev_pos = pos


## Call first in every unfrozen physics frame (savePrev() + tickTimers()).
func tick(dt: float) -> void:
	prev_pos = pos
	flash = maxf(0.0, flash - dt)
	immune = maxf(0.0, immune - dt)
	if flash <= 0:
		shown_hp = move_toward(shown_hp, maxf(hp, 0.0), max_hp * 1.5 * dt)


func rect() -> Rect2:
	return Rect2(pos + Vector2(-size.x / 2, -size.y), size)


## Area that hurts Clawd on contact; an empty Rect2 when harmless right now.
func hurtbox() -> Rect2:
	return rect()


## A falling player whose feet were above this line last frame stomps it (prevY + max(8, h / 2) in TS).
func stomp_line() -> float:
	return prev_pos.y - size.y + maxf(8.0, size.y / 2)


## Enemy.hit(): returns true if the hit was accepted. `kind` is stomp, pound, spin, beam or shot. The damage
## shows as a number over it (Overlay.damage_number(), a port addition).
func hit(kind: StringName, damage := 1.0) -> bool:
	if dead or invincible or immune > 0:
		return false
	if max_hp <= 0:
		max_hp = hp
		shown_hp = hp
	hp -= damage
	flash = 0.12
	var main := get_tree().get_first_node_in_group("main")
	if main and not projectile:
		main.overlay.damage_number(self, damage, hp <= 0)
	if hp <= 0:
		die(kind)
	elif kind != &"shot":
		# Melee hits give a short grace period so one spin is one hit.
		immune = 0.3
	return true


## Defeated: tokens pop out of its middle (popTokens()), Main plays the death burst, then _die() leaves
## whatever the subclass wants behind and frees the node.
func die(kind: StringName) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	var mid := rect().get_center()
	for i in tokens:
		Token.pop(level, mid)
	var main := get_tree().get_first_node_in_group("main")
	if main and not projectile:
		main.enemy_died(self, mid)
	_die(kind)


## Gone without a fight (a projectile that hit Clawd or a wall, or fell out of the level).
func remove() -> void:
	dead = true
	remove_from_group("enemies")
	queue_free()


func _die(_kind: StringName) -> void:
	queue_free()


## The white hit flash (`tint: '#FFFFFF'` while flash > 0 in the 2D draw()) or another tint on `mesh`.
func set_tint(mesh: GeometryInstance3D, color := Color(0, 0, 0, 0)) -> void:
	var c := (Color.WHITE if flash > 0 else color).srgb_to_linear()
	mesh.set_instance_shader_parameter("tint", Vector4(c.r, c.g, c.b, c.a))


## The nearest light's rim on `mesh` (see shaders/voxel.gdshader), measured `up` metres above the feet.
func set_rim(mesh: GeometryInstance3D, up := 0.35) -> void:
	var rim := GlowLight.rim_for(self, global_position + Vector3(0, up, 0))
	mesh.set_instance_shader_parameter("rim_light", rim.light)
	mesh.set_instance_shader_parameter("rim_energy", rim.energy)


## Where the Overlay centres its health bar (level pixels): 4 px over its box.
func bar_y() -> float:
	return rect().position.y - 4


## Every token it gives when defeated, including what it leaves behind (Main counts the level's total).
func token_total() -> int:
	return tokens


## moveX() in src/world/collision.ts for the `size` box: moves `dx` px unless a solid or corrupted tile
## stops it flush. Returns true when a wall stopped it.
func move_x(dx: float) -> bool:
	if dx == 0:
		return false
	var left := pos.x - size.x / 2
	var top := pos.y - size.y
	var tx := floori((left + size.x + dx - 0.001) / 16) if dx > 0 else floori((left + dx) / 16)
	for ty in range(floori(top / 16), floori((top + size.y - 0.001) / 16) + 1):
		if _solid(tx, ty):
			left = tx * 16.0 - size.x if dx > 0 else (tx + 1) * 16.0
			pos = Vector2(left + size.x / 2, pos.y)
			return true
	pos += Vector2(dx, 0)
	return false


## moveY(): moves `dy` px; a solid tile stops it either way, a one-way tile only when it falls onto it from
## above. Returns 1 when it landed on a floor, -1 when a ceiling stopped it, else 0.
func move_y(dy: float) -> int:
	if dy == 0:
		return 0
	var left := pos.x - size.x / 2
	var xs := range(floori(left / 16), floori((left + size.x - 0.001) / 16) + 1)
	if dy > 0:
		var ty := floori((pos.y + dy - 0.001) / 16)
		for tx in xs:
			var t := level.tile(Vector2(tx * 16 + 8, ty * 16 + 8))
			if t == Level.SOLID or t == Level.CORRUPT or (t == Level.ONEWAY and pos.y <= ty * 16 + 0.001):
				pos = Vector2(pos.x, ty * 16.0)
				return 1
	else:
		var ty := floori((pos.y - size.y + dy) / 16)
		for tx in xs:
			if _solid(tx, ty):
				pos = Vector2(pos.x, (ty + 1) * 16.0 + size.y)
				return -1
	pos += Vector2(0, dy)
	return 0


## hasFloorAt(): is there a solid, corrupted or one-way tile under the point `p`?
func floor_at(p: Vector2) -> bool:
	var t := level.tile(p)
	return t == Level.SOLID or t == Level.CORRUPT or t == Level.ONEWAY


func _solid(tx: int, ty: int) -> bool:
	var t := level.tile(Vector2(tx * 16 + 8, ty * 16 + 8))
	return t == Level.SOLID or t == Level.CORRUPT
