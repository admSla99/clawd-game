extends Node

## Autoload "Sound": the sound effects and music of src/core/audio.ts. The TS game ships no audio files and
## synthesizes everything with WebAudio; this does the same maths offline into AudioStreamWAVs, so it sounds the
## same without files either:
## - tone(): an oscillator (sine, triangle, and square / sawtooth band-limited with PolyBLEP like WebAudio's
##   wavetables) whose frequency ramps exponentially, with the TS gain envelope (0.0001 -> vol in 8 ms -> 0.0001).
## - noise(): white noise through WebAudio's bandpass biquad (RBJ, constant 0 dB peak) whose centre ramps
##   exponentially, with an exponential fade.
## - Music: the step sequencer of scheduleStep() (bass, arpeggio, lead every other 4 bars, drums) rendered as one
##   loop of the whole pattern (128 sixteenths with a lead, 64 without); notes that ring past the end wrap round
##   to the start, so it loops seamlessly.
## - Hover: the jet's looping bandpassed noise with the wobble of hoverUpdate() baked in (6 periods of 40 rad/s).
## The TS buses are baked into the samples (sfx 0.55, music 0.22); the master volume 0.8 is the Master bus, and
## Settings.muted mutes it. Effects render in a thread at start-up and each track the first time it plays, so
## nothing blocks the game.

const RATE := 44100
const MASTER := 0.8
const SFX_BUS := 0.55
const MUSIC_BUS := 0.22
const VOICES := 12

