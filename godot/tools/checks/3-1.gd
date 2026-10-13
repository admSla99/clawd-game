extends RefCounted

## 3-1 Endpoint Canopy (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd).

const TITLE := "3-1 Endpoint Canopy: the canopy motif, the hook up the first wall, parsers"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var tools0: Array = progress.tools.duplicate()
	progress.grant_tool("hook")
	m.load_level("3-1")
	await c.frames(3)
	c.ok(m.info.theme == "canopy" and int(m.info.world) == 3 and m.info.music == "canopy", "3-1 is world 3's first level, in the canopy theme")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_canopy.gdshader"),
		"the canopy motif (trees, vines, endpoint lanterns) is behind the level")
	c.ok(p.armed and m.tool_call.available(), "Clawd starts armed, with the Tool Call")
	var parsers: Array = c.enemies_of("res://scripts/parser.gd")
	c.ok(parsers.size() == 5 and c.bugs().size() == 3 and c.enemies_of("res://scripts/drone.gd").size() == 4
		and c.enemies_of("res://scripts/shield_bot.gd").size() == 2 and c.enemies_of("res://scripts/spam_bot.gd").size() == 2
		and c.enemies_of("res://scripts/turret.gd").size() == 2, "its enemies: 5 parsers, 3 bugs, 4 drones, 2 shield bots, 2 spam bots, 2 turrets")
	c.ok(c.get_nodes_in_group("anchors").size() == 19, "19 anchors")
	var sign_script := load("res://scripts/sign.gd")
	var signs: Array = m.level.get_children().filter(func(n): return n.get_script() == sign_script)
	c.ok(signs.size() == 3 and signs[1].text.begins_with("TOOL CALL") and signs[2].text.begins_with("PARSERS"), "its 3 signs teach the hook and parsers")

	# The first wall (columns 18-26, 8 tiles high) is climbed with the hook: jump under the anchor, aim up, zip, hop
	# onto the top.
	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 1000
	m.gun.mouse_moved = -1_000_000
	p.pos = Vector2(14 * TILE + 8, 21 * TILE)
	p.vel = Vector2.ZERO
	await c.frames(10)
	var st := {"zipped": false, "thrown": -1}
	await c.drive(func(i):
		st.zipped = st.zipped or p.state == &"zip"
		if p.on_ground and p.pos.y <= 13 * TILE + 0.5:
			return null
		if i == 0:
			return ["jump", "up"]
		if not st.zipped and p.vel.y > -60 and st.thrown < 0:
			st.thrown = i
			return ["jump", "up", "tool"]
		return ["right", "jump"] if st.zipped and p.state != &"zip" else ["jump", "up"], 240)
	c.ok(st.zipped and p.on_ground and absf(p.pos.y - 13 * TILE) < 0.5 and p.pos.x > 18 * TILE,
		"a jump, the hook straight up and a zip get Clawd onto the wall that a jump can't (%s)" % p.pos)

	# A parser: shots glance off its shell, the hook tears it off, then it can be shot.
	var pr = load("res://scripts/parser.gd").new()
	m.level.add_child(pr)
	pr.pos = Vector2(70 * TILE, 21 * TILE)
	await c.frames(2)
	c.ok(pr.blocks_direction(Vector2.RIGHT) and pr.blocks_direction(Vector2.DOWN) and not pr.hit(&"stomp", 4) and pr.hp == 4.0,
		"an armoured parser: shots glance off from every side, stomps only clank")
	c.ok(pr.hook_hit(Vector2.RIGHT) and not pr.armoured and not pr.blocks_direction(Vector2.RIGHT) and not pr.hook_hit(Vector2.RIGHT),
		"the hook tears its shell off (once)")
	c.ok(pr.hit(&"shot", 2.0) and pr.hp == 2.0, "bare, it takes damage")
	await c.frames(10)
	var x0: float = pr.pos.x
	await c.frames(30)
	c.ok(absf(pr.pos.x - x0) > 30 * 0.5 * 0.8, "and scurries twice as fast")
	pr.queue_free()
	progress.tools = tools0
	p.invuln = 0
	m.load_level("1-1")
	await c.frames(3)
	return true
