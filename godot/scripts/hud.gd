class_name Hud
extends Node2D

## The in-level HUD (drawHud() in src/render/hud.ts), drawn in view pixels like the Overlay: top left one
## dark panel with open corners (the 2D panel()) holding Clawd's hearts and, past a dotted divider, a spinning
## token and the token count; top right the level's id and name. An orange tab on the panel's top edge and a
## 1 px shadow under it tie it to the orange-on-dark look of the checkpoints and platforms.
## It reacts like the 2D HUD and a bit more: a lost heart flashes white and breaks into falling shards while
## the panel shakes and its border turns red; refilled hearts pop up with a white outline; the last heart beats;
## a collected token flies from where it was to the counter (collect_token()), which ticks up when it lands
## (the count shown lags Main.tokens by the flight) and bumps its digits in light orange.
## Runs on real time (_process), so it keeps moving through hitstop.

## Top left of the panel: 6 px into the part of the SubViewport that is on screen (Main.PAD is cut off).
const ORIGIN := Vector2(Main.PAD + 6, Main.PAD + 6)
const H := 16
const BORDER := Color("#343434")
const FILL := Color(0.075, 0.07, 0.085, 0.86)
const RED := Color("#E0605A")
const ORANGE := Color("#D97757")
const ORANGE_LIGHT := Color("#F0A585")
const TEXT := Color("#E6E6E6")
const TEXT_DIM := Color("#9A9A9A")
const ZERO_DIM := Color("#4A4A4E")
const SHADOW := Color(0, 0, 0, 0.55)
## Heart slot pitch and the token flight time.
const HEART_STEP := 11
const FLIGHT := 0.45
const STAGGER := 0.04
## The counter coin turns once every SPIN_EVERY seconds, taking SPIN_TIME.
const SPIN_EVERY := 3.0
const SPIN_TIME := 0.5

