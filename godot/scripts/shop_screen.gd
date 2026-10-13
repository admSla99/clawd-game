class_name ShopScreen
extends Node2D

## The shop (ShopScene in src/scenes/shop.ts), over the drifting backdrop like the map, in the HUD's look. On the
## left the items by section (icon, name, level pips / stock / price); on the right the selected item's card
## (description, level or stock, what buying does now); below it HAIKU, the shopkeeper: a blue Clawd with an
## orange bow tie (a voxel model at twice the size, hung on the camera like the title's Clawd) who only speaks in
## 5-7-5, typed out in a bubble: idle haiku every 9 s, thanks, refusals, and the fortunes it sells. Wallet top
## right (banked tokens, sparks not spent). Up / down (or the wheel) choose, Space / Enter or a click buys (or
## equips an owned weapon), Escape or the shop key goes back to the map. A list taller than the screen (with the
## ARMORY open) scrolls to keep the selected row in view, with arrows in the left margin. A weapon's card shows its
## gun and stat bars (DAMAGE, FIRE RATE, RANGE, HEAT, as in shop.ts). What is for sale and what it does is Shop.

const IDLE := [
	["tokens in your claw", "power waits upon the shelf", "spend them, little crab"],
	["a jet tuned just right", "hangs a moment in the air", "long gaps fear it so"],
	["no refunds, my friend", "all sales are final, much like", "a model's weights are"],
	["sparks hide in the dark", "my radar hums when they're near", "eighty tokens, yours"],
	["codex waits up north", "it types faster than it thinks", "bring a bigger heart"],
]
const THANKS := [["thank you, come again", "your wallet is lighter now", "your claws are not, though"]]
const DENIED := [["not enough to pay", "go collect a few more, then", "come back, little crab"]]
const LOCKED := [["the armory sleeps", "until a weapon is found", "beyond the first boss"]]
## Small talk once the ARMORY is open (IDLE_HAIKUS in shop.ts).
const ARMORY_IDLE := [
	["a bigger model", "is not always the answer", "but it sure helps here"],
	["context overflows", "like rain in a paper cup", "buy a bigger cup"],
	["codex waits up north", "it types faster than it thinks", "bring the big cannon"],
]
## HAIKU's colours: Clawd's layout in blues (HAIKU_PALETTE in TS, with the port's extra shades).
const HAIKU_PALETTE := {
	"O": Color("#7F9CC6"), "H": Color("#A9C0E2"), "h": Color("#94AED6"), "o": Color("#5D7499"),
	"d": Color("#4A5D7C"), "E": Color("#101418"), "W": Color("#F2F6FF"),
}
const BOW := ["O.O", "OLO", "O.O"]
const BUBBLE := Color("#5A6E8C")
const BUBBLE_TEXT := Color("#B8C8E0")
const ROW_H := 13
const ROW_STEP := 15
const LIST_W := 206
## Item icons, 9 x 9 px ("o" orange, "L" light orange, "W" white, "g" grey).
const ICONS := {
	"hearts": [".........", ".oo...oo.", "oLoo.oooo", "oLooooooo", ".ooooooo.", "..ooooo..", "...ooo...", "....o....", "........."],
	"hover": ["..ooooo..", ".oLLLLLo.", ".ooooooo.", "..o...o..", "..L...L..", "..o...o..", ".........", "..L...L..", "........."],
	"magnet": [".........", ".oo...oo.", ".oo...oo.", ".oo...oo.", ".WW...WW.", ".oo...oo.", "..ooooo..", "...ooo...", "........."],
	"radar": ["....L....", "...LLL...", "..L.L.L..", "....L....", "....o....", "..ooooo..", ".o.....o.", "o.......o", "........."],
	"fortune": ["..ooooo..", ".oLLLLLo.", ".oL...Lo.", ".oLLLLLo.", ".oL...Lo.", ".oLLLLLo.", ".oL...Lo.", ".oLLLLLo.", "..ooooo.."],
	"firewall": [".ooooooo.", ".oLLLLLo.", ".oLWWWLo.", ".oLWWWLo.", ".oLLWLLo.", "..oLLLo..", "...oLo...", "....o....", "........."],
	"double": [".........", "o...o.LL.", ".o.o.L..L", "..o....L.", ".o.o..L..", "o...o.LLL", ".........", ".........", "........."],
	"armory": ["...ggg...", "..g...g..", "..g...g..", ".ggggggg.", ".gg.g.gg.", ".ggg.ggg.", ".ggggggg.", ".........", "........."],
	"damage": [".........", "...ooo...", "...oLo...", ".oooLooo.", ".oLLLLLo.", ".oooLooo.", "...oLo...", "...ooo...", "........."],
	"rate": [".........", "o...o....", "oo..oo...", "oLo.oLo..", "oLLooLLo.", "oLo.oLo..", "oo..oo...", "o...o....", "........."],
	"context": [".........", ".........", "ggggggggg", "gooooo..g", "gLLLLL..g", "gooooo..g", "ggggggggg", ".........", "........."],
}
## The list ends this far above the bottom of the view (the help line is below it).
const LIST_BOTTOM := 16

