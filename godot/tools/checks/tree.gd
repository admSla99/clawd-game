extends RefCounted

## The prompt tree redrawn for the endgame (docs/endgame-plan.md E9; a section of tools/check.gd, `c` is check.gd):
## its size and shape, every stat it gives read somewhere, the new stats (life, armour and evasion per cent,
## elemental resistances, regeneration, leech, ailments on enemies and avoiding them on Clawd), the keystones
## Temperature 0., Robustness., Air-gapped. and Gradient Leech., Agentic loop., an old save's points given back, and
## the window's small map and the start's list.

const TITLE := "the prompt tree to 137 nodes: endgame stats, leech, ailments, new keystones (docs/endgame-plan.md E9)"


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var prompts = load("res://scripts/prompts.gd")
	var stats = load("res://scripts/stats.gd")
	var gear = load("res://scripts/gear.gd")
	var screen = load("res://scripts/tree_screen.gd")
	var experience = load("res://scripts/experience.gd")
	var saved := {"tree": progress.tree.duplicate(), "gear": progress.gear.duplicate(true), "level": progress.char_level,
		"bought": progress.points_bought, "tools": progress.tools.duplicate(), "upgrades": progress.upgrades.duplicate()}
	progress.upgrades = {}
	progress.gear = {}
	gear.invalidate()
	progress.char_level = 10
	# The tree: big, all joined, nodes apart, more of them than points at level 100.
	var nodes: Dictionary = prompts.NODES
	var kinds := {}
	for id in nodes:
		kinds[nodes[id].kind] = kinds.get(nodes[id].kind, 0) + 1
	c.ok(nodes.size() >= 120 and prompts.joined(nodes.keys()).size() == nodes.size()
		and prompts.LINKS.all(func(l): return nodes.has(l[0]) and nodes.has(l[1])),
		"%d nodes (%s), all joined to the start through %d links" % [nodes.size(), kinds, prompts.LINKS.size()])
	var keystones: Array = nodes.keys().filter(func(id): return nodes[id].kind == "keystone")
	keystones.sort()
	c.ok(keystones == ["airgap", "expert", "gradleech", "orchestrator", "robust", "temp0"], "six keystones: %s" % [keystones])
	var closest := INF
	var ids: Array = nodes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			closest = minf(closest, (nodes[ids[i]].at as Vector2).distance_to(nodes[ids[j]].at))
	c.ok(closest >= 16, "no two nodes closer than 16 px (%.1f)" % closest)
	var sparks := 0
	for id in ["3-1", "3-2", "3-3", "3-4", "3-B"]:
		sparks += FileAccess.get_file_as_string("res://levels/%s.txt" % id).count("S")
	var most: int = experience.MAX_LEVEL - 1 + sparks + prompts.BUY_MAX
	c.ok(most < nodes.size(), "not everything: level 100, world 3's %d sparks and every bought point make %d points" % [sparks, most])
	var named := {}
	for s in screen.STAT_NAMES + screen.FLAG_NAMES:
		named[s[0]] = true
	var unnamed := []
	for id in nodes:
		for k in nodes[id].mods:
			if not named.has(k) and not unnamed.has(k):
				unnamed.append(k)
	c.ok(unnamed.is_empty(), "every stat a node gives is named in the start's list %s" % [unnamed])
	c.ok(nodes.keys().all(func(id): return screen.wrap_text(nodes[id].desc, 480 - 28 - 16).size() <= 2),
		"every node's text fits the card's two lines")
	# Life, armour, evasion, resistances, regeneration, leech.
	progress.tree = ["de_a1", "de_a2"]
	c.ok(is_equal_approx(stats.max_life(), 110.0), "+10% maximum life: 110 at level 10")
	progress.tree = ["de_a1", "de_a2", "airgap"]
	c.ok(is_equal_approx(stats.max_life(), 66.0) and stats.resistances(30).chaos == 100.0,
		"Air-gapped.: 40% less life (66), Corruption resistance 100 whatever the map's penalty")
	progress.tree = ["hardened", "stochastic"]
	c.ok(is_equal_approx(stats.armour(), 52.0) and is_equal_approx(stats.evasion(), 52.0), "Hardened weights. and Stochastic depth.: 52 armour, 52 evasion")
	progress.tree = ["hardened", "stochastic", "robust"]
	c.ok(is_equal_approx(stats.armour(), 104.0) and stats.evasion() == 0.0, "Robustness.: the evasion is armour (104), none left")
	progress.tree = ["de_m1", "guardrails"]
	c.ok(stats.resistances().fire == 11.0 and stats.resistances().lightning == 11.0 and stats.resistances().chaos == 0.0,
		"Red Teaming and Guardrails.: +11% to the three elements' resistances")
	progress.tree = ["su_a1", "su_a2", "selfheal"]
	c.ok(is_equal_approx(stats.max_life(), 104.0) and is_equal_approx(stats.regen(), 2.08), "Self-repair and Self-healing.: 2% of 104 life a second")
	progress.tree = ["su_a1", "su_a2", "selfheal", "gradleech", "su_l1", "su_l2", "gradflow"]
	c.ok(stats.regen() == 0.0 and is_equal_approx(stats.leech(), 0.02), "Gradient Leech.: no regeneration; 2% leech")
	# Critical strikes and Temperature 0.
	progress.gear = {"weapon": {"base": "blaster", "rarity": "normal", "ilvl": 1, "affixes": []}}
	gear.invalidate()
	progress.tree = ["pr_a1", "pr_a2"]
	c.ok(is_equal_approx(stats.crit_chance(), 0.065) and is_equal_approx(stats.damage_mult(), 1.0), "Top-p Sampling: the blaster's 5% critical chance 30% more")
	progress.tree = ["pr_a1", "pr_a2", "temp0"]
	c.ok(stats.crit_chance() == 0.0 and is_equal_approx(stats.damage_mult(), 1.3), "Temperature 0.: no critical strikes, 30% more damage")
	progress.gear = {}
	gear.invalidate()
	# Elements and ailments on enemies.
	progress.tree = ["el_a1", "el_a2", "multimodal"]
	var ele: Dictionary = stats.elements()
	c.ok(ele.size() == 3 and is_equal_approx(ele.fire, 0.048) and is_equal_approx(stats.ele_mult(), 1.144),
		"Multimodal. adds 4% of each element, Multimodal Input 20% more of them")
	progress.tree = ["el_l2", "runaway", "el_m2", "coldstart", "el_o2", "surge"]
	c.ok(is_equal_approx(stats.ignite_chance(), 0.3125) and is_equal_approx(stats.shock_chance(), 0.42)
		and is_equal_approx(stats.freeze_share(), 0.2 / 1.9) and is_equal_approx(stats.burn_mult(), 1.4)
		and is_equal_approx(stats.ailment_time(), 1.35), "ignites and shocks more often, freezes easier, burns harder, all 35% longer")
	m.endgame = true
	m.load_level("1-1")
	await c.frames(3)
	c.flat_ground(m)
	p.invuln = 1000
	p.pos = Vector2(10 * c.TILE, 16 * c.TILE)
	p.vel = Vector2.ZERO
	var bug = load("res://scenes/bug.tscn").instantiate()
	m.level.add_child(bug)
	bug.pos = Vector2(40 * c.TILE, 16 * c.TILE)
	bug.hp = 100.0
	bug.max_hp = 100.0
	bug.afflict({"cold": 12.0})
	c.ok(is_equal_approx(bug.freeze_t, 0.6 * 1.35) and is_equal_approx(bug.chill_t, 1.5 * 1.35), "12% of its life as Latency freezes it (20% without), 35% longer")
	for i in 200:
		if bug.burn_t > 0:
			break
		bug.afflict({"fire": 10.0})
	c.ok(is_equal_approx(bug.burn_t, 2.0 * 1.35) and is_equal_approx(bug.burn_dps, 10.0 * 0.6 * 1.4 / 2.0), "and burns 40%% harder (%.1f a second)" % bug.burn_dps)
	# Leech: Clawd's hits fill the pool, his sub-agents' do not; it heals at 10% of life a second, twice that with
	# Gradient Leech.
	progress.tree = ["su_l1", "su_l2", "gradflow"]
	m.load_level("1-1")
	await c.frames(3)
	c.flat_ground(m)
	p.invuln = 1000
	p.pos = Vector2(10 * c.TILE, 16 * c.TILE)
	bug = load("res://scenes/bug.tscn").instantiate()
	m.level.add_child(bug)
	bug.pos = Vector2(40 * c.TILE, 16 * c.TILE)
	bug.hp = 1000.0
	p.life = 50.0
	bug.hit(&"shot", 100.0)
	bug.hit(&"shot", 100.0, false)
	c.ok(is_equal_approx(p.leech, 0.02) and is_equal_approx(p.leech_pool, 2.0), "a 100 hit leeches 2 life; a sub-agent's none")
	await c.frames(40)
	c.ok(is_equal_approx(p.life, 52.0) and p.leech_pool == 0.0, "the pool heals Clawd (%.2f life)" % p.life)
	progress.tree = ["su_l1", "su_l2", "gradflow", "su_m1", "su_m2", "su_m3", "gradleech"]
	m.load_level("1-1")
	await c.frames(3)
	p.invuln = 1000
	await c.physics_frame
	p.life = 10.0
	p.leech_pool = 40.0
	await c.physics_frame
	var heal: float = p.life - 10.0
	var want: float = p.max_life * p.LEECH_RATE * 2.0 / Engine.physics_ticks_per_second
	c.ok(p.leech_fast and p.regen == 0.0 and absf(heal - want) < 0.01, "Gradient Leech.: twice as fast (%.3f a frame), no regeneration" % heal)
	# Avoiding ailments, Agentic loop., Air-gapped.
	progress.tree = ["su_a1", "su_a2", "selfheal", "su_r1", "su_r2", "graceful", "su_o2"]
	m.load_level("1-1")
	await c.frames(3)
	var avoid_ok: bool = is_equal_approx(p.avoid, 0.6)
	p.avoid = 1.0
	for i in 40:
		p._mitigate(10.0, "fire", false)
		p._mitigate(10.0, "cold", false)
	avoid_ok = avoid_ok and p.burn_t == 0.0 and p.chill_t == 0.0
	p.avoid = 0.0
	p._mitigate(10.0, "cold", false)
	c.ok(avoid_ok and p.chill_t > 0, "60% ailment avoidance; at 100% no hit ignites or chills")
	p.clear_ailments()
	progress.tree = ["tc_a1", "tc_a2", "ontask", "tc_m1", "tc_m2", "tc_m3", "agentloop"]
	m.load_level("1-1")
	await c.frames(3)
	p.invuln = 0
	p.state = &"zip"
	var life: float = p.life
	var zipped: bool = p.hurt(p.pos.x + 5)
	p.state = &"normal"
	c.ok(p.zip_guard and not zipped and p.life == life and p.hurt(p.pos.x + 5) and p.life < life, "Agentic loop.: no hit while zipping, as ever after")
	progress.tree = ["airgap"]
	m.load_level("1-1")
	await c.frames(3)
	p.invuln = 0
	life = p.life
	c.ok(not p.hurt(p.pos.x + 5, 30.0, false, "chaos") and p.life == life and p.hurt(p.pos.x + 5, 30.0, false) and p.life < life,
		"Air-gapped.: a Corruption hit does nothing, a physical one hurts")
	m.endgame = false
	p.invuln = 0
	# The window: a small map of the big tree (not of the Atlas's), a click on it moves the view; the start's list.
	m.load_level("1-1")
	await c.frames(3)
	var vp_size: Vector2i = m.subviewport.size
	m.subviewport.size = Vector2i(480, 270) + Vector2i.ONE * m.PAD * 2
	progress.tree = ["of_a1", "expert"]
	progress.tree_redrawn = true
	m.open_tree_in_level()
	await c.frames(2)
	var tree = m.tree
	var mini: Rect2 = tree.mini_rect()
	c.ok(mini.size.x > 40 and tree.field().encloses(mini) and tree.note.contains("REDRAWN") and not progress.tree_redrawn,
		"the prompt tree has a small map in the field's corner; after a new layout it says every point is back")
	var b: Rect2 = screen.bounds(prompts)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = mini.position + (nodes.robust.at - b.position) * screen.MINI_SCALE
	tree.handle(click)
	click.pressed = false
	tree.handle(click)
	await c.frames(10)
	c.ok(tree.field().has_point(tree.screen_of("robust")) and tree.sel == "root", "a click on it moves the view there (Robustness. in sight)")
	c.ok(tree.totals_lines() == ["+43% damage", "-1 heart(s)"], "the start's list: %s" % [tree.totals_lines()])
	c.ok(["robust", "airgap", "de_a1", "temp0", "agentloop", "orchestrator", "multimodal", "retrieval"].map(func(id): return screen.branch_of(prompts, id))
		== ["DEFENCE", "DEFENCE", "DEFENCE", "PRECISION", "TOOL CALL", "SUB-AGENTS", "ELEMENTS", "MOVEMENT & TOKENS"]
		and screen.branch_of(prompts, "root") == "", "the card names the selected node's branch")
	tree.open(true)
	c.ok(tree.mini_rect().size == Vector2.ZERO, "the Atlas's tree fits the field: no small map")
	m.close_tree_in_level()
	m.subviewport.size = vp_size
	await c.frames(2)
	# An old save: its tree is gone, every point back, said once.
	progress.tree = saved.tree
	progress.gear = saved.gear
	gear.invalidate()
	progress.char_level = saved.level
	progress.upgrades = saved.upgrades
	progress.save()
	progress.save_items()
	var real_path: String = progress.path
	progress.path = "user://progress_check_tree_%d.json" % OS.get_process_id()
	var f := FileAccess.open(progress.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"wallet": 10, "tree": ["dmg1", "concise"], "char_level": 5}))
	f.close()
	progress.load_file()
	var first: bool = progress.tree.is_empty() and progress.tree_redrawn and prompts.points_free() == 4
	progress.load_file()
	c.ok(first and not progress.tree_redrawn and progress.char_level == 5, "an old layout's nodes are refunded (4 points free), once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.items_path()))
	progress.path = real_path
	progress.load_file()
	progress.points_bought = saved.bought
	progress.tools = saved.tools
	m.play("1-1")
	await c.frames(3)
	return true
