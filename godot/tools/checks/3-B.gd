extends RefCounted

## 3-B The Router (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd).

const TITLE := "3-B The Router: firewall, hook, packets, loopback, timeout storm, WORLD 3 CLEAR"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var snd = c.root.get_node("Sound")
	var tools0: Array = progress.tools.duplicate()
	progress.grant_tool("hook")
	m.load_level("3-B")
	await c.frames(3)
	var b = m.boss
	c.ok(m.info.theme == "router" and b != null and b.get_script() == load("res://scripts/router.gd") and b.TITLE == "THE ROUTER"
		and b.hp == 120.0 and b.max_hp == 120.0 and not b.health_bar, "3-B: the Router, 120 hp on the boss bar")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_router.gdshader"),
		"the router motif (a network with packets on its links) is behind the arena")
	var anchors: Array = c.get_nodes_in_group("anchors")
	c.ok(anchors.size() == 6 and b in anchors, "five anchors in the arena, and the Router is one too")
	c.ok(b.mode == &"intro" and not b.hit(&"shot", 5) and b.hp == 120.0 and not b.hurtbox().has_area(),
		"it can't be hurt during its intro, and touching it never hurts")
	p.invuln = 1000
	for i in 200:
		await c.physics_frame
		if b.mode != &"intro":
			break
	await c.frames(1)
	c.ok(b.mode != &"intro", "the intro ends")

	# The firewall: shots glance off; three catches of the hook expose the core.
	c.ok(b.firewall == 3 and b.blocks_direction(Vector2.RIGHT) and not b.hit(&"shot", 5) and b.hp == 120.0,
		"behind its firewall shots glance off it")
	c.ok(b.active, "the hook can catch it")
	for i in 3:
		b.catch()
	c.ok(b.firewall == 0 and b.exposed > 0 and not b.active and not b.blocks_direction(Vector2.RIGHT), "three catches tear the firewall off")
	c.ok(b.hit(&"shot", 5) and b.hp == 115.0, "and the exposed core takes damage")
	b.exposed = 0.02
	await c.frames(3)
	c.ok(b.firewall == 3 and b.blocks_direction(Vector2.RIGHT), "%.0f s later the firewall is back" % b.EXPOSED_TIME)

	# Routing: a packet runs to a port, which fires a burst.
	var shots := func() -> Array: return c.enemies_of("res://scripts/code_shot.gd")
	for s in shots.call():
		s.remove()
	b.mode = &"idle"
	b.timer = 0.0
	b.packets.clear()
	await c.frames(2)
	c.ok(b.packets.size() == 1, "it sends a packet down a cable")
	for i in 90:
		await c.physics_frame
		if shots.call().size() >= 2:
			break
	c.ok(shots.call().size() >= 2, "the port it reaches fires a burst (%d shots)" % shots.call().size())

	# Phase 1: rerouting, the firewall up again; a loopback echo hurts Clawd.
	b.firewall = 0
	b.exposed = 2.0
	b.hit(&"shot", b.hp - 79.0)
	c.ok(b.phase == 1 and b.mode == &"reroute" and b.firewall == 3 and b.exposed == 0.0, "at 2/3 of its hp it reroutes, the firewall back up")
	# Clawd stands still for 3 s, so the whole recording is where he stands.
	p.pos = Vector2(20 * TILE, 15 * TILE)
	await c.frames(200)
	p.invuln = 0
	b._loopback()
	var echo = c.get_nodes_in_group("echoes").filter(func(e): return e.hostile)
	var hearts0: int = p.hearts
	for i in 30:
		await c.physics_frame
		if p.hearts < hearts0:
			break
	c.ok(not echo.is_empty() and p.hearts < hearts0, "a loopback echo replays Clawd's last moves and hurts him")
	p.invuln = 1000
	await c.frames(260)
	c.ok(not echo.is_empty() and not is_instance_valid(echo[0]), "then it is gone")

	# Phase 2: the timeout storm.
	b.mode = &"idle"
	b.firewall = 0
	b.exposed = 2.0
	b.hit(&"shot", b.hp - 39.0)
	var plain: Array = c.get_nodes_in_group("anchors").filter(func(a): return a != b)
	c.ok(b.phase == 2 and plain.all(func(a): return a.timeout), "at 1/3 it starts the timeout storm: the anchors time out")
	c.ok(m.level.tile(Vector2(3 * TILE + 8, 14 * TILE + 8)) == 2 and m.level.tile(Vector2(36 * TILE + 8, 14 * TILE + 8)) == 2,
		"and the floor's edges turn to spikes")

	# Down: the exit opens, WORLD 3 CLEAR, the end.
	b.mode = &"idle"
	b.firewall = 0
	b.exposed = 2.0
	c.ok(b.hit(&"shot", 100.0) and b.mode == &"dead" and not b.fighting(), "its last hit point: CONNECTION RESET")
	for i in 240:
		await c.physics_frame
		if m.boss == null:
			break
	var goal = m.level.get_node_or_null("Goal")
	c.ok(m.boss == null and goal != null and m.overlay.popups.any(func(q): return q.text == "THE ROUTER IS DOWN"),
		"it goes down: THE ROUTER IS DOWN, the exit opens")
	m.reach_goal(goal)
	for i in 180:
		await c.physics_frame
		if not m.overlay.results.is_empty():
			break
	var res: Dictionary = m.overlay.results
	c.ok(res.get("title", "") == "WORLD 3 CLEAR" and res.get("note", "") == "THANKS FOR PLAYING!"
		and String(res.get("note_text", "")).begins_with("The Router is down."), "the results: WORLD 3 CLEAR, THANKS FOR PLAYING!")
	progress.tools = tools0
	p.invuln = 0
	m.load_level("1-1")
	await c.frames(3)
	return true
