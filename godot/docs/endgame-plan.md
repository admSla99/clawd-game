# Endgame plan: THE ATLAS (2026-10-15)

After world 3 the game grows an ARPG endgame in the manner of Path of Exile: farming maps for gear, currency and
levels that feed the prompt tree. Chosen by the user in an interview on 2026-10-15 (every pick below is theirs).
Tick the boxes in the commit that finishes a task; record extras the user asks for under *Added beyond the plan*.

## Decisions

| Topic | Choice |
|---|---|
| Core loop | **Map items + a Map Device.** Maps drop as items with a tier (T1-T16) and random mods; Clawd puts one into the device in his hideout and plays it; maps drop more maps. |
| Layouts | **Procedural, from hand-drawn chunks** (`levels/chunks/<theme>/*.txt`), seeded per map, built at runtime with `Level.build()`. |
| Gear | **Slots + rarity + affixes**: normal / magic / rare / unique, prefixes and suffixes in tiers gated by item level (= the area level where it dropped). |
| Tree points | **Character level from XP**: one point per level (cap 100), on top of world 3's sparks and the bought points. The tree grows to ~120 nodes. |
| Crafting | **Currency orbs** that drop in maps and work on items and maps. Tokens stay the shop's money. |
| Inventory | **A grid inventory and a stash** (items 1x1 to 2x3), tooltips that compare with what is equipped, items on the ground with labels coloured by rarity. |
| Death in a map | **Portals and XP loss**: a map opens 6 portals; dying sends Clawd to the hideout and the map stays as it was; with no portals left it is lost. A death costs 10% of the current level's XP. |
| Mechanics | **All four**: a map boss and Atlas progress, Delirium fog (waves), Breaches, pinnacle bosses. |
| Hideout | **A playable room** (a small 2.5D level): the Map Device, the stash, a vendor, a terminal for the prompt tree and the Atlas. |
| Damage | **Physical + three elements + chaos with resistances** (cap 75%) and ailments. |
| Weapons | **The five weapons become item bases** (Blaster, Spreader, Stream, Beam, Cannon) that drop with affixes; the ones Clawd found become normal items. The shop and its gun mods stay as global upgrades. |
| Health | **HP in the hideout and maps, hearts in the campaign.** Worlds 1-3 stay as they are; in the endgame Clawd has a number of HP (base + gear + tree), enemies hit for numbers scaled by the area level, armour and resistances reduce them, the HUD shows a bar. |
| Order | **A vertical slice first** (E1-E5), then the systems one at a time. |

## The design

### Character level

- `Progress.xp` and `Progress.char_level`; enemies give XP by their hp and the area level (campaign levels have
  an area level of their own, 1-1 = 1 up to 3-B = 27; map tier n = 30 + 2n). A little less XP from enemies far below
  Clawd's level, as in PoE.
