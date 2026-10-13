class_name GameMenu
extends Node2D

## The in-level menus of src/scenes/game.ts and src/scenes/keybinds.ts, drawn over everything in the Ui layer
## in SubViewport pixels with the HUD's panel look:
## - CONTROLS help (the `controls` key or the HUD button; drawControlsOverlay() in src/render/hud.ts): what
##   every key does, from the current bindings; confirm opens the keybindings.
## - PAUSE (the `pause` key, Escape or the HUD button): RESUME, RESTART FROM CHECKPOINT, RESTART LEVEL,
##   CRT FILTER, CROSSHAIR (the port's: its colour, confirm or left / right cycle it, with a preview), KEYBINDINGS,
##   QUIT TO MAP.
## - KEYBINDINGS (KeybindMenu): every bindable action with SLOTS key slots; confirm on a slot listens for the
##   next key (Escape cancels, Backspace clears the slot), a key bound to another action is refused with a
##   message, RESET DEFAULTS and BACK. Changes go to Settings, which saves them.
## Main forwards input events to handle(); the mouse works too (hover selects, click activates). While a menu
## is open the world is paused (Game.paused); closing it resumes two physics frames later, so the key that
## closed it is not also a jump.

enum { NONE, CONTROLS, PAUSE, KEYS }

const PAUSE_ITEMS := ["RESUME", "RESTART FROM CHECKPOINT", "RESTART LEVEL", "CRT FILTER", "CROSSHAIR", "KEYBINDINGS", "QUIT TO MAP"]
const BORDER := Color("#4A4A4A")
const SLOT_BORDER := Color("#2C2C2C")
const PANEL_FILL := Color(0.075, 0.07, 0.085, 0.97)
const SLOT_FILL := Color(0.06, 0.06, 0.07, 0.9)
const KEY_ROW := 11
const SLOT_W := 36

var state := NONE
var pause_index := 0
var key_row := 0
var key_slot := 0
var listening := false
var error := ""
## Seconds since the current menu opened (fade and slide in).
var open_t := 0.0
var _keys_from := NONE
var _unpause := 0
var _t := 0.0
var _mouse := Vector2(-1000, -1000)
var main: Main


func is_open() -> bool:
	return state != NONE


func _open(s: int) -> void:
	if state == NONE:
		open_t = 0.0
	state = s
	Game.paused = true
	_unpause = 0


func close() -> void:
	state = NONE
	listening = false
	error = ""
	_unpause = 2


func open_pause() -> void:
	if state == NONE and main.complete_t < 0 and main.mode == Main.Mode.PLAY:
		pause_index = 0
		Sound.play("select")
		_open(PAUSE)


func open_controls() -> void:
	if state == NONE and main.complete_t < 0:
		_open(CONTROLS)


func open_keys() -> void:
	_keys_from = state
	key_row = 0
	key_slot = 0
	listening = false
	error = ""
	open_t = 0.0
	_open(KEYS)


func _physics_process(_dt: float) -> void:
	if _unpause > 0:
		_unpause -= 1
		if _unpause == 0:
			Game.paused = false


func _process(dt: float) -> void:
	_t += dt
	open_t += dt
	if main:
		main.hud.mouse = _mouse
		main.hud.controls_open = state == CONTROLS
		main.hud.pause_open = state == PAUSE
	queue_redraw()


## An input event from Main, with mouse positions already in SubViewport pixels. Returns true when the menu
## used it.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		_mouse = event.position
		_hover(_mouse)
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse = event.position
		return _click(_mouse)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	if listening:
		_capture(event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode)
		return true
	if event.is_action_pressed("mute"):
		toggle_mute()
		return true
	match state:
		NONE:
			if event.is_action_pressed("pause"):
				open_pause()
				return state != NONE
			if event.is_action_pressed("controls"):
				open_controls()
				return state != NONE
			return false
		CONTROLS:
			if event.is_action_pressed("confirm"):
				open_keys()
			elif event.is_action_pressed("controls") or event.is_action_pressed("pause") or event.is_action_pressed("back"):
				close()
			return true
		PAUSE:
			if event.is_action_pressed("pause") or event.is_action_pressed("back"):
				close()
			elif _pressed(event, "down"):
				pause_index = (pause_index + 1) % PAUSE_ITEMS.size()
				Sound.play("select")
			elif _pressed(event, "up"):
				pause_index = (pause_index + PAUSE_ITEMS.size() - 1) % PAUSE_ITEMS.size()
				Sound.play("select")
			elif PAUSE_ITEMS[pause_index] == "CROSSHAIR" and (_pressed(event, "left") or _pressed(event, "right")):
				Settings.cycle_crosshair(1 if _pressed(event, "right") else -1)
				Sound.play("select")
			elif event.is_action_pressed("confirm"):
				_activate_pause()
			return true
		KEYS:
			_keys_input(event)
			return true
	return false