var main: Main
var sel := 0
var t := 0.0
var haiku: Array = IDLE[0]
var haiku_t := 0.0
## HAIKU hops for a moment when he speaks.
var bounce := 0.0
var _mouse := Vector2(-1000, -1000)
var _props: Node3D
var _haiku_body: MeshInstance3D
var _icons := {}
## What is for sale while the shop is open (Shop.items()), and how far the list is scrolled (px).
var items: Array = Shop.ITEMS
var _scroll := 0.0


func open() -> void:
	visible = true
	t = 0.0
	sel = 0
	_scroll = 0.0
	items = Shop.items()
	say(_idle())
	_ensure_props()
	_props.visible = true


func close() -> void:
	visible = false
	if _props:
		_props.visible = false


func _idle() -> Array:
	var pool: Array = IDLE + ARMORY_IDLE if not Progress.weapons.is_empty() else IDLE
	return pool[randi() % pool.size()]


func say(lines: Array) -> void:
	haiku = lines
	haiku_t = 0.0
	bounce = 0.4


# --- Input ---------------------------------------------------------------------

func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		sel = (sel + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else items.size() - 1)) % items.size()
		Sound.play("select")
		return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		var rows := _rows()
		for i in rows.size():
			if _shown(rows[i]) and rows[i].has_point(_mouse):
				if i == sel:
					_activate()
				else:
					sel = i
					Sound.play("select")
				return true
		if _detail_rect().has_point(_mouse):
			_activate()
		return true
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if event.is_action_pressed("back") or event.is_action_pressed("shop"):
		Sound.play("select")
		main.show_map(main.front.sel)
	elif event.is_action_pressed("down") or event.is_action_pressed("ui_down"):
		sel = (sel + 1) % items.size()
		Sound.play("select")
	elif event.is_action_pressed("up") or event.is_action_pressed("ui_up"):
		sel = (sel + items.size() - 1) % items.size()
		Sound.play("select")
	elif event.is_action_pressed("confirm") or event.is_action_pressed("jump"):
		_activate()
	else:
		return false
	return true


func _activate() -> void:
	var it: Dictionary = items[sel]
	if it.kind == "locked":
		Sound.play("denied")
		say(LOCKED[0])
		return
	match Shop.buy(it, main.level_ids):
		"bought":
			Sound.play("buy")
			say(Progress.fortune if it.kind == "fortune" else THANKS[0])
		"equipped":
			Sound.play("select")
		"poor":
			Sound.play("denied")
			say(DENIED[0])
		_:
			Sound.play("denied")


# --- Layout --------------------------------------------------------------------

func _view() -> Rect2:
	return Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)


## Row rects in item order, under their section headings, scrolled by _scroll.
func _rows() -> Array:
	var v := _view()
	var y := _list_top() - _scroll
	var section := ""
	var out := []
	for it in items:
		if it.section != section:
			section = it.section
			y += 10
		out.append(Rect2(v.position.x + 14, y, LIST_W, ROW_H))
		y += ROW_STEP
	return out


func _list_top() -> float:
	return _view().position.y + 32


func _list_bottom() -> float:
	return _view().end.y - LIST_BOTTOM


## Whether a row is inside the list area (only those are drawn and clickable).
func _shown(r: Rect2) -> bool:
	return r.position.y >= _list_top() - 0.5 and r.end.y <= _list_bottom() + 0.5


