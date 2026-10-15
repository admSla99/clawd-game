class_name InventoryScreen
extends Node2D

## The inventory window (docs/endgame-plan.md E3), Path of Exile's: on the right Clawd's equipment slots over his
## 12 x 5 inventory, on the left the 12 x 12 stash (from the map, later the hideout) or, in a level, his stats.
## Items are picked up onto the cursor and put down in a grid (swapping with the one item under them) or a slot
## of their kind (swapping with what is equipped). The mouse: left click picks up / puts down, right click equips
## or takes off at once, Ctrl + click moves between inventory and stash. The keys: arrows move a cursor over
## cells and slots, Space / Enter pick up and put down, X equips or takes off, C moves to the other grid, Delete
## twice destroys, I or Escape closes (a held item goes back first). The hovered item shows its tooltip, what
## equipping it would change, and the equipped one's tooltip beside it.
## Made by Main under Ui. In a level it pauses the game and Main applies the gear when it closes (gear_changed());
## from the map it is Main.Mode.ITEMS, over the drifting backdrop. The hideout's vendor (Vendor) opens it with its
## stock on the left: a click there buys, an item put down there (or Ctrl + click / C in the inventory) sells.
## The Map Device opens it with the device on the left (docs/endgame-plan.md E5): a slot for one map (put it there,
## or right click / Ctrl + click / X / C a map), its tooltip, and O (or the button) opens it; with a map already
## open and the slot empty, O goes back in.
## Under the inventory the currency pouch (Currency): a click (Space) takes an orb onto the cursor, a click on an
## item (in the inventory, the stash, a slot or the device) uses it there, and it stays on the cursor for the next
## one until right click or Escape (or none is left).

const CELL := 12
const GRID_W := 144
## The currency row: one slot per orb, this wide.
const ORB_W := 18
## Equipment slots: top-left cell and size in the equipment area (8 x 6 cells).
const EQUIP := {
	"weapon": [Vector2i(0, 0), Vector2i(2, 3)], "helmet": [Vector2i(3, 0), Vector2i(2, 2)],
	"amulet": [Vector2i(5, 1), Vector2i(1, 1)], "ring1": [Vector2i(2, 3), Vector2i(1, 1)],
	"body": [Vector2i(3, 2), Vector2i(2, 3)], "ring2": [Vector2i(5, 3), Vector2i(1, 1)],
	"gloves": [Vector2i(0, 4), Vector2i(2, 2)], "boots": [Vector2i(6, 4), Vector2i(2, 2)],
}
## The ghost drawn in an empty slot.
const GHOST := {"weapon": "blaster", "helmet": "tin_visor", "amulet": "amber_core", "ring1": "iron_plugin",
	"body": "scrap_plating", "ring2": "iron_plugin", "gloves": "grip_pads", "boots": "rubber_treads"}
const CELL_FILL := Color(0.06, 0.06, 0.07, 0.92)
const CELL_LINE := Color("#202024")

var main: Node
## What is on the left: "stats", "stash" (from the map and the hideout's stash) or "vendor" (the hideout's vendor).
var left := "stats"
var stash_open := false
var vendor_open := false
var device_open := false
var t := 0.0
## The item on the cursor and where it came from ({area, at} or {area: "equip", slot}).
var held := {}
var held_from := {}
## The orb on the cursor (an id of Currency.ORBS), or "".
var held_orb := ""
var _rng := RandomNumberGenerator.new()
## The keyboard cursor: area "inv", "stash" or "equip", a cell or a slot; `keys` while the keys moved it last.
var cur := {"area": "inv", "cell": Vector2i.ZERO, "slot": "weapon"}
var keys := false
var changed := false
var note := ""
var note_t := 0.0
var destroy_armed := 0.0
var _mouse := Vector2(-1000, -1000)


func open(side := "stats") -> void:
	visible = true
	left = side
	stash_open = side == "stash"
	vendor_open = side == "vendor"
	device_open = side == "device"
	t = 0.0
	held = {}
	held_from = {}
	held_orb = ""
	_rng.randomize()
	changed = false
	note = ""
	destroy_armed = 0.0
	cur = {"area": "inv", "cell": Vector2i.ZERO, "slot": "weapon"}


## Closes the window; a held item goes back first. Returns whether the gear changed while it was open.
func close() -> bool:
	if not held.is_empty():
		_return_held()
	visible = false
	return changed


func _process(dt: float) -> void:
	t += dt
	note_t = maxf(0.0, note_t - dt)
	destroy_armed = maxf(0.0, destroy_armed - dt)
	queue_redraw()


# --- Layout --------------------------------------------------------------------

func view() -> Rect2:
	return Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)


