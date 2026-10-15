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