## An action, or its arrow key, so the menus stay usable whatever the bindings are.
func _pressed(event: InputEvent, action: String) -> bool:
	return event.is_action_pressed(action) or event.is_action_pressed("ui_" + action)


func _activate_pause() -> void:
	Sound.play("confirm")
	match PAUSE_ITEMS[pause_index]:
		"RESUME":
			close()
		"RESTART FROM CHECKPOINT":
			close()
			main.player.respawn()
		"RESTART LEVEL":
			close()
			main.load_level(main.level_id)
		"CRT FILTER":
			Settings.set_crt(not Settings.crt)
			main.crt.visible = Settings.crt
		"CROSSHAIR":
			Settings.cycle_crosshair()
		"KEYBINDINGS":
			open_keys()
		"QUIT TO MAP":
			state = NONE
			main.show_map(main.level_ids.find(main.level_id))


func _keys_rows() -> int:
	return Settings.BINDABLE.size() + 2


func _keys_input(event: InputEvent) -> void:
	if event.is_action_pressed("back") or event.is_action_pressed("pause"):
		_close_keys()
		return
	if _pressed(event, "down") or _pressed(event, "up") or _pressed(event, "left") or _pressed(event, "right"):
		error = ""
	if _pressed(event, "down"):
		key_row = (key_row + 1) % _keys_rows()
		Sound.play("select")
	elif _pressed(event, "up"):
		key_row = (key_row + _keys_rows() - 1) % _keys_rows()
		Sound.play("select")
	elif _pressed(event, "right"):
		key_slot = mini(Settings.SLOTS - 1, key_slot + 1)
	elif _pressed(event, "left"):
		key_slot = maxi(0, key_slot - 1)
	elif event.is_action_pressed("confirm"):
		_activate_keys()


func _activate_keys() -> void:
	if key_row < Settings.BINDABLE.size():
		listening = true
		error = ""
	elif key_row == Settings.BINDABLE.size():
		Settings.reset_defaults()
		Sound.play("confirm")
		error = ""
	else:
		_close_keys()


func _close_keys() -> void:
	listening = false
	error = ""
	if _keys_from == NONE:
		close()
	else:
		state = _keys_from


## The key pressed while listening for a new binding.
func _capture(code: int) -> void:
	var action: StringName = Settings.BINDABLE[key_row]
	if code == KEY_ESCAPE:
		listening = false
		return
	if code == KEY_BACKSPACE:
		Settings.clear(action, key_slot)
	else:
		var other := Settings.bind(action, key_slot, code)
		if other != &"":
			# Refuse and keep listening, so another key can be picked.
			error = "%s ALREADY BOUND TO %s" % [Settings.key_label(code), Settings.LABELS[other]]
			Sound.play("denied")
			return
	listening = false
	error = ""
	Sound.play("confirm")


## The mute key or the HUD's speaker (toggleMute() in src/app.ts); saved with the settings.
func toggle_mute() -> void:
	Settings.set_muted(not Settings.muted)
	Sound.set_muted(Settings.muted)


func _hover(p: Vector2) -> void:
	var l := layout()
	match state:
		PAUSE:
			for i in l.rows.size():
				if l.rows[i].has_point(p):
					pause_index = i
		KEYS:
			if listening:
				return
			for r in l.slots.size():
				for s in l.slots[r].size():
					if l.slots[r][s].has_point(p):
						key_row = r
						key_slot = s
			if l.reset.has_point(p):
				key_row = Settings.BINDABLE.size()
			elif l.back.has_point(p):
				key_row = Settings.BINDABLE.size() + 1