func origin(area: String) -> Vector2:
	var v := view()
	var rx := v.end.x - 14 - GRID_W
	match area:
		"equip":
			return Vector2(rx + (GRID_W - 8 * CELL) / 2.0, v.position.y + 40)
		"inv":
			return Vector2(rx, v.position.y + 40 + 6 * CELL + 14)
		"orbs":
			return Vector2(rx, v.position.y + 40 + 6 * CELL + 14 + Gear.INV_SIZE.y * CELL + 16)
	return Vector2(v.position.x + 14, v.position.y + 40)


## Where `area` starts: the stash and the vendor share the left side.
func _origin_of(area: String) -> Vector2:
	if area == "device":
		return origin("stash") + Vector2(GRID_W / 2.0 - CELL / 2.0, 22)
	return origin("stash" if area == "vendor" else area)


## The device's button (O): open the map in the slot, or go back into the open one.
func device_button() -> Rect2:
	var o := origin("stash")
	return Rect2(o.x + 14, o.y + Gear.STASH_SIZE.y * CELL - 22, GRID_W - 28, 14)


func grid_size(area: String) -> Vector2i:
	return Gear.STASH_SIZE if area == "stash" else Vendor.SIZE if area == "vendor" else Vector2i.ONE if area == "device" \
		else Gear.INV_SIZE


func items_of(area: String) -> Array:
	return Progress.stash if area == "stash" else Progress.vendor if area == "vendor" else Progress.device if area == "device" \
		else Progress.inventory


## The grid on the left ("stash", "vendor") or "".
func left_area() -> String:
	return "stash" if stash_open else "vendor" if vendor_open else "device" if device_open else ""


## The currency row's slot `i`.
func orb_rect(i: int) -> Rect2:
	return Rect2(origin("orbs") + Vector2(i * ORB_W, 0), Vector2(ORB_W - 2, 18))


func slot_rect(slot: String) -> Rect2:
	var o := origin("equip")
	var s: Array = EQUIP[slot]
	return Rect2(o + Vector2(s[0]) * CELL, Vector2(s[1]) * CELL)


func cell_rect(area: String, r: Rect2i) -> Rect2:
	return Rect2(_origin_of(area) + Vector2(r.position) * CELL, Vector2(r.size) * CELL)


## What lies under `p`: {area, cell} for a grid, {area: "equip", slot}, or {area: ""}.
func hit(p: Vector2) -> Dictionary:
	for area in (["inv", left_area()] if left_area() != "" else ["inv"]):
		var r := cell_rect(area, Rect2i(Vector2i.ZERO, grid_size(area)))
		if r.has_point(p):
			return {"area": area, "cell": Vector2i(((p - r.position) / CELL).floor())}
	for slot in EQUIP:
		if slot_rect(slot).has_point(p):
			return {"area": "equip", "slot": slot}
	for i in Currency.ORDER.size():
		if orb_rect(i).has_point(p):
			return {"area": "orbs", "cell": Vector2i(i, 0)}
	return {"area": ""}


## The target the keys or the mouse point at.
func target() -> Dictionary:
	return cur.duplicate() if keys else hit(_mouse)


func item_at(tg: Dictionary) -> Dictionary:
	match tg.get("area", ""):
		"equip":
			return Progress.gear.get(tg.slot, {})
		"inv", "stash", "vendor", "device":
			return Gear.item_at(items_of(tg.area), tg.cell)
	return {}


# --- Input ---------------------------------------------------------------------

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		keys = false
		return true
	if event is InputEventMouseButton and event.pressed:
		_mouse = event.position
		keys = false
		var tg := hit(_mouse)
		if device_open and event.button_index == MOUSE_BUTTON_LEFT and device_button().has_point(_mouse):
			activate_device()
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.ctrl_pressed:
				move_across(tg)
			else:
				primary(tg)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			quick(tg)
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return event is InputEventKey or event is InputEventMouseButton
	if (event.is_action_pressed("back") or event.is_action_pressed("inventory")) and held_orb != "":
		held_orb = ""
		Sound.play("select")
	elif event.is_action_pressed("back") or event.is_action_pressed("inventory"):
		Sound.play("select")
		main.close_items()
	elif _dir(event) != Vector2i.ZERO:
		_step(_dir(event))
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		keys = true
		primary(cur)
	elif event.physical_keycode == KEY_X:
		keys = true
		quick(cur)
	elif event.physical_keycode == KEY_C:
		keys = true
		move_across(cur)
	elif event.physical_keycode == KEY_DELETE:
		destroy(target())
	elif event.physical_keycode == KEY_O and device_open:
		activate_device()
	return true


