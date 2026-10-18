class_name Stats
extends RefCounted

## Clawd's stats from everything that gives them (docs/endgame-plan.md E2): the prompt tree (Prompts.stat()) and
## the equipped gear (Gear.stat()); map mods will join them. Per cent stats add up before they multiply, like
## Path of Exile's "increased". The shop's upgrades stay where they were (Weapons, Main._apply_loadout()).

## Critical strikes: the weapon's base chance (its implicit) plus `crit` from gear, in per cent, `crit_inc` per cent
## more (the tree); they deal CRIT_MULTI plus `crit_multi` per cent. Temperature 0. (the tree's `precise`) has none.
const CRIT_MULTI := 150.0


static func total(key: String) -> float:
	return Prompts.stat(key) + Gear.stat(key)


## Damage times this: `damage` from both, and Temperature 0.'s more.
static func damage_mult() -> float:
	return maxf(0.1, 1.0 + total("damage") / 100.0) * (1.0 + Prompts.PRECISE_MORE if Prompts.on("precise") else 1.0)


static func rate_mult() -> float:
	return maxf(0.1, 1.0 + total("rate") / 100.0)


static func token_mult() -> float:
	return 1.0 + (Prompts.stat("tokens") + Gear.stat("tokens")) / 100.0


static func crit_chance() -> float:
	if Prompts.on("precise"):
		return 0.0
	return clampf(total("crit") * (1.0 + total("crit_inc") / 100.0) / 100.0, 0.0, 1.0)


static func crit_mult() -> float:
	return (CRIT_MULTI + total("crit_multi")) / 100.0


# --- The endgame's hit points (Main.endgame: the hideout and maps) -------------------------------------------

## Life: BASE_LIFE, LIFE_PER_LEVEL per character level, the gear's `life`, and LIFE_PER_HEART for every heart the
## prompt tree and the shop's Extra Heart give or take in the campaign, `life_pct` per cent more (the tree), and
## Air-gapped.'s less.
const BASE_LIFE := 50.0
const LIFE_PER_LEVEL := 5.0
const LIFE_PER_HEART := 25.0
## An enemy's hit in an area of level a: ENEMY_HIT * ENEMY_GROWTH^a (11.5 at 1, 41 at 30, 154 at 60; a T1 map, area
## level 32, hits for 45; raised after the first playtest: too easy).
const ENEMY_HIT := 11.0
const ENEMY_GROWTH := 1.045
## Armour takes armour / (armour + 5 x damage) off a hit, at most ARMOUR_CAP (Path of Exile's formula).
const ARMOUR_CAP := 0.9
## Evasion avoids a hit with a chance of evasion / (evasion + 100 + 20 x area level), at most EVADE_CAP.
const EVADE_CAP := 0.75


static func max_life() -> float:
	var hearts := Prompts.stat("hearts") + Progress.upgrade("hearts")
	var flat := BASE_LIFE + LIFE_PER_LEVEL * Progress.char_level + total("life") + LIFE_PER_HEART * hearts
	var less := 1.0 - Prompts.AIRGAP_LESS_LIFE if Prompts.on("airgap") else 1.0
	return maxf(1.0, flat * (1.0 + total("life_pct") / 100.0) * less)


## Armour and evasion: flat ones (gear, the tree) `armour_pct` / `evasion_pct` per cent more; with Robustness.
## evasion counts as armour and none is left to evade with.
static func armour() -> float:
	var a := total("armour") * (1.0 + total("armour_pct") / 100.0)
	if Prompts.on("robust"):
		a += total("evasion") * (1.0 + total("evasion_pct") / 100.0)
	return a


static func evasion() -> float:
	if Prompts.on("robust"):
		return 0.0
	return total("evasion") * (1.0 + total("evasion_pct") / 100.0)


## Life regenerated a second: the gear's `regen` and `regen_pct` per cent of maximum life (the tree); none with
## Gradient Leech.
static func regen() -> float:
	if Prompts.on("gradleech"):
		return 0.0
	return total("regen") + max_life() * total("regen_pct") / 100.0


## The share of the damage Clawd deals that is leeched as life (`leech`, per cent).
static func leech() -> float:
	return total("leech") / 100.0


static func enemy_hit(area: int) -> float:
	return ENEMY_HIT * pow(ENEMY_GROWTH, area)


