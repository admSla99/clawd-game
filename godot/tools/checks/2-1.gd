extends RefCounted

## 2-1 Merge Conflict Mesa (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd:
## c.ok(), await c.frames(), c.current_scene, c.enemies_of(), c.bugs(), await c.drive(), ...). The template for the
## other levels' sections.

const TITLE := "2-1 Merge Conflict Mesa: the diff-strata motif, armed start and full-jump fit"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	m.load_level("2-1")
	await c.frames(3)
	c.ok(m.info.theme == "mesa" and int(m.info.world) == 2, "2-1 is world 2's first level, in the mesa theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_mesa.gdshader"),
		"the mesa motif (diff strata with conflict seams) is behind the level")
	var pal: Dictionary = load("res://scripts/themes.gd").palette("mesa")
	c.ok(m.motif.material.get_shader_parameter("haze_color") == Vector3(pal.haze.r, pal.haze.g, pal.haze.b)
		and m.motif.material.get_shader_parameter("line_color") == Vector3(pal.ray.r, pal.ray.g, pal.ray.b),
		"in the theme's haze, with seams in its ray colour")
	c.ok(p.armed and m.gun.armed, "Clawd starts armed")
	c.ok(c.enemies_of("res://scripts/spam_bot.gd").size() == 2 and c.enemies_of("res://scripts/drone.gd").size() == 4
		and c.enemies_of("res://scripts/turret.gd").size() == 2 and c.enemies_of("res://scripts/shield_bot.gd").size() == 2
		and c.bugs().size() == 7, "its enemies: 7 bugs, 2 spam bots, 4 drones, 2 turrets, 2 shield bots")
	var sign_script := load("res://scripts/sign.gd")
	var signs: Array = m.level.get_children().filter(func(c): return c.get_script() == sign_script)
	c.ok(signs.size() == 4 and signs[0].text.begins_with("AIM WITH THE MOUSE") and signs[2].text.begins_with("SHIELD BOTS"),
		"its 4 signs keep the TS texts (they match the port's controls)")

	# Full jumps fit the map: the pit at columns 83-98 is crossed on its one-way platforms (86-88, 92-94).
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 1000
	p.pos = Vector2(79 * TILE + 8, 17 * TILE)
	p.vel = Vector2.ZERO
	await c.frames(10)
	# Supports from left to right: [left end, right end, top]; the controller runs to the edge, jumps, steers
	# to the next one's middle and hovers if it falls short.
	var sup := [[0.0, 83.0 * TILE, 17.0 * TILE], [86.0 * TILE, 89.0 * TILE, 14.0 * TILE],
		[92.0 * TILE, 95.0 * TILE, 14.0 * TILE], [99.0 * TILE, 130.0 * TILE, 17.0 * TILE]]
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
			if st.on == 3:
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
	c.ok(st.best == 3 and not st.fell, "a full jump crosses the pit on its two platforms (reached %d of 3)" % st.best)

	# The spark under the corrupted floor (columns 150-153): a pound breaks in, a full jump climbs out.
	var collected: Array = m.sparks.duplicate()
	p.pos = Vector2(152 * TILE, 14 * TILE)
	p.vel = Vector2.ZERO
	await c.drive(func(i):
		if i < 4:
			return []
		return ["down"] if i < 8 else (null if p.on_ground and p.pos.y > 18 * TILE else []), 120)
	c.ok(p.on_ground and absf(p.pos.y - 20 * TILE) < 0.5, "a pound breaks the corrupted floor and lands in the pocket below")
	c.ok(m.sparks.count(true) > collected.count(true), "where the spark is")
	var out := {"done": false}
	await c.drive(func(i):
		if i < 3:
			return []
		if i == 3:
			return ["jump"]
		if p.on_ground and p.pos.x > 154 * TILE:
			out.done = absf(p.pos.y - 17 * TILE) < 0.5
			return null
		# Jump held all the way: past the apex Clawd hovers while he moves over the edge.
		return ["jump", "right"] if p.pos.y < 17 * TILE - 4 else ["jump"], 240)
	c.ok(out.done, "and a full jump climbs out of it")
	return true