func _dir(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("left") or event.is_action_pressed("ui_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("right") or event.is_action_pressed("ui_right"):
		return Vector2i.RIGHT
	if event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		return Vector2i.UP
	if event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		return Vector2i.DOWN
	return Vector2i.ZERO


## Moves the keyboard cursor a cell (or a slot) towards `d`, across into the next area at an edge.
func _step(d: Vector2i) -> void:
	if not keys:
		var h := hit(_mouse)
		if h.area != "":
			cur = {"area": h.area, "cell": h.get("cell", Vector2i.ZERO), "slot": h.get("slot", "weapon")}
	keys = true
	Sound.play("select")
	var at := _cursor_rect().get_center()
	if cur.area == "equip":
		var best := ""
		var best_d := INF
		for slot in EQUIP:
			var c := slot_rect(slot).get_center() - at
			if slot == cur.slot or c.dot(Vector2(d)) <= 0:
				continue
			var dist := c.length() + absf(c.cross(Vector2(d))) * 2
			if dist < best_d:
				best_d = dist
				best = slot
		if best != "":
			cur.slot = best
		elif d == Vector2i.DOWN:
			cur.area = "inv"
			cur.cell = Vector2i(clampi(int((at.x - origin("inv").x) / CELL), 0, Gear.INV_SIZE.x - 1), 0)
		elif d == Vector2i.LEFT and left_area() != "":
			cur.area = left_area()
			cur.cell = Vector2i(grid_size(cur.area).x - 1, 0)
		return
	if cur.area == "orbs":
		if d.x != 0:
			cur.cell = Vector2i(clampi(cur.cell.x + d.x, 0, Currency.ORDER.size() - 1), 0)
		elif d == Vector2i.UP:
			cur.area = "inv"
			cur.cell = Vector2i(mini(int(cur.cell.x * ORB_W / CELL), Gear.INV_SIZE.x - 1), Gear.INV_SIZE.y - 1)
		return
	var g := grid_size(cur.area)
	var next: Vector2i = cur.cell + d
	if Rect2i(Vector2i.ZERO, g).has_point(next):
		cur.cell = next
	elif cur.area == "inv" and d == Vector2i.DOWN:
		cur.area = "orbs"
		cur.cell = Vector2i(mini(int(cur.cell.x * CELL / ORB_W), Currency.ORDER.size() - 1), 0)
	elif cur.area == "inv" and d == Vector2i.UP:
		cur.area = "equip"
		cur.slot = "gloves" if at.x < origin("equip").x + 4 * CELL else "boots"
	elif cur.area == "inv" and d == Vector2i.LEFT and left_area() != "":
		cur.area = left_area()
		cur.cell = Vector2i(grid_size(cur.area).x - 1, mini(cur.cell.y, grid_size(cur.area).y - 1))
	elif cur.area in ["stash", "vendor", "device"] and d == Vector2i.RIGHT:
		cur.area = "inv"
		cur.cell = Vector2i(0, mini(cur.cell.y, Gear.INV_SIZE.y - 1))


func _cursor_rect() -> Rect2:
	if cur.area == "equip":
		return slot_rect(cur.slot)
	if cur.area == "orbs":
		return orb_rect(cur.cell.x)
	return cell_rect(cur.area, Rect2i(cur.cell, Vector2i.ONE))


func say(s: String) -> void:
	note = s
	note_t = 2.0


# --- Moving items ----------------------------------------------------------------

## Left click / Space: picks up what is there, or puts the held item down (swapping with one item under it).
func primary(tg: Dictionary) -> void:
	if tg.get("area", "") == "":
		return
	# The currency: take an orb onto the cursor, or use the one there on an item.
	if tg.area == "orbs":
		if held.is_empty():
			_take_orb(Currency.ORDER[tg.cell.x])
		return
	if held_orb != "":
		_use_orb(tg)
		return
	if tg.area == "vendor":
		if held.is_empty():
			_buy(item_at(tg))
		else:
			_sell(held)
			held = {}
			held_from = {}
		return
	if tg.area == "device" and not held.is_empty() and not Maps.is_map(held):
		Sound.play("denied")
		say("ONLY MAPS GO INTO THE DEVICE")
		return
	if held.is_empty():
		var it := item_at(tg)
		if it.is_empty():
			return
		_lift(it, tg)
		Sound.play("select")
		return
	if tg.area == "equip":
		if not Items.equippable(held) or Items.SLOT_KIND[tg.slot] != Items.kind(held):
			Sound.play("denied")
			say("THAT GOES IN THE %s SLOT" % Items.KIND_NAME[Items.kind(held)])
			return
		var old := Gear.equip(held, tg.slot)
		_set_held(old, {"area": "equip", "slot": tg.slot})
		changed = true
		Sound.play("confirm")
		return
	var items := items_of(tg.area)
	var size := Items.size(held)
	var at := _drop_cell(tg, size)
	var r := Rect2i(at, size)
	if not Rect2i(Vector2i.ZERO, grid_size(tg.area)).encloses(r):
		Sound.play("denied")
		return
	var under := Gear.overlapping(items, r)
	if under.size() > 1:
		Sound.play("denied")
		return
	if under.size() == 1:
		items.erase(under[0])
	held.at = [at.x, at.y]
	items.append(held)
	_set_held(under[0] if under.size() == 1 else {}, {"area": tg.area, "at": Gear.at_of(under[0]) if under.size() == 1 else at})
	Progress.save_items()
	Sound.play("select")


## Where the held item's top-left goes: under the keyboard cursor, or centred on the mouse.
func _drop_cell(tg: Dictionary, size: Vector2i) -> Vector2i:
	if keys:
		return tg.cell
	var o := _origin_of(tg.area)
	var tl := (_mouse - o - Vector2(size) * CELL / 2.0 + Vector2.ONE * CELL / 2.0) / CELL
	var g := grid_size(tg.area)
	return Vector2i(clampi(floori(tl.x), 0, g.x - size.x), clampi(floori(tl.y), 0, g.y - size.y))


## Right click / X: an item in the inventory or stash goes on (what it replaces into its place, or the first free
## cell), an equipped one comes off into the inventory.
func quick(tg: Dictionary) -> void:
	if held_orb != "":
		held_orb = ""
		Sound.play("select")
		return
	if not held.is_empty() or tg.get("area", "") in ["", "orbs"]:
		return
	var it := item_at(tg)
	if it.is_empty():
		return
	if tg.area == "vendor":
		_buy(it)
		return
	# Maps go into the device, not on Clawd.
	if Maps.is_map(it):
		if device_open and tg.area != "device":
			_into_device(it, tg.area)
		elif not device_open:
			Sound.play("denied")
			say("MAPS GO INTO THE MAP DEVICE (HIDEOUT)")
		return
	if tg.area == "equip":
		if not Gear.take(Progress.gear[tg.slot]):
			Sound.play("denied")
			say("INVENTORY FULL")
			return
		Gear.unequip(tg.slot)
	else:
		var items := items_of(tg.area)
		var at := Gear.at_of(it)
		items.erase(it)
		var old := Gear.equip(it, Gear.slot_for(it))
		if not old.is_empty() and not Gear.place(items, grid_size(tg.area), old, at):
			# No room for what came off: undo.
			Gear.equip(old, Gear.slot_for(old) if Items.kind(old) != "ring" else _slot_of(it))
			Gear.place(items, grid_size(tg.area), it, at)
			Sound.play("denied")
			say("NO ROOM FOR %s" % Items.name_of(old).to_upper())
			return
	changed = true
	Progress.save_items()
	Sound.play("confirm")


func _slot_of(it: Dictionary) -> String:
	for slot in Progress.gear:
		if is_same(Progress.gear[slot], it):
			return slot
	return Gear.slot_for(it)


## Ctrl + click / C: between the inventory and the stash (the first free cell there).
func move_across(tg: Dictionary) -> void:
	if held_orb != "":
		return
	if device_open and held.is_empty():
		var dit := item_at(tg)
		if Maps.is_map(dit) and tg.get("area", "") == "inv":
			_into_device(dit, "inv")
		elif tg.get("area", "") == "device" and not dit.is_empty():
			Progress.device.erase(dit)
			if not Gear.take(dit):
				Progress.device.append(dit)
				say("INVENTORY FULL")
			Progress.save_items()
		return
	if vendor_open and held.is_empty():
		var vit := item_at(tg)
		if tg.get("area", "") == "inv" and not vit.is_empty():
			Progress.inventory.erase(vit)
			_sell(vit)
		elif tg.get("area", "") == "vendor":
			_buy(vit)
		return
	if not stash_open or not held.is_empty() or tg.get("area", "") not in ["inv", "stash"]:
		if not stash_open:
			say("THE STASH IS IN THE HIDEOUT (OR ON THE MAP)")
		return
	var it := item_at(tg)
	if it.is_empty():
		return
	var to := "stash" if tg.area == "inv" else "inv"
	var items := items_of(tg.area)
	items.erase(it)
	if not Gear.place(items_of(to), grid_size(to), it):
		items.append(it)
		Sound.play("denied")
		say("THE %s IS FULL" % ("STASH" if to == "stash" else "INVENTORY"))
		return
	Progress.save_items()
	Sound.play("select")


func _take_orb(id: String) -> void:
	if held_orb == id:
		held_orb = ""
		Sound.play("select")
	elif Currency.count(id) <= 0:
		Sound.play("denied")
		say("NO %s LEFT" % Currency.name_of(id).to_upper())
	else:
		held_orb = id
		Sound.play("select")


## The orb on the cursor on the item at `tg`.
func _use_orb(tg: Dictionary) -> void:
	if tg.area == "vendor":
		Sound.play("denied")
		say("BUY IT FIRST")
		return
	var it := item_at(tg)
	var why := Currency.apply(held_orb, it, _rng)
	if why != "":
		Sound.play("denied")
		say(why)
		return
	Sound.play("buy")
	say("%s · %s" % [Currency.name_of(held_orb).to_upper(), Items.name_of(it).to_upper()])
	if tg.area == "equip":
		changed = true
	if Currency.count(held_orb) <= 0:
		held_orb = ""


## A map from `area` into the device; the one there goes back into its place.
func _into_device(it: Dictionary, area: String) -> void:
	var items := items_of(area)
	var at := Gear.at_of(it)
	items.erase(it)
	var old: Array = Progress.device.duplicate()
	Progress.device.clear()
	Gear.place(Progress.device, Vector2i.ONE, it, Vector2i.ZERO)
	for o in old:
		if not Gear.place(items, grid_size(area), o, at):
			Gear.place(Progress.stash, Gear.STASH_SIZE, o)
	Progress.save_items()
	Sound.play("confirm")


## O / the button: opens the map in the slot (giving up an open one), or goes back into the open map.
func activate_device() -> void:
	if not held.is_empty():
		return
	if not Progress.device.is_empty():
		var it: Dictionary = Progress.device[0]
		Progress.device.clear()
		Progress.save_items()
		main.close_items()
		Sound.play("weaponGet")
		main.start_map(it)
	elif not main.map_run.is_empty():
		main.close_items()
		Sound.play("confirm")
		main.enter_map()
	else:
		Sound.play("denied")
		say("PUT A MAP INTO THE DEVICE")


## Sells `it` (already out of its grid or off the cursor) to the vendor.
func _sell(it: Dictionary) -> void:
	var price := Vendor.sell_price(it)
	Progress.wallet += price
	Progress.save()
	Progress.save_items()
	Sound.play("buy")
	say("SOLD %s FOR %d TOKENS" % [Items.name_of(it).to_upper(), price])


func _buy(it: Dictionary) -> void:
	if it.is_empty():
		return
	match Vendor.buy(it):
		"bought":
			Sound.play("buy")
			say("BOUGHT %s" % Items.name_of(it).to_upper())
		"poor":
			Sound.play("denied")
			say("NOT ENOUGH TOKENS (%d)" % Vendor.buy_price(it))
		"full":
			Sound.play("denied")
			say("INVENTORY FULL")


## Delete: the held item, or the one under the cursor, is destroyed on the second press.
func destroy(tg: Dictionary) -> void:
	if held_orb != "":
		return
	if tg.get("area", "") == "vendor" and held.is_empty():
		return
	var it := held if not held.is_empty() else item_at(tg)
	if it.is_empty():
		return
	if destroy_armed <= 0:
		destroy_armed = 1.5
		Sound.play("select")
		say("PRESS DELETE AGAIN TO DESTROY %s" % Items.name_of(it).to_upper())
		return
	destroy_armed = 0.0
	if not held.is_empty():
		held = {}
		held_from = {}
	elif tg.area == "equip":
		Gear.unequip(tg.slot)
		changed = true
	else:
		items_of(tg.area).erase(it)
	Progress.save_items()
	Sound.play("agentGone")
	say("DESTROYED")


func _lift(it: Dictionary, tg: Dictionary) -> void:
	if tg.area == "equip":
		Gear.unequip(tg.slot)
		changed = true
		_set_held(it, {"area": "equip", "slot": tg.slot})
	else:
		items_of(tg.area).erase(it)
		_set_held(it, {"area": tg.area, "at": Gear.at_of(it)})
	Progress.save_items()


func _set_held(it: Dictionary, from: Dictionary) -> void:
	held = it
	held_from = from if not it.is_empty() else {}


## The held item back where it came from, else the inventory, else the stash, else onto the ground by Clawd.
func _return_held() -> void:
	var it := held
	held = {}
	var from := held_from
	held_from = {}
	if from.get("area", "") == "equip" and not Progress.gear.has(from.slot):
		Gear.equip(it, from.slot)
		changed = true
		return
	if from.get("area", "") in ["inv", "stash"] and Gear.place(items_of(from.area), grid_size(from.area), it, from.at):
		Progress.save_items()
		return
	if Gear.place(Progress.inventory, Gear.INV_SIZE, it) or Gear.place(Progress.stash, Gear.STASH_SIZE, it):
		Progress.save_items()
		return
	if main.mode == Main.Mode.PLAY:
		ItemDrop.drop(main.level, main.player.pos + Vector2(0, -10), it)


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var v := view()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.02, 0.04, 0.78))
	_big("INVENTORY", v.position + Vector2(14, 8), Hud.ORANGE)
	Hud.draw_xp(self, Vector2(v.position.x + 14 + PixelFont.width("INVENTORY") * 2 + 14, v.position.y + 12), Progress.char_level,
		Experience.fraction())
	var wallet := str(Progress.wallet)
	PixelFont.draw(self, wallet, Vector2(v.end.x - 14 - PixelFont.width(wallet), v.position.y + 12), Hud.TEXT)
	draw_texture(Hud._coin_tex[8], Vector2(v.end.x - 14 - PixelFont.width(wallet) - 12, v.position.y + 11))
	if stash_open:
		_label("STASH", origin("stash"))
		_draw_grid("stash")
	elif vendor_open:
		_label("VENDOR · BUYS ANYTHING", origin("stash"))
		_draw_grid("vendor")
	elif device_open:
		_label("MAP DEVICE", origin("stash"))
		_draw_device()
	else:
		_draw_stats()
	_label("EQUIPPED", origin("equip"))
	for slot in EQUIP:
		_draw_slot(slot)
	_label("CARRIED", origin("inv"))
	_draw_grid("inv")
	_label("CURRENCY", origin("orbs"))
	_draw_orbs()
	# The keyboard cursor.
	if keys:
		var cr := _cursor_rect()
		var pulse := 0.6 + 0.4 * sin(t * 6)
		draw_rect(cr.grow(1), Color(Hud.ORANGE_LIGHT, pulse), false)
	# The held orb or item on the cursor (or over the keyboard cursor).
	if held_orb != "":
		_draw_tooltips()
		var oc := (_cursor_rect().get_center() if keys else _mouse + Vector2(8, 8)).round()
		ItemTooltip.draw_icon(self, {"currency": held_orb}, oc, 1)
	elif not held.is_empty():
		var size := Vector2(Items.size(held)) * CELL
		var at := (_cursor_rect().position if keys else _mouse - size / 2.0).round()
		draw_rect(Rect2(at, size), Color(Items.color(held), 0.25))
		ItemTooltip.draw_icon(self, held, at + size / 2.0, _scale(held))
	else:
		_draw_tooltips()
	var across := "SELL" if vendor_open else "STASH"
	var help := "LMB PICK UP / PUT DOWN   RMB EQUIP   CTRL+LMB %s   DEL DEL DESTROY   I / ESC CLOSE" % across if not keys \
		else "ARROWS MOVE   SPACE PICK UP / PUT DOWN   X EQUIP   C %s   DEL DEL DESTROY   I / ESC CLOSE" % across
	if held_orb != "":
		help = "CLICK AN ITEM TO USE %s   RMB / ESC PUT IT BACK" % Currency.name_of(held_orb).to_upper()
	if note_t > 0:
		help = note
	PixelFont.draw_centred(self, help, v.get_center().x, v.end.y - 10, Hud.ORANGE_LIGHT if note_t > 0 else Color("#5C5C5C"))


