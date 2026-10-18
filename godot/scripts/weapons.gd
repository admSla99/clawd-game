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
## The endgame's melee weapons (docs/endgame-plan.md E14), the weapon items of swords and axes: `class` (the guns'
## is "gun"), swings a second (`fire_rate`, so the gun's stats read the same), damage a swing, `reach` (px from
## Clawd's arm), `arc` (radians round the aim it hits in), a combo of `combo` swings whose last deals `finisher`
## times as much in an arc 1.3 times as wide, and `swing` (seconds the blade sweeps and hits). Scripts/melee.gd
## swings them. Swords are quick; axes slow and heavy, their swing a whole circle round Clawd (a cleave).
const MELEE := {
	"tokenizer_blade": {"id": "tokenizer_blade", "name": "Tokenizer Blade", "class": "sword", "kind": "sword", "fire_rate": 2.6,
		"damage": 5.0, "reach": 30.0, "arc": 1.9, "combo": 3, "finisher": 1.5, "swing": 0.16, "color": Color("#DDE8EE")},
	"attention_sabre": {"id": "attention_sabre", "name": "Attention Sabre", "class": "sword", "kind": "sword", "fire_rate": 2.7,
		"damage": 7.5, "reach": 32.0, "arc": 2.0, "combo": 3, "finisher": 1.5, "swing": 0.16, "color": Color("#8CE0FF")},
	"transformer_edge": {"id": "transformer_edge", "name": "Transformer Edge", "class": "sword", "kind": "sword", "fire_rate": 2.8,
		"damage": 11.0, "reach": 34.0, "arc": 2.1, "combo": 3, "finisher": 1.6, "swing": 0.15, "color": Color("#F2D27A")},
	"pruning_axe": {"id": "pruning_axe", "name": "Pruning Axe", "class": "axe", "kind": "axe", "fire_rate": 1.15,
		"damage": 13.0, "reach": 34.0, "arc": 6.3, "combo": 1, "finisher": 1.0, "swing": 0.28, "color": Color("#E0B070")},
	"gradient_cleaver": {"id": "gradient_cleaver", "name": "Gradient Cleaver", "class": "axe", "kind": "axe", "fire_rate": 1.2,
		"damage": 19.0, "reach": 36.0, "arc": 6.3, "combo": 1, "finisher": 1.0, "swing": 0.28, "color": Color("#FF8A3D")},
	"dropout_reaver": {"id": "dropout_reaver", "name": "Dropout Reaver", "class": "axe", "kind": "axe", "fire_rate": 1.25,
		"damage": 27.0, "reach": 38.0, "arc": 6.3, "combo": 1, "finisher": 1.0, "swing": 0.27, "color": Color("#B07CFF")},
}
## What each class is called (the item's tooltip, the HUD).
const CLASS_NAME := {"gun": "GUN", "sword": "SWORD", "axe": "AXE"}
## The gun upgrades of UPGRADES (the others, Extra Heart, Jet Tuning and Token Magnet, are in Shop.ITEMS).
const UPGRADES := [
	{"id": "damage", "name": "Bigger Model", "desc": "+25% weapon damage per level.", "prices": [100, 220, 400], "sparks": [0, 2, 6]},
	{"id": "rate", "name": "Faster Inference", "desc": "+15% fire rate per level.", "prices": [90, 200, 350]},
	{"id": "context", "name": "Longer Context", "desc": "Fire longer before the context overflows.", "prices": [80, 200]},
]


static func get_def(id: String) -> Dictionary:
	return WEAPONS.get(id, MELEE.get(id, WEAPONS.blaster))


static func has(id: String) -> bool:
	return WEAPONS.has(id) or MELEE.has(id)


## A weapon's class: "gun", "sword" or "axe".
static func class_of(w: Dictionary) -> String:
	return w.get("class", "gun")


static func is_melee(w: Dictionary) -> bool:
	return class_of(w) in ["sword", "axe"]


## loadoutFromSave(): +25 % damage, +15 % fire rate per level, and 100 context plus 40 per level; times the prompt
## tree's and the gear's (Stats) and the equipped weapon item's own (local) damage and fire rate.
static func damage_mult() -> float:
	return (1.0 + 0.25 * Progress.upgrade("damage")) * Stats.damage_mult() * (1.0 + Gear.stat("local_damage") / 100.0) \
		* Stats.ele_mult()


static func rate_mult() -> float:
	return (1.0 + 0.15 * Progress.upgrade("rate")) * Stats.rate_mult() * (1.0 + Gear.stat("local_rate") / 100.0)


static func heat_cap() -> float:
	return (100.0 + 40.0 * Progress.upgrade("context")) * (1.0 + Stats.total("heat") / 100.0)


## The owned weapons in slot order.
static func owned() -> Array:
	return ORDER.filter(func(id: String) -> bool: return Progress.weapons.has(id))
