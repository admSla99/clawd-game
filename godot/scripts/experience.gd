class_name Experience
extends RefCounted

## Clawd's character level (docs/endgame-plan.md E1): defeated enemies give XP, levels go up to MAX_LEVEL, and
## every level gained is a point in the prompt tree (Prompts.points_total()). The numbers live here; the state
## (Progress.char_level, Progress.xp) in Progress, and Main grants the XP (gain_xp()).
## An enemy is worth its full hit points times a factor that grows with the area level; enemies far below
## Clawd's level give much less (Path of Exile's penalty), so old levels do not farm well.

const MAX_LEVEL := 100
## XP from level L to L + 1: NEED_BASE * L^1.6 * 1.06^L (22 for the first, ~7700 at 20, ~10 million at 99).
## The campaign gives about 11000 in all, level 13 by the end of 3-B.
const NEED_BASE := 20.0
## Bosses' worth in hit points (Hallucination falls to three stomps; the others' fights are long).
const BOSS_WORTH := {"hallucination": 30.0, "codex": 150.0, "router": 160.0}
## Gold, the colour of XP and levels in the HUD, the map, the popups.
const COLOR := Color("#F2D27A")


## XP needed from `level` to the next one.
static func need(level: int) -> int:
	return roundi(NEED_BASE * pow(level, 1.6) * pow(1.06, level))


## The campaign's area levels: the n-th level in play order (from 0) is 1 + 2n, so 1-1 is 1 and 3-B 27 (maps,
## later, start above that).
static func area_level(index: int) -> int:
	return 1 + 2 * maxi(index, 0)


## XP for an enemy of `hp` full hit points in an area of level `area`, for Clawd at `level` (at least 1).
static func kill_xp(hp: float, area: int, level: int) -> int:
	return maxi(1, roundi(hp * (1.0 + area / 4.0) * penalty(area, level)))


## Path of Exile's XP penalty for enemies far below Clawd: none within a safe range of 3 levels (+1 per 16 of
## Clawd's levels), then quickly less. Enemies above Clawd give full XP.
static func penalty(area: int, level: int) -> float:
	var safe := 3 + level / 16
	var over := maxi(0, level - area - safe)
	if over == 0:
		return 1.0
	return pow((safe + 5.0) / (safe + 5.0 + pow(over, 2.5)), 1.5)


## How far Clawd is into the current level, 0 to 1 (1 at the cap).
static func fraction() -> float:
	if Progress.char_level >= MAX_LEVEL:
		return 1.0
	return clampf(float(Progress.xp) / need(Progress.char_level), 0.0, 1.0)