func _draw_grid(area: String) -> void:
	var g := grid_size(area)
	var r := cell_rect(area, Rect2i(Vector2i.ZERO, g))
	Hud.panel(self, r.grow(2), Color("#2A2A30"), Color(0.03, 0.03, 0.04, 0.9))
	for x in g.x:
		for y in g.y:
			draw_rect(Rect2(r.position + Vector2(x, y) * CELL, Vector2.ONE * (CELL - 1)), CELL_FILL)
	var hover := target()
	for it in items_of(area):
		var ir := cell_rect(area, Gear.rect_of(it))
		var lit: bool = hover.get("area", "") == area and Gear.rect_of(it).has_point(hover.cell)
		_draw_item(it, ir, lit)


func _draw_slot(slot: String) -> void:
	var r := slot_rect(slot).grow(-1)
	var it: Dictionary = Progress.gear.get(slot, {})
	var hover := target()
	var lit: bool = hover.get("area", "") == "equip" and hover.slot == slot
	var fits: bool = not held.is_empty() and Items.SLOT_KIND[slot] == Items.kind(held)
	Hud.panel(self, r, Hud.ORANGE if fits else Color("#3A3A42") if lit else Color("#26262C"), CELL_FILL)
	if it.is_empty():
		ItemTooltip.draw_icon(self, {}, r.get_center(), 1 if r.size.x < CELL * 2 else 2, true, GHOST[slot])
	else:
		_draw_item(it, r, lit)