- Points for the tree = (level - 1) + world 3's sparks + bought points. The HUD shows an XP bar under the hearts / HP.
- XP loss on death only in maps (never below the level's start).

### Items

- An item: base (slot, size, implicit), rarity, item level, affixes (id, tier, rolled value), for maps also tier
  and quantity / rarity / pack size. Stored as dictionaries in `user://items.json` (inventory, stash, equipped), not
  in `progress.json`.
- Slots (AI themed): **Weapon** (the five bases), **Context Window** (helmet), **Chassis** (body), **Actuators**
  (gloves), **Treads** (boots), **Core** (amulet), two **Plugins** (rings).
- Rarity: normal (no affixes), magic (1 prefix + 1 suffix at most), rare (up to 3 + 3, a generated name like
  "Hollow Gradient"), unique (fixed affixes and a special effect, from pinnacle bosses and rare drops).
- Affixes, prefixes: flat / % damage, element added to attacks, + max HP, armour, evasion, + projectiles;
  suffixes: fire rate, crit chance / multiplier, resistances, movement speed, + item rarity, hover / zip time.
  Tiers by item level, rolled values within a tier.
- One stat model for everything (`scripts/stats.gd`): tree, gear and map mods add up to one table that `Main`,
  `Player`, `Gun`, `Echo` read (today `Prompts.stat()` / `damage_mult()` and `Weapons.damage_mult()` are separate).
- Drops: every enemy rolls for an item (chance by its hp, more with rarity / quantity), bosses for several; items
  lie on the ground with a label, Clawd picks them up with the interact key; currency stacks.

### Currency (names are proposals)

| Orb | PoE | Does |
|---|---|---|
| Prompt Seed | Transmutation | normal -> magic |
| Few-shot Example | Augmentation | adds an affix to a magic item |
| Resample | Alteration | rerolls a magic item |
| Distillation | Alchemy | normal -> rare |
| Temperature Spike | Chaos | rerolls a rare item |
| Fine-tune | Exalted | adds an affix to a rare item |
| Context Reset | Scouring | -> normal |
| RLHF | Divine | rerolls the values, not the affixes |

### Damage types

Physical, **Overheat** (fire; ignite burns over time), **Latency** (cold; chill slows, freeze stops),
**Voltage** (lightning; shock makes the target take more damage) and **Corruption** (chaos; past resistances only
by its own resistance). Clawd's resistances are capped at 75%, maps and late tiers lower them. Enemies get a damage
type (turrets fire Voltage, spam bots Corruption, ...); the tier's mods add more.

### Maps

- A map item: tier, theme (world 1, 2 or 3 chunks), mods (prefix / suffix like items: "Hallucinating" more packs,
  "Rate Limited" enemies fire faster, "Overheated" extra fire damage, "Low Context" less max HP, "No Retry" no
  regeneration ...), quantity / rarity / pack size from the mods.
- The generator: chunks are small ASCII maps with marked entries and exits (heights) and a kind (start, corridor,
  arena, climb, boss); a seeded walk joins 8-14 of them by theme and tier into one level, fills the enemy slots by
  tier and mods, puts the boss arena at the end. A check builds many seeds per theme and runs the reach logic on
  each.
- The map boss: a scaled version of a campaign boss or a new one per theme; killing it completes the map.
- Map Device: an object in the hideout; a screen to put a map in, see its mods and open it. 6 portals per map,
  shown in the HUD.

### Hideout

A small level (`levels/hideout.txt`, theme of its own) where Clawd walks: the Map Device, the stash (opens the stash
and the inventory), a vendor (sells items for tokens and orb shards, buys a few basics) and a terminal for the
prompt tree and the Atlas. It opens on the world map once 3-B is beaten; maps return here.

### Atlas, mechanics, pinnacle

- **Atlas**: a screen of the tiers and themes; completing a map of tier n the first time unlocks n + 1 and gives an
  Atlas point; Atlas points go into a small tree of map bonuses (more mechanics, more of an orb, sustain).
- **Delirium fog**: a "hallucination fog" mirror at the map's start; while Clawd is in the fog, waves of enemies
  grow stronger and drop more; leaving it or a timer ends it; it drops splinters toward a delirium map.
- **Breach**: a rift that grows from a hand in the map, spills enemies from the void while it is open and shuts
  after a timer; its enemies drop splinters that make a Breach map with its own boss.
- **Pinnacle bosses**: uber Hallucination, Codex and Router, each opened with fragments that drop from T11+ maps,
  with unique items of their own.

## Milestones

- [x] E0 The interview and this plan.
- [x] E1 Character level: XP, levels, area levels, points from levels in the tree, the HUD bar, checks, README.
      Campaign area levels are 1 + 2n in play order (3-B 27); the campaign ends at about level 13.
- [ ] E2 Items and stats: the item model, bases, affix tables, rarity, the stat model, numeric HP in the endgame,
      drops on the ground and pickup, checks, README.
- [ ] E3 Inventory and stash: the grid UI, equipping, tooltips with comparison, the stash, `items.json`, checks.
- [ ] E4 The hideout: the room, the stash, the vendor, the terminal, the entry from the world map.
- [ ] E5 Maps: chunks of world 1, the generator and its check, map items and mods, the Map Device, portals, the
      map boss, maps dropping maps (T1-T5). **The vertical slice ends here: a first playtest.**
- [ ] E6 Currency orbs: drops, stacks, using them on items and maps.
- [ ] E7 Damage types, resistances and ailments on enemies, gear and map mods.
- [ ] E8 Chunks of worlds 2 and 3, tiers up to T16, the Atlas screen and its points.
- [ ] E9 The prompt tree grows to ~120 nodes for levels up to 100, new keystones.
- [ ] E10 Delirium fog.
- [ ] E11 Breaches.
- [ ] E12 Pinnacle bosses and uniques.
- [ ] E13 Balance pass, docs.

## Added beyond the plan

(nothing yet)
