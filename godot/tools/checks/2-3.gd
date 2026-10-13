extends RefCounted

## 2-3 Prompt Injection Swamp (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is
## check.gd: c.ok(), await c.frames(), c.current_scene, c.enemies_of(), c.bugs(), await c.drive(), ...).

const TITLE := "2-3 Prompt Injection Swamp: the corrupted-pools motif, eight injectors and full-jump fit"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	m.load_level("2-3")
	await c.frames(3)
	c.ok(m.info.theme == "swamp" and int(m.info.world) == 2, "2-3 is in world 2, in the swamp theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_swamp.gdshader"),
		"the swamp motif (corrupted data pools, cables, bubbles of text) is behind the level")
	var pal: Dictionary = load("res://scripts/themes.gd").palette("swamp")
	c.ok(m.motif.material.get_shader_parameter("haze_color") == Vector3(pal.haze.r, pal.haze.g, pal.haze.b)
		and m.motif.material.get_shader_parameter("line_color") == Vector3(pal.ray.r, pal.ray.g, pal.ray.b),
		"in the theme's haze, with ripples and text in its ray colour")
	c.ok(p.armed and m.gun.armed, "Clawd starts armed")
	var injs: Array = c.enemies_of("res://scripts/injector.gd")
	c.ok(injs.size() == 8 and c.enemies_of("res://scripts/spam_bot.gd").size() == 4
		and c.enemies_of("res://scripts/drone.gd").size() == 1 and c.enemies_of("res://scripts/turret.gd").size() == 1
		and c.enemies_of("res://scripts/shield_bot.gd").size() == 1 and c.bugs().is_empty(),
		"its enemies: 8 injectors, 4 spam bots, a drone, a turret and a shield bot")
	var sign_script := load("res://scripts/sign.gd")
	var signs: Array = m.level.get_children().filter(func(n): return n.get_script() == sign_script)
	c.ok(signs.size() == 1 and signs[0].text.begins_with("PROMPT INJECTORS SPLIT INTO BUGS"), "its sign keeps the TS text")

	# Injectors out of Clawd's reach wait with their timer running out; their squash stops at the hop's, so
	# the blob keeps its ">_" (it used to flatten until building its mesh failed).
	await c.frames(300)
	var far: Array = injs.filter(func(e): return absf(e.pos.x - p.pos.x) > 260 and e.grounded)
	var kept := far.filter(func(e): return e.timer < -2.0 and e._body.mesh != null and e._body.mesh.get_aabb().size.y * TILE >= 11.0)
	c.ok(far.size() >= 5 and kept.size() == far.size(), "injectors waiting out of range keep their shape")

	# Full jumps fit the map. Enemies go; supports are [left end, right end, top] in px, the controller runs to
	# a support's right end, jumps, steers to the next one's middle and hovers if it falls short.
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 0
	# The five pits between the pillars (columns 44-79), up and down by 1-2 tiles.
	var pillars := [[0.0, 44.0 * TILE, 17.0 * TILE], [48.0 * TILE, 52.0 * TILE, 15.0 * TILE],
		[56.0 * TILE, 60.0 * TILE, 14.0 * TILE], [64.0 * TILE, 68.0 * TILE, 15.0 * TILE],
		[72.0 * TILE, 76.0 * TILE, 13.0 * TILE], [80.0 * TILE, 90.0 * TILE, 17.0 * TILE]]
	var r: Dictionary = await _climb(c, p, Vector2(40 * TILE + 8, 17 * TILE), pillars)
	c.ok(r.best == 5 and not r.fell, "full jumps cross the five pits between the pillars (reached %d of 5)" % r.best)
	# The one-way steps (columns 92-108) up to the spark on the top one.
	var collected: int = m.sparks.count(true)
	var stairs := [[80.0 * TILE, 91.0 * TILE, 17.0 * TILE], [92.0 * TILE, 97.0 * TILE, 13.0 * TILE],
		[98.0 * TILE, 103.0 * TILE, 10.0 * TILE], [104.0 * TILE, 106.0 * TILE, 7.0 * TILE]]
	r = await _climb(c, p, Vector2(86 * TILE, 17 * TILE), stairs)
	await c.frames(10)
	c.ok(r.best == 3 and not r.fell and m.sparks.count(true) == collected + 1,
		"and climb the one-way steps to the spark on the top one")

	# The spike bed (columns 136-173) on its two moving platforms and the ledge at 169-171: a jump when the
	# next landing comes close, like the last gap of 1-1.
	var plats: Array = c.get_nodes_in_group("platforms")
	plats.sort_custom(func(a, b): return a.x < b.x)
	c.ok(plats.size() == 2 and plats.all(func(q): return q.axis == "h"), "2 horizontal moving platforms over the spikes")
	p.pos = Vector2(134 * TILE, 17 * TILE)
	p.vel = Vector2.ZERO
	await c.frames(10)
	var hp: int = p.hearts
	var st := {"stage": 0, "air": false, "fell": false}
	await c.drive(func(_i):
		var s: int = st.stage
		var ledge := 169.0 * TILE
		var target: float = [plats[0].x, plats[1].x, ledge, 174.0 * TILE][s]
		var edge: float = [136.0 * TILE, plats[0].x + 48, plats[1].x + 48, ledge + 48][s]
		var closing: bool = [plats[0].dx < 0, plats[1].dx < plats[0].dx, plats[1].dx > 0, true][s]
		var on_target: bool = (s < 2 and p.riding == plats[s]) or (s == 2 and p.on_ground and absf(p.pos.y - 14 * TILE) < 0.5
			and p.pos.x > ledge - 9) or (s == 3 and p.on_ground and p.pos.x > 174 * TILE)
		if p.hearts < hp or (p.pos.y > 16 * TILE and p.pos.x > 136 * TILE and p.pos.x < 174 * TILE):
			st.fell = true
			return null
		if st.air and on_target:
			st.air = false
			st.stage += 1
			return null if st.stage == 4 else []
		if not st.air:
			if target - edge < [64.0, 130.0, 100.0, 200.0][s] and closing and p.on_ground:
				st.air = true
				return ["jump", "right"]
			return ["right"] if p.pos.x < edge - (20 if s == 0 else 10) else []
		# Hover while falling short; steer to the middle of a 3-tile landing, so Clawd does not slide off it.
		var acts := ["jump"] if p.vel.y > 0 and p.pos.x < target + 8 else []
		if p.pos.x < target + 18:
			acts.append("right")
		elif s < 3 and p.pos.x > target + 30:
			acts.append("left")
		return acts, 1500)
	c.ok(st.stage == 4 and not st.fell, "full jumps cross the spike bed on the two platforms and the ledge (stage %d of 4)" % st.stage)

	# The spark under the corrupted floor (columns 214-217): a pound breaks in, a full jump climbs out.
	collected = m.sparks.count(true)
	p.pos = Vector2(215 * TILE + 8, 14 * TILE)
	p.vel = Vector2.ZERO
	await c.drive(func(i):
		if i < 4:
			return []
		return ["down"] if i < 8 else (null if p.on_ground and p.pos.y > 18 * TILE else []), 120)
	c.ok(p.on_ground and absf(p.pos.y - 20 * TILE) < 0.5, "a pound breaks the corrupted floor and lands in the pocket below")
	await c.frames(10)
	c.ok(m.sparks.count(true) == collected + 1, "where the spark is")
	var out := {"done": false}
	await c.drive(func(i):
		if i < 3:
			return []
		if i == 3:
			return ["jump"]
		if p.on_ground and p.pos.x > 218 * TILE:
			out.done = absf(p.pos.y - 17 * TILE) < 0.5
			return null
		return ["jump", "right"] if p.pos.y < 17 * TILE - 4 else ["jump"], 240)
	c.ok(out.done, "and a full jump climbs out of it to the exit")
	return true


## Drives Clawd from `start` along `sup` ([left end, right end, top] px, left to right): {best, fell}.
func _climb(c, p, start: Vector2, sup: Array) -> Dictionary:
	p.pos = start
	p.vel = Vector2.ZERO
	await c.frames(10)
	var last: int = sup.size() - 1
	var st := {"on": 0, "best": 0, "fell": false}
	await c.drive(func(_i):
		var x: float = p.pos.x
		if p.pos.y > 18 * TILE:
			st.fell = true
			return null
		if p.on_ground:
			for s in sup.size():
				if absf(p.pos.y - sup[s][2]) < 0.5 and x > sup[s][0] - 9 and x < sup[s][1] + 9:
					st.on = s
					st.best = maxi(st.best, s)
			if st.on == last:
				return null
			return ["right", "jump"] if x > sup[st.on][1] - 10 else ["right"]
		var target: float = (sup[st.on + 1][0] + minf(sup[st.on + 1][1], sup[st.on + 1][0] + 48)) / 2
		var acts := []
		if x < target - 3:
			acts.append("right")
		elif x > target + 3:
			acts.append("left")
		if p.vel.y > 0 and x < target - 24:
			acts.append("jump")
		return acts, 900)
	return st