func _draw_item(it: Dictionary, r: Rect2, lit: bool) -> void:
	var col := Items.color(it)
	draw_rect(r.grow(-1), Color(col.darkened(0.7), 0.85 if lit else 0.6))
	if lit:
		draw_rect(r.grow(-1), Color(col, 0.6), false)
	ItemTooltip.draw_icon(self, it, r.get_center(), _scale(it))


func _scale(it: Dictionary) -> int:
	return 1 if Items.size(it).x < 2 and Items.kind(it) != "weapon" else 2


## The currency row: each orb's slot with its icon and count, the held one lit; the hovered one's tooltip.
func _draw_orbs() -> void:
	var tg := target()
	for i in Currency.ORDER.size():
		var id: String = Currency.ORDER[i]
		var r := orb_rect(i)
		var n := Currency.count(id)
		var lit: bool = tg.get("area", "") == "orbs" and tg.cell.x == i
		Hud.panel(self, r, Hud.ORANGE if held_orb == id else Color("#3A3A42") if lit else Color("#26262C"), CELL_FILL)
		ItemTooltip.draw_icon(self, {"currency": id}, r.get_center() + Vector2(0, -2), 1, n == 0)
		var s := str(n)
		PixelFont.draw(self, s, Vector2(r.end.x - 1 - PixelFont.width(s), r.end.y - 7), Hud.TEXT if n > 0 else Color("#4A4A4E"))
	if tg.get("area", "") == "orbs" and held.is_empty():
		var id: String = Currency.ORDER[tg.cell.x]
		var orb: Dictionary = Currency.ORBS[id]
		var rows := [[orb.name, orb.color], [orb.desc, ItemTooltip.IMPLICIT], ["%d IN THE POUCH" % Currency.count(id), Hud.TEXT_DIM]]
		var at := ItemTooltip.place(ItemTooltip.size(rows), orb_rect(tg.cell.x), view(), "left")
		ItemTooltip.draw(self, rows, at, Currency.LABEL.darkened(0.3))


