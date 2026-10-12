# Port plan: all levels, shooting and weapons

Goal: every level of the TS game (`src/world/levels/`, 1-1 … 2-B) playable in the Godot 2.5D port, with its
enemies, level features, bosses, a scenery motif per theme, and world 2's shooting and weapons. 1-1 is done
(see `../README.md`). Tick the boxes in the commit that finishes a task.

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
  tilt the aim without a mouse, and the right stick aims on a gamepad. World 2's sign texts stay.
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

| Level | Theme | Unported spawns | Feature |
|---|---|---|---|
| 1-1 | plains | `F` ×1 | |
| 1-2 | caves | `R` ×4, `F` ×3 | `dark` |
| 1-3 | window | `F` ×3 | `risingVoid` (speed 22, delay 4) |
| 1-B | boss | `B` Hallucination | blaster drop |
| 2-1 | mesa | `F` ×2, `D` ×4, `T` ×2, `H` ×2 | armed |
| 2-2 | forge | `Y` ×5, `D` ×3, `R` ×3, `H` ×2, `T` ×1 | armed |
| 2-3 | swamp | `F` ×4, `D` ×1, `I` ×8, `T` ×1, `H` ×1 | armed |
| 2-4 | towers | `H` ×3, `D` ×4, `T` ×4, `F` ×2 | armed |
| 2-B | codex | `B` Codex | world 2 clear |

## Every level: definition of done

1. `node godot/tools/export_levels.mjs` (repo root; `git checkout` the `.txt` files that only changed line
   endings), then `convert_level.gd -- <id>`.
2. All spawns of the level ported. Full-jump fit checked; a map override is added if needed.
3. The theme's scenery motif.
4. A `tools/check.gd` section: the level loads, its spawns match the map, and its features work.
5. Screenshots of the real window (start, features, enemies, exit). Fix what they show.
6. `godot/README.md` updated, commit + push, then **stop for the user's playtest**.

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
- [ ] Arena; port `src/entities/boss/hallucination.ts` (attacks, phases, HP, teleports) as a big voxel model.
- [ ] Boss HP bar in the HUD; sounds `bossHit`, `bossTeleport`.
- [ ] `WeaponPickup` (`src/entities/pickups.ts`): the blaster drop, `weaponGet`, saved in `Progress`.
- [ ] "WORLD 1 CLEAR!" results; the map unlocks world 2.
- [ ] Glitching-forest motif.
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M5 Shooting and weapons
- [ ] `weapons.gd`: port `src/weapons.ts` (5 weapons, gun upgrades, loadout from `Progress`).
- [ ] `gun.gd`: port `src/entities/gun.ts` (fire rate, spread, pellets, context heat and overheat).
- [ ] `bullet.gd`: port `src/entities/bullets.ts` (5 kinds, pierce, splash, hits on terrain, enemies and `X`
      blocks) as glowing voxels with lights.
- [ ] Aiming: mouse onto the z = 0 plane through the oblique camera, ↑ / ↓ keys, right stick; a dotted crosshair
      instead of the cursor; Clawd faces the aim.
- [ ] Armed Clawd: voxel gun, muzzle flash (`drawArmedExtras`).
- [ ] HUD: context heat bar and weapon label. Weapon switching: `prev` / `next` / slot keys in `Settings` and
      the keybind menu.
- [ ] Sounds `shoot`, `gunToken`, `gunPellet`, `gunGlyph`, … in `Sound.PRELOAD`.
- [ ] Shop: unlock the ARMORY after 1-B (weapons, Bigger Model, Faster Inference, Longer Context, equip).
- [ ] Check sections (fire rate, heat, damage, pierce, splash, aim), screenshots in 1-1, README, commit + push
      → **playtest**.

### M6 World-2 enemies (each with check section and voxel model)
- [ ] World 2's "tough" HP (`spawnEntities()` in `src/scenes/game.ts`).
- [ ] `T` Turret and `Y` ceiling turret (`src/entities/enemies2.ts`).
- [ ] `D` Drone.
- [ ] `H` ShieldBot (shield that blocks shots from the front).
- [ ] `I` Injector.

### M7 2-1 Merge Conflict Mesa
- [ ] Convert, spawns, armed start, sign texts. Mesa motif: diff strata with conflict-marker seams.
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M8 2-2 GPU Forge
- [ ] Convert, spawns. Forge motif: server racks and GPU monoliths (embers already exist).
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M9 2-3 Prompt Injection Swamp
- [ ] Convert, spawns. Swamp motif: corrupted data pools and text bubbles.
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M10 2-4 The Diff Towers
- [ ] Convert, spawns. Towers motif: transformer stacks with light in the residual stream.
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M11 2-B Codex
- [ ] Arena; port `src/entities/boss/codex.ts` as a big voxel model; "WORLD 2 CLEAR!".
- [ ] Codex motif: code monoliths with scrolling code.
- [ ] Check section, screenshots, README, commit + push → **playtest**.

### M12 Finish
- [ ] Full playthrough title → 2-B; balance check of token income vs. ARMORY prices.
- [ ] `CLAUDE.md` "Godot port status" and `godot/README.md` brought up to date.

## Open points (decide when we get there)
- The port reads no gamepad yet (no joypad events in `project.godot` or `scripts/`). Right-stick aiming needs
  basic gamepad input first (move, jump, spin, shoot, menus); decide in M5 whether to add it there or later.
- Unlocking the shop after 1-1 (port) vs. after 1-B (TS) stays; only the ARMORY row waits for 1-B.
