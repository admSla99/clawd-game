class_name Shop
extends RefCounted

## What the shop sells and what buying does (ShopScene in src/scenes/shop.ts, prices from src/weapons.ts). It
## opens after 1-1 with the upgrades that work in world 1 (Extra Heart, Jet Tuning, Token Magnet, at the TS
## prices) and four things of the port's own: the Spark Radar and HAIKU's Fortune Haiku (tools for finding
## everything) and two consumables, Firewall and Double Tokens. The world-2 weapons and gun mods wait behind one
## locked ARMORY row until Clawd finds a weapon (the blaster 1-B drops); then items() puts the ARMORY (the five
## weapons: buy, then equip) and the GUN MODS (Bigger Model, Faster Inference, Longer Context) in its place.
## Everything is bought with banked tokens (Progress.wallet), the rarer things with sparks too
## (Progress.sparks_available()). ShopScreen draws it.

## kind: "upgrade" (levels, `prices` / `sparks` per level), "fortune" (repeatable), "stock" (consumable, up to
## `max` in stock), "locked", and from items(): "weapon" (`price`, `sparks`; bought once, then equipped). World 3's
## System Prompts are not sold here: they are the prompt tree's (scripts/prompts.gd, TreeScreen).
const ITEMS := [
	{"id": "hearts", "kind": "upgrade", "section": "UPGRADES", "name": "Extra Heart", "prices": [100, 250], "sparks": [0, 4],
		"desc": "One more heart to lose. Checkpoints refill to it too."},
	{"id": "hover", "kind": "upgrade", "section": "UPGRADES", "name": "Jet Tuning", "prices": [60, 160],
		"desc": "+30% hover time per level, for the long gaps."},
	{"id": "magnet", "kind": "upgrade", "section": "UPGRADES", "name": "Token Magnet", "prices": [120],
		"desc": "Tokens within four and a half tiles fly to you."},
	{"id": "radar", "kind": "upgrade", "section": "TOOLS", "name": "Spark Radar", "prices": [80],
		"desc": "An arrow by Clawd points to the nearest spark you have never found. It beats faster the closer you get."},
	{"id": "fortune", "kind": "fortune", "section": "TOOLS", "name": "Fortune Haiku", "price": 25,
		"desc": "HAIKU tells you, in 5-7-5, where a spark or a lost sub-agent still hides in a level you can play."},
	{"id": "firewall", "kind": "stock", "section": "CONSUMABLES", "name": "Firewall", "price": 40, "max": 3,
		"desc": "Blocks the next hit that would cost a heart. One guards each level, and it is only used up when it breaks."},
	{"id": "double", "kind": "stock", "section": "CONSUMABLES", "name": "Double Tokens", "price": 100, "max": 3,
		"desc": "Every token counts twice. One is used each time you clear a level."},
	{"id": "armory", "kind": "locked", "section": "WORLD 2", "name": "Armory",
		"desc": "Five weapons and their mods (Bigger Model, Faster Inference, Longer Context) for world 2, where Clawd shoots. It opens when Clawd finds a weapon."},
]

## Token Magnet reach in px (loadoutFromSave(): magnet 72).
const MAGNET := 72.0
const NUMBERS := ["one", "two", "three", "four", "five", "six"]


## What is for sale now: ITEMS, with the ARMORY and GUN MODS instead of the locked row once Clawd owns a weapon.
static func items() -> Array:
	if Progress.weapons.is_empty():
		return ITEMS
	var out := ITEMS.filter(func(it: Dictionary) -> bool: return it.kind != "locked")
	for id in Weapons.ORDER:
		var w: Dictionary = Weapons.WEAPONS[id]
		out.append({"id": id, "kind": "weapon", "section": "ARMORY", "name": w.name, "desc": w.desc, "price": w.price, "sparks": w.sparks})
	for u in Weapons.UPGRADES:
		var it: Dictionary = u.duplicate()
		it.kind = "upgrade"
		it.section = "GUN MODS"
		out.append(it)
	return out


static func item(id: String) -> Dictionary:
	for it in items():
		if it.id == id:
			return it
	return {}


