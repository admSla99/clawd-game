# Port plan: all levels, shooting and weapons

Goal: every level of the TS game (`src/world/levels/`, 1-1 … 2-B) playable in the Godot 2.5D port, with its
enemies, level features, bosses, a scenery motif per theme, and world 2's shooting and weapons. World 1, shooting,
the world-2 enemies and 2-1 are done (M0-M7, see `../README.md`). Tick the boxes in the commit that finishes a task.

## Decisions (interview, 2026-10-12)

- **Order**: world 1 level by level, then shooting, then world 2 level by level. The game stays playable after
  every milestone.
- **Scenery**: every theme gets its own motif from `scenery-themes.md` on top of the neural forest, through the
  `Scenery` layers, the theme palette and `shaders/scenery.gdshader`.
- **Darkness (1-2)**: real 3D light, not a 2D overlay. Terrain and scenery go dark, Clawd carries a light, and
  sparks, checkpoints and lanterns glow on their own.
- **Full jump only**: when a TS map does not work with it, use a Godot-only map override (like
  `levels/overrides.json` for texts). The TS maps and their reachability tests stay unchanged.
- **Aiming**: as in TS. The mouse aims through a dotted crosshair on the gameplay plane (z = 0), X shoots and ↑ / ↓
  tilt the aim without a mouse. (A gamepad was planned here; in M5 the user decided against it.) World 2's sign
  texts stay.
- **Weapons**: as in TS. Hallucination (1-B) drops the Token Blaster, world 2 is armed, and the shop's ARMORY
  (4 weapons + Bigger Model / Faster Inference / Longer Context) unlocks after 1-B.
- **Token drops**: every enemy drops its TS amount × 5, like the bug (2 → 10). Shop prices stay as in TS.
- **Look of shooting**: a voxel gun in Clawd's hands (from the TS sprite), glowing voxel bullets, a GlowLight on
  big ones (orb, beam), a muzzle flash and spark bursts on hits.
- **Bosses**: TS behaviour 1:1 (attacks, phases, HP) with a 2.5D look: a big voxel model and an arena that uses
  depth and lights.
- **Rhythm**: within a milestone, work on my own (checks, screenshots, README, commit + push after each task).
  Stop at the end of each level / milestone so the user can play it.
- **Visual checks**: throwaway capture scripts of the real window, not the editor over MCP.

## Spawns still to port

Every spawn is ported except the boss Codex (`B` in 2-B, M11): all levels are converted and their enemies work,
so 2-2, 2-3 and 2-4 can already be played (without their motifs); 2-B has no boss yet, so it cannot be finished.

| Level | Theme | Spawns (all ported) | Feature |
|---|---|---|---|
| 2-2 | forge | `Y` ×5, `D` ×3, `R` ×3, `H` ×2, `T` ×1 | armed |
| 2-3 | swamp | `F` ×4, `D` ×1, `I` ×8, `T` ×1, `H` ×1 | armed |
| 2-4 | towers | `H` ×3, `D` ×4, `T` ×4, `F` ×2 | armed |
| 2-B | codex | `B` Codex (**not ported**) | world 2 clear |

## Every level: definition of done

1. `node godot/tools/export_levels.mjs` (repo root; `git checkout` the `.txt` files that only changed line
   endings), then `convert_level.gd -- <id>`.
2. All spawns of the level ported. Full-jump fit checked; a map override is added if needed.
3. The theme's scenery motif.
4. A check section in `tools/checks/<id>.gd` (template: `tools/checks/2-1.gd`): the level loads, its spawns
   match the map, its motif is up, full jumps fit, and its features work.
5. Screenshots of the real window (start, features, enemies, exit). Fix what they show.
6. `godot/README.md` updated, commit + push, then **stop for the user's playtest**.

## Parallel work (M8-M11)

M8, M9, M10 and M11 touch different levels and can run at the same time in separate worktrees of `godot-2.5d`.
M12 waits for all of them. Rules, so they never edit the same lines:

- A motif is found by its file name: `shaders/motif_<theme>.gdshader` (a background ColorRect shader, uniforms as
  in `motif_mesa.gdshader`) or `scripts/<theme>_motif.gd` (3D objects among the scenery, like
  `window_motif.gd`). Don't register it anywhere: `main.gd` needs no change for a motif.
- Checks go into `tools/checks/<id>.gd` only (with its `.uid`), not into `tools/check.gd`.
- Docs: only your level's section under *World 2 levels* in `godot/README.md` (it may list your new files there;
  don't add Layout rows or edit the *Checks* paragraph) and only your milestone's boxes in this file. Don't edit
  `CLAUDE.md`, `docs/scenery-themes.md` or *Added beyond the plan*; M12 brings them up to date.