## The hovered item's tooltip, what equipping it would change, and the equipped one beside it.
func _draw_tooltips() -> void:
	var tg := target()
	var it := item_at(tg)
	if it.is_empty():
		return
	var anchor := slot_rect(tg.slot) if tg.area == "equip" else cell_rect(tg.area, Gear.rect_of(it))
	var rows := ItemTooltip.rows(it, main.endgame)
	var other := {}
	if tg.area != "equip" and Items.equippable(it):
		other = Progress.gear.get(Gear.slot_for(it), {})
		rows += ItemTooltip.compare_rows(it, other)
	if tg.area == "vendor":
		var price := Vendor.buy_price(it)
		rows += [[], ["CLICK BUYS · %d TOKENS" % price, Hud.ORANGE_LIGHT if Progress.wallet >= price else Hud.RED]]
	elif tg.area == "inv" and vendor_open:
		rows += [[], ["CTRL+CLICK SELLS · %d TOKENS" % Vendor.sell_price(it), Hud.ORANGE_LIGHT]]
	var side := "right" if tg.area in ["stash", "vendor", "device"] else "left"
	var sz := ItemTooltip.size(rows)
	var at := ItemTooltip.place(sz, anchor, view(), side)
	var box := ItemTooltip.draw(self, rows, at, Items.color(it).darkened(0.35))
	if not other.is_empty():
		var orows := ItemTooltip.rows(other, main.endgame, "EQUIPPED")
		var osz := ItemTooltip.size(orows)
		var oat := ItemTooltip.place(osz, box, view(), side)
		if Rect2(oat, osz).intersects(box) or Rect2(oat, osz).intersects(anchor):
			return
		ItemTooltip.draw(self, orows, oat, Hud.BORDER.lightened(0.2))


