class_name Stats
extends RefCounted

## Clawd's stats from everything that gives them (docs/endgame-plan.md E2): the prompt tree (Prompts.stat()) and
## the equipped gear (Gear.stat()); map mods will join them. Per cent stats add up before they multiply, like
## Path of Exile's "increased". The shop's upgrades stay where they were (Weapons, Main._apply_loadout()).

## Critical strikes: the weapon's base chance (its implicit) plus `crit` from gear, in per cent; they deal
## CRIT_MULTI plus `crit_multi` per cent.
const CRIT_MULTI := 150.0


static func total(key: String) -> float:
	return Prompts.stat(key) + Gear.stat(key)


static func damage_mult() -> float:
	return maxf(0.1, 1.0 + total("damage") / 100.0)


static func rate_mult() -> float:
	return maxf(0.1, 1.0 + total("rate") / 100.0)


static func token_mult() -> float:
	return 1.0 + (Prompts.stat("tokens") + Gear.stat("tokens")) / 100.0


static func crit_chance() -> float:
	return clampf(total("crit") / 100.0, 0.0, 1.0)


static func crit_mult() -> float:
	return (CRIT_MULTI + total("crit_multi")) / 100.0


# --- The endgame's hit points (Main.endgame: the hideout and maps) -------------------------------------------

## Life: BASE_LIFE, LIFE_PER_LEVEL per character level, the gear's `life`, and LIFE_PER_HEART for every heart the
## prompt tree and the shop's Extra Heart give or take in the campaign.
const BASE_LIFE := 50.0
const LIFE_PER_LEVEL := 5.0
const LIFE_PER_HEART := 25.0
## An enemy's hit in an area of level a: ENEMY_HIT * ENEMY_GROWTH^a (8.4 at 1, 30 at 30, 112 at 60; a T1 map, area
## level 32, hits for 33).
const ENEMY_HIT := 8.0
const ENEMY_GROWTH := 1.045
## Armour takes armour / (armour + 5 x damage) off a hit, at most ARMOUR_CAP (Path of Exile's formula).
const ARMOUR_CAP := 0.9
## Evasion avoids a hit with a chance of evasion / (evasion + 100 + 20 x area level), at most EVADE_CAP.
const EVADE_CAP := 0.75


static func max_life() -> float:
	var hearts := Prompts.stat("hearts") + Progress.upgrade("hearts")
	return maxf(1.0, BASE_LIFE + LIFE_PER_LEVEL * Progress.char_level + total("life") + LIFE_PER_HEART * hearts)


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