- Shared scripts (`main.gd`, `enemy.gd`, `scenery.gd`, `hud.gd`, `overlay.gd`, ...): change them only when the
  level really needs it, in small, separate hunks. M11 (Codex) is the one expected to change `main.gd`
  (`_spawn_boss()`, `boss_defeated()`, the results) and `hud.gd` (the boss bar's name).
- Capture scripts: `tools/_capture_<id>.gd`, with `user://progress_capture_<id>.json` and screenshots in
  `%TEMP%/clawd_cap_<id>/`; delete the script and its `.uid` before committing.
- Before pushing: `git fetch`, `git rebase origin/godot-2.5d`, run `tools/check.gd` again, then push. Never force.

## Tasks

### M0 Groundwork
- [x] This plan, linked from `CLAUDE.md`.
- [ ] Godot-only map overrides in `export_levels.mjs` (only once a level needs one; none so far).
- [x] Generic per-level check in `tools/check.gd`: every converted level loads, has a start and a goal, and its
      spawn counts match its `.txt`.
- [x] All nine levels re-converted with every spawn ported so far.

### M1 Enemy base and world-1 enemies
- [x] `enemy.gd`: port `Enemy` (`src/entities/entity.ts`): hp, `hit(damage)`, stomp / spin / pound handling,
      token drop × 5, death burst. Move `bug.gd` onto it.
- [x] `Shot` (enemy projectile) and `F` SpamBot (`src/entities/enemies.ts`), voxel model, sounds; re-convert
      1-1 (its `F`).
- [x] `R` RateLimiter: 2×2 "429" crusher that drops when Clawd is below and rises slowly; its top is walkable.

### M2 1-2 Gradient Caves
- [x] Convert; spawns `R` `F`.
- [x] `dark`: darkness in the terrain / scenery / decor shaders, Clawd's light, glowing sparks, checkpoints and
      lanterns; the cave fog colour (TS clears to `#111111`).
- [x] Caves motif: the inverted loss landscape.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M3 1-3 Context Window
- [x] Convert; spawns `F` `V`.
- [x] `risingVoid`: the rising null (delay, speed, kill, reset at checkpoints, the camera), drawn in 2.5D across
      the block depth.
- [x] Window motif: floating text windows that crumble into pixels.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M4 1-B The Hallucination
- [x] Arena; port `src/entities/boss/hallucination.ts` (attacks, phases, HP, teleports) as a big voxel model.
- [x] Boss HP bar in the HUD; sounds `bossHit`, `bossTeleport`.
- [x] `WeaponPickup` (`src/entities/pickups.ts`): the blaster drop, `weaponGet`, saved in `Progress`.
- [x] "WORLD 1 CLEAR!" results; the map unlocks world 2.
- [x] Glitching-forest motif.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M5 Shooting and weapons
- [x] `weapons.gd`: port `src/weapons.ts` (5 weapons, gun upgrades, loadout from `Progress`).
- [x] `gun.gd`: port `src/entities/gun.ts` (fire rate, spread, pellets, context heat and overheat).
- [x] `bullet.gd`: port `src/entities/bullets.ts` (5 kinds, pierce, splash, hits on terrain, enemies and `X`
      blocks) as glowing voxels with lights.
- [x] Aiming: mouse onto the z = 0 plane through the oblique camera, ↑ / ↓ keys; a dotted crosshair instead of
      the cursor; Clawd faces the aim. (No right stick: the user decided against gamepad support.)
- [x] Armed Clawd: voxel gun, muzzle flash (`drawArmedExtras`).
- [x] HUD: context heat bar and weapon label. Weapon switching: `prev` / `next` / slot keys in `Settings` and
      the keybind menu.
- [x] Sounds `shoot`, `gunToken`, `gunPellet`, `gunGlyph`, … in `Sound.PRELOAD`.
- [x] Shop: unlock the ARMORY after 1-B (weapons, Bigger Model, Faster Inference, Longer Context, equip).
- [x] Check sections (fire rate, heat, damage, pierce, splash, aim), screenshots in 2-1, README, commit + push
      → **playtest**.

### M6 World-2 enemies (each with check section and voxel model)
- [x] World 2's "tough" HP (`spawnEntities()` in `src/scenes/game.ts`): bugs 2, spam bots 3. Done early, with
      the health bars (see *Added beyond the plan*).
- [x] `T` Turret and `Y` ceiling turret (`src/entities/enemies2.ts`).
- [x] `D` Drone.
- [x] `H` ShieldBot (shield that blocks shots from the front).
- [x] `I` Injector.

### M7 2-1 Merge Conflict Mesa
- [x] Convert, spawns, armed start, sign texts. Mesa motif: diff strata with conflict-marker seams. Full jumps
      fit (no override: no ceilings or spikes; the check drives the pit and the corrupted pocket); the TS sign
      texts match the port's controls.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M8 2-2 GPU Forge
- [x] Convert, spawns. Forge motif: server racks and GPU monoliths (embers already exist). Full jumps fit (no
      override: the ceiling is high everywhere; the check drives both spike beds, the rate-limiter nook and the
      corrupted pocket); the TS sign text is kept. Pickups no longer miss while Clawd blinks after a hit.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M9 2-3 Prompt Injection Swamp
- [x] Convert, spawns. Swamp motif: corrupted data pools and text bubbles. Full jumps fit (no override: no
      ceilings; the check drives the pillar pits, the one-way steps, the spike bed on its moving platforms and
      the corrupted pocket). Injectors out of range no longer flatten until their mesh fails.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M10 2-4 The Diff Towers
- [x] Convert, spawns. Towers motif: transformer stacks with light in the residual stream. Full jumps fit (no
      override: no ceilings or spikes; the check climbs the whole level); one-way landing fixed in `player.gd` for
      platforms two rows apart.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M11 2-B Codex
- [x] Arena; port `src/entities/boss/codex.ts` as a big voxel model; "CODEX HAS BEEN DEPRECATED", "WORLD 2
      CLEAR!" and the last level's results text ("THANKS FOR PLAYING!", `results.ts`).
- [x] Codex motif: code monoliths with scrolling code.
- [x] Check section, screenshots, README, commit + push → **playtest**.

### M12 Finish
- [x] Full playthrough title → 2-B (the user, 2026-10-12; the bugs it found are fixed after M12); balance check
      of token income vs. ARMORY prices (with 5× tokens and 3× hp): a full clear brings ~175 tokens in world 1 and
      ~1190 in world 2 against 750 + 2880 for everything, so one run buys about two world-1 upgrades and a weapon
      or mod per world-2 level, everything takes about two more runs of world 2 (*Shop* in `godot/README.md`). TS
      prices stay; the Spark Radar costs 80 tokens and no sparks (3 sparks made the spark prices 38 against the
      levels' 35, so nobody could buy everything) and Double Tokens 100 (at 50 it paid back ~5× per world-2 run).
- [x] `CLAUDE.md` "Godot port status", `docs/scenery-themes.md` and `godot/README.md` (Layout rows, *Checks*)
      brought up to date after the parallel milestones.
- [x] Small TS details still missing: Clawd holds his gun on the world map in world 2 (`levelSelect.ts`; its
      comment says so but its code draws him unarmed, so the port draws the equipped weapon in his hands).

## Added beyond the plan

Things the user asked for on top of the TS game and the tasks above, so we know they were extras:

- [x] **Damage numbers** (after M5, 2026-10-12): every hit that lands on an enemy shows its damage over it,
      rising and fading (`Overlay.damage_number()`); quick hits on the same enemy within 0.12 s add up in one
      number (beam, stream, a spread's pellets), the killing blow's number is light orange.
- [x] **Enemy health bars** (after M5, 2026-10-12): hidden at full health; once hurt, a bar over the enemy
      (12-24 px, red hit points, the ones just lost in light draining away). Not on bosses (the HUD bar) or
      projectiles (`Overlay.show_bar()`).

- [x] **Three times the hit points** (2026-10-12): every enemy has `Enemy.HP_FACTOR` (3) × its TS hp, set in
      `Main.load_level()` (bosses and projectiles keep theirs). World 1: bugs and spam bots 3 (a stomp or a spin
      still kills, the jet takes three hits); world 2: bugs 6, spam bots 9.
- [x] **Map card fix** (2026-10-12): CLEARED and ARMED overlapped on world-2 cards, and 2-3's name ran out of
      the card: the card is wider, its bottom row is laid out left to right, and a name too long for twice the
      size is drawn at the normal size.
- [x] **A heart per 300 tokens** (M12, 2026-10-13): TS gives one per 100 (`Main.TOKENS_PER_HEART`); with 5× tokens
      that made 2-3 extra hearts in every world-2 level.
- [x] **Platforms are cover** (bug list, 2026-10-13): Clawd's bullets and the beam stop on one-way planks (from
      either side), moving platforms, rate limiters and fake platforms, not only on solid / corrupted tiles as in
      TS (`Bullet.blocked()`).
- [x] **Readable found sparks** (bug list, 2026-10-13): a spark found on an earlier run is the solid star, smaller
      and muted with a soft glow, instead of TS's dotted star at 55 %, which all but vanished in the port's levels.
- [x] **Crosshair colour** (bug list, 2026-10-13): the crosshair has a dark outline and the colour the player picks
      under CROSSHAIR in the pause menu (white by default; TS's orange is one of the choices), saved in settings.

## Open points (decide when we get there)
- Gamepad: decided in M5, not added (the user's call). The port is keyboard and mouse only.
- Unlocking the shop after 1-1 (port) vs. after 1-B (TS) stays; only the ARMORY row waits for 1-B.
