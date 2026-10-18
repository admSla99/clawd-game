extends RefCounted

## The endgame's weapon classes (docs/endgame-plan.md E14.1-E14.2; a section of tools/check.gd, `c` is check.gd):
## swords, axes, bows and staves as item bases that only maps drop, their sprites, the tooltip's class and speed,
## swinging (damage, the sword's combo and finisher, the axe's cleave behind Clawd, a sword's arc not reaching
## behind), cutting shots, the pogo; drawing a bow (a weak tap, a full draw, a falling arrow that pierces one
## enemy), a staff's bonk and its implicit.

const TITLE := "weapon classes: swords, axes, bows, staves; swings, combos, cleaves, the pogo, drawn arrows (docs/endgame-plan.md E14.1-2)"


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
	# The bases: three of each class, from item level 30, so the campaign (areas up to 27) never drops them and maps do.
	var melee: Array = items.BASES.keys().filter(func(b): return items.BASES[b].kind == "weapon" and not items.BASES[b].weapon in weapons.WEAPONS)
	var classes: Array = melee.map(func(b): return weapons.class_of(weapons.get_def(items.BASES[b].weapon)))
	c.ok(melee.size() == 12 and melee.all(func(b): return items.BASES[b].level >= 30)
		and ["sword", "axe", "bow", "staff"].all(func(k): return classes.count(k) == 3),
		"three swords, axes, bows and staves, from item level 30: %s" % [melee])
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
		return rows[sprite.GRIP_ROW[id]][0] == "g" and rows.all(func(r): return r.length() == rows[0].length())),
		"each has a sprite held by its grip")
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
	# A bow: holding draws it, letting go shoots an arrow; a tap shoots a weak one.
	progress.gear = {"weapon": {"base": "recurrent_bow", "rarity": "normal", "ilvl": 40, "affixes": []}}
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
	var arrows := func(): return c.get_nodes_in_group("bullets").filter(func(b): return b.kind == "arrow" and not b.dead)
	d = 12.0 * weapons.damage_mult()
	Input.action_press("attack")
	await c.frames(2)
	Input.action_release("attack")
	await c.frames(2)
	var tap: Array = arrows.call()
	c.ok(weapons.is_bow(m.gun.weapon) and tap.size() == 1 and tap[0].damage < 0.45 * d and tap[0].gravity > 0,
		"a tap shoots a weak arrow (%.1f of %.1f)" % [tap[0].damage if not tap.is_empty() else 0.0, d])
	for a in tap:
		a.queue_free()
	await c.frames(15)
	Input.action_press("attack")
	await c.frames(50)
	var drawn: bool = m.gun.bow.full and arrows.call().is_empty()
	Input.action_release("attack")
	await c.frames(2)
	var shot_arrows: Array = arrows.call()
	c.ok(drawn and shot_arrows.size() == 1 and is_equal_approx(shot_arrows[0].damage, d) and m.gun.heat == 0.0,
		"held, it draws in full and shoots nothing until let go; then an arrow of all its damage (%.1f), no heat" % d)
	var vy: float = shot_arrows[0].vel.y
	await c.frames(10)
	c.ok(is_instance_valid(shot_arrows[0]) and shot_arrows[0].vel.y > vy + 30, "the arrow falls (%.0f -> %.0f px/s down)" % [vy, shot_arrows[0].vel.y if is_instance_valid(shot_arrows[0]) else 0.0])
	await c.frames(60)
	# It pierces one enemy and stops in the second.
	var first = dummy.call(p.pos + Vector2(40, 0))
	var second = dummy.call(p.pos + Vector2(64, 0))
	var third = dummy.call(p.pos + Vector2(88, 0))
	Input.action_press("attack")
	await c.frames(50)
	Input.action_release("attack")
	await c.frames(30)
	c.ok(first.hp < 1000.0 and second.hp < 1000.0 and third.hp == 1000.0, "a full draw's arrow pierces one enemy and stops in the next")
	for e in [first, second, third]:
		e.queue_free()
	# A staff: a short, weak bonk; its implicit is spell damage and COMPUTE.
	var staff_item := {"base": "inference_staff", "rarity": "normal", "ilvl": 40, "affixes": []}
	progress.gear = {"weapon": staff_item}
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
	front = dummy.call(p.pos + Vector2(20, 0))
	Input.action_press("attack")
	await c.frames(2)
	Input.action_release("attack")
	await c.frames(20)
	rows = tooltip.rows(staff_item, true).map(func(r): return r[0] if not r.is_empty() else "")
	c.ok(m.gun.weapon["class"] == "staff" and is_equal_approx(front.hp, 1000.0 - 4.0 * weapons.damage_mult())
		and rows.has("+20% spell damage") and rows.has("+15 maximum compute"), "a staff bonks for 4; +20%% spell damage, +15 compute: %s" % [rows])
	front.queue_free()
	m.endgame = false
	progress.gear = saved.gear
	progress.tree = saved.tree
	gear.invalidate()
	p.invuln = 0
	m.play("1-1")
	await c.frames(3)
	return true