## Scrolls just enough to show the selected row, with its section's heading when it is the section's first row.
func _follow() -> void:
	var r: Rect2 = _rows()[sel]
	# Unscrolled positions; the top wins when the row does not fit whole.
	var top := r.position.y + _scroll
	if sel == 0 or items[sel].section != items[sel - 1].section:
		top -= 10
	var bottom := r.end.y + _scroll
	_scroll = maxf(0.0, minf(maxf(_scroll, bottom - _list_bottom()), top - _list_top()))


func _detail_rect() -> Rect2:
	var v := _view()
	var x := v.position.x + 14 + LIST_W + 10
	return Rect2(x, v.position.y + 32, v.end.x - 14 - x, 116)


# --- Update --------------------------------------------------------------------

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	haiku_t += dt
	bounce = maxf(0.0, bounce - dt)
	# A fortune stays up longer than small talk.
	if haiku_t > (20.0 if haiku == Progress.fortune else 9.0):
		say(_idle())
	_follow()
	_update_haiku()
	queue_redraw()


func _haiku_feet() -> Vector2:
	var d := _detail_rect()
	return Vector2(d.position.x + 26, _view().end.y - 24)


## Where SubViewport pixel `sv` is relative to the camera, in front of everything (see FrontEnd).
func _on_camera(sv: Vector2) -> Vector3:
	var half := get_viewport_rect().size / 2
	return Vector3((sv.x - half.x) * Px.M, -(sv.y - half.y) * Px.M, -GameCamera.DISTANCE) + FrontEnd.FRONT


func _ensure_props() -> void:
	if _props:
		return
	_props = Node3D.new()
	_props.name = "ShopProps"
	_props.scale = Vector3.ONE * 2
	main.camera.add_child(_props)
	_haiku_body = MeshInstance3D.new()
	_props.add_child(_haiku_body)
	var bow := MeshInstance3D.new()
	bow.mesh = Voxel.mesh(BOW, {"O": Color("#D97757"), "L": Color("#F0A585")}, {"O": 14, "L": 14}, Px.M, Voxel.MATERIAL)
	# At the bottom of his body, just above the legs (the 2D bow tie's place).
	bow.position.y = 6 * Px.M
	_props.add_child(bow)


func _update_haiku() -> void:
	var hop := roundf(absf(sin(bounce * 20)) * 2) if bounce > 0 else 0.0
	_props.position = _on_camera(_haiku_feet() + Vector2(0, -hop * 2))
	var blink := sin(t * 0.8) > 0.97
	_haiku_body.mesh = ClawdSprite.mesh({"arms": "high" if bounce > 0 else "mid", "legs": "stand", "eyes": "blink" if blink else "open",
		"look": Vector2i(1, 0), "palette": HAIKU_PALETTE, "top": {"H": Color("#9BB4DA")}})


# --- Drawing -------------------------------------------------------------------

func _draw() -> void:
	var v := _view()
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.02, 0.02, 0.04, 0.5))
	_big("SHOP", v.position + Vector2(14, 8), Hud.ORANGE)
	_text("run by HAIKU · 5-7-5 customer service", v.position + Vector2(14 + PixelFont.width("SHOP") * 2 + 10, 12), Hud.TEXT_DIM)
	_draw_wallet(v)
	_draw_list()
	_draw_detail()
	_draw_bubble()
	var help := "↑ ↓ CHOOSE    SPACE BUY / EQUIP    ESC BACK" if not Progress.weapons.is_empty() else "↑ ↓ CHOOSE    SPACE BUY    ESC BACK"
	_text(help, Vector2(v.get_center().x - PixelFont.width(help) / 2.0, v.end.y - 10), Color("#5C5C5C"))


func _text(s: String, at: Vector2, color: Color) -> void:
	PixelFont.draw(self, s, at + Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, at, color)


func _big(s: String, at: Vector2, color: Color) -> void:
	draw_set_transform(at.round(), 0, Vector2(2, 2))
	PixelFont.draw(self, s, Vector2(0, 1), Color(0, 0, 0, 0.65))
	PixelFont.draw(self, s, Vector2.ZERO, color)
	draw_set_transform(Vector2.ZERO)