## TRACKS in src/core/audio.ts.
const TRACKS := {
	"shop": {bpm = 96, roots = [53, 50, 55, 48], minor = [false, true, false, false], arp = [0, 2, 1, 3, 2, 1, 0, 2], drums = false},
	"mesa": {bpm = 136, roots = [52, 52, 48, 50], minor = [true, true, false, false], arp = [0, 2, 1, 2, 3, 2, 1, 2],
		lead = [7, -1, 7, 10, -1, 12, -1, 10, 7, -1, 5, -1, 3, -1, 5, -1], drums = true},
	"forge": {bpm = 144, roots = [45, 45, 43, 41], minor = [true, true, false, false], arp = [0, 0, 2, 0, 1, 0, 2, 3],
		lead = [12, -1, 12, -1, 10, -1, 7, -1, 8, -1, 7, -1, 5, -1, 3, -1], drums = true},
	"swamp": {bpm = 112, roots = [50, 53, 48, 46], minor = [true, false, false, false], arp = [0, 1, 2, 1, 0, 2, 1, 3],
		lead = [3, -1, -1, 5, -1, -1, 7, -1, 10, -1, -1, 7, -1, 5, -1, -1], drums = true},
	"towers": {bpm = 148, roots = [57, 55, 53, 52], minor = [true, false, false, true], arp = [0, 1, 2, 3, 2, 1, 0, 1],
		lead = [12, -1, 15, -1, 14, -1, 12, 10, -1, 12, -1, 7, -1, -1, 10, -1], drums = true},
	"codex": {bpm = 160, roots = [47, 47, 48, 46], minor = [true, true, false, false], arp = [0, 0, 3, 0, 2, 0, 3, 1],
		lead = [12, 14, 15, -1, 14, 12, -1, 10, 12, -1, 7, -1, 8, 7, -1, -1], drums = true},
	"title": {bpm = 92, roots = [57, 53, 48, 55], minor = [true, false, false, false], arp = [0, 1, 2, 1, 3, 2, 1, 2], drums = false},
	"map": {bpm = 100, roots = [52, 48, 55, 50], minor = [true, false, false, false], arp = [0, 2, 1, 2, 0, 2, 3, 2], drums = false},
	"plains": {bpm = 128, roots = [57, 53, 48, 55], minor = [true, false, false, false], arp = [0, 1, 2, 3, 2, 1, 2, 1],
		lead = [12, -1, 10, -1, 7, -1, 5, 7, -1, -1, 3, -1, 5, -1, -1, -1], drums = true},
	"caves": {bpm = 104, roots = [50, 46, 45, 41], minor = [true, false, true, false], arp = [0, 2, 1, 2, 3, 2, 1, 0], drums = true},
	"window": {bpm = 140, roots = [55, 51, 53, 50], minor = [true, false, false, true], arp = [0, 1, 2, 3, 0, 1, 2, 3],
		lead = [7, -1, 5, -1, 3, -1, 2, -1, 3, 5, -1, 7, -1, 10, -1, -1], drums = true},
	"boss": {bpm = 150, roots = [45, 45, 46, 44], minor = [true, true, false, false], arp = [0, 0, 2, 0, 3, 0, 2, 1],
		lead = [12, 11, 12, -1, 15, -1, 12, -1, 10, -1, 8, -1, 7, -1, -1, -1], drums = true},
	# World 3 (not in TS): the same sequencer, new patterns.
	"canopy": {bpm = 132, roots = [53, 50, 46, 48], minor = [false, true, false, false], arp = [0, 2, 1, 2, 3, 1, 2, 1],
		lead = [12, -1, 14, 12, -1, 9, -1, 7, 9, -1, 12, -1, 10, -1, 9, -1], drums = true},
	"cliffs": {bpm = 124, roots = [55, 52, 48, 50], minor = [false, true, false, false], arp = [0, 1, 2, 3, 2, 3, 1, 2],
		lead = [7, -1, -1, 9, -1, 11, -1, 12, -1, -1, 11, -1, 9, -1, 7, -1], drums = true},
	"sandbox": {bpm = 140, roots = [48, 48, 53, 55], minor = [false, false, false, false], arp = [0, 2, 1, 3, 0, 2, 1, 3],
		lead = [12, -1, 12, 11, 12, -1, 7, -1, 9, -1, 7, -1, 4, -1, 7, -1], drums = true},
	"ravine": {bpm = 152, roots = [49, 49, 52, 47], minor = [true, true, false, true], arp = [0, 0, 2, 0, 1, 0, 3, 2],
		lead = [12, -1, 11, -1, 12, 15, -1, 12, 11, -1, 8, -1, 7, -1, 8, -1], drums = true},
	"router": {bpm = 164, roots = [44, 44, 47, 42], minor = [true, true, false, false], arp = [0, 3, 0, 2, 0, 3, 1, 2],
		lead = [12, 12, 15, -1, 12, -1, 17, 15, -1, 12, -1, 10, 12, -1, -1, -1], drums = true},
}

## The effects the port uses, rendered at start-up (play() renders any other one on first use).
const PRELOAD := ["jump", "land", "spin", "stomp", "pound", "poundLand", "break", "token", "hurt", "die", "checkpoint",
	"select", "confirm", "complete", "heart", "enemyDie", "denied", "spark", "rescue", "buy", "deflect", "shoot", "crush",
	"bossHit", "bossTeleport", "weaponGet", "gunToken", "gunPellet", "gunGlyph", "gunBeam", "gunOrb", "overheat",
	"explode", "hit", "typing", "slam", "laser"]

## Name -> AudioStreamWAV.
var sfx := {}
## Track -> AudioStreamWAV, once rendered.
var tracks := {}
var track := ""
## Every effect played, newest last (tools/check.gd reads it).
var played: Array[String] = []

var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _hover: AudioStreamPlayer
var _hover_on := false
var _thread: Thread
var _jobs: Array[String] = []
var _mutex := Mutex.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioServer.set_bus_volume_db(0, linear_to_db(MASTER))
	set_muted(Settings.muted)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_hover = AudioStreamPlayer.new()
	_hover.volume_linear = 0.0
	add_child(_hover)
	_queue("sfx")


func set_muted(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)


## play() in src/core/audio.ts.
func play(id: String) -> void:
	played.append(id)
	if played.size() > 64:
		played.pop_front()
	_mutex.lock()
	var stream: AudioStreamWAV = sfx.get(id)
	_mutex.unlock()
	if stream == null:
		return
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.play()