static func armour_reduction(armour: float, damage: float) -> float:
	if armour <= 0 or damage <= 0:
		return 0.0
	return minf(ARMOUR_CAP, armour / (armour + 5.0 * damage))


static func evade_chance(evasion: float, area: int) -> float:
	if evasion <= 0:
		return 0.0
	return minf(EVADE_CAP, evasion / (evasion + 100.0 + 20.0 * area))


# --- Damage types, resistances, ailments (docs/endgame-plan.md E7) ----------------------------------------------

## The elements besides physical: Overheat (fire), Latency (cold), Voltage (lightning), Corruption (chaos).
const ELEMENTS := ["fire", "cold", "lightning", "chaos"]
const ELEMENT_NAME := {"physical": "PHYSICAL", "fire": "OVERHEAT", "cold": "LATENCY", "lightning": "VOLTAGE", "chaos": "CORRUPTION"}
const ELEMENT_COLOR := {"physical": Color("#E0605A"), "fire": Color("#FF8A3D"), "cold": Color("#8CE0FF"),
	"lightning": Color("#FFE45C"), "chaos": Color("#B07CFF")}
## Resistances count up to RES_CAP; a map lowers them by RES_PENALTY a tier.
const RES_CAP := 75.0
const RES_PENALTY := 5.0
## Ailments, on Clawd and on enemies alike: an Overheat part ignites IGNITE_CHANCE of the time (BURN_SHARE of it
## over BURN_TIME s); a Latency part chills for CHILL_TIME s (CHILL_FACTOR speed), and one of FREEZE_SHARE of an
## enemy's life freezes it for FREEZE_TIME s; a Voltage part shocks SHOCK_CHANCE of the time (SHOCK_TAKEN more
## damage taken for SHOCK_TIME s). Corruption has none.
const IGNITE_CHANCE := 0.25
const BURN_SHARE := 0.6
const BURN_TIME := 2.0
const CHILL_TIME := 1.5
const CHILL_FACTOR := 0.7
const FREEZE_SHARE := 0.2
const FREEZE_TIME := 0.6
const SHOCK_CHANCE := 0.3
const SHOCK_TIME := 2.0
const SHOCK_TAKEN := 0.2


## Clawd's resistances (element -> per cent) after `penalty`, at most RES_CAP each; `res_ele` counts for Overheat,
## Latency and Voltage. Air-gapped.: Corruption cannot hurt (100).
static func resistances(penalty := 0.0) -> Dictionary:
	var out := {}
	for k in ELEMENTS:
		out[k] = minf(RES_CAP, total("res_" + k) + (total("res_ele") if k != "chaos" else 0.0) - penalty)
	if Prompts.on("airgap"):
		out.chaos = 100.0
	return out


## The share of Clawd's damage added as each element (element -> fraction; fire, cold, lightning), `ele_damage`
## per cent more.
static func elements() -> Dictionary:
	var out := {}
	var more := 1.0 + total("ele_damage") / 100.0
	for k in ["fire", "cold", "lightning"]:
		var v := total("extra_" + k) / 100.0
		if v > 0:
			out[k] = v * more
	return out


## Damage times this for the elements added as extra (1 without any).
static func ele_mult() -> float:
	var n := 1.0
	var e := elements()
	for k in e:
		n += e[k]
	return n


## The elemental parts of a hit of `damage` (that already includes ele_mult()), for the ailments.
static func ailment_parts(damage: float) -> Dictionary:
	var e := elements()
	var out := {}
	for k in e:
		out[k] = damage * e[k] / ele_mult()
	return out


## Clawd's ailments on enemies, more by the tree: igniting and shocking more often (`ignite`, `shock`), freezing
## with less of a hit (`freeze`), burning harder (`burn`), every ailment longer (`ailment_time`).
static func ignite_chance() -> float:
	return minf(1.0, IGNITE_CHANCE * (1.0 + total("ignite") / 100.0))


static func shock_chance() -> float:
	return minf(1.0, SHOCK_CHANCE * (1.0 + total("shock") / 100.0))


static func freeze_share() -> float:
	return FREEZE_SHARE / (1.0 + total("freeze") / 100.0)


static func burn_mult() -> float:
	return 1.0 + total("burn") / 100.0


static func ailment_time() -> float:
	return 1.0 + total("ailment_time") / 100.0


## The chance Clawd avoids an ailment (`avoid`, per cent).
static func avoid_chance() -> float:
	return clampf(total("avoid") / 100.0, 0.0, 1.0)
