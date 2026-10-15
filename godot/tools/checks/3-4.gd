extends RefCounted

## 3-4 Timeout Ravine (a section of tools/check.gd, which runs every tools/checks/<id>.gd; `c` is check.gd).

const TITLE := "3-4 Timeout Ravine: the ravine motif, timeout anchors, a racing plate and a plate in a pit"
const TILE := 16


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var tools0: Array = progress.tools.duplicate()
	progress.grant_tool("hook")
	progress.grant_tool("agents")
	m.load_level("3-4")
	await c.frames(3)
	c.ok(m.info.theme == "ravine" and m.info.music == "ravine" and m.info.subAgents == true
		and m.info.plateHold["1"] == 3.5 and m.info.plateHold["2"] == 4.0, "3-4 is in the ravine theme, its plates hold 3.5 and 4 s")
	c.ok(m.motif.visible and m.motif.material.shader.resource_path.ends_with("motif_ravine.gdshader"),
		"the ravine motif (walls, clocks timing out, spinners) is behind the level")
	var anchors: Array = c.get_nodes_in_group("anchors").filter(func(a): return a.get_script().resource_path.ends_with("/anchor.gd"))
	var timeouts: Array = anchors.filter(func(a): return a.timeout)
	c.ok(timeouts.size() == 20 and anchors.size() - timeouts.size() == 5, "20 timeout anchors and 5 plain ones")
	c.ok(c.get_nodes_in_group("plates").size() == 3 and c.get_nodes_in_group("gates").size() == 2, "3 plates and 2 gates")
	# The gateway (after the playthrough, docs/prompt-tree-plan.md T3): past the old exit at column 221 a checkpoint
	# and a sign, a chasm of six timeout anchors with a turret on a pillar, drones and a webhook, then an arena.
	var past := func(n: Node) -> bool: return Px.of(n.position).x > 222 * TILE
	var later: Array = c.get_nodes_in_group("enemies").filter(past)
	var goal = m.level.get_node("Goal")
	c.ok(later.size() == 17 and timeouts.filter(past).size() == 6
		and m.level.get_children().any(func(n): return n.name.begins_with("Checkpoint") and past.call(n))
		and Px.of(goal.position).x > 330 * TILE and m.info.signs.size() == 4,
		"past the old exit: a checkpoint, 6 timeout anchors over a chasm, 17 enemies in the gateway, a 4th sign, the exit at the end")

	for e in c.get_nodes_in_group("enemies"):
		e.remove()
	await c.frames(2)
	p.invuln = 1000

	# A timeout anchor answers once: the zip works, then it goes quiet and the hook can't pick it; it comes back.
	var a = timeouts.filter(func(t): return t.feet().x < 20 * TILE)[0]
	m.gun.mouse_moved = -1_000_000
	p.pos = Vector2(12 * TILE, 18 * TILE)
	p.vel = Vector2.ZERO
	p.facing = 1
	await c.frames(4)
	# Up and to the right of him: thrown along that line the hook picks it.
	var angle: float = (a.point() - m.tool_call.hand()).angle()
	c.ok(m.tool_call.pick(angle) == a, "the hook picks the first timeout anchor")
	m.tool_call.candidate = a
	m.tool_call.throw(angle)
	var st := {"zip": false}
	for i in 90:
		await c.physics_frame
		st.zip = st.zip or p.state == &"zip"
		if st.zip and p.state != &"zip":
			break
	c.ok(st.zip and a.fuse > 0 and a.active, "it catches Clawd's hook and its fuse burns")
	await c.frames(int(a.FUSE * 60) + 4)
	c.ok(not a.active and a.gone > 0, "%.1f s later it times out" % a.FUSE)
	p.pos = Vector2(12 * TILE, 18 * TILE)
	p.vel = Vector2.ZERO
	await c.frames(4)
	c.ok(m.tool_call.pick((a.point() - m.tool_call.hand()).angle()) != a, "and the hook can't pick it while it is quiet")
	await c.frames(int(a.COME_BACK * 60) + 4)
	c.ok(a.active, "after %.0f s it answers again" % a.COME_BACK)

	# The racing plate: Clawd steps off, gate a stays open for 3.5 s, then shuts.
	var plate1 = c.get_nodes_in_group("plates").filter(func(q): return q.digit == 1)[0]
	var gate_a = c.get_nodes_in_group("gates").filter(func(g): return g.letter == "a")[0]
	p.pos = plate1.feet()
	await c.frames(4)
	p.pos = plate1.feet() + Vector2(-4 * TILE, 0)
	await c.frames(180)
	var still: bool = gate_a.open
	await c.frames(40)
	c.ok(still and not gate_a.open, "gate a stays open 3.5 s after Clawd steps off its plate")

	# The pit: Clawd alone can press only one of the two 2-plates.
	var twos: Array = c.get_nodes_in_group("plates").filter(func(q): return q.digit == 2)
	var gate_b = c.get_nodes_in_group("gates").filter(func(g): return g.letter == "b")[0]
	twos.sort_custom(func(x, y): return x.feet().y < y.feet().y)
	c.ok(twos[1].feet().y > twos[0].feet().y + 5 * TILE, "one 2-plate is on the cliff, the other down in the pit")
	p.pos = twos[1].feet()
	await c.frames(4)
	c.ok(twos[1].pressed and not gate_b.open, "the pit's plate alone leaves gate b shut")
	await c.frames(190)
	await c.drive(func(i): return ["agent"] if i < 2 else null, 3)
	p.pos = twos[0].feet()
	await c.frames(4)
	c.ok(gate_b.open, "a sub-agent in the pit and Clawd on the cliff open it")

	m.echoes.reset()
	progress.tools = tools0
	p.invuln = 0
	m.load_level("1-1")
	await c.frames(3)
	return true
