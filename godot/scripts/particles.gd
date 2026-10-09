class_name Particles
extends Node2D

## CPU particle list ported from src/render/particles.ts: squares that fly, fall, slow down with
## drag, fade out and shrink near the end of their life. Capped at 1500 like the TS version.

const MAX := 1500

var list: Array[Dictionary] = []


## Same options and defaults as Particles.emit() in TS: count 8, speed 80 (x0.4..1), life 0.5
## (x0.6..1), all directions unless `spread` is given, color picked at random from `colors`.
func emit(at: Vector2, o: Dictionary = {}) -> void:
	var colors: Array = o.get("color", [Color.WHITE])
	for i in o.get("count", 8):
		var angle: float = o.get("angle", 0.0) + (randf() * TAU if not o.has("spread") else (randf() - 0.5) * o.spread)
		var speed: float = o.get("speed", 80.0) * (0.4 + randf() * 0.6)
		var life: float = o.get("life", 0.5) * (0.6 + randf() * 0.4)
		list.append({
			"p": at,
			"v": Vector2(cos(angle), sin(angle)) * speed + Vector2(o.get("vx", 0.0), o.get("vy", 0.0)),
			"life": life,
			"max": life,
			"size": o.get("size", 1.0),
			"color": colors.pick_random(),
			"gravity": o.get("gravity", 0.0),
			"drag": o.get("drag", 0.0),
		})
	if list.size() > MAX:
		list = list.slice(list.size() - MAX)


func clear() -> void:
	list.clear()


func _physics_process(dt: float) -> void:
	if Game.frozen():
		return
	var alive: Array[Dictionary] = []
	for p in list:
		p.life -= dt
		if p.life <= 0:
			continue
		p.v.y += p.gravity * dt
		if p.drag:
			p.v *= maxf(0, 1 - p.drag * dt)
		p.p += p.v * dt
		alive.append(p)
	list = alive
	queue_redraw()


func _draw() -> void:
	for p in list:
		var t: float = p.life / p.max
		var s: float = p.size * (1.0 if t > 0.3 else 0.6)
		var c: Color = p.color
		c.a *= minf(1, t * 1.6)
		draw_rect(Rect2(p.p - Vector2(s, s) / 2, Vector2(s, s)), c)