## playMusic(): starts `name` from its beginning (or stops the music for ""), rendering it first if needed.
func play_music(id: String) -> void:
	if id == track:
		return
	track = id
	_music.stop()
	if id == "" or not TRACKS.has(id):
		return
	_mutex.lock()
	var stream: AudioStreamWAV = tracks.get(id)
	_mutex.unlock()
	if stream:
		_music.stream = stream
		_music.play()
	else:
		_queue(id)


## The jet: fades in when it starts (hoverStart(), 0.05 s) and out when it stops (hoverStop()).
func hover(on: bool) -> void:
	_mutex.lock()
	var ready := sfx.has("_hover")
	_mutex.unlock()
	if on == _hover_on or not ready:
		return
	_hover_on = on
	var tween := create_tween()
	if on:
		_hover.stream = sfx["_hover"]
		_hover.play(randf() * 0.5)
		tween.tween_property(_hover, "volume_linear", 1.0, 0.05)
	else:
		tween.tween_property(_hover, "volume_linear", 0.0, 0.1)
		tween.tween_callback(_hover.stop)


func _process(_dt: float) -> void:
	# A track that finished rendering starts if it is still wanted.
	if track != "" and not _music.playing:
		_mutex.lock()
		var stream: AudioStreamWAV = tracks.get(track)
		_mutex.unlock()
		if stream:
			_music.stream = stream
			_music.play()


func _queue(job: String) -> void:
	_mutex.lock()
	if job not in _jobs:
		_jobs.append(job)
	_mutex.unlock()
	if _thread == null or not _thread.is_alive():
		if _thread:
			_thread.wait_to_finish()
		_thread = Thread.new()
		_thread.start(_work)


func _work() -> void:
	while true:
		_mutex.lock()
		if _jobs.is_empty():
			_mutex.unlock()
			return
		var job: String = _jobs.pop_front()
		_mutex.unlock()
		if job == "sfx":
			for n in PRELOAD:
				var s := render_sfx(n)
				_mutex.lock()
				sfx[n] = s
				_mutex.unlock()
			var h := render_hover()
			_mutex.lock()
			sfx["_hover"] = h
			_mutex.unlock()
		else:
			var t := render_track(job)
			_mutex.lock()
			tracks[job] = t
			_mutex.unlock()


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()


# --- Synthesis ---------------------------------------------------------------

