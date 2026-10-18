# Endgame plan: THE ATLAS (2026-10-15)

> **Status (2026-10-16):** E0-E5, the vertical slice, are done and the user played them ("everything works";
> tuned harder after it, see *Added beyond the plan*). E6 (currency orbs), E7 (damage types) and E8 (the Atlas:
> worlds 2 and 3 as maps, tiers to T16, the Atlas's tree) and E9 (the prompt tree redrawn, 137 nodes) are done.
> Next is **E14, weapon classes and skills** (the user's priority, 2026-10-18); E10-E13 can wait.
> The view stays 2.5D from the side: a top-down prototype was tried on a branch on 2026-10-16 and the user turned
> it down (2026-10-18).

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
| Weapons and skills (E14) | **Swords, axes, bows, staves** besides the guns; **a skill bar with gems** (four slots, a skill and two Hooks each, gems level up); **COMPUTE** as mana; **endgame only** (2026-10-18). |

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

### Weapon classes and skills (E14)

Asked for on 2026-10-18 ("other kinds of weapons, swords, axes, bows, and spells or skills like in PoE"), ahead of
E10-E13, which the user called less needed. The user's calls: **swords, axes, bows and staves** next to the five
guns; **a skill bar with gems** (PoE's gems with simplified linking); a new resource, **COMPUTE** (mana); all of it
**in the endgame only** (maps and the hideout's vendor), the campaign stays as it is.

**What there is now.** Every weapon is a gun: `Weapons.WEAPONS` (five, kinds token / pellet / glyph / beam / orb),
fired by `Gun` (aim from the mouse or the keys, context heat, overheating), with bullets (`Bullet`), the beam
(`Main.fire_beam()`) and the orb's splash (`Main.explode()`). A weapon item (`Items.BASES`, kind "weapon") names
the gun it fires, and while one is equipped it decides the gun (no switching on 1-5). Clawd's own melee is the
spin (C, or the attack unarmed), the stomp and the pound, for fixed damage (`Enemy.SPIN_DAMAGE` etc.). Damage
goes through `Enemy.hit()`; `Stats` adds up the tree's and the gear's stats; `Main.endgame` gives Clawd hit points.
Mouse: left attacks, right throws the hook, middle sends a sub-agent, the wheel switches guns.

**Weapon classes.** A base gets a `class`: `gun` (the five), `sword`, `axe`, `bow`, `staff`; three tiers of base
each (item levels 1 / 22 / 45 of the maps' areas, so from T1), with a base damage, attack speed and critical
chance, and local affixes as guns have. `Gun` stays the hand (aim, the held voxel model, recoil) and hands the
attack to a class:

| Class | Bases (proposals) | The attack (left button / attack key) |
|---|---|---|
| Sword | Tokenizer Blade, Attention Sabre, Transformer Edge | A quick slash towards the aim: an arc hitbox (about 28 px, 110 deg) for a few frames, every enemy hit once a swing; a three-hit combo (the third wider and +50 %); a downward slash in the air bounces Clawd like a stomp (a pogo, hover back); a slash cuts cancellable enemy shots |
| Axe | Pruning Axe, Gradient Cleaver, Dropout Reaver | A slow, heavy swing (about 0.6 s): a wider arc that cleaves behind too, more damage, knock-back; also the pogo |
| Bow | Recurrent Bow, Backprop Longbow, Residual Bow | Hold to draw (0.15 to 0.7 s), release to shoot: the arrow's speed and damage grow with the draw (40 % to 100 %), it falls in an arc and pierces one enemy; a full draw flashes |
| Staff | Inference Staff, Embedding Rod, Oracle Staff | A short, weak bonk; its implicit adds spell damage and COMPUTE: the weapon for casters |
| Gun | the five guns | As now (context heat) |

Melee and bows use no heat. Tags decide what stats apply: melee (sword, axe, staff), projectile (bow, gun),
attack (every weapon). New voxel models (`WeaponSprite`, like `GunSprite`), a swing trail, arrows (a `Bullet` kind
with gravity), synthesized sounds.

**Skills.** Skill gems drop as items (1 x 1, drawn as a little SKILL.md page in its tag's colour; kind "skill"):
**active skills** and **Hooks** (support gems). The inventory window gets a SKILLS page (beside the stats and the
stash): four slots, each one skill and up to two Hooks that change it. The slots are cast with **1-4** (they do
nothing in the endgame now, where the equipped item decides the gun), aimed with the mouse like the gun. A gem
levels up (1-20) with the XP Clawd earns while it is slotted; its level raises its damage and effect and needs a
character level. The HUD shows a skill bar (the four, their keys, cooldown sweeps, dim without COMPUTE).

- **COMPUTE**: a blue bar under the life bar, maximum about 50 + 2 a level, regenerating a few per cent a second;
  every skill costs some, some have a cooldown too. Gear, the tree and staves add maximum COMPUTE, its
  regeneration and lower costs. "NOT ENOUGH COMPUTE" when short.
- **Spells** (their own base damage by gem level, `spell_damage`, cast speed, no weapon needed):

  | Skill | PoE's | What it does |
  |---|---|---|
  | Overheat Bolt | Fireball | A projectile that bursts in a small area; Overheat, ignites |
  | Voltage Arc | Arc | A bolt that chains from enemy to enemy (3); Voltage, shocks |
  | Cold Cache | Frost Nova | A ring around Clawd; Latency, chills and freezes |
  | Prompt Injection | Essence Drain | A slow projectile that corrupts: Corruption damage over time |
  | Rate Limit Strike | Lightning Strike from the sky | Marks the aimed spot; a bolt falls there 0.6 s later |
  | Spawn Subprocess | Summon Raging Spirits | Two or three flying minions that seek enemies for a while |
  | Context Switch | Flame Dash | Blinks a short way towards the aim, through enemies (a cooldown) |
  | Guardrail | Steelskin | A shield that takes the next hits up to an amount for 4 s (a cooldown) |

- **Attacks** (the weapon's damage and speed, they need its class):

  | Skill | Needs | What it does |
  |---|---|---|
  | Gradient Slam | sword, axe, staff | A slam: a shockwave runs along the ground both ways |
  | Batch Spin | sword, axe | Hold to spin, moving, hitting all around (Cyclone) |
  | Beam Search | bow | A fan of arrows (Split Arrow) |
  | Token Rain | bow | Arrows rain over the aimed area (Rain of Arrows) |

- **Hooks** (support gems, they fit the skills with the right tags): Parallel (+2 projectiles, less damage each),
  Pierce, Chain (+1), Wider Context (bigger area), Concentrated (more damage, smaller area), Added Overheat /
  Latency / Voltage (a share of the damage added as the element), Low Latency (faster cast and attack), Efficient
  (lower cost), Retry (a spell repeats once, weaker), Gradient Hook (leech from the skill's hits).
- **Stats and drops**: new stats `spell_damage`, `melee_damage`, `projectile_damage`, `cast_speed`, `area`,
  `projectiles`, `compute`, `compute_regen`, `cost`, `skill_levels` (+n to the gems' levels); affixes for them on the
  new bases and on gear (staves spell damage, cores +1 to skill levels ...); the prompt tree gets nodes for them
  (a ninth sector or branches; adding nodes refunds nothing). Weapon bases of the new classes and gems drop only
  in maps (gems about as often as an orb), the vendor sells a few level-1 gems; the first visit to the hideout after
  E14 gives two (Overheat Bolt and Context Switch), like the device's first map.
- **Code** (proposals): `Weapons` and `Items.BASES` get classes; `scripts/melee.gd` (swings, combo, pogo, cutting
  shots), `scripts/bow.gd` (drawing, arrows); `scripts/skills.gd` (`Skills`: the gems' table, levels, costs,
  formulas, casting) with an effect script per skill where it needs one; `Progress.skills` (the four slots: a gem
  and two Hooks each, items with their XP); `Player.compute`; the HUD's skill bar and COMPUTE bar; the inventory's
  SKILLS page. Checks: `tools/checks/weapons.gd`, `tools/checks/skills.gd`.
- **Risks**: melee in a platformer is short and dangerous (contact damage): the pogo, cutting shots and leech have
  to make it worth it, and the playtest decides. Many new effects to draw readably at 480 x 270. The balance of
  three ways to play (guns, melee, spells) is E14.7's work.

## Milestones

- [x] E0 The interview and this plan.
- [x] E1 Character level: XP, levels, area levels, points from levels in the tree, the HUD bar, checks, README.
      Campaign area levels are 1 + 2n in play order (3-B 27); the campaign ends at about level 13.
- [x] E2 Items and stats: the item model, bases, affix tables, rarity, the stat model, numeric HP in the endgame,
      drops on the ground and pickup, checks, README. Items drop in the campaign too, E picks them up (next weapon
      moved to R), one equipped weapon item is the gun Clawd holds (the user's calls). HP: 50 + 5 a level, enemy
      hits 8 x 1.06^area level, PoE's armour, evasion as a chance; `Main.endgame` turns it on (nothing does yet).
- [x] E3 Inventory and stash: the grid UI, equipping, tooltips with comparison, the stash, `items.json`, checks.
      I opens it (in a level it pauses, without the stash; from the map with it, until the hideout has a chest);
      the weapons found before items are normal items in the stash.
- [x] E4 The hideout: the room, the stash, the vendor, the terminal, the entry from the world map. The vendor
      sells a stock of ten items that comes anew after every level cleared; the stash stays on the map too.
- [x] E5 Maps: chunks of world 1, the generator and its check, map items and mods, the Map Device, portals, the
      map boss, maps dropping maps (T1-T5). **The vertical slice ends here: a first playtest.** The boss is THE
      OVERFITTER (a giant shield bot); the device gives a T1 map when there is none; an open map lives in memory
      only (quitting the game gives it up); enemy hits grow 1.045^area level (was 1.06).
- [x] E6 Currency orbs: drops, stacks, using them on items and maps. The eight orbs of the table above, in a pouch
      of their own shown in the inventory window (not in its grid), picked up on touch, used by clicking the orb
      and then the item (it stays on the cursor).
- [x] E7 Damage types, resistances and ailments on enemies, gear and map mods. Ailments work both ways (ignite,
      chill / freeze, shock); resistances drop 5 % a map tier; Corruption resistance from item level 20.
- [x] E8 Chunks of worlds 2 and 3, tiers up to T16, the Atlas screen and its points. The user's calls
      (2026-10-18): tiers in bands by world (T1-5 world 1, T6-10 world 2, T11-16 world 3); a set of chunks per
      world, the map's theme (palette, motif, music) one of that world's levels'; new giant bosses made from
      enemies (world 2 THE JAILBREAK, an injector; world 3 THE INFINITE LOOP, a Retry Loop; Codex and the Router
      stay for the pinnacle); a small Atlas tree (22 nodes) with a point per new tier and per world's first rare
      map (19). Area levels grow 2 / 3 / 4 a tier by world (T16 79, so the top affix tiers drop), enemy life
      x1.045 a level past area level 40; maps drop no higher than the open tier; the hideout has a globe for the
      Atlas, Tab switches it with the prompt tree.
- [x] E9 The prompt tree grows to ~120 nodes for levels up to 100, new keystones. The user's calls (2026-10-18):
      a new tree from scratch (an old save's points come back once), endgame stats plus a few new mechanics (per
      cent life / armour / evasion, elemental resistances, regeneration of life, leech, ailments on enemies likelier
      and longer, avoiding them on Clawd), four new keystones (Temperature 0., Air-gapped., Gradient Leech.,
      Robustness.; You are an expert. and Orchestrator. stay), refunds stay free. 137 nodes in eight sectors with
      an outer ring; 129 points at level 100 with every spark and bought point. The window got a small map and a
      list of the totals.
- [ ] E10 Delirium fog.
- [ ] E11 Breaches.
- [ ] E12 Pinnacle bosses and uniques.
- [ ] E13 Balance pass, docs.
- [ ] E14 Weapon classes and skills (*Weapon classes and skills* above; asked for on 2026-10-18, before E10-E13):
  - [x] E14.1 Weapon classes: `class` on the bases, the new bases drop only in maps, the hand handing attacks to
        a class; swords and axes (the arc, the combo, the pogo, cutting shots, the cleave), their models, sounds,
        checks. Done: `Weapons.MELEE`, `scripts/melee.gd`; base item levels 30 / 46 / 62; an axe's swing is a whole
        circle; the HUD shows the class and the sword's combo.
  - [ ] E14.2 Bows and staves: drawing, arcing arrows that pierce; the staff's bonk and its spell stats.
  - [ ] E14.3 COMPUTE and the skill system: the bar, gems as items, the inventory's SKILLS page, four slots on 1-4,
        the HUD's skill bar, gem XP and levels; the first skills: Overheat Bolt, Context Switch, Gradient Slam.
  - [ ] E14.4 The other skills: Voltage Arc, Cold Cache, Prompt Injection, Rate Limit Strike, Spawn Subprocess,
        Guardrail, Batch Spin, Beam Search, Token Rain.
  - [ ] E14.5 Hooks (support gems).
  - [ ] E14.6 Stats: affixes for the classes, spells and COMPUTE; the prompt tree's new nodes; gems at the vendor.
  - [ ] E14.7 A playtest and balance of guns, melee and spells.

## Added beyond the plan

- After the first playtest of the slice (2026-10-16, "too easy, drops ok, the token flight drags"): enemy hits
  11 x 1.045^area level (was 8), maps' enemy life 1.08^(area level - 24) (was 1.05), 80 % of the slots filled (was
  65 %), the map boss 40 x a shield bot's life (was 25); tokens fly to the HUD in 0.3 s with at most 0.15 s of
  stagger, and past six waiting the next ones join the last flight.