## Clawd's stats from the tree and the gear (the left side while the stash is closed).
func _draw_stats() -> void:
	var o := origin("stash")
	var r := Rect2(o, Vector2(GRID_W, Gear.STASH_SIZE.y * CELL))
	Hud.panel(self, r.grow(2), Color("#2A2A30"), Color(0.03, 0.03, 0.04, 0.9))
	_label("CLAWD   * ONLY IN THE ENDGAME", o)
	var pct := func(k: String) -> String: return "%+d%%" % roundi(Stats.total(k))
	var lines := [
		["LEVEL", str(Progress.char_level)],
		["DAMAGE", pct.call("damage")],
		["FIRE RATE", pct.call("rate")],
		["CRITICAL CHANCE", "%d%%" % roundi(Stats.crit_chance() * 100)],
		["CRITICAL DAMAGE", "%d%%" % roundi(Stats.crit_mult() * 100)],
		["RUN SPEED", pct.call("run")],
		["HOVER TIME", pct.call("hover")],
		["HOOK REACH", pct.call("reach")],
		["ITEM RARITY", pct.call("rarity")],
		["TOKENS", pct.call("tokens")],
		[],
		["LIFE *", str(roundi(Stats.max_life()))],
		["ARMOUR *", str(roundi(Stats.total("armour")))],
		["EVASION *", str(roundi(Stats.total("evasion")))],
		["REGENERATION *", "%d/s" % roundi(Stats.total("regen"))],
		["OVERHEAT RES. *", "%d%%" % roundi(Stats.total("res_fire"))],
		["LATENCY RES. *", "%d%%" % roundi(Stats.total("res_cold"))],
		["VOLTAGE RES. *", "%d%%" % roundi(Stats.total("res_lightning"))],
	]
	var y := o.y + 4
	for l in lines:
		if l.is_empty():
			y += 4
			continue
		PixelFont.draw(self, l[0], Vector2(o.x + 6, y), Hud.TEXT_DIM)
		PixelFont.draw(self, l[1], Vector2(o.x + GRID_W - 6 - PixelFont.width(l[1]), y), Hud.TEXT)
		y += PixelFont.LINE


