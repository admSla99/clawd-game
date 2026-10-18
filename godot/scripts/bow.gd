class_name Bow
extends RefCounted

## A bow's draw and shot (docs/endgame-plan.md E14.2), for Gun when the weapon it holds is a bow (Weapons.BOWS).
## Holding the attack draws it: a full draw takes 1 / (fire_rate x the attack speed) seconds, with a click and a
## flash when it is full. Letting go shoots an arrow (a Bullet of kind "arrow" that falls and pierces) along the
## aim: its damage from MIN_POWER of the weapon's at no draw to all of it at a full one, its speed likewise from
## MIN_SPEED; critical strikes, Temperature 1.5 (doubles, a wilder aim) and elements as a gun's shots. No context
## heat. Being hurt, spinning or anything else that stops the attack lets the arrow go slack (no shot).

const MIN_POWER := 0.35
const MIN_SPEED := 0.55
## After a shot, the next draw waits this long.
const NOCK := 0.15

var gun: Gun
## Seconds drawn, 0 when not drawing.
var draw_t := 0.0
var drawing := false
var full := false


func _init(g: Gun) -> void:
	gun = g


func reset() -> void:
	draw_t = 0.0
	drawing = false
	full = false


## Seconds a full draw takes.
func full_draw() -> float:
	return 1.0 / (gun.weapon.fire_rate * Weapons.rate_mult())


## How far it is drawn, 0 to 1.
func power() -> float:
	return clampf(draw_t / full_draw(), 0.0, 1.0) if drawing else 0.0


## One physics frame: `held` draws, its release shoots; `can` false (hurt, spinning) lets the draw go. Returns
## the arrow shot this frame, or null.
func update(dt: float, held: bool, can: bool) -> Bullet:
	gun.cooldown -= dt
	if not can:
		reset()
		return null
	if held:
		if not drawing and gun.cooldown <= 0:
			drawing = true
			draw_t = 0.0
			full = false
		if drawing:
			draw_t += dt
			if not full and draw_t >= full_draw():
				full = true
				Sound.play("bowFull")
				gun.main.particles.emit(gun.pivot(), {count = 6, speed = 40, life = 0.2, color = [gun.weapon.color, Color.WHITE]})
		return null
	if not drawing:
		return null
	return _shoot()


func _shoot() -> Bullet:
	var w := gun.weapon
	var p := power()
	reset()
	gun.cooldown = NOCK
	var damage: float = w.damage * Weapons.damage_mult() * lerpf(MIN_POWER, 1.0, p)
	var angle := gun.player.aim
	var temp := Prompts.on("temperature") and not Prompts.on("precise")
	if temp:
		angle += (randf() - 0.5) * 2 * Prompts.TEMP_SPREAD
		if randf() < Prompts.TEMP_CRIT:
			damage *= 2.0
	if randf() < Stats.crit_chance():
		damage *= Stats.crit_mult()
	var from := gun.pivot() + Vector2(cos(angle), sin(angle)) * 8
	var b := Bullet.fire(gun.main.level, from, angle, w.speed * lerpf(MIN_SPEED, 1.0, p), w, damage)
	b.gravity = w.gravity
	gun.flash = 0.0
	gun.recoil = 0.6 * p
	Sound.play("bowShot")
	return b
