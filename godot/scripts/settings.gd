extends Node

## Autoload "Settings": the player's key bindings, the CRT filter, mute and the crosshair's colour, saved in
## user://settings.cfg (like `save.keys` and `renderer.crt` in src/app.ts; the crosshair colour is the port's). Bindings follow src/core/input.ts: every action the player
## can rebind has up to SLOTS keys (physical keycodes, so the layout of the keyboard does not matter), applied
## to the InputMap actions of the same name; a few keys always do the same thing (FIXED) and cannot be
## rebound. W may serve both jump and up, as in the default layout; any other key belongs to one action.

## Where they are saved (tools/check.gd points this elsewhere so it never touches the player's file).
var path := "user://settings.cfg"
const SLOTS := 3
## Actions the player can rebind, in the order the keybinding menu lists them.
const BINDABLE: Array[StringName] = [&"left", &"right", &"up", &"down", &"jump", &"attack", &"spin", &"tool", &"agent", &"pickup", &"inventory", &"prev", &"next", &"pause", &"shop", &"tree", &"mute", &"controls"]
const LABELS := {
	&"left": "MOVE LEFT",
	&"right": "MOVE RIGHT",
	&"up": "UP",
	&"down": "DOWN / POUND",
	&"jump": "JUMP",
	&"attack": "ATTACK (SPIN / SHOOT)",
	&"spin": "SPIN",
	&"tool": "TOOL CALL (HOOK)",
	&"agent": "SEND SUB-AGENT",
	&"pickup": "PICK UP ITEM",
	&"inventory": "INVENTORY",
	&"prev": "PREV WEAPON",
	&"next": "NEXT WEAPON",
	&"pause": "PAUSE",
	&"shop": "SHOP (MAP)",
	&"tree": "PROMPT TREE (MAP)",
	&"mute": "MUTE",
	&"controls": "CONTROLS HELP",
}
const DEFAULTS := {
	&"left": [KEY_LEFT, KEY_A],
	&"right": [KEY_RIGHT, KEY_D],
	&"up": [KEY_UP, KEY_W],
	&"down": [KEY_DOWN, KEY_S],
	&"jump": [KEY_SPACE, KEY_W, KEY_K],
	&"attack": [KEY_X, KEY_J],
	&"spin": [KEY_C, KEY_L],
	&"tool": [KEY_SHIFT, KEY_F],
	&"agent": [KEY_G],
	&"pickup": [KEY_E],
	&"inventory": [KEY_I],
	&"prev": [KEY_Q],
	&"next": [KEY_R],
	&"pause": [KEY_P],
	&"shop": [KEY_B],
	&"tree": [KEY_T],
	&"mute": [KEY_M],
	&"controls": [KEY_H],
}
## Keys that cannot be rebound (FIXED_KEYS in TS): Escape pauses and goes back, Enter and Space confirm,
## Backspace goes back, 1-5 pick a weapon slot.
const FIXED := {
	&"pause": [KEY_ESCAPE],
	&"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE],
	&"back": [KEY_ESCAPE, KEY_BACKSPACE],
	&"slot1": [KEY_1],
	&"slot2": [KEY_2],
	&"slot3": [KEY_3],
	&"slot4": [KEY_4],
	&"slot5": [KEY_5],
}
## The mouse (attachMouse() in src/core/input.ts): the left button attacks (shoots when armed), the right one
## throws the Tool Call (it spun in TS; spin keeps C / L, and unarmed the attack button spins anyway), the wheel
## switches weapons (down = next).
const MOUSE := {
	&"attack": [MOUSE_BUTTON_LEFT],
	&"tool": [MOUSE_BUTTON_RIGHT],
	&"agent": [MOUSE_BUTTON_MIDDLE],
	&"next": [MOUSE_BUTTON_WHEEL_DOWN],
	&"prev": [MOUSE_BUTTON_WHEEL_UP],
}
## Short names for keys whose own name is too long for a key slot.
const SHORT := {
	KEY_SPACE: "SPACE", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓", KEY_SHIFT: "SHIFT",
	KEY_CTRL: "CTRL", KEY_ALT: "ALT", KEY_TAB: "TAB", KEY_ENTER: "ENTER", KEY_KP_ENTER: "ENTER",
	KEY_BACKSPACE: "BKSP", KEY_CAPSLOCK: "CAPS", KEY_ESCAPE: "ESC", KEY_INSERT: "INS", KEY_DELETE: "DEL",
	KEY_HOME: "HOME", KEY_END: "END", KEY_PAGEUP: "PGUP", KEY_PAGEDOWN: "PGDN", KEY_META: "META",
}

## The crosshair's colours, [name, colour], picked in the pause menu (a port addition: TS's orange dots got lost
## against the orange and red levels). White, with the crosshair's dark outline, reads on every level.
const CROSSHAIRS := [["WHITE", Color("#FFFFFF")], ["CYAN", Color("#5FF2FF")], ["LIME", Color("#B4FF4D")],
	["MAGENTA", Color("#FF5CDB")], ["YELLOW", Color("#FFE45C")], ["ORANGE", Color("#D97757")]]