## The device: its slot in a frame, the map's lines under it, what is open, and the button.
func _draw_device() -> void:
	var o := origin("stash")
	var r := Rect2(o, Vector2(GRID_W, Gear.STASH_SIZE.y * CELL))
	Hud.panel(self, r.grow(2), Color("#2A2A30"), Color(0.03, 0.03, 0.04, 0.9))
	var slot := cell_rect("device", Rect2i(Vector2i.ZERO, Vector2i.ONE))
	var pulse := 0.5 + 0.5 * sin(t * 3)
	Hud.panel(self, slot.grow(4), Hud.ORANGE.lerp(Hud.ORANGE_LIGHT, pulse) if not Progress.device.is_empty() else Color("#3A3A42"), CELL_FILL)
	if Progress.device.is_empty():
		ItemTooltip.draw_icon(self, {}, slot.get_center(), 1, true, "map")
	else:
		_draw_item(Progress.device[0], slot, false)
	var y := slot.end.y + 10
	var lines := []
	if not Progress.device.is_empty():
		var it: Dictionary = Progress.device[0]
		lines.append([Items.name_of(it), Items.color(it)])
		lines.append(["TIER %d · AREA LEVEL %d" % [it.tier, it.ilvl], Hud.TEXT_DIM])
		for l in Items.lines(it) + Maps.extra_lines(it):
			lines.append([l[0], ItemTooltip.IMPLICIT if l[2] else ItemTooltip.AFFIX])
		lines.append(["%d PORTALS" % Main.MAP_PORTALS, Hud.TEXT_DIM])
	else:
		lines.append(["PUT A MAP IN THE SLOT", Hud.TEXT_DIM])
	if not main.map_run.is_empty():
		lines.append(["", Hud.TEXT_DIM])
		lines.append(["OPEN: " + Items.name_of(main.map_run.item), Items.color(main.map_run.item)])
		lines.append(["%d / %d PORTALS LEFT" % [main.map_run.portals, Main.MAP_PORTALS], Hud.ORANGE_LIGHT])
		if not Progress.device.is_empty():
			lines.append(["(a new map gives it up)", ItemTooltip.DIM])
	for l in lines:
		PixelFont.draw_centred(self, l[0], r.get_center().x, y, l[1])
		y += PixelFont.LINE
	var b := device_button()
	var label := "O · OPEN THE MAP" if not Progress.device.is_empty() else "O · BACK INTO THE MAP" if not main.map_run.is_empty() else ""
	if label != "":
		var on := b.has_point(_mouse)
		Hud.panel(self, b, Hud.ORANGE, Color(0.12, 0.07, 0.05, 0.95) if on else Color(0.07, 0.07, 0.08, 0.9))
		PixelFont.draw_centred(self, label, b.get_center().x, b.position.y + 4, Hud.ORANGE_LIGHT)


func _label(s: String, at: Vector2) -> void:
	PixelFont.draw(self, s, at + Vector2(0, -10), Hud.TEXT_DIM)


func _big(s: String, at: Vector2, color: Color) -> void:
	draw_set_transform(at.round(), 0, Vector2(2, 2))
	PixelFont.draw(self, s, Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, Vector2.ZERO, color)
	draw_set_transform(Vector2.ZERO)
