extends RefCounted

## Melee weapons (docs/endgame-plan.md E14.1; a section of tools/check.gd, `c` is check.gd): swords and axes as
## item bases that only maps drop, their sprites, the tooltip's class and speed, swinging (damage, the sword's
## combo and finisher, the axe's cleave behind Clawd, a sword's arc not reaching behind), cutting shots, the pogo.

const TITLE := "melee weapons: swords and axes, swings, combos, cleaves, cut shots, the pogo (docs/endgame-plan.md E14.1)"


func run(c) -> bool:
	var m = c.current_scene
	var p = m.player
	var progress = c.root.get_node("Progress")
	var items = load("res://scripts/items.gd")
	var weapons = load("res://scripts/weapons.gd")
	var gear = load("res://scripts/gear.gd")
	var sprite = load("res://scripts/gun_sprite.gd")
	var tooltip = load("res://scripts/item_tooltip.gd")
	var saved := {"gear": progress.gear.duplicate(true), "tree": progress.tree.duplicate()}
	# The bases: six, from item level 30, so the campaign (areas up to 27) never drops them and maps do.
	var melee: Array = items.BASES.keys().filter(func(b): return items.BASES[b].kind == "weapon" and weapons.is_melee(weapons.get_def(items.BASES[b].weapon)))
	c.ok(melee.size() == 6 and melee.all(func(b): return items.BASES[b].level >= 30)
		and melee.map(func(b): return weapons.class_of(weapons.get_def(items.BASES[b].weapon))).count("axe") == 3,
		"three swords and three axes, from item level 30: %s" % [melee])
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var campaign := 0
	var maps := 0
	for i in 600:
		if melee.has(items.roll(27, rng).base):
			campaign += 1
		if melee.has(items.roll(70, rng).base):
			maps += 1
	c.ok(campaign == 0 and maps > 0, "none in 600 items of the campaign's last area, %d in 600 of a T16 map's" % maps)
	c.ok(melee.all(func(b):
		var id: String = items.BASES[b].weapon
		var rows: Array = sprite.SPRITES[id]
		return rows[sprite.GRIP_ROW[id]][0] == "g"), "each has a sprite held by its grip")
	var sword_item := {"base": "tokenizer_blade", "rarity": "normal", "ilvl": 40, "affixes": []}
	var rows: Array = tooltip.rows(sword_item, true).map(func(r): return r[0] if not r.is_empty() else "")
	c.ok(rows.has("SWORD · ITEM LEVEL 40") and rows.has("5 DAMAGE · 2.6 SWINGS A SECOND"), "the tooltip names the class and its speed: %s" % [rows])
	# Holding a sword in the endgame. Temperature 0. keeps critical strikes out of the numbers.
	progress.tree = ["temp0"]
	progress.gear = {"weapon": sword_item}
	gear.invalidate()
	m.endgame = true
	m.load_level("2-1")
	await c.frames(3)
	c.flat_ground(m)
	p.invuln = 1000
	p.pos = Vector2(10 * c.TILE + 8, 16 * c.TILE)
	p.vel = Vector2.ZERO
	p.facing = 1
	m.gun.mouse_moved = -1_000_000
	await c.frames(3)
	c.ok(m.gun.armed and m.gun.weapon.id == "tokenizer_blade" and weapons.is_melee(m.gun.weapon), "the equipped sword is the weapon Clawd holds")
	var dummy := func(at: Vector2):
		var e = load("res://scenes/bug.tscn").instantiate()
		m.level.add_child(e)
		e.set_physics_process(false)
		e.pos = at
		e.hp = 1000.0
		e.max_hp = 1000.0
		return e
	var front = dummy.call(p.pos + Vector2(22, 0))
	var behind = dummy.call(p.pos + Vector2(-16, 0))
	var d: float = 5.0 * weapons.damage_mult()
	# One swing.
	Input.action_press("attack")
	await c.frames(2)
	Input.action_release("attack")
	await c.frames(20)
	c.ok(is_equal_approx(front.hp, 1000.0 - d) and behind.hp == 1000.0, "a swing hits in front (%.1f) and not behind" % (1000.0 - front.hp))
	# The combo: three swings, the last 1.5 times as hard.
	front.hp = 1000.0
	await c.frames(30)
	var heat_before: float = m.gun.heat
	Input.action_press("attack")
	await c.frames(55)
	Input.action_release("attack")
	await c.frames(30)
	c.ok(is_equal_approx(front.hp, 1000.0 - 3.5 * d) and m.gun.heat == heat_before,
		"three swings, the third a finisher: %.1f (3.5 x %.1f), no context heat" % [1000.0 - front.hp, d])
	# A swing cuts an enemy shot it meets.
	var shot = load("res://scripts/shot.gd").fire(m.level, p.pos + Vector2(26, -9), Vector2(-20, 0), Color.RED, true, 10.0)
	Input.action_press("attack")
	await c.frames(2)
	Input.action_release("attack")
	await c.frames(10)
	c.ok(not is_instance_valid(shot) or shot.dead, "a swing cuts an enemy shot")
	# The pogo: a downward swing in the air bounces off the enemy below.
	front.queue_free()
	behind.queue_free()
	await c.frames(30)
	var below = dummy.call(p.pos + Vector2(4, 0))
	p.pos = below.pos + Vector2(0, -34)
	p.vel = Vector2.ZERO
	await c.physics_frame
	Input.action_press("attack")
	Input.action_press("down")
	var bounced := false
	for i in 12:
		await c.physics_frame
		bounced = bounced or p.vel.y < -200
	Input.action_release("attack")
	Input.action_release("down")
	c.ok(below.hp < 1000.0 and bounced and m.gun.melee.pogo_done and p.state != &"pound", "a downward swing in the air hits the enemy below and bounces Clawd off it")
	below.queue_free()
	# An axe: one heavy swing that reaches behind Clawd too.
	progress.gear = {"weapon": {"base": "pruning_axe", "rarity": "normal", "ilvl": 40, "affixes": []}}
	gear.invalidate()
	m.load_level("2-1")
	await c.frames(3)
	c.flat_ground(m)
	p.invuln = 1000
	p.pos = Vector2(10 * c.TILE + 8, 16 * c.TILE)
	p.vel = Vector2.ZERO
	p.facing = 1
	m.gun.mouse_moved = -1_000_000
	await c.frames(3)
	front = dummy.call(p.pos + Vector2(24, 0))
	behind = dummy.call(p.pos + Vector2(-14, 0))
	d = 13.0 * weapons.damage_mult()
	Input.action_press("attack")
	await c.frames(2)
	Input.action_release("attack")
	await c.frames(30)
	c.ok(m.gun.weapon["class"] == "axe" and is_equal_approx(front.hp, 1000.0 - d) and is_equal_approx(behind.hp, 1000.0 - d),
		"an axe's swing (%.1f) cleaves the enemy behind Clawd too" % d)
	front.queue_free()
	behind.queue_free()
	m.endgame = false
	progress.gear = saved.gear
	progress.tree = saved.tree
	gear.invalidate()
	p.invuln = 0
	m.play("1-1")
	await c.frames(3)
	return true