func _click(p: Vector2) -> bool:
	var l := layout()
	var hud: Dictionary = main.hud.buttons()
	match state:
		NONE:
			if main.mode != Main.Mode.PLAY:
				return false
			if hud.mute.has_point(p):
				toggle_mute()
				return true
			if hud.controls.has_point(p):
				open_controls()
			elif hud.pause.has_point(p):
				open_pause()
			return state != NONE
		CONTROLS:
			if l.change.has_point(p):
				open_keys()
			else:
				close()
		PAUSE:
			for i in l.rows.size():
				if l.rows[i].has_point(p):
					pause_index = i
					_activate_pause()
					return true
			if hud.pause.has_point(p):
				close()
		KEYS:
			if listening:
				listening = false
				return true
			_hover(p)
			for r in l.slots.size():
				for s in l.slots[r].size():
					if l.slots[r][s].has_point(p):
						_activate_keys()
						return true
			if l.reset.has_point(p) or l.back.has_point(p):
				_activate_keys()
	return true


## The visible part of the SubViewport (Main.PAD is cut off on every side).
func _view() -> Rect2:
	return Rect2(Vector2.ONE * Main.PAD, get_viewport_rect().size - Vector2.ONE * Main.PAD * 2)


## The controls help as [keys, what they do] (controlLines() in src/render/hud.ts, without the gamepad line).
## Shooting, aiming and switching weapons are listed once Clawd has found a weapon.
func control_lines() -> Array:
	var k := func(actions: Array) -> String: return Settings.keys_text(actions)
	var first := func(a: StringName) -> String: return Settings.key_label(Settings.bindings[a][0])
	var armed := not Progress.weapons.is_empty()
	var lines := [
		[k.call([&"left", &"right"]), "Move"],
		[k.call([&"jump"]), "Jump"],
		["HOLD " + first.call(&"jump") + " (AIR)", "Hover — the jet hurts enemies"],
	]
	if armed:
		lines.append([k.call([&"attack"]), "World 1: spin · Worlds 2-3: shoot"])
		lines.append([k.call([&"spin"]), "Spin attack"])
	else:
		lines.append([k.call([&"attack", &"spin"]), "Spin attack"])
	lines.append_array([
		[k.call([&"down"]) + " (AIR)", "Ground pound — breaks corrupted data"],
		[first.call(&"down") + " + " + first.call(&"jump"), "Drop through platforms"],
	])
	if armed:
		lines.append_array([
			["MOUSE + LMB", "World 2: aim and shoot"],
			[first.call(&"up") + " " + first.call(&"down") + " + " + first.call(&"attack"), "Aim up / down without a mouse"],
			["1-5 · " + k.call([&"prev", &"next"]) + " · WHEEL", "Switch weapon"],
		])
	if Progress.has_tool("hook"):
		lines.append([k.call([&"tool"]) + " / RMB", "Tool Call: zip to endpoints, rip shields"])
	if Progress.has_tool("agents"):
		lines.append([k.call([&"agent"]) + " / MMB", "Sub-agent: replays your last 3 s, holds plates"])
	lines.append_array([
		[k.call([&"shop"]) + " (MAP)", "Shop"],
		[k.call([&"pause"]) + " / ESC · " + k.call([&"mute"]) + " · " + k.call([&"controls"]), "Pause · mute · this help"],
	])
	return lines


