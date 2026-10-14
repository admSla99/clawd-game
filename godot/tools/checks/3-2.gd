extends RefCounted

## 3-2 Webhook Cliffs (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd).

const TITLE := "3-2 Webhook Cliffs: the cliffs motif, webhooks, a sub-agent to stand on, the plate puzzles"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var tools0: Array = progress.tools.duplicate()
	progress.grant_tool("hook")
	progress.grant_tool("agents")
	m.load_level("3-2")
	await c.frames(3)
	c.ok(m.info.theme == "cliffs" and m.info.music == "cliffs" and m.info.subAgents == true and m.info.plateHold["2"] == 2.5,
		"3-2 is in the cliffs theme; sub-agents are part of it; its 2-plates hold for 2.5 s")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_cliffs.gdshader"),
		"the cliffs motif (pillars, callbacks flying between them) is behind the level")
	var hooks: Array = c.enemies_of("res://scripts/webhook.gd")
	c.ok(hooks.size() == 3 and c.enemies_of("res://scripts/parser.gd").size() == 2 and c.enemies_of("res://scripts/drone.gd").size() == 3
		and c.enemies_of("res://scripts/turret.gd").size() == 1 and c.bugs().size() == 1, "its enemies: 3 webhooks, 2 parsers, 3 drones, a turret, a bug")
	var plates: Array = c.get_nodes_in_group("plates")
	var gates: Array = c.get_nodes_in_group("gates")
	c.ok(plates.size() == 3 and plates.filter(func(q): return q.digit == 2).size() == 2 and gates.size() == 2
		and plates.all(func(q): return q.cells == 2), "3 plates (one 1, two 2s, 2 tiles wide) and 2 gates")
	var gate_a = gates.filter(func(g): return g.letter == "a")[0]
	var gate_b = gates.filter(func(g): return g.letter == "b")[0]
	c.ok(not gate_a.open and not gate_b.open and m.level.tile(Vector2(36 * TILE + 8, 44 * TILE + 8)) == 0, "both gates start shut")

	for e in c.get_nodes_in_group("enemies"):
		if e.get_script() != load("res://scripts/webhook.gd"):
			e.remove()
	await c.frames(2)
	p.invuln = 1000
	m.gun.mouse_moved = -1_000_000

	# The first ledge (columns 14-24, 5 tiles up) needs a sub-agent to stand on: stand still, send one, step back,
	# hop onto it and jump to the ledge.
	m.echoes.reset()
	p.pos = Vector2(12 * TILE + 8, 80 * TILE)
	p.vel = Vector2.ZERO
	p.facing = 1
	var st := {"phase": 0, "t": 0, "best": 99999.0}
	await c.drive(func(i):
		st.best = minf(st.best, p.pos.y)
		match st.phase:
			0:
				if i > 190:
					st.phase = 1
					return ["agent"]
				return []
			1:
				# Back off a tile and a half.
				if p.pos.x < 10 * TILE + 8:
					st.phase = 2
					return []
				return ["left"]
			2:
				st.t += 1
				if st.t < 6:
					return []
				st.phase = 3
				return ["right", "jump"]
			3:
				if p.on_ground and p.riding != null:
					st.phase = 4
					st.t = 0
					return []
				return ["right"] if p.pos.x < 12 * TILE + 4 else ["jump"]
			4:
				st.t += 1
				if p.on_ground and p.pos.y <= 75 * TILE + 0.5:
					return null
				return ["right", "jump"] if st.t > 3 else []
		return [], 600)
	c.ok(p.on_ground and absf(p.pos.y - 75 * TILE) < 0.5,
		"standing on a sub-agent Clawd jumps onto the ledge a jump can't reach (%s)" % p.pos)

	# Plate 1 opens the ceiling's gate; a sub-agent left on it holds it.
	m.echoes.reset()
	var plate1 = plates.filter(func(q): return q.digit == 1)[0]
	p.pos = plate1.feet()
	p.vel = Vector2.ZERO
	await c.frames(6)
	c.ok(plate1.pressed and gate_a.open and m.level.tile(Vector2(36 * TILE + 8, 44 * TILE + 8)) == -1, "Clawd on plate 1 opens the ceiling's gate a")
	await c.frames(190)
	await c.drive(func(i): return ["agent"] if i < 2 else null, 3)
	p.pos = plate1.feet() + Vector2(5 * TILE, 0)
	await c.frames(6)
	c.ok(gate_a.open, "a sub-agent sent from the plate keeps it open while he goes")

	# Two plates of 2: one alone does nothing; a sub-agent on one, Clawd on the other opens gate b, and the hold
	# gives him 2.5 s to run through.
	m.echoes.reset()
	await c.frames(2)
	var twos: Array = plates.filter(func(q): return q.digit == 2)
	twos.sort_custom(func(a, b): return a.feet().x < b.feet().x)
	p.pos = twos[1].feet()
	p.vel = Vector2.ZERO
	await c.frames(6)
	c.ok(twos[1].pressed and not gate_b.open, "Clawd on one of the 2s alone: the gate stays shut")
	p.pos = twos[0].feet()
	await c.frames(190)
	await c.drive(func(i): return ["agent"] if i < 2 else null, 3)
	p.pos = twos[1].feet()
	await c.frames(6)
	c.ok(twos[0].pressed and twos[1].pressed and gate_b.open, "a sub-agent on the other opens gate b")
	st = {"through": false}
	await c.drive(func(i):
		if p.pos.x > 27 * TILE + 9:
			st.through = true
			return null
		return ["right"], 180)
	c.ok(st.through, "and the hold lets Clawd run through it in time (%s)" % p.pos)

	# A webhook: an anchor that moves; caught, it is stunned and harmless, and Clawd zips up to it.
	var wh = hooks[0]
	c.ok(wh.is_in_group("anchors") and wh.active and wh.hurtbox().has_area(), "a webhook is an anchor, and hurts to touch")
	wh.catch()
	await c.frames(2)
	c.ok(wh.mode == &"stunned" and not wh.hurtbox().has_area(), "caught by the hook it hangs stunned and harmless")
	var x0: Vector2 = wh.pos
	await c.frames(30)
	c.ok(wh.pos == x0, "and still")
	await c.frames(70)
	c.ok(wh.mode != &"stunned", "for %.1f s" % wh.STUN)
	# Clawd below it and near: it aims and dives.
	wh.mode = &"patrol"
	wh.cooldown = 0.0
	p.pos = wh.point() + Vector2(20, 70)
	var dove := false
	for i in 90:
		await c.physics_frame
		dove = dove or wh.mode == &"dive"
	c.ok(dove, "with Clawd near and below it, it dives at him")

	m.echoes.reset()
	progress.tools = tools0
	p.invuln = 0
	m.load_level("1-1")
	await c.frames(3)
	return true
