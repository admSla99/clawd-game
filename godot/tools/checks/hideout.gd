extends RefCounted

## The hideout (docs/endgame-plan.md E4; a section of tools/check.gd, `c` is check.gd): opened from the map once
## 3-B is beaten, hit points there, its five stations and what each does, the vendor buying and selling.

const TITLE := "the hideout: stations, stash, vendor, terminal, Map Device, portal (docs/endgame-plan.md E4)"


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var main_script = load("res://scripts/main.gd")
	var vendor = load("res://scripts/vendor.gd")
	var saved := {"levels": progress.levels.duplicate(true), "wallet": progress.wallet, "runs": progress.runs}
	var key := func(code: int) -> InputEventKey:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.pressed = true
		return e
	# Opens from the map once 3-B is beaten.
	progress.levels = {}
	m.show_map()
	await c.frames(3)
	m.front.handle(key.call(KEY_O))
	await c.frames(2)
	c.ok(not main_script.hideout_open() and m.mode == m.Mode.MAP, "before 3-B is beaten O does nothing on the map")
	progress.levels = {"3-B": {"completed": true, "sparks": [], "agents": [], "best_time": null}}
	m.front.handle(key.call(KEY_O))
	await c.frames(5)
	c.ok(m.mode == m.Mode.PLAY and m.level_id == "hideout" and m.endgame and p.hp_mode and m.info.theme == "hideout",
		"after it O opens the hideout: a level of its own, hit points there")
	var st := {}
	for s in c.get_nodes_in_group("stations"):
		st[s.kind] = s
	c.ok(st.keys().size() == 5 and c.get_nodes_in_group("enemies").is_empty(), "five stations (%s), no enemies" % [st.keys()])
	var use := func(kind: String) -> void:
		p.pos = st[kind].feet()
		p.vel = Vector2.ZERO
		await c.frames(3)
		Input.action_press("pickup")
		await c.frames(2)
		Input.action_release("pickup")
		await c.frames(2)
	# The stash.
	await use.call("stash")
	c.ok(m.items.visible and m.items.stash_open and c.root.get_node("Game").paused, "E at the vault opens the inventory with the stash")
	m.close_items()
	await c.frames(2)
	# The vendor: a stock of ten, buying and selling.
	progress.wallet = 100000
	progress.runs = 7
	progress.vendor = []
	await use.call("vendor")
	c.ok(m.items.visible and m.items.vendor_open and progress.vendor.size() == vendor.COUNT and progress.vendor_at == 7,
		"E at the vendor opens it with a stock of %d items" % vendor.COUNT)
	var it: Dictionary = progress.vendor[0]
	var price: int = vendor.buy_price(it)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var vp_size: Vector2i = m.subviewport.size
	m.subviewport.size = Vector2i(480, 270) + Vector2i.ONE * m.PAD * 2
	click.position = m.items.cell_rect("vendor", load("res://scripts/gear.gd").rect_of(it)).get_center()
	m.items.handle(click)
	c.ok(progress.inventory.has(it) and not progress.vendor.has(it) and progress.wallet == 100000 - price,
		"a click buys an item for %d tokens (4x its worth)" % price)
	click.position = m.items.cell_rect("inv", load("res://scripts/gear.gd").rect_of(it)).get_center()
	click.ctrl_pressed = true
	m.items.handle(click)
	c.ok(not progress.inventory.has(it) and progress.wallet == 100000 - price + vendor.sell_price(it),
		"Ctrl + click sells it back for %d" % vendor.sell_price(it))
	progress.wallet = 0
	click.ctrl_pressed = false
	click.position = m.items.cell_rect("vendor", load("res://scripts/gear.gd").rect_of(progress.vendor[0])).get_center()
	m.items.handle(click)
	c.ok(progress.inventory.is_empty() and m.items.note.begins_with("NOT ENOUGH TOKENS"), "without the tokens nothing is bought")
	m.subviewport.size = vp_size
	m.close_items()
	var stock: Array = progress.vendor.duplicate()
	vendor.ensure_stock()
	c.ok(progress.vendor == stock, "the stock stays until a level is cleared")
	progress.runs += 1
	vendor.ensure_stock()
	c.ok(progress.vendor != stock, "then it comes anew")
	c.ok(vendor.sell_price({"base": "iron_plugin", "rarity": "rare", "ilvl": 30, "affixes": []}) == 96
		and vendor.sell_price({"base": "iron_plugin", "rarity": "normal", "ilvl": 1, "affixes": []}) == 3, "a rare of level 30 sells for 96, a normal one of 1 for 3")
	# The terminal: the prompt tree over the hideout.
	await use.call("terminal")
	c.ok(m.tree.visible and m.tree.overlay and m.mode == m.Mode.PLAY and c.root.get_node("Game").paused, "E at the terminal opens the prompt tree over the hideout")
	m._input(key.call(KEY_ESCAPE))
	await c.frames(2)
	c.ok(not m.tree.visible and m.mode == m.Mode.PLAY and m.level_id == "hideout" and not c.root.get_node("Game").paused,
		"Escape closes it back into the hideout")
	# The Map Device (maps come in E5) and the portal.
	await use.call("device")
	c.ok(m.overlay.popups.any(func(pp): return pp.text == "NO MAPS YET"), "the Map Device has no maps yet")
	await use.call("portal")
	c.ok(m.mode == m.Mode.MAP, "the portal goes back to the world map")
	m.play("1-1")
	await c.frames(3)
	c.ok(not m.endgame and not p.hp_mode, "a campaign level has hearts again")
	progress.levels = saved.levels
	progress.wallet = saved.wallet
	progress.runs = saved.runs
	progress.vendor = []
	progress.inventory = []
	progress.save_items()
	return true
