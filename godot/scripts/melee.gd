class_name Melee
extends RefCounted

## A sword's or an axe's swings (docs/endgame-plan.md E14), for Gun when the weapon it holds is melee
## (Weapons.MELEE). The attack starts a swing towards the aim: the blade sweeps across `arc` round it for `swing`
## seconds, and everything within `reach` of Clawd's arm inside that arc is hit once a swing (Enemy.hit(&"slash"),
## the gun's damage, critical strikes and elements, a short hitstop). Swords alternate the sweep down and up in a
## combo of three whose last swing is wider and harder; an axe sweeps a whole circle round Clawd (a cleave).
## A swing that hits an enemy while it points down in the air bounces Clawd off it like a stomp (a pogo); a swing
## cuts the enemy shots it meets (the cancellable ones) and strikes a brittle crate at its tip. Shields block it as
## they block shots.

## The combo starts again when no swing follows within this long after the last one could.
const COMBO_GRACE := 0.35
## The finisher's arc is this much wider.
const FINISHER_ARC := 1.3
## A swing pointing at least this far down (sin of the aim) bounces off what it hits in the air.
const POGO_SIN := 0.5
const HITSTOP := 0.04

var gun: Gun
## The current swing: time left of its sweep and its whole length, the aim it started at, which way it sweeps
## (1 from above to below in front of Clawd, -1 back up), its arc, damage, and what it has hit.
var swing_t := 0.0
var swing_len := 0.0
var angle := 0.0
var side := 1
var arc := 0.0
var damage := 0.0
var finisher := false
var hits: Array = []
var pogo_done := false
## The next swing's place in the combo (0 first) and how long the combo waits for it.
var combo := 0
var combo_t := 0.0


func _init(g: Gun) -> void:
	gun = g


func reset() -> void:
	swing_t = 0.0
	combo = 0
	combo_t = 0.0
	hits = []


func swinging() -> bool:
	return swing_t > 0


## One physics frame: a swing in progress hits; `trigger` starts the next once the cooldown allows. Returns true
## when a swing started.
func update(dt: float, trigger: bool) -> bool:
	gun.cooldown -= dt
	combo_t -= dt
	if combo_t <= 0:
		combo = 0
	var started := false
	if trigger and gun.cooldown <= 0:
		_start()
		started = true
	if swing_t > 0:
		swing_t = maxf(0.0, swing_t - dt)
		_strike()
	return started


func _start() -> void:
	var w := gun.weapon
	var player := gun.player
	gun.cooldown = 1.0 / (w.fire_rate * Weapons.rate_mult())
	swing_len = minf(w.swing, gun.cooldown * 0.8)
	swing_t = swing_len
	angle = player.aim
	finisher = combo == int(w.combo) - 1 and int(w.combo) > 1
	side = 1 if combo % 2 == 0 else -1
	arc = w.arc * (FINISHER_ARC if finisher else 1.0)
	combo = (combo + 1) % int(w.combo)
	combo_t = gun.cooldown + COMBO_GRACE
	hits = []
	pogo_done = false
	damage = w.damage * Weapons.damage_mult() * (w.finisher if finisher else 1.0)
	# Temperature 1.5's double hits and critical strikes, as the gun's shots.
	var temp := Prompts.on("temperature") and not Prompts.on("precise")
	if temp and randf() < Prompts.TEMP_CRIT:
		damage *= 2.0
	if randf() < Stats.crit_chance():
		damage *= Stats.crit_mult()
	Sound.play("axeSwing" if w["class"] == "axe" else "swordSwing")
	gun.recoil = 0.0
	# A brittle crate at the blade's tip breaks a little.
	var tip: Vector2 = gun.pivot() + Vector2(cos(angle), sin(angle)) * w.reach * 0.8
	Brittle.strike(gun.main.level, tip)


## Where the blade points now: from one end of the arc to the other as the swing goes, from above to below in
## front of Clawd (or back up).
func blade_angle() -> float:
	if swing_t <= 0 or swing_len <= 0:
		return gun.player.aim
	var t := 1.0 - swing_t / swing_len
	var f := 1.0 if cos(angle) >= 0 else -1.0
	var from := angle - f * side * arc / 2
	return from + f * side * arc * ease(t, 0.6)


## Whether level point `p` is in the swing's reach: near Clawd's arm and inside the arc round the aim.
func reaches(p: Vector2) -> bool:
	var pv := gun.pivot()
	var d := p - pv
	if d.length() > gun.weapon.reach:
		return false
	return d.length() < 6 or absf(angle_difference(angle, d.angle())) <= arc / 2


## The point of rect `r` nearest Clawd's arm.
func nearest(r: Rect2) -> Vector2:
	var pv := gun.pivot()
	return Vector2(clampf(pv.x, r.position.x, r.end.x), clampf(pv.y, r.position.y, r.end.y))


func _strike() -> void:
	var main := gun.main
	var player := gun.player
	var w := gun.weapon
	var dir := Vector2(cos(angle), sin(angle))
	var struck := false
	for e: Enemy in gun.get_tree().get_nodes_in_group("enemies"):
		if e.dead or hits.has(e):
			continue
		var p := nearest(e.rect())
		if not reaches(p):
			continue
		hits.append(e)
		if e.projectile:
			# A cut shot.
			if e.cancellable:
				e.remove()
				Sound.play("deflect")
				main.particles.emit(p, {count = 5, speed = 70, life = 0.2, color = [w.color, Color.WHITE]})
			continue
		if e.has_method("blocks_direction") and e.blocks_direction(dir):
			Sound.play("deflect")
			main.particles.emit(p, {count = 5, speed = 70, life = 0.2, color = [Color("#5FD0D8"), Color.WHITE]})
			continue
		if e.hit(&"slash", damage):
			if not Stats.elements().is_empty():
				e.afflict(Stats.ailment_parts(damage))
			struck = true
			main.particles.emit(p, {count = 6, speed = 90, angle = dir.angle(), spread = 1.6, life = 0.22, color = [w.color, Color.WHITE]})
	if struck:
		Sound.play("slashHit")
		Game.hitstop(HITSTOP)
		main.shake(0.12 if w["class"] == "axe" else 0.06)
		# The pogo: a downward swing in the air bounces off what it hit, once a swing.
		if not pogo_done and not player.on_ground and sin(angle) >= POGO_SIN:
			pogo_done = true
			player._bounce()
	# The blade's trail: a spark at its tip as it sweeps.
	var a := blade_angle()
	main.particles.emit(gun.pivot() + Vector2(cos(a), sin(a)) * w.reach * 0.9,
		{count = 2, speed = 12, life = 0.18, color = [w.color, Color.WHITE]})