## The price of the item's next purchase, {tokens, sparks}, or {} when it can't be bought (maxed, locked, full,
## or nothing left to tell).
static func price(it: Dictionary, ids: Array) -> Dictionary:
	match it.kind:
		"upgrade":
			var lv := Progress.upgrade(it.id)
			if lv >= it.prices.size():
				return {}
			var sp: Array = it.get("sparks", [])
			return {"tokens": it.prices[lv], "sparks": sp[lv] if lv < sp.size() else 0}
		"fortune":
			return {"tokens": it.price, "sparks": 0} if not secrets(ids).is_empty() else {}
		"stock":
			return {"tokens": it.price, "sparks": 0} if Progress.in_stock(it.id) < it.max else {}
		"weapon":
			return {"tokens": it.price, "sparks": it.sparks} if not Progress.weapons.has(it.id) else {}
	return {}


static func affordable(p: Dictionary) -> bool:
	return not p.is_empty() and Progress.wallet >= p.tokens and Progress.sparks_available() >= p.sparks


## Buys the item: "bought", "equipped" (a weapon Clawd owns: he holds it now), "poor" (not enough tokens or
## sparks) or "none" (can't be bought).
static func buy(it: Dictionary, ids: Array) -> String:
	if it.kind == "weapon" and Progress.weapons.has(it.id):
		Progress.equipped = it.id
		Progress.save()
		return "equipped"
	var p := price(it, ids)
	if p.is_empty():
		return "none"
	if not affordable(p):
		return "poor"
	Progress.wallet -= p.tokens
	Progress.sparks_spent += p.sparks
	match it.kind:
		"upgrade":
			Progress.upgrades[it.id] = Progress.upgrade(it.id) + 1
		"stock":
			Progress.stock[it.id] = Progress.in_stock(it.id) + 1
		"fortune":
			Progress.fortune = tell_fortune(ids)
		"weapon":
			# grantWeapon() saves, and a new weapon is held at once (activate() in shop.ts).
			Progress.grant_weapon(it.id)
	Progress.save()
	return "bought"


# --- Fortunes -------------------------------------------------------------------

## Everything still hidden in the playable levels: sparks never found and sub-agents never rescued, as
## {key, level, kind ("S" / "A"), index, x, y} in map tiles, in level order.
static func secrets(ids: Array) -> Array:
	var out := []
	for i in ids.size():
		if not Progress.is_unlocked(ids, i):
			break
		var id: String = ids[i]
		var prog := Progress.progress_for(id)
		var rows := _map(id)
		var count := {"S": 0, "A": 0}
		for y in rows.size():
			for x in rows[y].length():
				var ch: String = rows[y][x]
				if ch != "S" and ch != "A":
					continue
				var n: int = count[ch]
				count[ch] = n + 1
				var found: Array = prog.sparks if ch == "S" else prog.agents
				if n < found.size() and found[n]:
					continue
				out.append({"key": "%s:%s:%d" % [id, ch, n], "level": id, "kind": ch, "index": n, "x": x, "y": y})
	return out


static func _map(id: String) -> PackedStringArray:
	return FileAccess.get_file_as_string("res://levels/%s.txt" % id).trim_suffix("\n").split("\n")


## The next fortune: a secret HAIKU has not told about yet (or, once it has told about all of them, the first one
## again), as three lines: what and where, which stretch between the checkpoints, and how high.
static func tell_fortune(ids: Array) -> Array:
	var all := secrets(ids)
	if all.is_empty():
		return ["nothing hides from you", "every spark is in your claw", "rest now, little crab"]
	var pick: Dictionary = all[0]
	for s in all:
		if s.key not in Progress.hinted:
			pick = s
			break
	if pick.key not in Progress.hinted:
		Progress.hinted.append(pick.key)
	return fortune_lines(pick)


static func fortune_lines(s: Dictionary) -> Array:
	var rows := _map(s.level)
	var what := "a spark sleeps in %s" % s.level if s.kind == "S" else "a friend waits in %s" % s.level
	# Which stretch: by the checkpoints before it.
	var saves := 0
	var last := true
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "C":
				if x < s.x:
					saves += 1
				else:
					last = false
	var where := "before the first save" if saves == 0 else "beyond the final save" if last else "past save number %s" % NUMBERS[mini(saves, NUMBERS.size()) - 1]
	# How high: the first solid tile below it.
	var gap := -1
	var under := ""
	for y in range(s.y + 1, rows.size()):
		if s.x < rows[y].length() and rows[y][s.x] in ["#", "=", "X", "^"]:
			gap = y - s.y - 1
			under = rows[y][s.x]
			break
	var height := "hung above the void" if gap < 0 else ("right above a ledge" if under == "=" else "close to the cold ground") if gap <= 1 		else "a jump above the floor" if gap <= 4 else "high above your head"
	return [what, where, height]
