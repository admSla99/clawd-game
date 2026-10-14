extends RefCounted

## 3-3 The Sandbox (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd).

const TITLE := "3-3 The Sandbox: the sandbox motif, brittle crates, Retry Loops and their red gate"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var tools0: Array = progress.tools.duplicate()
	progress.grant_tool("hook")
	m.load_level("3-3")
	await c.frames(3)
	c.ok(m.info.theme == "sandbox" and m.info.music == "sandbox", "3-3 is in the sandbox theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_sandbox.gdshader"),
		"the sandbox motif (container stacks built and torn down) is behind the level")
	var loops: Array = c.enemies_of("res://scripts/retry_loop.gd")
	c.ok(loops.size() == 3 and c.enemies_of("res://scripts/parser.gd").size() == 2 and c.bugs().size() == 1
		and c.enemies_of("res://scripts/shield_bot.gd").size() == 1 and c.enemies_of("res://scripts/turret.gd").size() == 1
		and c.enemies_of("res://scripts/drone.gd").size() == 2 and c.enemies_of("res://scripts/spam_bot.gd").size() == 1,
		"its enemies: 3 Retry Loops, 2 parsers, a bug, a shield bot, a turret, 2 drones, a spam bot")
	var crates: Array = c.get_nodes_in_group("brittle")
	c.ok(crates.size() == 212 and m.level.brittle.size() == 212, "212 brittle crates")
	var gate = c.get_nodes_in_group("gates")[0]
	c.ok(gate.letter == "z" and not gate.open and m.level.tile(Vector2(196 * TILE + 8, 19 * TILE + 8)) == 0, "the red gate z starts shut")

	for e in c.get_nodes_in_group("enemies"):
		if e.get_script() != load("res://scripts/retry_loop.gd"):
			e.remove()
	await c.frames(2)
	p.invuln = 1000

	# A crate is solid; three bullets break it.
	var wall := Vector2(14 * TILE + 8, 19 * TILE + 8)
	c.ok(m.level.tile(wall) == 0 and load("res://scripts/bullet.gd").blocked(m.level, wall), "a crate is solid and stops shots")
	var w = load("res://scripts/weapons.gd").get_def("blaster")
	for i in 3:
		load("res://scripts/bullet.gd").fire(m.level, wall + Vector2(-30, 0), 0.0, 380.0, w, 2.0)
		await c.frames(12)
	c.ok(m.level.tile(wall) == -1 and not m.level.brittle.has(Vector2i(14, 19)), "three shots break it")
	# A pound breaks the one under Clawd and he keeps falling.
	p.pos = Vector2(27 * TILE + 8, 12 * TILE - 40)
	p.vel = Vector2.ZERO
	await c.frames(4)
	await c.drive(func(i): return ["down"] if i < 3 else (null if i > 40 else []), 45)
	c.ok(not m.level.brittle.has(Vector2i(27, 12)) and p.pos.y > 12 * TILE + 4, "a pound smashes the crate under Clawd and he drops through")
	# An orb's blast breaks crates around it.
	var blast_at := Vector2(37 * TILE + 8, 17 * TILE + 8)
	m.explode(blast_at, 26.0, 1.0)
	await c.frames(2)
	c.ok(not m.level.brittle.has(Vector2i(37, 17)), "an explosion breaks the crates it reaches")
	# Zipping into a crate breaks it: an anchor behind the maze's wall.
	var a = c.add_anchor(m, Vector2(100 * TILE + 8, 16 * TILE + 8))
	p.pos = Vector2(83 * TILE + 8, 20 * TILE)
	p.vel = Vector2.ZERO
	p.facing = 1
	await c.frames(4)
	var column := [Vector2i(86, 18), Vector2i(86, 19)]
	var had: bool = column.all(func(t): return m.level.brittle.has(t))
	m.tool_call.target = a
	m.tool_call.state = m.tool_call.HELD
	p.start_zip(a.point() + Vector2(0, 12))
	for i in 90:
		await c.physics_frame
		if p.state != &"zip":
			break
	c.ok(had and column.all(func(t): return not m.level.brittle.has(t)) and p.pos.x > 90 * TILE, "zipping into a crate smashes it and Clawd goes on (%s)" % p.pos)
	a.queue_free()
	m.tool_call.reset()

	# A Retry Loop spawns bugs while Clawd is near, at most 3 alive; with every loop gone the red gate opens.
	var loop = loops[0]
	p.pos = loop.pos + Vector2(-60, 5 * TILE)
	p.vel = Vector2.ZERO
	loop.timer = 0.0
	await c.frames(3)
	c.ok(loop.spawned.size() == 1, "near a Retry Loop, it drops a bug")
	for i in 3:
		loop.timer = 0.0
		await c.frames(2)
	c.ok(loop.spawned.size() == 3, "no more than 3 of its own at once")
	for l in loops:
		c.ok(l.hit(&"shot", 100.0), "a loop can be destroyed")
	await c.frames(4)
	c.ok(c.get_nodes_in_group("retry_loops").is_empty() and gate.open and m.level.tile(Vector2(196 * TILE + 8, 19 * TILE + 8)) == -1,
		"with every Retry Loop gone the red gate opens")
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	progress.tools = tools0
	p.invuln = 0
	m.load_level("1-1")
	await c.frames(3)
	return true
