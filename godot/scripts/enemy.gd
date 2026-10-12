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


func rect() -> Rect2:
	return Rect2(pos + Vector2(-size.x / 2, -size.y), size)


## Area that hurts Clawd on contact; an empty Rect2 when harmless right now.
func hurtbox() -> Rect2:
	return rect()


## A falling player whose feet were above this line last frame stomps it (prevY + max(8, h / 2) in TS).
func stomp_line() -> float:
	return prev_pos.y - size.y + maxf(8.0, size.y / 2)


## Enemy.hit(): returns true if the hit was accepted. `kind` is stomp, pound, spin, beam or shot.
func hit(kind: StringName, damage := 1.0) -> bool:
	if dead or invincible or immune > 0:
		return false
	hp -= damage
	flash = 0.12
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