## An item's icon: its grid in ICONS, or a weapon's gun (GunSprite) at one pixel a cell.
func _icon(id: String) -> ImageTexture:
	if not _icons.has(id):
		if GunSprite.SPRITES.has(id):
			_icons[id] = Spark._texture(GunSprite.SPRITES[id], GunSprite.PALETTE)
		else:
			_icons[id] = Spark._texture(ICONS[id], {"o": Color("#D97757"), "L": Color("#F0A585"), "W": Color("#FFF1E6"), "g": Color("#5A5A5A")})
	return _icons[id]


func _draw_wallet(v: Rect2) -> void:
	var sparks := str(Progress.sparks_available())
	var x := v.end.x - 14 - PixelFont.width(sparks)
	_text(sparks, Vector2(x, v.position.y + 12), Hud.TEXT)
	x -= 13
	draw_texture(Spark.icon(), Vector2(x, v.position.y + 10))
	var tokens := str(Progress.wallet)
	x -= 10 + PixelFont.width(tokens)
	_text(tokens, Vector2(x, v.position.y + 12), Hud.TEXT)
	draw_texture(Hud._coin_tex[8], Vector2(x - 12, v.position.y + 11))


## A price from the right edge leftwards: token icon and amount, then spark icon and amount; red when short.
func _draw_price(right: float, y: float, p: Dictionary) -> void:
	var x := right
	if p.sparks > 0:
		var s := str(p.sparks)
		x -= PixelFont.width(s)
		PixelFont.draw(self, s, Vector2(x, y), Hud.TEXT if Progress.sparks_available() >= p.sparks else Hud.RED)
		x -= 11
		draw_texture(Spark.icon(), Vector2(x, y - 2))
		x -= 8
	var tk := str(p.tokens)
	x -= PixelFont.width(tk)
	PixelFont.draw(self, tk, Vector2(x, y), Hud.TEXT if Progress.wallet >= p.tokens else Hud.RED)
	draw_texture(Hud._coin_tex[8], Vector2(x - 11, y - 1))


func _draw_list() -> void:
	var rows := _rows()
	var section := ""
	var x: float = rows[0].position.x
	if _scroll > 0:
		PixelFont.draw(self, "▲", Vector2(x - 9, _list_top() + 1), Hud.ORANGE)
	if rows[-1].end.y > _list_bottom() + 0.5:
		PixelFont.draw(self, "▼", Vector2(x - 9, _list_bottom() - 7), Hud.ORANGE)
	for i in items.size():
		var it: Dictionary = items[i]
		var r: Rect2 = rows[i]
		var heading: bool = it.section != section
		section = it.section
		if heading and _shown(r) and r.position.y - 9 >= _list_top() - 0.5:
			PixelFont.draw(self, section, r.position + Vector2(0, -9), Color("#6A6A6A"))
		if not _shown(r):
			continue
		var selected := i == sel
		var hover := r.has_point(_mouse)
		var border := Hud.ORANGE if selected else Hud.ORANGE_LIGHT.lerp(Color("#2C2C2C"), 0.5) if hover else Color("#2C2C2C")
		Hud.panel(self, r, border, Color(0.12, 0.075, 0.07, 0.94) if selected else Color(0.07, 0.07, 0.08, 0.9))
		var locked: bool = it.kind == "locked"
		var icon := _icon(it.id)
		draw_texture(icon, r.position + Vector2(3, floorf((ROW_H - icon.get_height()) / 2.0)))
		var name_col := Color("#6A6A6A") if locked else Hud.TEXT if selected else Hud.TEXT_DIM
		PixelFont.draw(self, it.name, r.position + Vector2(17, 4), name_col)
		var right := r.end.x - 5
		var y := r.position.y + 4
		match it.kind:
			"upgrade":
				var lv := Progress.upgrade(it.id)
				var n: int = it.prices.size()
				for k in n:
					draw_rect(Rect2(r.end.x - 74 + k * 5, y + 1, 3, 3), Hud.ORANGE if k < lv else Color("#3A3A3A"))
				if lv >= n:
					PixelFont.draw(self, "MAX", Vector2(right - PixelFont.width("MAX"), y), Color("#6A6A6A"))
				else:
					_draw_price(right, y, Shop.price(it, main.level_ids))
			"stock":
				var have := Progress.in_stock(it.id)
				PixelFont.draw(self, "x%d" % have, Vector2(r.end.x - 74, y), Hud.ORANGE_LIGHT if have > 0 else Color("#4A4A4A"))
				var p := Shop.price(it, main.level_ids)
				if p.is_empty():
					PixelFont.draw(self, "FULL", Vector2(right - PixelFont.width("FULL"), y), Color("#6A6A6A"))
				else:
					_draw_price(right, y, p)
			"fortune":
				var p := Shop.price(it, main.level_ids)
				if p.is_empty():
					PixelFont.draw(self, "ALL FOUND", Vector2(right - PixelFont.width("ALL FOUND"), y), Color("#6A6A6A"))
				else:
					_draw_price(right, y, p)
			"locked":
				PixelFont.draw(self, "LOCKED", Vector2(right - PixelFont.width("LOCKED"), y), Color("#5A5A5A"))
			"weapon":
				if Progress.weapons.has(it.id):
					var eq: bool = Progress.equipped == it.id
					var s := "EQUIPPED" if eq else "OWNED"
					PixelFont.draw(self, s, Vector2(right - PixelFont.width(s), y), Hud.ORANGE if eq else Color("#6A6A6A"))
				else:
					_draw_price(right, y, Shop.price(it, main.level_ids))


