extends RefCounted

## Maps (docs/endgame-plan.md E5; a section of tools/check.gd, `c` is check.gd): map items and their mods, the
## generator, the Map Device, a run with its portals, dying, going back in, the boss, MAP COMPLETE and the way home.

const TITLE := "maps: items, the generator, the Map Device, portals, the boss (docs/endgame-plan.md E5)"


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var maps = load("res://scripts/maps.gd")
	var items = load("res://scripts/items.gd")
	var gen = load("res://scripts/map_gen.gd")
	var exp = load("res://scripts/experience.gd")
	var saved := {"levels": progress.levels.duplicate(true), "wallet": progress.wallet, "level": progress.char_level, "xp": progress.xp}
	# Map items.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var mg: Dictionary = maps.roll(3, rng, "rare")
	c.ok(mg.base == "map" and mg.tier == 3 and mg.ilvl == 36 and mg.affixes.size() >= 3
		and mg.affixes.all(func(a): return "map" in items.AFFIXES[a.id].kinds) and items.name_of(mg).ends_with("Map")
		and not items.equippable(mg) and maps.quantity(mg) == 8.0 * mg.affixes.size(),
		"a rare T3 map: area level 36, %d map mods, +%d%% quantity, not wearable (%s)" % [mg.affixes.size(), maps.quantity(mg), items.name_of(mg)])
	var t2: Dictionary = maps.roll(2, rng, "normal")
	c.ok(items.name_of(t2) == "%s Map T2" % maps.THEME_NAMES[t2.theme] and t2.theme in maps.THEMES[1],
		"a normal map's name: %s (a theme of world 1's)" % items.name_of(t2))
	# The generator.
	var a: PackedStringArray = gen.generate(77, 2)
	var b: PackedStringArray = gen.generate(77, 2)
	var text := "".join(a)
	var widths := {}
	for r in a:
		widths[r.length()] = true
	var names: Array = gen.layout(77, 2)
	c.ok(a == b and a.size() == gen.ROWS and widths.size() == 1 and text.count("@") == 1 and text.count("B") == 1 and text.count("Q") == 1
		and not "&" in text and not "~" in text and names[0] == "start" and names[-1] == "boss" and names.size() == 2 + gen.MID_MIN + 1,
		"a seed gives the same map: %d rows of %d tiles, start, %d middle chunks, the boss; every slot decided" % [a.size(), a[0].length(), names.size() - 2])
	var count := func(rows: PackedStringArray) -> int:
		var n := 0
		for r in rows:
			for ch in r:
				if ch in "EFHTD":
					n += 1
		return n
	var few: int = count.call(gen.generate(5, 1, 0.0))
	var many: int = count.call(gen.generate(5, 1, 100.0))
	c.ok(many > few and not "T" in "".join(gen.generate(5, 1, 0.0)), "pack size fills more slots (%d enemies, %d with +100%%); no turrets in T1" % [few, many])
	# The Map Device gives a first map, O opens it.
	progress.levels = {"3-B": {"completed": true, "sparks": [], "agents": [], "best_time": null}}
	progress.inventory = []
	progress.stash = []
	progress.device = []
	progress.char_level = 16
	progress.xp = 1000
	m.show_hideout()
	await c.frames(5)
	var st := func(kind: String):
		for s in c.get_nodes_in_group("stations"):
			if s.kind == kind:
				return s
		return null
	var use := func(s) -> void:
		p.pos = s.feet()
		p.vel = Vector2.ZERO
		await c.frames(3)
		Input.action_press("pickup")
		await c.frames(2)
		Input.action_release("pickup")
		await c.frames(3)
	await use.call(st.call("device"))
	c.ok(m.items.visible and m.items.device_open and progress.device.size() == 1 and maps.is_map(progress.device[0]) and progress.device[0].tier == 1,
		"E at the Map Device opens it with a first T1 map in its slot (none anywhere else)")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_O
	key.pressed = true
	m.items.handle(key)
	await c.frames(5)
	c.ok(m.mode == m.Mode.PLAY and m.level_id == "map" and m.endgame and p.hp_mode and m.area_level == 32 and m.map_run.portals == 6
		and progress.device.is_empty(), "O opens it: a map level of area level 32 with 6 portals, the map used up")
	var life: float = maps.life_mult(32)
	var bugs: Array = c.get_nodes_in_group("enemies").filter(func(e): return e.get_script() == load("res://scripts/bug.gd"))
	var boss = m.map_run.boss
	c.ok(not bugs.is_empty() and is_equal_approx(bugs[0].hp, 2.0 * 3.0 * life) and is_equal_approx(boss.hp, boss.LIFE * life) and m.boss == boss
		and boss.max_hp == boss.hp and boss.TITLE == "THE OVERFITTER",
		"its enemies have x%.2f life (a bug %.1f), the boss %d with the HUD's bar" % [life, bugs[0].hp if not bugs.is_empty() else 0.0, boss.hp])
	var map_level = m.level
	# Home through the start's portal, and back in.
	m.tokens = 30
	var wallet: int = progress.wallet
	await use.call(st.call("portal"))
	c.ok(m.level_id == "hideout" and not m.map_run.is_empty() and progress.wallet == wallet + 30, "the start's portal leads home, the tokens banked, the map stays open")
	m.use_station(st.call("device"))
	await c.frames(2)
	m.items.handle(key)
	await c.frames(5)
	c.ok(m.level_id == "map" and is_same(m.level, map_level) and is_same(m.map_run.boss, boss) and is_equal_approx(boss.hp, boss.LIFE * life),
		"O goes back into the same map, its enemies not scaled twice")
	# Dying costs a portal and a tenth of the level's XP.
	p.invuln = 0
	p.evasion = 0
	p.life = 1
	p.hurt(p.pos.x + 5)
	await c.frames(4)
	c.ok(m.level_id == "hideout" and m.map_run.portals == 5 and progress.xp == 1000 - roundi(exp.need(16) * 0.1),
		"dying goes home with 5 portals left and %d XP less" % roundi(exp.need(16) * 0.1))
	# The boss: MAP COMPLETE, maps and items, a portal home.
	m.enter_map()
	await c.frames(3)
	p.pos = boss.pos + Vector2(-80, 0)
	await c.frames(2)
	boss.hit(&"shot", 100000)
	await c.frames(60)
	var drops: Array = c.get_nodes_in_group("loot")
	var map_drops: Array = drops.filter(func(d): return maps.is_map(d.item))
	var home = m.level.get_node_or_null("HomePortal")
	c.ok(m.map_run.done and m.overlay.popups.any(func(pp): return pp.text == "MAP COMPLETE") and map_drops.size() >= maps.BOSS_MAPS
		and drops.size() >= maps.BOSS_MAPS + m.BOSS_DROPS and home != null and progress.maps_done.get("1", 0) == 1,
		"the boss falls: MAP COMPLETE, %d maps and %d items drop, a portal home, the tier counted" % [map_drops.size(), drops.size() - map_drops.size()])
	c.ok(map_drops.all(func(d): return d.item.tier in [1, 2]), "the maps it drops are T1 or T2")
	await use.call(home)
	c.ok(m.level_id == "hideout" and m.map_run.is_empty(), "its portal goes home and the map closes")
	# The last portal: the map collapses.
	m.start_map(maps.roll(1, rng, "normal"))
	await c.frames(3)
	m.map_run.portals = 1
	p.invuln = 0
	p.life = 1
	p.hurt(p.pos.x + 5)
	await c.frames(4)
	c.ok(m.level_id == "hideout" and m.map_run.is_empty() and m.overlay.popups.any(func(pp): return pp.text == "THE MAP COLLAPSED"),
		"dying with the last portal: THE MAP COLLAPSED")
	# QUIT TO MAP in a map goes home; maps drop from enemies there.
	m.start_map(maps.roll(1, rng, "magic"))
	await c.frames(3)
	for n in c.get_nodes_in_group("loot"):
		n.free()
	m.loot_rng.seed = 9
	for i in 300:
		m.roll_drop(3.0, p.pos)
	var dropped: int = c.get_nodes_in_group("loot").filter(func(d): return maps.is_map(d.item)).size()
	c.ok(dropped > 3 and dropped < 30, "enemies in a map drop maps now and then (%d in 300)" % dropped)
	m.quit_level()
	await c.frames(3)
	c.ok(m.level_id == "hideout" and not m.map_run.is_empty(), "QUIT TO MAP from a map goes to the hideout")
	m._end_map()
	m.play("1-1")
	await c.frames(3)
	progress.levels = saved.levels
	progress.wallet = saved.wallet
	progress.char_level = saved.level
	progress.xp = saved.xp
	progress.maps_done = {}
	progress.atlas_bonus = []
	progress.inventory = []
	progress.device = []
	progress.save_items()
	return true