static func midi(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## PolyBLEP correction around a waveform jump at phase 0, for phase step `dt`.
static func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	if t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


## Adds a tone() to `buf` starting at `delay` s: `type` sine / triangle / square / sawtooth, frequency
## ramping exponentially from `f0` to `f1`, gain 0.0001 -> `vol` in 8 ms -> 0.0001 at `dur`. Samples past the
## end wrap round to the start when `wrap` (music loops).
static func tone(buf: PackedFloat32Array, type: String, f0: float, f1: float, dur: float, vol: float, delay := 0.0, wrap := false) -> void:
	var n := int(dur * RATE)
	var start := int(delay * RATE)
	var size := buf.size()
	var f := f0
	var fk := pow(maxf(20.0, f1) / f0, 1.0 / maxf(1.0, dur * RATE))
	var attack := int(0.008 * RATE)
	var g := 0.0001
	var gk_up := pow(vol / 0.0001, 1.0 / attack)
	var gk_down := pow(0.0001 / vol, 1.0 / maxf(1.0, n - attack))
	var phase := 0.0
	var tri := type == "triangle"
	var sq := type == "square"
	var saw := type == "sawtooth"
	for i in n:
		var dt := f / RATE
		var y: float
		if sq:
			y = (1.0 if phase < 0.5 else -1.0) + _blep(phase, dt) - _blep(fmod(phase + 0.5, 1.0), dt)
		elif saw:
			y = 2.0 * phase - 1.0 - _blep(phase, dt)
		elif tri:
			y = 4.0 * phase - 1.0 if phase < 0.5 else 3.0 - 4.0 * phase
		else:
			y = sin(phase * TAU)
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += y * g
		g *= gk_up if i < attack else gk_down
		phase += dt
		if phase >= 1.0:
			phase -= 1.0
		f *= fk


## Adds a noise() to `buf`: white noise through a bandpass of quality `q` whose centre ramps from `f0` to `f1`,
## starting at gain `vol` and fading exponentially to 0.0001 at `dur`.
static func noise(buf: PackedFloat32Array, dur: float, vol: float, f0: float, f1: float, delay := 0.0, q := 1.0, wrap := false) -> void:
	var n := int(dur * RATE)
	var start := int(delay * RATE)
	var size := buf.size()
	var f := f0
	var fk := pow(maxf(40.0, f1) / f0, 1.0 / maxf(1.0, dur * RATE))
	var g := vol
	var gk := pow(0.0001 / vol, 1.0 / maxf(1.0, n))
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var rng := RandomNumberGenerator.new()
	for i in n:
		# Coefficients of the moving filter, refreshed every 16 samples.
		if i % 16 == 0:
			var w := TAU * minf(f, RATE * 0.49) / RATE
			var alpha := sin(w) / (2.0 * q)
			var a0 := 1.0 + alpha
			b0 = alpha / a0
			a1 = -2.0 * cos(w) / a0
			a2 = (1.0 - alpha) / a0
		var x := rng.randf() * 2.0 - 1.0
		var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var j := start + i
		if j >= size:
			if not wrap:
				break
			j %= size
		buf[j] += y * g
		g *= gk
		f *= fk


## play() in src/core/audio.ts, as a buffer of the effect's length.
static func render_sfx(id: String) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(_sfx_length(id) * RATE) + 1)
	match id:
		"jump":
			tone(buf, "square", 220, 520, 0.12, 0.12)
		"land":
			noise(buf, 0.08, 0.25, 900, 200, 0, 0.8)
		"spin":
			noise(buf, 0.22, 0.25, 600, 3000, 0, 2)
			tone(buf, "triangle", 300, 600, 0.18, 0.08)
		"stomp":
			tone(buf, "square", 600, 1200, 0.08, 0.14)
			tone(buf, "square", 900, 1800, 0.08, 0.1, 0.05)
		"pound":
			tone(buf, "sawtooth", 900, 200, 0.16, 0.08)
		"poundLand":
			tone(buf, "sine", 140, 40, 0.3, 0.5)
			noise(buf, 0.25, 0.4, 500, 80, 0, 0.7)
		"break":
			noise(buf, 0.3, 0.45, 2500, 300, 0, 0.6)
			tone(buf, "square", 180, 60, 0.2, 0.12)
		"spark":
			for i in 5:
				var f := midi(76 + [0, 4, 7, 12, 16][i])
				tone(buf, "square", f, f, 0.12, 0.1, i * 0.055)
		"token":
			tone(buf, "square", 1320, 1320, 0.05, 0.06)
			tone(buf, "square", 1760, 1760, 0.07, 0.06, 0.04)
		"hurt":
			tone(buf, "sawtooth", 420, 90, 0.3, 0.16)
			noise(buf, 0.2, 0.2, 1200, 200, 0, 1)
		"die":
			tone(buf, "square", 500, 60, 0.6, 0.15)
		"checkpoint":
			for i in 3:
				var f := midi(69 + [0, 7, 12][i])
				tone(buf, "triangle", f, f, 0.18, 0.16, i * 0.08)
		"rescue":
			for i in 5:
				var f := midi(72 + [0, 4, 7, 11, 14][i])
				tone(buf, "triangle", f, f, 0.2, 0.14, i * 0.07)
		"enemyDie":
			noise(buf, 0.18, 0.3, 3000, 400, 0, 1.5)
			tone(buf, "square", 700, 120, 0.15, 0.08)
		"select":
			tone(buf, "square", 660, 660, 0.05, 0.07)
		"confirm":
			tone(buf, "square", 660, 660, 0.06, 0.08)
			tone(buf, "square", 990, 990, 0.1, 0.08, 0.06)
		"complete":
			var notes := [0, 4, 7, 12, 7, 12, 16, 19]
			for i in notes.size():
				var f := midi(67 + notes[i])
				tone(buf, "square", f, f, 0.16, 0.1, i * 0.09)
		"denied":
			tone(buf, "square", 180, 160, 0.12, 0.09)
			tone(buf, "square", 140, 120, 0.16, 0.09, 0.12)
		"buy":
			for i in 4:
				var f := midi(74 + [0, 7, 12, 16][i])
				tone(buf, "square", f, f, 0.1, 0.09, i * 0.05)
		"deflect":
			tone(buf, "triangle", 2400, 1800, 0.08, 0.08)
		"shoot":
			tone(buf, "square", 1400, 500, 0.1, 0.05)
		"gunToken":
			tone(buf, "square", 980, 420, 0.06, 0.06)
		"gunPellet":
			noise(buf, 0.14, 0.35, 2200, 300, 0, 0.7)
			tone(buf, "square", 220, 80, 0.1, 0.1)
		"gunGlyph":
			# TS picks 1500-2100 Hz at random; the pre-rendered effect uses the middle.
			tone(buf, "square", 1800, 900, 0.03, 0.035)
		"gunBeam":
			tone(buf, "sawtooth", 1800, 1700, 0.08, 0.025)
		"gunOrb":
			tone(buf, "sine", 300, 90, 0.35, 0.3)
			tone(buf, "square", 600, 150, 0.2, 0.06)
		"overheat":
			tone(buf, "sawtooth", 700, 120, 0.5, 0.1)
			noise(buf, 0.5, 0.2, 4000, 500, 0, 2)
		"explode":
			tone(buf, "sine", 160, 30, 0.45, 0.5)
			noise(buf, 0.45, 0.5, 1500, 60, 0, 0.6)
		"hit":
			tone(buf, "square", 420, 300, 0.04, 0.05)
		"bossHit":
			tone(buf, "sawtooth", 300, 60, 0.4, 0.2)
			noise(buf, 0.4, 0.4, 4000, 200, 0, 0.8)
		"bossTeleport":
			tone(buf, "sine", 200, 1600, 0.3, 0.1)
			noise(buf, 0.3, 0.12, 6000, 1500, 0, 3)
		"weaponGet":
			for i in 7:
				var f := midi(64 + [0, 4, 7, 12, 16, 19, 24][i])
				tone(buf, "square", f, f, 0.25, 0.1, i * 0.08)
		"crush":
			tone(buf, "sine", 110, 35, 0.35, 0.45)
			noise(buf, 0.3, 0.35, 400, 60, 0, 0.6)
		"typing":
			# TS picks 3000-5000 Hz at random; the pre-rendered effect uses the middle.
			noise(buf, 0.025, 0.25, 4000, 2000, 0, 3)
		"slam":
			tone(buf, "sine", 90, 30, 0.5, 0.6)
			noise(buf, 0.4, 0.5, 600, 50, 0, 0.5)
		"laser":
			tone(buf, "sawtooth", 220, 2200, 0.4, 0.12)
			noise(buf, 0.4, 0.2, 5000, 800, 0, 1)
		"heart":
			for i in 4:
				var f := midi(72 + [0, 5, 9, 12][i])
				tone(buf, "triangle", f, f, 0.15, 0.14, i * 0.06)
		_:
			push_warning("Sound: no effect named %s" % id)
	return _wav(buf, SFX_BUS)


