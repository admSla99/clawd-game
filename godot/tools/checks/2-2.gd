extends RefCounted

## 2-2 GPU Forge (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd: c.ok(),
## await c.frames(), c.current_scene, c.enemies_of(), c.bugs(), await c.drive(), ...).

const TITLE := "2-2 GPU Forge: the racks-and-GPUs motif, armed start and full-jump fit"
const TILE := 16
## The top of the floor (row 19) and of the spike beds on it.
const FLOOR := 19 * TILE


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	m.load_level("2-2")
	await c.frames(3)
	c.ok(m.info.theme == "forge" and int(m.info.world) == 2, "2-2 is a world-2 level in the forge theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_forge.gdshader"),
		"the forge motif (server racks and GPU monoliths) is behind the level")
	var pal: Dictionary = load("res://scripts/themes.gd").palette("forge")
	c.ok(m.motif.material.get_shader_parameter("haze_color") == Vector3(pal.haze.r, pal.haze.g, pal.haze.b)
		and m.motif.material.get_shader_parameter("line_color") == Vector3(pal.ray.r, pal.ray.g, pal.ray.b),
		"in the theme's haze, with LEDs and hot dies in its ray colour")
	c.ok(p.armed and m.gun.armed, "Clawd starts armed")
	var turrets: Array = c.enemies_of("res://scripts/turret.gd")
	c.ok(turrets.size() == 6 and turrets.filter(func(t): return t.ceiling).size() == 5
		and c.enemies_of("res://scripts/drone.gd").size() == 3 and c.enemies_of("res://scripts/rate_limiter.gd").size() == 3
		and c.enemies_of("res://scripts/shield_bot.gd").size() == 2 and c.bugs().size() == 3
		and c.enemies_of("res://scripts/spam_bot.gd").is_empty(),
		"its enemies: 5 ceiling turrets and 1 floor turret, 3 drones, 3 rate limiters, 2 shield bots, 3 bugs")
	var sign_script := load("res://scripts/sign.gd")
	var signs: Array = m.level.get_children().filter(func(n): return n.get_script() == sign_script)
	c.ok(signs.size() == 1 and signs[0].text.begins_with("RED VENTS BURN"), "its sign keeps the TS text")
	c.ok(m.sparks.size() == 5, "5 sparks")

	# Full jumps fit the map. The first spike bed (columns 45-76) is crossed on the two moving platforms.
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 1000
	var plats: Array = c.get_nodes_in_group("platforms").filter(func(n): return n.get_script() == load("res://scripts/moving_platform.gd"))
	plats.sort_custom(func(a, b): return a.x < b.x)
	c.ok(plats.size() == 2 and plats[0].axis == "h", "2 horizontal moving platforms over the first spike bed")
	p.pos = Vector2(44 * TILE + 4, FLOOR)
	p.vel = Vector2.ZERO
	await c.frames(10)
	var ride := {"stage": 0, "air": false, "fell": false}
	await c.drive(func(_i):
		var x: float = p.pos.x
		if p.on_ground and not p.riding and x > 45 * TILE - 9 and x < 77 * TILE + 9:
			ride.fell = true
			return null
		var target: float = [plats[0].x + 24, plats[1].x + 24, 79 * TILE][ride.stage]
		var landed: bool = (ride.stage < 2 and p.riding == plats[ride.stage]) or (ride.stage == 2 and p.on_ground and x > 77 * TILE + 9)
		if ride.air and landed:
			ride.air = false
			ride.stage += 1
			return null if ride.stage == 3 else []
		if not ride.air:
			# Jump once the next landing spot is close enough and coming closer.
			var edge: float = [45 * TILE, plats[0].x + 48, plats[1].x + 48][ride.stage]
			var next: float = [plats[0].x, plats[1].x, 77 * TILE][ride.stage]
			var closing: bool = [plats[0].dx < 0, plats[1].dx < plats[0].dx, plats[1].dx > 0][ride.stage]
			# Wait at the edge (riding along); the gaps never close below 5 tiles, so the hover carries him over.
			if next - x < 112 and closing:
				ride.air = true
				return ["jump", "right"]
			return ["right"] if x < edge - 12 else []
		# In the air: steer to the middle of the landing spot, hover (jump held) while falling short of it.
		var acts := []
		if x < target - 3:
			acts.append("right")
		elif x > target + 3:
			acts.append("left")
		if p.vel.y < 0 or x < target - 24:
			acts.append("jump")
		return acts, 1500)
	c.ok(ride.stage == 3 and not ride.fell, "full jumps cross the first spike bed on its moving platforms (reached %d of 3)" % ride.stage)

	# The second spike bed (columns 130-164) is crossed on an arch of one-way platforms, up to row 10 and down.
	# Supports from left to right: [left end, right end, top].
	var sup := [[0.0, 130.0 * TILE, FLOOR], [130.0 * TILE, 135.0 * TILE, 16.0 * TILE], [137.0 * TILE, 142.0 * TILE, 13.0 * TILE],
		[144.0 * TILE, 149.0 * TILE, 10.0 * TILE], [151.0 * TILE, 156.0 * TILE, 13.0 * TILE], [158.0 * TILE, 163.0 * TILE, 16.0 * TILE],
		[165.0 * TILE, 200.0 * TILE, FLOOR]]
	p.pos = Vector2(127 * TILE + 8, FLOOR)
	p.vel = Vector2.ZERO
	await c.frames(10)
	var st := {"on": 0, "best": 0, "fell": false}
	await c.drive(func(_i):
		var x: float = p.pos.x
		if p.on_ground and absf(p.pos.y - FLOOR) < 0.5 and x > 130 * TILE and x < 165 * TILE:
			st.fell = true
			return null
		if p.on_ground:
			for s in sup.size():
				if absf(p.pos.y - sup[s][2]) < 0.5 and x > sup[s][0] - 9 and x < sup[s][1] + 9:
					st.on = s
					st.best = maxi(st.best, s)
			if st.on == sup.size() - 1:
				return null
			return ["right", "jump"] if x > sup[st.on][1] - 10 else ["right"]
		var nxt: Array = sup[st.on + 1]
		var target: float = (nxt[0] + minf(nxt[1], nxt[0] + 48)) / 2
		var acts := []
		if x < target - 3:
			acts.append("right")
		elif x > target + 3:
			acts.append("left")
		if p.vel.y > 0 and x < target - 24:
			acts.append("jump")
		return acts, 1500)
	c.ok(st.best == sup.size() - 1 and not st.fell,
		"full jumps climb the arch of platforms over the second spike bed and down again (reached %d of %d)" % [st.best, sup.size() - 1])

	# The spark over the arch's top (column 146, row 7): a full jump from the top platform.
	var collected: Array = m.sparks.duplicate()
	p.pos = Vector2(146 * TILE + 8, 10 * TILE)
	p.vel = Vector2.ZERO
	await c.frames(10)
	await c.drive(func(i): return ["jump"] if i < 20 else (null if p.on_ground else []), 120)
	c.ok(m.sparks.count(true) > collected.count(true), "a full jump from the top of the arch takes its spark")

	# The spark in the nook over the middle rate limiter (columns 103-106, rows 6-9): it crashes down next to
	# Clawd, he jumps on it while it rests and rides it up into the nook.
	m.load_level("2-2")
	await c.frames(3)
	var limiter = null
	for e in c.get_nodes_in_group("enemies"):
		if e.get_script() == load("res://scripts/rate_limiter.gd") and absf(e.x - 104 * TILE) < 1:
			limiter = e
		else:
			e.remove()
	await c.frames(2)
	p.invuln = 1000
	p.pos = Vector2(104 * TILE - 6, FLOOR)
	p.vel = Vector2.ZERO
	collected = m.sparks.duplicate()
	var nook := {"step": 0, "rode": false}
	await c.drive(func(_i):
		if m.sparks.count(true) > collected.count(true):
			return null
		match nook.step:
			0:
				# Under its edge it shakes; step out of the way.
				if limiter.mode == &"shake":
					nook.step = 1
				return []
			1:
				if limiter.mode == &"rest":
					nook.step = 2
					return ["jump"]
				return ["left"] if p.pos.x > 103 * TILE - 12 else []
			2:
				# Up onto it while it rests.
				if p.riding == limiter:
					nook.rode = true
					nook.step = 3
					return []
				# A full jump, no hover: down onto its middle before it rises.
				var acts := ["jump"] if p.vel.y < 0 else []
				if p.pos.x < limiter.x + 14:
					acts.append("right")
				elif p.pos.x > limiter.x + 18:
					acts.append("left")
				return acts
			_:
				# Carried up into the nook; at the top, jump (the nook's ceiling stops a full jump) and steer over
				# the spark, a column left of where he stands.
				if limiter.mode == &"idle" and p.riding == limiter:
					return ["jump"]
				if not p.on_ground and p.pos.y < 11 * TILE:
					return ["left"] if p.pos.x > 104 * TILE + 8 else []
				return []
		return [], 600)
	c.ok(nook.rode, "Clawd gets onto the rate limiter while it rests")
	c.ok(m.sparks.count(true) > collected.count(true), "and rides it up into the nook with the spark")

	# The spark under the corrupted floor (columns 200-203): a pound breaks in, a full jump climbs out.
	collected = m.sparks.duplicate()
	p.pos = Vector2(202 * TILE, 16 * TILE)
	p.vel = Vector2.ZERO
	await c.drive(func(i):
		if i < 4:
			return []
		return ["down"] if i < 8 else (null if p.on_ground and p.pos.y > FLOOR + TILE else []), 120)
	c.ok(p.on_ground and absf(p.pos.y - 22 * TILE) < 0.5, "a pound breaks the corrupted floor and lands in the pocket below")
	c.ok(m.sparks.count(true) > collected.count(true), "where the spark is")
	var out := {"done": false}
	await c.drive(func(i):
		if i < 3:
			return []
		if i == 3:
			return ["jump"]
		if p.on_ground and p.pos.x > 204 * TILE:
			out.done = absf(p.pos.y - FLOOR) < 0.5
			return null
		return ["jump", "right"] if p.pos.y < FLOOR - 4 else ["jump"], 240)
	c.ok(out.done, "and a full jump climbs out of it")
	return true
