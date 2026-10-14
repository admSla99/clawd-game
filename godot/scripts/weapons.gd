class_name Weapons

## Clawd's weapons and gun upgrades from src/weapons.ts: WEAPONS (stats and shop prices), WEAPON_ORDER (slots
## 1-5), the gun upgrades the shop sells (Bigger Model, Faster Inference, Longer Context) and the gun part of
## loadoutFromSave(). Speeds in px/s, spreads and fans in radians, life in seconds; `heat` is the context each
## shot adds, `pierce` how many enemies a bullet passes through, `splash` an explosion where it stops.

const WEAPONS := {
	"blaster": {"id": "blaster", "name": "Token Blaster", "desc": "Fires freshly minted tokens. Reliable, cheap to run.",
		"price": 0, "sparks": 0, "kind": "token", "fire_rate": 6.0, "damage": 2.0, "speed": 380.0, "spread": 0.03,
		"pellets": 1, "fan": 0.0, "life": 0.9, "heat": 7.0, "pierce": 0, "color": Color("#D97757")},
	"spreader": {"id": "spreader", "name": "Context Spreader", "desc": "Five tokens at once in a wide fan. Devastating up close.",
		"price": 120, "sparks": 0, "kind": "pellet", "fire_rate": 1.9, "damage": 2.0, "speed": 340.0, "spread": 0.05,
		"pellets": 5, "fan": 0.55, "life": 0.38, "heat": 20.0, "pierce": 0, "color": Color("#F0A585")},
	"stream": {"id": "stream", "name": "Stream Output", "desc": "Streams characters as fast as they are sampled.",
		"price": 220, "sparks": 3, "kind": "glyph", "fire_rate": 15.0, "damage": 1.0, "speed": 440.0, "spread": 0.09,
		"pellets": 1, "fan": 0.0, "life": 0.7, "heat": 4.5, "pierce": 0, "color": Color("#E6E6E6")},
	"beam": {"id": "beam", "name": "Attention Beam", "desc": "Attends to everything in a line. Pierces all targets.",
		"price": 380, "sparks": 8, "kind": "beam", "fire_rate": 20.0, "damage": 1.0, "speed": 0.0, "spread": 0.0,
		"pellets": 1, "fan": 0.0, "life": 0.0, "heat": 3.6, "pierce": 99, "color": Color("#5FD0D8")},
	"cannon": {"id": "cannon", "name": "Opus Cannon", "desc": "One big, thoughtful answer. Explodes and breaks corrupted data.",
		"price": 520, "sparks": 12, "kind": "orb", "fire_rate": 1.1, "damage": 14.0, "speed": 230.0, "spread": 0.0,
		"pellets": 1, "fan": 0.0, "life": 2.0, "heat": 34.0, "pierce": 0, "splash": {"radius": 40.0, "damage": 8.0},
		"color": Color("#D97757")},
}
const ORDER := ["blaster", "spreader", "stream", "beam", "cannon"]
## The gun upgrades of UPGRADES (the others, Extra Heart, Jet Tuning and Token Magnet, are in Shop.ITEMS).
const UPGRADES := [
	{"id": "damage", "name": "Bigger Model", "desc": "+25% weapon damage per level.", "prices": [100, 220, 400], "sparks": [0, 2, 6]},
	{"id": "rate", "name": "Faster Inference", "desc": "+15% fire rate per level.", "prices": [90, 200, 350]},
	{"id": "context", "name": "Longer Context", "desc": "Fire longer before the context overflows.", "prices": [80, 200]},
]


static func get_def(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS.blaster)


## loadoutFromSave(): +25 % damage, +15 % fire rate per level, and 100 context plus 40 per level.
static func damage_mult() -> float:
	return (1.0 + 0.25 * Progress.upgrade("damage")) * Prompts.damage_mult()


static func rate_mult() -> float:
	return (1.0 + 0.15 * Progress.upgrade("rate")) * Prompts.rate_mult()


static func heat_cap() -> float:
	return 100.0 + 40.0 * Progress.upgrade("context")


## The owned weapons in slot order.
static func owned() -> Array:
	return ORDER.filter(func(id: String) -> bool: return Progress.weapons.has(id))