## Rects of everything clickable in the open menu, in SubViewport pixels: `panel`, and per menu `rows`
## (pause), `slots` [row][slot], `reset`, `back` (keybindings) or `change` (controls).
func layout() -> Dictionary:
	var v := _view()
	var c := v.get_center()
	var out := {"rows": [], "slots": [], "reset": Rect2(), "back": Rect2(), "change": Rect2()}
	match state:
		PAUSE:
			var w := 200.0
			var h := 28.0 + PAUSE_ITEMS.size() * 13 + 18
			out.panel = Rect2(roundf(c.x - w / 2), roundf(c.y - h / 2), w, h)
			for i in PAUSE_ITEMS.size():
				out.rows.append(Rect2(out.panel.position.x + 6, out.panel.position.y + 28 + i * 13, w - 12, 13))
		CONTROLS:
			var lines := control_lines()
			var kw := 0
			var dw := 0
			for l in lines:
				kw = maxi(kw, PixelFont.width(l[0]))
				dw = maxi(dw, PixelFont.width(l[1]))
			var w := float(maxi(230, 12 + kw + 14 + dw + 12))
			var h := 30.0 + lines.size() * 11 + 22
			out.panel = Rect2(roundf(c.x - w / 2), roundf(c.y - h / 2), w, h)
			out.key_w = kw
			var bw := PixelFont.width("ENTER — CHANGE KEYS") + 14
			out.change = Rect2(roundf(c.x - bw / 2.0), out.panel.end.y - 17, bw, 11)
		KEYS:
			var w := 250.0
			# Rows, the buttons, a line for the error and one for the hint.
			var h := 27.0 + Settings.BINDABLE.size() * KEY_ROW + 11 + 26
			var top := maxf(v.position.y + 2, roundf(c.y - h / 2))
			out.panel = Rect2(roundf(c.x - w / 2), top, w, h)
			var slot_x: float = out.panel.end.x - 8 - Settings.SLOTS * (SLOT_W + 3)
			for i in Settings.BINDABLE.size():
				var row := []
				for s in Settings.SLOTS:
					row.append(Rect2(slot_x + s * (SLOT_W + 3), top + 25 + i * KEY_ROW, SLOT_W, 10))
				out.slots.append(row)
			var by := top + 27 + Settings.BINDABLE.size() * KEY_ROW
			var rw := PixelFont.width("RESET DEFAULTS") + 14
			var bw := PixelFont.width("BACK") + 14
			out.reset = Rect2(roundf(out.panel.position.x + w / 3 - rw / 2.0), by, rw, 11)
			out.back = Rect2(roundf(out.panel.position.x + w * 2 / 3 - bw / 2.0), by, bw, 11)
	return out


func _draw() -> void:
	if state == NONE:
		return
	var k := clampf(open_t / 0.15, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.03, 0.03, 0.05, 0.6 * k))
	var l := layout()
	match state:
		PAUSE:
			_draw_pause(l)
		CONTROLS:
			_draw_controls(l)
		KEYS:
			_draw_keys(l)


## A title at twice the size, centred, in orange.
func _title(text: String, cx: float, y: float) -> void:
	draw_set_transform(Vector2(roundf(cx - PixelFont.width(text)), y), 0, Vector2(2, 2))
	PixelFont.draw(self, text, Vector2(0, 1), Color(0, 0, 0, 0.6))
	PixelFont.draw(self, text, Vector2.ZERO, Hud.ORANGE)
	draw_set_transform(Vector2.ZERO)


## A selected row: a faint orange bar with a bright left edge.
func _highlight(r: Rect2) -> void:
	draw_rect(r, Color(Hud.ORANGE, 0.12))
	draw_rect(Rect2(r.position, Vector2(1, r.size.y)), Hud.ORANGE)


func _draw_pause(l: Dictionary) -> void:
	var p: Rect2 = l.panel
	Hud.panel(self, p, BORDER, PANEL_FILL, true)
	_title("PAUSED", p.get_center().x, p.position.y + 8)
	for i in PAUSE_ITEMS.size():
		var r: Rect2 = l.rows[i]
		var sel := i == pause_index
		var label: String = PAUSE_ITEMS[i]
		if label == "CRT FILTER":
			label += ": " + ("ON" if Settings.crt else "OFF")
		if label == "CROSSHAIR":
			label += ": " + Settings.CROSSHAIRS[Settings.crosshair][0]
			# A preview at the row's right end.
			Hud.draw_crosshair(self, Vector2(r.end.x - 12, r.position.y + 6), Settings.crosshair_color())
		if sel:
			_highlight(r)
			# The marker nudges right and back, like a blinking prompt.
			PixelFont.draw(self, ">", r.position + Vector2(6 + (1 if fmod(_t, 0.8) < 0.4 else 0), 3), Hud.ORANGE)
		PixelFont.draw(self, label, r.position + Vector2(16, 3), Hud.TEXT if sel else Hud.TEXT_DIM)
	_hint(p, "↑↓ SELECT · ←→ COLOUR · ESC RESUME" if PAUSE_ITEMS[pause_index] == "CROSSHAIR" else "↑↓ SELECT · ENTER OK · ESC RESUME")


