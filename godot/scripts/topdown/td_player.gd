class_name TdPlayer
extends TdActor

## Clawd in the top-down prototype: WASD in eight directions (relative to the screen: W is up on screen), aiming at
## the mouse, shooting the gun he holds (the equipped weapon item or the one picked in the campaign, with every
## multiplier of Weapons and Stats, critical strikes too), and Space dodges: a short dash he cannot be hit in.
## Life, armour, evasion and regeneration come from Stats like in a map.

const SPEED := 4.6
const DODGE_SPEED := 13.0
const DODGE_TIME := 0.2
const DODGE_COOLDOWN := 0.55
const HURT_GRACE := 0.8
## W on screen: away from the camera on the ground.
const SCREEN_UP := Vector2(-0.7071, -0.7071)

var life := 100.0
var max_life := 100.0
var armour := 0.0
var evasion := 0.0
var regen := 0.0
var weapon: Dictionary
var cooldown := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.ZERO
var grace := 0.0
var aim := Vector2.RIGHT
var walk := 0.0
var moving := false


func setup() -> void:
	max_life = Stats.max_life()
	life = max_life
	armour = Stats.total("armour")
	evasion = Stats.total("evasion")
	regen = Stats.total("regen")
	var id := Progress.equipped if Weapons.WEAPONS.has(Progress.equipped) else "blaster"
	if not Gear.weapon().is_empty():
		id = Items.BASES[Gear.weapon().base].weapon
	weapon = Weapons.get_def(id)


func _ready() -> void:
	radius = 0.3
	super()
	_update_mesh()


func _update_mesh() -> void:
	var legs := "stand" if not moving or int(walk * 8) % 2 == 0 else "tuck"
	if dodge_t > 0:
		legs = "tuck"
	body.mesh = TdActor.sprite(ClawdSprite.frame("mid", legs), ClawdSprite.PALETTE, ClawdSprite.DEPTH, ClawdSprite.TOP)


func input_dir() -> Vector2:
	var ix := Input.get_axis("left", "right")
	var iy := Input.get_axis("up", "down")
	var d := SCREEN_RIGHT * ix - SCREEN_UP * iy
	return d.normalized() if d.length() > 0.1 else Vector2.ZERO


## One step: moves or dodges, regenerates, and returns the shots fired (towards `aim_at`).
func tick(dt: float, room: TdRoom, aim_at: Vector2, trigger: bool, dodge: bool) -> Array:
	flash = maxf(0.0, flash - dt)
	grace = maxf(0.0, grace - dt)
	cooldown -= dt
	dodge_cd -= dt
	life = minf(max_life, life + regen * dt)
	var d := input_dir()
	moving = d != Vector2.ZERO
	if dodge and dodge_cd <= 0 and dodge_t <= 0:
		dodge_dir = d if moving else aim
		dodge_t = DODGE_TIME
		dodge_cd = DODGE_COOLDOWN
	if dodge_t > 0:
		dodge_t -= dt
		pos = room.slide(pos, dodge_dir * DODGE_SPEED * dt, radius)
	else:
		pos = room.slide(pos, d * SPEED * (1.0 + Stats.total("run") / 100.0) * dt, radius)
	if moving:
		walk += dt
	var to := aim_at - pos
	if to.length() > 0.1:
		aim = to.normalized()
	face(aim)
	_update_mesh()
	place()
	body.rotation_degrees.z = -360.0 * (1.0 - dodge_t / DODGE_TIME) * facing if dodge_t > 0 else 0.0
	var shots := []
	if trigger and cooldown <= 0 and dodge_t <= 0:
		cooldown = 1.0 / (weapon.fire_rate * Weapons.rate_mult())
		var dmg: float = weapon.damage * Weapons.damage_mult()
		var crit := randf() < Stats.crit_chance()
		if crit:
			dmg *= Stats.crit_mult()
		var n: int = weapon.pellets
		for i in n:
			var off: float = -weapon.fan / 2 + weapon.fan * i / (n - 1) if n > 1 else 0.0
			var a: float = aim.angle() + off + (randf() - 0.5) * 2 * weapon.spread
			var speed: float = maxf(weapon.speed, 400.0) / 16.0
			var range_t: float = weapon.life if weapon.life > 0 else 0.6
			var s := TdShot.make(pos + aim * 0.45, Vector2.from_angle(a) * speed, dmg, true, weapon.color, range_t)
			s.crit = crit
			shots.append(s)
	return shots


func dodging() -> bool:
	return dodge_t > 0


## Hit for `dmg` (an enemy's hit of the area level when negative): evasion, armour, a short grace. Returns what was
## taken (-1 evaded, 0 ignored).
func hurt(dmg: float, area: int) -> float:
	if dodging() or grace > 0:
		return 0.0
	if randf() < Stats.evade_chance(evasion, area):
		grace = HURT_GRACE * 0.5
		return -1.0
	var hit := (dmg if dmg >= 0 else Stats.enemy_hit(area))
	hit *= 1.0 - Stats.armour_reduction(armour, hit)
	life -= hit
	flash = 0.12
	grace = HURT_GRACE
	return hit