## Action -> Array of physical keycodes.
var bindings := {}
var crt := true
var muted := false
## Index into CROSSHAIRS.
var crosshair := 0


func _ready() -> void:
	bindings = defaults()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		for a in BINDABLE:
			var keys: Array = cfg.get_value("keys", a, [])
			if not keys.is_empty() and keys.all(func(k): return k is int):
				bindings[a] = keys.slice(0, SLOTS)
		# An action added after the file was saved takes its default keys from the actions that had them (E went
		# from NEXT WEAPON to PICK UP ITEM); an action left without keys gets its own defaults back.
		for a in BINDABLE:
			if cfg.has_section("keys") and not cfg.has_section_key("keys", a):
				for b in BINDABLE:
					if b != a:
						bindings[b] = bindings[b].filter(func(k): return k == KEY_W or k not in DEFAULTS[a])
		for a in BINDABLE:
			if bindings[a].is_empty():
				bindings[a] = DEFAULTS[a].filter(func(k): return conflict(a, k) == &"")
		crt = cfg.get_value("video", "crt", true)
		muted = cfg.get_value("audio", "muted", false)
		var name: String = str(cfg.get_value("video", "crosshair", "WHITE"))
		crosshair = maxi(0, CROSSHAIRS.map(func(c: Array) -> String: return c[0]).find(name))
	apply()


static func defaults() -> Dictionary:
	var out := {}
	for a in BINDABLE:
		out[a] = DEFAULTS[a].duplicate()
	return out


## Puts the bindings and the fixed keys into the InputMap.
func apply() -> void:
	for a in BINDABLE + FIXED.keys().filter(func(a): return a not in BINDABLE):
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.2)
		InputMap.action_erase_events(a)
		for code in bindings.get(a, []) + FIXED.get(a, []):
			var e := InputEventKey.new()
			e.physical_keycode = code
			InputMap.action_add_event(a, e)
		for button in MOUSE.get(a, []):
			var m := InputEventMouseButton.new()
			m.button_index = button
			InputMap.action_add_event(a, m)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for a in BINDABLE:
		cfg.set_value("keys", a, bindings[a])
	cfg.set_value("video", "crt", crt)
	cfg.set_value("video", "crosshair", CROSSHAIRS[crosshair][0])
	cfg.set_value("audio", "muted", muted)
	cfg.save(path)


func reset_defaults() -> void:
	bindings = defaults()
	apply()
	save()


## Another action that already uses `code`, or &"" (conflictFor() in src/scenes/keybinds.ts).
func conflict(action: StringName, code: int) -> StringName:
	for b in BINDABLE:
		var w_shared := code == KEY_W and ((action == &"jump" and b == &"up") or (action == &"up" and b == &"jump"))
		if b != action and code in bindings[b] and not w_shared:
			return b
	return &""


## Binds `code` to slot `slot` of `action` (rebinding a key the action already has moves it). Returns the
## action it conflicts with, or &"" when it was bound.
func bind(action: StringName, slot: int, code: int) -> StringName:
	var other := conflict(action, code)
	if other != &"":
		return other
	var keys: Array = bindings[action]
	var i := keys.find(code)
	if i >= 0 and i != slot:
		keys.remove_at(i)
	if slot < keys.size():
		keys[slot] = code
	else:
		keys.append(code)
	apply()
	save()
	return &""


## Clears slot `slot`, keeping at least one key so the action (and the menus) stay reachable.
func clear(action: StringName, slot: int) -> void:
	var keys: Array = bindings[action]
	if slot < keys.size() and keys.size() > 1:
		keys.remove_at(slot)
		apply()
		save()


func set_muted(on: bool) -> void:
	muted = on
	save()


func set_crt(on: bool) -> void:
	crt = on
	save()


## The next (`step` 1) or previous (-1) crosshair colour, saved.
func cycle_crosshair(step := 1) -> void:
	crosshair = posmod(crosshair + step, CROSSHAIRS.size())
	save()


func crosshair_color() -> Color:
	return CROSSHAIRS[crosshair][1]


## keyLabel() in src/core/input.ts: arrows as arrows, letters and symbols as themselves, short names for the rest.
static func key_label(code: int) -> String:
	if SHORT.has(code):
		return SHORT[code]
	if code >= 33 and code <= 126:
		return char(code).to_upper()
	var key_name := OS.get_keycode_string(code).to_upper()
	return key_name.substr(0, 6)


## All keys of `actions` as labels joined by spaces (k() in controlLines()), without repeats.
func keys_text(actions: Array) -> String:
	var seen := []
	for a in actions:
		for code in bindings[a]:
			var l := key_label(code)
			if l not in seen:
				seen.append(l)
	return " ".join(seen) if not seen.is_empty() else "-"