func _draw_controls(l: Dictionary) -> void:
	var p: Rect2 = l.panel
	Hud.panel(self, p, BORDER, PANEL_FILL, true)
	_title("CONTROLS", p.get_center().x, p.position.y + 8)
	var lines := control_lines()
	for i in lines.size():
		var y := p.position.y + 30 + i * 11
		PixelFont.draw(self, lines[i][0], Vector2(p.position.x + 12, y), Hud.TEXT)
		PixelFont.draw(self, lines[i][1], Vector2(p.position.x + 12 + l.key_w + 14, y), Hud.TEXT_DIM)
	var b: Rect2 = l.change
	var on := b.has_point(_mouse)
	Hud.panel(self, b, Hud.ORANGE if on else SLOT_BORDER, SLOT_FILL)
	PixelFont.draw_centred(self, "ENTER — CHANGE KEYS", b.get_center().x, b.position.y + 2, Hud.ORANGE_LIGHT if on else Hud.TEXT)


func _draw_keys(l: Dictionary) -> void:
	var p: Rect2 = l.panel
	Hud.panel(self, p, BORDER, PANEL_FILL, true)
	_title("KEYBINDINGS", p.get_center().x, p.position.y + 6)
	for i in Settings.BINDABLE.size():
		var a: StringName = Settings.BINDABLE[i]
		var sel := i == key_row
		var slots: Array = l.slots[i]
		var y: float = slots[0].position.y
		if sel:
			_highlight(Rect2(p.position.x + 4, y - 1, p.size.x - 8, KEY_ROW + 1))
		PixelFont.draw(self, Settings.LABELS[a], Vector2(p.position.x + 10, y + 2), Hud.TEXT if sel else Hud.TEXT_DIM)
		var keys: Array = Settings.bindings[a]
		for s in slots.size():
			var cur := sel and s == key_slot
			var text := Settings.key_label(keys[s]) if s < keys.size() else "-"
			if cur and listening:
				text = "..." if fmod(_t, 0.6) < 0.3 else ""
			_keycap(slots[s], text, cur, cur and listening, s < keys.size())
	_button(l.reset, "RESET DEFAULTS", key_row == Settings.BINDABLE.size())
	_button(l.back, "BACK", key_row == Settings.BINDABLE.size() + 1)
	if error != "":
		PixelFont.draw_centred(self, error, p.get_center().x, p.end.y - 23, Hud.RED)
	var hint := "PRESS A KEY · ESC CANCEL · BKSP CLEAR" if listening else "↑↓ ROW · ←→ SLOT · ENTER REBIND"
	_hint(p, hint)


## A key slot drawn as a keycap: a darker bottom edge under the face, orange when selected, lit while it
## listens for a key.
func _keycap(r: Rect2, text: String, selected: bool, live: bool, bound: bool) -> void:
	var face := Color(Hud.ORANGE, 0.22) if live else SLOT_FILL
	draw_rect(Rect2(r.position + Vector2(1, r.size.y), Vector2(r.size.x - 2, 1)), Color(0, 0, 0, 0.5))
	Hud.panel(self, r, Hud.ORANGE if selected else SLOT_BORDER, face)
	draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), Color(0, 0, 0, 0.35))
	var col := Hud.ORANGE_LIGHT if live else Hud.TEXT if bound else Hud.ZERO_DIM
	PixelFont.draw_centred(self, text, r.get_center().x, r.position.y + 2, col)


func _button(r: Rect2, text: String, selected: bool) -> void:
	Hud.panel(self, r, Hud.ORANGE if selected else SLOT_BORDER, SLOT_FILL)
	PixelFont.draw_centred(self, text, r.get_center().x, r.position.y + 2, Hud.TEXT if selected else Hud.TEXT_DIM)


func _hint(p: Rect2, text: String) -> void:
	PixelFont.draw_centred(self, text, p.get_center().x, p.end.y - 11, Color("#5C5C5C"))