## How long an effect lasts (its last note's delay + length).
static func _sfx_length(id: String) -> float:
	match id:
		"spark": return 4 * 0.055 + 0.12
		"checkpoint": return 2 * 0.08 + 0.18
		"rescue": return 4 * 0.07 + 0.2
		"complete": return 7 * 0.09 + 0.16
		"heart": return 3 * 0.06 + 0.15
		"buy": return 3 * 0.05 + 0.1
		"deflect": return 0.08
		"shoot": return 0.1
		"bossHit": return 0.4
		"gunToken": return 0.06
		"gunPellet": return 0.14
		"gunGlyph": return 0.03
		"gunBeam": return 0.08
		"gunOrb": return 0.35
		"overheat", "explode": return 0.5
		"hit": return 0.04
		"bossTeleport": return 0.3
		"weaponGet": return 6 * 0.08 + 0.25
		"crush": return 0.35
		"typing": return 0.025
		"slam": return 0.5
		"laser": return 0.4
		"die": return 0.6
		"denied": return 0.28
		"break", "poundLand", "hurt": return 0.3
		"spin": return 0.22
		"confirm": return 0.16
		"stomp": return 0.13
		"token": return 0.11
	return 0.2


## The hover jet (hoverStart() + hoverUpdate()): noise through a bandpass of Q 3 whose centre swings
## 1400 +- 400 Hz at 40 rad/s, gain 0.16; 6 swings long so it loops.
static func render_hover() -> AudioStreamWAV:
	var n := int(6 * TAU / 40.0 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var rng := RandomNumberGenerator.new()
	# Two passes: the first settles the filter, the second is kept, so the loop has no click.
	for pass_i in 2:
		for i in n:
			if i % 16 == 0:
				var w := TAU * (1400.0 + sin(float(i) / RATE * 40.0) * 400.0) / RATE
				var alpha := sin(w) / 6.0
				var a0 := 1.0 + alpha
				b0 = alpha / a0
				a1 = -2.0 * cos(w) / a0
				a2 = (1.0 - alpha) / a0
			var x := rng.randf() * 2.0 - 1.0
			var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			buf[i] = y * 0.16
	var wav := _wav(buf, SFX_BUS)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


## One loop of a track (schedule() / scheduleStep()): 16 steps a bar, a chord per bar, the lead on every
## other 4 bars.
static func render_track(id: String) -> AudioStreamWAV:
	var def: Dictionary = TRACKS[id]
	var step_dur: float = 60.0 / def.bpm / 4.0
	var bars: int = def.roots.size()
	var steps := bars * 16 * (2 if def.has("lead") else 1)
	var buf := PackedFloat32Array()
	buf.resize(int(steps * step_dur * RATE))
	for step in steps:
		var bar := (step / 16) % bars
		var s := step % 16
		var t: float = step * step_dur
		var root: int = def.roots[bar]
		var chord := [0, 3 if def.minor[bar] else 4, 7, 12]
		if s % 4 == 0:
			var f := midi(root - 12)
			tone(buf, "triangle", f, f, step_dur * 3.5, 0.5, t, true)
		if s % 2 == 0:
			var f := midi(root + 12 + chord[def.arp[(s / 2) % def.arp.size()]])
			tone(buf, "square", f, f, step_dur * 1.6, 0.07, t, true)
		if def.has("lead") and (step / 64) % 2 == 1 and def.lead[s] >= 0:
			var f := midi(root + 12 + def.lead[s])
			tone(buf, "triangle", f, f, step_dur * 1.8, 0.16, t, true)
		if def.drums:
			if s % 8 == 0:
				tone(buf, "sine", 120, 40, 0.14, 0.6, t, true)
			if s % 8 == 4:
				noise(buf, 0.12, 0.35, 1800, 900, t, 0.8, true)
			if s % 2 == 1:
				noise(buf, 0.03, 0.12, 8000, 7000, t, 1, true)
	var wav := _wav(buf, MUSIC_BUS)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = buf.size()
	return wav


## 16-bit mono PCM at RATE, scaled by `gain` (the TS bus).
static func _wav(buf: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav
