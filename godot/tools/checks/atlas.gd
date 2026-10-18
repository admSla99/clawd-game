extends RefCounted

## The Atlas (docs/endgame-plan.md E8; a section of tools/check.gd, `c` is check.gd): tiers up to T16 in three
## worlds, their area levels, themes, chunks and enemies, the bosses of worlds 2 and 3, the Atlas's progress (a
## tier unlocks the next, maps drop no higher, points from tiers and rare maps), its tree and what it does in maps,
## the Atlas station and Tab in the tree's window.

const TITLE := "the Atlas: tiers T1-T16, worlds 2 and 3 as maps, their bosses, the Atlas's tree (docs/endgame-plan.md E8)"


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var maps = load("res://scripts/maps.gd")
	var gen = load("res://scripts/map_gen.gd")
	var atlas = load("res://scripts/atlas.gd")
	var items = load("res://scripts/items.gd")
	var currency = load("res://scripts/currency.gd")
	var saved := {"levels": progress.levels.duplicate(true), "maps_done": progress.maps_done.duplicate(), "atlas": progress.atlas.duplicate(),
		"bonus": progress.atlas_bonus.duplicate(), "level": progress.char_level, "xp": progress.xp}
	progress.maps_done = {}
	progress.atlas = []
	progress.atlas_bonus = []
	# Tiers, worlds, area levels, enemy life.
	c.ok(maps.MAX_TIER == 16 and [1, 5, 6, 10, 11, 16].map(func(t): return maps.world_of(t)) == [1, 1, 2, 2, 3, 3],
		"16 tiers: T1-5 world 1, T6-10 world 2, T11-16 world 3")
	var areas: Array = [1, 5, 6, 10, 11, 16].map(func(t): return maps.area_level(t))
	c.ok(areas == [32, 40, 43, 55, 59, 79], "area levels grow 2, 3 and 4 a tier by world: %s" % [areas])
	c.ok(is_equal_approx(maps.life_mult(40), pow(1.08, 16)) and is_equal_approx(maps.life_mult(79), pow(1.08, 16) * pow(1.045, 39)),
		"enemy life x%.1f at T5, x%.1f at T16 (slower growth past area level 40)" % [maps.life_mult(40), maps.life_mult(79)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	var themes_ok := true
	for t in [3, 7, 12, 16]:
		for i in 8:
			var it: Dictionary = maps.roll(t, rng)
			themes_ok = themes_ok and it.theme in maps.THEMES[maps.world_of(t)] and it.ilvl == maps.area_level(t) \
				and (it.rarity == "rare" or items.name_of(it).contains("%s Map T%d" % [maps.THEME_NAMES[it.theme], t]))
	c.ok(themes_ok, "a map takes a theme of its world's levels and its name (e.g. %s)" % items.name_of(maps.roll(12, rng, "normal")))
	# Chunks and enemies by world.
	var mids2: Array = gen.mids("world2")
	var mids3: Array = gen.mids("world3")
	var l7: Array = gen.layout(5, 7)
	var l16: Array = gen.layout(5, 16)
	c.ok(mids2.size() >= 8 and mids3.size() >= 8 and l7.slice(1, -1).all(func(n): return n in mids2) and l16.slice(1, -1).all(func(n): return n in mids3)
		and l16.size() == 2 + gen.MID_MIN + gen.MID_TIER / 2, "T7 maps are world 2's chunks (%d), T16 world 3's (%d), %d middle chunks at most" % [mids2.size(), mids3.size(), l16.size() - 2])
	var chars := func(rows: PackedStringArray) -> Dictionary:
		var out := {}
		for r in rows:
			for ch in r:
				if ch in "EFHTDIPWLRY":
					out[ch] = true
		return out
	var w2: Dictionary = chars.call(gen.generate(11, 8, 50.0))
	var w3: Dictionary = chars.call(gen.generate(11, 14, 50.0))
	c.ok(w2.has("I") and not w2.has("P") and w3.has("P") and not w3.has("T"), "world 2's maps have injectors, world 3's parsers %s %s" % [w2.keys(), w3.keys()])
	# Progress: a tier completed opens the next; maps drop no higher.
	rng.seed = 3
	c.ok(atlas.unlocked_tier() == 1 and maps.drop_tier(1, rng, 100.0) == 1 and atlas.points_total() == 0,
		"nothing completed: T1 open, a dropped map stays T1 however lucky")
	var gave: Array = atlas.complete(1, false)
	c.ok(gave == ["tier"] and atlas.unlocked_tier() == 2 and maps.drop_tier(1, rng, 100.0) == 2 and maps.drop_tier(5, rng, 100.0) == 5
		and atlas.points_total() == 1, "T1 completed: an Atlas point, T2 open, T1 maps drop T2 maps, a T5 one (old save) its own tier")
	c.ok(atlas.complete(1, true) == ["bonus"] and atlas.complete(2, true) == ["tier"] and atlas.points_total() == 3,
		"a rare map: a point for its world, once (3 points from T1, T2 and world 1's rare map)")
	# The tree.
	c.ok(atlas.toggle("emergence") == "far" and atlas.toggle("qty1") == "allocated" and atlas.stat("quantity") == 4.0
		and atlas.toggle("qty2") == "allocated" and atlas.toggle("qty1") == "holds" and atlas.points_free() == 1,
		"its tree: next to the start first, a point a node, a node others hang on stays")
	var mg: Dictionary = maps.roll(3, rng, "rare")
	var mods: int = mg.affixes.size()
	c.ok(is_equal_approx(maps.run_quantity(mg), 8.0 * mods + 8.0) and is_equal_approx(maps.run_rarity(mg), 5.0 * mods),
		"a map's run gets its mods' quantity and the Atlas's (+%d%%)" % maps.run_quantity(mg))
	progress.atlas = ["qty1", "qty2", "scaling", "emergence", "drop1", "drop2", "selfplay", "xp1", "xp2", "redundancy", "warm", "orb1", "orb2", "distill"]
	progress.maps_done = {}
	for t in range(1, 15):
		progress.maps_done[str(t)] = 1
	c.ok(is_equal_approx(maps.run_quantity(mg), 16.0 * mods + 18.0) and m.map_portals() == 8 and atlas.stat("pack") == 10.0
		and atlas.orb_bonus() == {"distill": 200.0}, "Emergence doubles the mods' loot; Redundancy gives 8 portals; Scaling Laws more enemies")
	var picks := {}
	rng.seed = 4
	for i in 400:
		var id: String = currency.roll(rng, {"finetune": 100000.0})
		picks[id] = picks.get(id, 0) + 1
	c.ok(picks.get("finetune", 0) > 300, "an orb's bonus makes it likelier (%d fine-tunes in 400, 2 without)" % picks.get("finetune", 0))
	# A world 2 map: its theme and music, THE JAILBREAK.
	progress.levels = {"3-B": {"completed": true, "sparks": [], "agents": [], "best_time": null}}
	progress.char_level = 40
	progress.xp = 0
	var t7: Dictionary = maps.roll(7, rng, "normal")
	progress.maps_done.erase("7")
	m.show_hideout()
	await c.frames(3)
	m.start_map(t7)
	await c.frames(3)
	var boss = m.map_run.boss
	var life: float = maps.life_mult(maps.area_level(7))
	c.ok(m.level_id == "map" and m.info.theme == t7.theme and m.info.music == t7.theme and m.area_level == 46 and m.map_run.portals == 8
		and boss.get_script() == load("res://scripts/jailbreak.gd") and boss.TITLE == "THE JAILBREAK" and is_equal_approx(boss.hp, boss.LIFE * life)
		and boss.element == "chaos", "a T7 map: the %s theme and music, area level 46, 8 portals, THE JAILBREAK (%d hp)" % [t7.theme, boss.hp])
	for e in c.get_nodes_in_group("enemies"):
		if e != boss and e.pos.distance_to(boss.pos) < 400:
			e.remove()
	p.pos = boss.pos + Vector2(-120, 0)
	p.invuln = 1000
	await c.frames(2)
	var near_shots := func() -> int:
		return c.enemies_of("res://scripts/shot.gd").filter(func(s): return s.element == "chaos" and s.pos.distance_to(boss.pos) < 80).size()
	var shots_before: int = near_shots.call()
	boss.landings = boss.SPLIT_EVERY - 1
	boss._landed()
	await c.frames(1)
	var adds: Array = c.enemies_of("res://scripts/injector.gd").filter(func(e): return e != boss and e.no_loot)
	c.ok(near_shots.call() == shots_before + boss.SHOTS and adds.size() == 1,
		"a landing sprays %d corruption shots, and every third an injector that drops nothing" % boss.SHOTS)
	await c.frames(240)
	c.ok(boss.landings > boss.SPLIT_EVERY, "it hops at Clawd (%d landings in 4 s)" % boss.landings)
	var loot_before: int = c.get_nodes_in_group("loot").size()
	m.loot_rng.seed = 1
	for i in 30:
		var bug = load("res://scenes/bug.tscn").instantiate()
		bug.no_loot = true
		m.level.add_child(bug)
		bug.pos = p.pos + Vector2(40, 0)
		bug.hit(&"shot", 1000.0)
	await c.frames(2)
	c.ok(c.get_nodes_in_group("loot").size() == loot_before, "an enemy with no_loot drops nothing")
	boss.hit(&"shot", 1000000.0)
	await c.frames(3)
	var pops: Array = m.overlay.popups.map(func(pp): return pp.text)
	c.ok(m.map_run.done and progress.maps_done.get("7", 0) == 1 and atlas.unlocked_tier() == 15 and "MAP COMPLETE" in pops
		and "+1 ATLAS POINT · T8 OPEN" in pops, "its death completes the map and counts T7: +1 ATLAS POINT · T8 OPEN")
	m._end_map()
	# World 3: THE INFINITE LOOP hangs over its marker and fires rings.
	var t12: Dictionary = maps.roll(12, rng, "rare")
	progress.maps_done.erase("12")
	m.start_map(t12)
	await c.frames(3)
	boss = m.map_run.boss
	var marker = m.level.get_node("Boss")
	c.ok(boss.get_script() == load("res://scripts/infinite_loop.gd") and boss.TITLE == "THE INFINITE LOOP" and boss.element == "fire"
		and is_equal_approx(boss.pos.y, load("res://scripts/px.gd").of(marker.position).y - boss.RISE) and t12.theme in maps.THEMES[3],
		"a T12 map: world 3's %s theme, THE INFINITE LOOP hanging %d px over its spot" % [t12.theme, boss.RISE])
	for e in c.get_nodes_in_group("enemies"):
		if e != boss and e.pos.distance_to(boss.pos) < 400:
			e.remove()
	p.pos = boss.pos + Vector2(-150, 64)
	p.invuln = 1000
	boss.ring_t = 0.01
	await c.frames(2)
	var fire_shots: Array = c.enemies_of("res://scripts/shot.gd").filter(func(s): return s.element == "fire")
	c.ok(fire_shots.size() == boss.RING, "it fires a ring of %d overheat shots" % boss.RING)
	await c.frames(200)
	var spawned: Array = boss.spawned.filter(func(b): return is_instance_valid(b))
	c.ok(not spawned.is_empty() and spawned.all(func(b): return b.no_loot), "and drops bugs that drop nothing (%d)" % spawned.size())
	progress.atlas_bonus = []
	boss.hit(&"shot", 1000000.0)
	await c.frames(3)
	pops = m.overlay.popups.map(func(pp): return pp.text)
	c.ok(m.map_run.done and progress.atlas_bonus == [3] and pops.any(func(s): return s.begins_with("+1 ATLAS POINT · T13 OPEN"))
		and pops.any(func(s): return s.contains("WORLD 3'S RARE MAP")), "a new tier and world 3's first rare map: two Atlas points")
	m._end_map()
	# The Atlas station and Tab.
	m.show_hideout()
	await c.frames(3)
	var station = null
	for s in c.get_nodes_in_group("stations"):
		if s.kind == "atlas":
			station = s
	p.pos = station.feet()
	p.vel = Vector2.ZERO
	await c.frames(3)
	Input.action_press("pickup")
	await c.frames(2)
	Input.action_release("pickup")
	await c.frames(2)
	c.ok(m.tree.visible and m.tree.atlas and m.tree.overlay and m.tree.sel == "root" and station.title() == "ATLAS",
		"E at the globe opens the Atlas's tree over the hideout")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	m.tree.handle(tab)
	c.ok(m.tree.visible and not m.tree.atlas, "Tab switches to the prompt tree")
	m.tree.handle(tab)
	var vp_size: Vector2i = m.subviewport.size
	m.subviewport.size = Vector2i(480, 270) + Vector2i.ONE * m.PAD * 2
	await c.frames(2)
	progress.atlas = []
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = m.tree.screen_of("orb1")
	m.tree.handle(click)
	click.pressed = false
	m.tree.handle(click)
	c.ok(m.tree.atlas and progress.atlas == ["orb1"] and m.tree.field().position.y > m.tree._view().position.y + m.tree.FIELD_TOP,
		"back to the Atlas: a click allocates a node; the field sits under the tier strip")
	m.subviewport.size = vp_size
	m.close_tree_in_level()
	await c.frames(2)
	p.invuln = 0
	m.play("1-1")
	await c.frames(3)
	progress.levels = saved.levels
	progress.maps_done = saved.maps_done
	progress.atlas = saved.atlas
	progress.atlas_bonus = saved.bonus
	progress.char_level = saved.level
	progress.xp = saved.xp
	progress.inventory = []
	progress.device = []
	progress.save()
	progress.save_items()
	return true