## 9 x 8 heart, lit from the top left like the voxel sprites: H highlight, L lit, O body, S shade.
const HEART := [
	".LL...OO.",
	"LHLO.OOOO",
	"LLOOOOOOS",
	"OOOOOOOOS",
	".OOOOOOS.",
	"..OOOSS..",
	"...OSS...",
	"....S....",
]
const HEART_PALETTE := {"H": Color("#FFD0C6"), "L": Color("#F28A80"), "O": RED, "S": Color("#A8403F")}
## The same heart one step brighter, for the beat of the last heart.
const HEART_BRIGHT := {"H": Color.WHITE, "L": Color("#FFD0C6"), "O": Color("#F28A80"), "S": RED}
## An 8 px coin in TokenSprite's palette, and its narrower spin frames.
const COIN := {
	8: ["..cccc..", ".cLLTTc.", "cLWLTTTc", "cLLTTTTc", "cTTTTTSc", "cTTTTSSc", ".cTSSSc.", "..cccc.."],
	6: [".cccc.", "cLLTTc", "cWLTTc", "cLTTTc", "cTTTSc", "cTTSSc", "cTSSSc", ".cccc."],
	4: [".cc.", "cLTc", "cWTc", "cLTc", "cTTc", "cTSc", "cTSc", ".cc."],
	2: ["cc", "LT", "LT", "LT", "TS", "TS", "TS", "cc"],
}
## A 4 px coin for the tokens in flight.
const COIN_SMALL := [".TT.", "TLTT", "TTTS", ".SS."]
## 4 x 7 digits for the counter, taller than PixelFont's.
const DIGITS := [
	[".##.", "#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
	["..#.", ".##.", "..#.", "..#.", "..#.", "..#.", ".###"],
	[".##.", "#..#", "...#", "..#.", ".#..", "#...", "####"],
	[".##.", "#..#", "...#", "..#.", "...#", "#..#", ".##."],
	["#..#", "#..#", "#..#", "####", "...#", "...#", "...#"],
	["####", "#...", "###.", "...#", "...#", "#..#", ".##."],
	[".##.", "#...", "#...", "###.", "#..#", "#..#", ".##."],
	["####", "...#", "..#.", "..#.", ".#..", ".#..", ".#.."],
	[".##.", "#..#", "#..#", ".##.", "#..#", "#..#", ".##."],
	[".##.", "#..#", "#..#", ".###", "...#", "...#", ".##."],
]

static var _heart_tex := _texture(HEART, HEART_PALETTE)
static var _heart_bright_tex := _texture(HEART, HEART_BRIGHT)
static var _heart_white_tex := _texture(HEART, {"H": Color.WHITE, "L": Color.WHITE, "O": Color.WHITE, "S": Color.WHITE})
static var _socket_tex := _socket()
static var _ring_tex := _ring()
static var _coin_tex := _coins()
static var _coin_white_tex := _texture(COIN[8], {"c": Color.WHITE, "L": Color.WHITE, "T": Color.WHITE, "S": Color.WHITE, "W": Color.WHITE})
static var _coin_small_tex := _texture(COIN_SMALL, TokenSprite.PALETTE)
static var _slash_tex := _texture(["...#", "...#", "..#.", ".##.", ".#..", "#...", "#..."], {"#": Color.WHITE})
static var _digit_tex: Array = DIGITS.map(func(rows: Array) -> ImageTexture: return _texture(rows, {"#": Color.WHITE}))

## Mouse position in SubViewport pixels (GameMenu passes it on), for the buttons' hover look.
var mouse := Vector2(-1000, -1000)
## Whether the controls help / pause menu is open, so their buttons show as pressed.
var controls_open := false
var pause_open := false
## Level label at the top right, set by reset().
var label_id := ""
var label_name := ""
## The token count shown (Main.tokens minus the tokens still in flight).
var shown := 0
var _t := 0.0
## Hearts shown, and the slots drawn (3, or more after +1 HEART).
var _hearts := -1
## Heart index -> seconds since it was refilled (negative: still waiting to appear).
var _gained := {}
var _shards := []
var _flights := []
var _hurt := 0.0
var _bump := 0.0
## The run's rescued sub-agents (Main.agents, shared), and seconds since the last rescue.
var agents: Array = []
## The run's found sparks (Main.sparks, shared), and how long the SPARKS counter still flashes (flashSparks).
var sparks: Array = []
var _spark_flash := 0.0
var _rescued := 0
var _agent_t := 10.0
## While > 0 the hearts stay as shown (the last heart breaking before the refill on a respawn).
var _hold := 0.0
## Delay for the next token's flight, growing while tokens come in quickly.
var _stagger := 0.0
## Double Tokens is on (Main sets it): "x2" by the count, and each landing token counts twice.
var double_tokens := false
## The Firewall: drawn as one more slot after the hearts while it is up; when it breaks it flashes and shatters
## (seconds left of that).
var _shield_up := false
var _shield_break := 0.0
static var _shield_tex := Spark._texture(ShopScreen.ICONS["firewall"], {"o": ORANGE, "L": ORANGE_LIGHT, "W": Color("#FFF1E6")})
static var _shield_white := Spark._texture(ShopScreen.ICONS["firewall"], {"o": Color.WHITE, "L": Color.WHITE, "W": Color.WHITE})
var _player: Player


func reset(id: String, level_name: String) -> void:
	label_id = id
	label_name = level_name.to_lower()
	shown = 0
	_hearts = -1
	_gained.clear()
	_shards.clear()
	_flights.clear()
	_hurt = 0.0
	_bump = 0.0
	_rescued = 0
	_agent_t = 10.0
	_spark_flash = 0.0
	_hold = 0.0
	_stagger = 0.0


## Main hands over Clawd once it has made him.
func bind(player: Player) -> void:
	_player = player
	_player.event.connect(_on_player_event)


## A token was collected at `from` (view pixels): it flies to the counter and is counted when it lands.
## Tokens picked up together leave one after another (a bug's ten stream in instead of flying as one clump).
func collect_token(from: Vector2, n := 1) -> void:
	_flights.append({"from": from, "t": -_stagger, "arc": randf_range(18, 34), "n": n})
	_stagger += STAGGER


func _on_player_event(kind: StringName, _at: Vector2) -> void:
	if kind == &"die" and _hearts > 0:
		# The last heart breaks, then all of them come back.
		_lose(_hearts - 1)
		_hearts = 0
		_hold = 0.55


func _lose(i: int) -> void:
	_hurt = 0.3
	_gained.erase(i)
	var at := _heart_pos(i) + Vector2(4.5, 4)
	for k in 9:
		var a := randf() * TAU
		_shards.append({"p": at + Vector2(cos(a), sin(a)) * 2, "v": Vector2(cos(a) * randf_range(25, 60), -randf_range(30, 80)),
			"c": [RED, HEART_PALETTE.L, HEART_PALETTE.S, Color.WHITE][k % 4], "t": 0.0})


func _process(dt: float) -> void:
	_t += dt
	_hurt = maxf(0.0, _hurt - dt)
	_bump = maxf(0.0, _bump - dt)
	_hold = maxf(0.0, _hold - dt)
	_stagger = maxf(0.0, _stagger - dt)
	_agent_t += dt
	_spark_flash = maxf(0.0, _spark_flash - dt)
	_shield_break = maxf(0.0, _shield_break - dt)
	if _player:
		if _shield_up and not _player.shield:
			_shield_break = 0.5
			var at := _heart_pos(_slots()) + Vector2(4.5, 4)
			for k in 10:
				var a := randf() * TAU
				_shards.append({"p": at, "v": Vector2(cos(a), sin(a)) * randf_range(30, 70) + Vector2(0, -40),
					"c": [ORANGE, ORANGE_LIGHT, Color.WHITE][k % 3], "t": 0.0})
		_shield_up = _player.shield
	var rescued := agents.count(true)
	if rescued != _rescued:
		_rescued = rescued
		_agent_t = 0.0
	if _player:
		var h := _player.hearts
		if _hearts < 0:
			_hearts = h
		elif _hold <= 0:
			for i in range(h, _hearts):
				_lose(i)
			for i in range(_hearts, h):
				# Refilled hearts pop in one after another.
				_gained[i] = -(i - _hearts) * 0.08
			_hearts = h
	for i in _gained.keys():
		_gained[i] += dt
		if _gained[i] > 0.4:
			_gained.erase(i)
	for s in _shards:
		s.t += dt
		s.v.y += 260 * dt
		s.p += s.v * dt
	_shards = _shards.filter(func(s: Dictionary) -> bool: return s.t < 0.6)
	var landed := 0
	for f in _flights:
		f.t += dt
		if f.t >= FLIGHT:
			landed += int(f.get("n", 1))
	if landed:
		_flights = _flights.filter(func(f: Dictionary) -> bool: return f.t < FLIGHT)
		shown += landed
		_bump = 0.25
	# Fade out under the level-complete panel.
	var main := get_tree().get_first_node_in_group("main")
	var hide: bool = main != null and main.complete_t >= 1.6
	modulate.a = move_toward(modulate.a, 0.0 if hide else 1.0, dt * 4)
	queue_redraw()


func _slots() -> int:
	return maxi(_player.max_hearts if _player else Player.MAX_HEARTS, _hearts)


## Whether the Firewall slot is drawn (up, or still shattering).
func _shield_slot() -> bool:
	return _shield_up or _shield_break > 0


func _heart_pos(i: int) -> Vector2:
	return ORIGIN + _shake() + Vector2(5 + i * HEART_STEP, 4)


func _shake() -> Vector2:
	return Vector2((1 if int(_t * 30) % 2 == 0 else -1) if _hurt > 0.1 else 0, 0)


func _hearts_w() -> int:
	return 5 + (_slots() + (1 if _shield_slot() else 0)) * HEART_STEP - 2 + 5


func _count_text() -> String:
	return "%03d" % shown


## The counter coin's centre in view pixels (where the tokens fly to).
func coin_centre() -> Vector2:
	return ORIGIN + Vector2(_hearts_w() + _sparks_w() + 1 + 4 + 4, 8)


## A spark was found: the SPARKS counter flashes for 1.4 s.
func flash_sparks() -> void:
	_spark_flash = 1.4


func _sparks_text() -> String:
	return "%d/%d" % [sparks.count(true), sparks.size()]


## Width of the sparks section (none in a level without sparks): divider, icon, "x/y".
func _sparks_w() -> int:
	return 1 + 4 + 9 + 4 + _sparks_text().length() * 5 - 1 + 6 if not sparks.is_empty() else 0


func _draw() -> void:
	var o := ORIGIN + _shake()
	var hw := _hearts_w()
	var digits := _count_text()
	var tw := 1 + 4 + 8 + 4 + digits.length() * 5 - 1 + 6 + (4 + PixelFont.width("x2") if double_tokens else 0)
	# Sub-agents (when the level has any): a small Clawd, grey until one is rescued, and "x/y".
	var agents_text := "%d/%d" % [_rescued, agents.size()]
	var aw := 4 + 13 + 4 + agents_text.length() * 5 - 1 + 6 if not agents.is_empty() else 0
	var sw := _sparks_w()
	var w := hw + sw + tw + aw
	var hurt_k := clampf(_hurt / 0.3, 0.0, 1.0)
	panel(self, Rect2(o, Vector2(w, H)), BORDER.lerp(RED, hurt_k), FILL, true)

	# Hearts.
	var beat := _hearts == 1 and _slots() > 1 and fmod(_t, 0.9) < 0.14
	for i in _slots():
		var p := _heart_pos(i)
		var g: float = _gained.get(i, 1.0)
		if i >= _hearts or g < 0:
			draw_texture(_socket_tex, p)
			continue
		if g < 0.1:
			p.y -= 1
		if g < 0.06:
			draw_texture(_heart_white_tex, p)
		else:
			draw_texture(_heart_bright_tex if beat else _heart_tex, p)
		if g < 0.3:
			draw_texture(_ring_tex, p - Vector2.ONE, Color(1, 1, 1, 1.0 - g / 0.3))
		elif beat:
			draw_texture(_ring_tex, p - Vector2.ONE, Color(RED, 0.45))
	for s in _shards:
		var c: Color = s.c
		c.a = 1.0 - s.t / 0.6
		draw_rect(Rect2(s.p.round(), Vector2.ONE), c)

	# Sparks: a small spark (grey until one is found) and "x/y" in light orange while it flashes, like the 2D
	# SPARKS panel's orange border.
	if sw > 0:
		for y in range(3, H - 3, 2):
			draw_rect(Rect2(o.x + hw, o.y + y, 1, 1), BORDER.lightened(0.15))
		var found := sparks.count(true)
		var flash := _spark_flash > 0 and fmod(_spark_flash, 0.2) < 0.12
		var sx := o.x + hw + 1 + 4
		draw_texture(Spark.icon(found == 0), Vector2(sx, o.y + 3 - (1 if flash else 0)))
		var stext := _sparks_text()
		var scol := ORANGE_LIGHT if _spark_flash > 0 else TEXT if found > 0 else ZERO_DIM
		for k in stext.length():
			var ch := stext[k]
			var glyph: ImageTexture = _slash_tex if ch == "/" else _digit_tex[int(ch)]
			draw_texture(glyph, Vector2(sx + 9 + 4 + k * 5, o.y + 5), SHADOW)
			draw_texture(glyph, Vector2(sx + 9 + 4 + k * 5, o.y + 4), scol)

	# Dotted divider.
	for y in range(3, H - 3, 2):
		draw_rect(Rect2(o.x + hw + sw, o.y + y, 1, 1), BORDER.lightened(0.15))

	# The coin faces the front and turns once now and then; it glints white while the counter bumps.
	var cx := o.x + hw + sw + 1 + 4
	var spin := absf(cos(minf(fmod(_t, SPIN_EVERY) / SPIN_TIME, 1.0) * PI))
	var cw := 8 if spin > 0.75 or _bump > 0 else 6 if spin > 0.45 else 4 if spin > 0.18 else 2
	var tex: ImageTexture = _coin_tex[cw]
	draw_texture(tex, Vector2(cx + (8 - cw) / 2, o.y + 4))
	if _bump > 0.15:
		draw_texture(_coin_white_tex, Vector2(cx, o.y + 4), Color(1, 1, 1, (_bump - 0.15) / 0.1))

	# The count: leading zeros dim, digits with a 1 px shadow, bumped in light orange.
	var dx := cx + 8 + 4
	var lead := true
	var bump_k := clampf(_bump / 0.25, 0.0, 1.0)
	for k in digits.length():
		var d := int(digits[k])
		lead = lead and d == 0 and k < digits.length() - 1
		var col := ZERO_DIM if lead else TEXT.lerp(ORANGE_LIGHT, bump_k)
		var y := o.y + 4 - (1 if _bump > 0.2 and not lead else 0)
		draw_texture(_digit_tex[d], Vector2(dx + k * 5, y + 1), SHADOW)
		draw_texture(_digit_tex[d], Vector2(dx + k * 5, y), col)

	if double_tokens:
		_text_shadowed("x2", Vector2(dx + digits.length() * 5 + 3, o.y + 5), ORANGE_LIGHT)

	# Firewall slot.
	if _shield_slot():
		var sp := _heart_pos(_slots())
		if _shield_up:
			draw_texture(_shield_tex, sp + Vector2(0, -1 if fmod(_t, 2.0) < 0.12 else 0))
		elif _shield_break > 0.4:
			draw_texture(_shield_white, sp)

	if not agents.is_empty():
		var ax := o.x + hw + sw + tw
		for y in range(3, H - 3, 2):
			draw_rect(Rect2(ax, o.y + y, 1, 1), BORDER.lightened(0.15))
		var cheer := _agent_t < 0.8 and fmod(_agent_t, 0.2) < 0.1
		var icon := ClawdSprite.texture(ClawdSprite.frame("high" if cheer else "mid"), Color(0, 0, 0, 0) if _rescued > 0 else Color("#6A6A6A"))
		draw_texture(icon, Vector2(ax + 4, o.y + 3 - (1 if cheer else 0)))
		var col := TEXT.lerp(ORANGE_LIGHT, clampf(1.0 - _agent_t / 0.8, 0.0, 1.0)) if _rescued > 0 else ZERO_DIM
		for k in agents_text.length():
			var ch := agents_text[k]
			var glyph: ImageTexture = _slash_tex if ch == "/" else _digit_tex[int(ch)]
			draw_texture(glyph, Vector2(ax + 4 + 13 + 4 + k * 5, o.y + 5), SHADOW)
			draw_texture(glyph, Vector2(ax + 4 + 13 + 4 + k * 5, o.y + 4), col)

	_draw_radar()

	# Tokens in flight: an arc from where they were picked up, speeding up into the counter.
	var to := coin_centre()
	for f in _flights:
		var e := pow(maxf(f.t, 0.0) / FLIGHT, 1.6)
		var from: Vector2 = f.from
		var ctrl := from.lerp(to, 0.35) + Vector2(0, -f.arc)
		var p := from.lerp(ctrl, e).lerp(ctrl.lerp(to, e), e)
		draw_texture(_coin_small_tex, (p - Vector2(2, 2)).round())

	_draw_boss_bar()

	# Top right: CONTROLS, pause and mute buttons, then the level label (like the 2D HUD).
	var b := buttons()
	if b.has("label"):
		panel(self, b.label, BORDER)
		PixelFont.draw(self, label_id, b.label.position + Vector2(6, 5), ORANGE_LIGHT)
		PixelFont.draw(self, " · " + label_name, b.label.position + Vector2(6 + PixelFont.width(label_id) + 1, 5), TEXT_DIM)
	var on: bool = b.mute.has_point(mouse)
	panel(self, b.mute, _button_border(on, false))
	_speaker(b.mute.position + Vector2(5, 8), Settings.muted, ORANGE_LIGHT if on else TEXT)
	on = b.pause.has_point(mouse)
	panel(self, b.pause, _button_border(on, pause_open))
	var bars := ORANGE_LIGHT if on or pause_open else TEXT
	for x in [6, 10]:
		draw_rect(Rect2(b.pause.position + Vector2(x, 5), Vector2(2, 6)), bars)
	on = b.controls.has_point(mouse)
	panel(self, b.controls, _button_border(on, controls_open))
	PixelFont.draw(self, "CONTROLS", b.controls.position + Vector2(6, 5), ORANGE_LIGHT if on or controls_open else TEXT)


## drawBossBar() in src/render/hud.ts: the boss's name over a 150 px bar near the bottom of the view; up to 5 hp
## one segment of 2 px dashes per hit point (red with orange glints, dark once lost), else 50 cells.
func _draw_boss_bar() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.boss == null or not is_instance_valid(main.boss) or not main.boss.fighting():
		return
	var b = main.boss
	var view := get_viewport_rect().size - Vector2.ONE * Main.PAD * 2
	var w := 150.0
	var x := floorf(Main.PAD + view.x / 2 - w / 2)
	var y := Main.PAD + view.y - 22
	_text_shadowed(b.TITLE, Vector2(floorf(Main.PAD + view.x / 2 - PixelFont.width(b.TITLE) / 2.0), y - 10), TEXT)
	var max_hp: int = b.max_hp
	if max_hp <= 5:
		var seg := w / max_hp
		for i in max_hp:
			var on: bool = i < b.hp
			var d := 0.0
			while d < seg - 4:
				var c := (ORANGE_LIGHT if sin(_t * 10 + d) > 0.8 else RED) if on else Color("#333333")
				draw_rect(Rect2(x + floorf(i * seg + d), y, 2, 4), c)
				d += 3
	else:
		for i in 50:
			var on: bool = float(i) / 50 < float(b.hp) / max_hp
			draw_rect(Rect2(x + i * 3, y, 2, 4), (ORANGE_LIGHT if sin(_t * 10 + i) > 0.85 else RED) if on else Color("#333333"))


## drawSpeaker() in src/render/shapes.ts: a speaker with two sound waves, or a cross when muted. `at` is the
## left end of its middle row.
func _speaker(at: Vector2, muted: bool, color: Color) -> void:
	draw_rect(Rect2(at + Vector2(0, -1), Vector2(2, 3)), color)
	draw_rect(Rect2(at + Vector2(2, -2), Vector2(1, 5)), color)
	draw_rect(Rect2(at + Vector2(3, -3), Vector2(1, 7)), color)
	if muted:
		for i in 4:
			draw_rect(Rect2(at + Vector2(5 + i, -2 + i), Vector2.ONE), RED)
			draw_rect(Rect2(at + Vector2(8 - i, -2 + i), Vector2.ONE), RED)
	else:
		draw_rect(Rect2(at + Vector2(5, -1), Vector2(1, 3)), color)
		draw_rect(Rect2(at + Vector2(7, -3), Vector2(1, 7)), color)


func _text_shadowed(s: String, at: Vector2, color: Color) -> void:
	PixelFont.draw(self, s, at + Vector2(0, 1), SHADOW)
	PixelFont.draw(self, s, at, color)


## The Spark Radar: a small chevron 26 px from Clawd's middle, pointing to the nearest never-found spark, beating
## faster the closer it is; gone once the spark is about on Clawd.
func _draw_radar() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not _player or main.complete_t >= 0:
		return
	var target: Spark = main.radar_target()
	if target == null:
		return
	var d: Vector2 = target.feet() + Vector2(0, -Spark.CENTRE_Y) - (_player.pos + Vector2(0, -9))
	var dist := d.length()
	if dist < 40:
		return
	var dir := d / dist
	var beat := clampf(dist / 400.0, 0.25, 1.2)
	var on := fmod(_t, beat) < beat * 0.55
	var col := Color(ORANGE_LIGHT if on else ORANGE, 1.0 if on else 0.7)
	var c: Vector2 = main.overlay.to_view(_player.pos + Vector2(0, -9))
	var perp := Vector2(-dir.y, dir.x)
	# A chevron 2 px thick: a shadow, the arms, and a white-hot tip while it beats.
	var pts := []
	for k in 5:
		pts.append(dir * (28 - k) + perp * k)
		pts.append(dir * (28 - k) - perp * k)
		pts.append(dir * (27 - k) + perp * k)
		pts.append(dir * (27 - k) - perp * k)
	for p in pts:
		draw_rect(Rect2((c + p).round() + Vector2(0, 1), Vector2.ONE), SHADOW)
	for p in pts:
		draw_rect(Rect2((c + p).round(), Vector2.ONE), col)
	if on:
		draw_rect(Rect2((c + dir * 28).round(), Vector2.ONE), Color.WHITE)


func _button_border(hovered: bool, active: bool) -> Color:
	return ORANGE if active else BORDER.lerp(ORANGE_LIGHT, 0.45) if hovered else BORDER


## The rects of the top-right items in SubViewport pixels: `label` (when there is one), `mute`, `pause`,
## `controls`.
func buttons() -> Dictionary:
	var right := get_viewport_rect().size.x - ORIGIN.x
	var out := {}
	if label_id != "":
		var tw := PixelFont.width(label_id) + 1 + PixelFont.width(" · " + label_name)
		out.label = Rect2(right - tw - 12, ORIGIN.y, tw + 12, H)
		right -= tw + 12 + 4
	out.mute = Rect2(right - 18, ORIGIN.y, 18, H)
	right -= 18 + 4
	out.pause = Rect2(right - 18, ORIGIN.y, 18, H)
	right -= 18 + 4
	var cw := PixelFont.width("CONTROLS") + 12
	out.controls = Rect2(right - cw, ORIGIN.y, cw, H)
	return out


## panel() from src/render/shapes.ts (fill, 1 px border with open corners) with a 1 px shadow under it and a
## faint highlight along the inside of the top edge; `tab` adds the short orange tab on top. Drawn onto `c`
## (inside its _draw()), so the menus share the look.
static func panel(c: CanvasItem, r: Rect2, border: Color, fill := FILL, tab := false) -> void:
	r = Rect2(r.position.round(), r.size.round())
	c.draw_rect(Rect2(r.position.x + 1, r.end.y, r.size.x - 2, 1), Color(0, 0, 0, 0.35))
	c.draw_rect(r, fill)
	c.draw_rect(Rect2(r.position.x + 2, r.position.y + 1, r.size.x - 4, 1), Color(1, 1, 1, 0.05))
	c.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), border)
	c.draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), border)
	c.draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), border)
	c.draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), border)
	if tab:
		c.draw_rect(Rect2(r.position.x + 3, r.position.y, 7, 1), ORANGE)
		c.draw_rect(Rect2(r.position.x + 3, r.position.y + 1, 7, 1), Color(ORANGE, 0.25))