## Words of `s` wrapped to `w` px, from `at` down, 8 px a line. Returns the y after the last line.
func _wrap(s: String, at: Vector2, w: float, color: Color) -> float:
	var line := ""
	var y := at.y
	for word in s.split(" "):
		var test := word if line == "" else line + " " + word
		if PixelFont.width(test) > w and line != "":
			PixelFont.draw(self, line, Vector2(at.x, y), color)
			line = word
			y += 8
		else:
			line = test
	if line != "":
		PixelFont.draw(self, line, Vector2(at.x, y), color)
		y += 8
	return y


func _draw_detail() -> void:
	var d := _detail_rect()
	var it: Dictionary = items[sel]
	Hud.panel(self, d, Color("#4A4A4A"), Color(0.07, 0.07, 0.08, 0.95), true)
	_big(String(it.name).to_upper(), d.position + Vector2(8, 7), Hud.TEXT if it.kind != "locked" else Color("#8A8A8A"))
	var y := _wrap(it.desc, d.position + Vector2(8, 26), d.size.x - 16, Hud.TEXT_DIM)
	y += 4
	var info := ""
	var info_col := Hud.ORANGE_LIGHT
	match it.kind:
		"upgrade":
			info = "LEVEL %d / %d" % [Progress.upgrade(it.id), it.prices.size()]
		"stock":
			info = "IN STOCK %d / %d" % [Progress.in_stock(it.id), it.max]
		"fortune":
			var left := Shop.secrets(main.level_ids).size()
			info = "%d STILL HIDDEN IN THE OPEN LEVELS" % left if left > 0 else "NOTHING LEFT TO FIND"
	if info != "":
		PixelFont.draw(self, info, Vector2(d.position.x + 8, y), info_col)
		y += 10
	var effect := _mod_effect(it)
	if effect != "":
		PixelFont.draw(self, effect, Vector2(d.position.x + 8, y), Hud.TEXT_DIM)
		y += 10
	if it.kind == "weapon":
		_draw_stats(Weapons.get_def(it.id), d, y)
	# The last fortune, to read again.
	if it.kind == "fortune" and not Progress.fortune.is_empty():
		for line in Progress.fortune:
			PixelFont.draw(self, line, Vector2(d.position.x + 14, y), BUBBLE_TEXT)
			y += 8
	var p := Shop.price(it, main.level_ids)
	var hint := ""
	var col := Hud.ORANGE
	if it.kind == "locked":
		hint = "OPENS IN WORLD 2"
		col = Color("#6A6A6A")
	elif it.kind == "weapon" and Progress.weapons.has(it.id):
		hint = "SPACE / CLICK: EQUIP"
		if Progress.equipped == it.id:
			hint = "EQUIPPED · SWITCH: 1-5 / %s / WHEEL" % Settings.keys_text(["prev", "next"])
	elif p.is_empty():
		hint = "FULLY UPGRADED" if it.kind == "upgrade" else "STOCK FULL" if it.kind == "stock" else "NOTHING LEFT TO TELL"
		col = Color("#6A6A6A")
	elif Shop.affordable(p):
		hint = "SPACE / CLICK: BUY"
	else:
		hint = "NOT ENOUGH " + ("TOKENS" if Progress.wallet < p.tokens else "SPARKS")
		col = Hud.RED
	PixelFont.draw(self, hint, Vector2(d.position.x + 8, d.end.y - 11), col)
	if not p.is_empty():
		_draw_price(d.end.x - 8, d.end.y - 11, p)