## A text-grid sprite as a texture ('.' transparent).
static func _texture(rows: Array, palette: Dictionary) -> ImageTexture:
	var img := Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in rows[y].length():
			if palette.has(rows[y][x]):
				img.set_pixel(x, y, palette[rows[y][x]])
	return ImageTexture.create_from_image(img)


static func _coins() -> Dictionary:
	var out := {}
	for w in COIN:
		out[w] = _texture(COIN[w], TokenSprite.PALETTE)
	return out


static func _in_heart(x: int, y: int) -> bool:
	return y >= 0 and y < HEART.size() and x >= 0 and x < HEART[0].length() and HEART[y][x] != "."


## An empty heart: a dark outline round a darker inside.
static func _socket() -> ImageTexture:
	var rows := []
	for y in HEART.size():
		var r := ""
		for x in HEART[0].length():
			if not _in_heart(x, y):
				r += "."
			elif _in_heart(x - 1, y) and _in_heart(x + 1, y) and _in_heart(x, y - 1) and _in_heart(x, y + 1):
				r += "i"
			else:
				r += "e"
		rows.append(r)
	return _texture(rows, {"e": Color("#4A4650"), "i": Color("#1C1A22")})


## The 1 px ring just outside the heart (11 x 10, drawn 1 px up and left of it), white to be tinted.
static func _ring() -> ImageTexture:
	var rows := []
	for y in range(-1, HEART.size() + 1):
		var r := ""
		for x in range(-1, HEART[0].length() + 1):
			var near := _in_heart(x - 1, y) or _in_heart(x + 1, y) or _in_heart(x, y - 1) or _in_heart(x, y + 1)
			r += "#" if near and not _in_heart(x, y) else "."
		rows.append(r)
	return _texture(rows, {"#": Color.WHITE})