## What a gun mod does now, and after the next level: damage and fire rate multipliers, the context size.
func _mod_effect(it: Dictionary) -> String:
	if it.section != "GUN MODS":
		return ""
	var lv := Progress.upgrade(it.id)
	var at := func(l: int) -> String:
		match it.id:
			"damage":
				return "x%.2f" % (1.0 + 0.25 * l)
			"rate":
				return "x%.2f" % (1.0 + 0.15 * l)
		return str(100 + 40 * l)
	var what: String = {"damage": "DAMAGE", "rate": "FIRE RATE", "context": "CONTEXT"}[it.id]
	if lv >= it.prices.size():
		return "%s %s" % [what, at.call(lv)]
	return "%s %s → %s" % [what, at.call(lv), at.call(lv + 1)]


## A weapon's stat bars (render() in shop.ts): damage per second, fire rate, range (the beam's fixed) and heat per
## second, 20 cells each; a line for the cannon's splash or the beam's pierce; its gun at four times the list size.
func _draw_stats(w: Dictionary, d: Rect2, y: float) -> void:
	var dps: float = w.damage * w.pellets * w.fire_rate
	var stats := [
		["DAMAGE", minf(1.0, dps / 36)],
		["FIRE RATE", minf(1.0, w.fire_rate / 20)],
		["RANGE", 0.85 if w.kind == "beam" else minf(1.0, w.speed * w.life / 360)],
		["HEAT", minf(1.0, w.heat * w.fire_rate / 80)],
	]
	for k in stats.size():
		PixelFont.draw(self, stats[k][0], Vector2(d.position.x + 8, y + k * 9), Color("#6A6A6A"))
		for c in 20:
			draw_rect(Rect2(d.position.x + 62 + c * 4, y + 1 + k * 9, 3, 4), Hud.ORANGE if float(c) / 20 < stats[k][1] else Color("#2E2E2E"))
	if w.has("splash"):
		PixelFont.draw(self, "splash damage · breaks corrupted blocks", Vector2(d.position.x + 8, y + 37), Hud.ORANGE_LIGHT)
	if w.kind == "beam":
		PixelFont.draw(self, "pierces every enemy in the line", Vector2(d.position.x + 8, y + 37), BeamFx.CYAN)
	var icon := _icon(w.id)
	var at := Vector2(d.position.x + 148 + (d.end.x - 8 - d.position.x - 148 - icon.get_width() * 4) / 2.0, y + 18 - icon.get_height() * 2).round()
	draw_set_transform(at, 0, Vector2(4, 4))
	draw_texture(icon, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)


## HAIKU's words, typed out at 40 letters a second, in a blue bubble with a tail towards him.
func _draw_bubble() -> void:
	var feet := _haiku_feet()
	var w := 0
	for line in haiku:
		w = maxi(w, PixelFont.width(line))
	var r := Rect2(feet.x + 34, feet.y - 52, w + 14, 32)
	Hud.panel(self, r, BUBBLE, Color(0.07, 0.08, 0.1, 0.95))
	for i in 3:
		draw_rect(Rect2(r.position.x - 1 - i, r.end.y - 10 + i, 1 + i, 1), BUBBLE)
	var chars := floori(haiku_t * 40)
	var used := 0
	for i in haiku.size():
		var line: String = haiku[i]
		var shown := line.substr(0, maxi(0, chars - used))
		used += line.length()
		PixelFont.draw(self, shown, r.position + Vector2(7, 5 + i * 8), BUBBLE_TEXT)
	PixelFont.draw_centred(self, "HAIKU", feet.x, feet.y + 4, Color("#7F9CC6"))
