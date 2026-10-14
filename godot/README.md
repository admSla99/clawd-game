# CLAWD — the Godot 2.5D game

CLAWD in Godot 4.7.2, in 3D with a side camera (2.5D): all nine levels of worlds 1 and 2, both bosses, shooting
and the shop, playable from the title to the end of 2-B; world 3 is planned in `docs/world3-plan.md`. GDScript;
Forward+ renderer on desktop, Compatibility (WebGL 2) on the web export.

The game began as a port of a TypeScript browser game (`src/`, `tests/`), which is kept on the `ts-legacy` branch
and is no longer developed; the 2D port is on the `godot-2d-port` branch. Scripts that port TS code still name the
TS file or function they come from (`src/...` paths refer to that branch), and `docs/port-plan.md` is the
finished plan of the port. This repository is the game now: new levels and features are made here directly.

## Setup on a new machine (Linux x86_64)

```bash
cd godot
./tools/install_godot.sh                                # editor + web export templates (resumes if cut off)
godot --headless --script tools/build_meshlib.gd        # regenerates tiles/terrain_meshlib.tres
godot --headless --script tools/convert_level.gd        # levels/*.txt -> levels/*.tscn
godot --headless --import                               # first import, creates .godot/
godot --editor --path .
```

`install_godot.sh` downloads from the official GitHub release and checks the files against its
`SHA512-SUMS.txt`. It installs:

| What | Where |
|---|---|
| Editor binary | `~/.local/opt/godot/4.7.2-stable/godot`, linked as `~/.local/bin/godot` |
| Web export templates | `~/.local/share/godot/export_templates/4.7.2.stable/` |

The templates archive is ~1.3 GB (all platforms); the script keeps only the `web_*` templates.
Re-running the script skips anything already installed. To change version, edit `VERSION` in the script
and `config/features` in `project.godot`.

On macOS or Windows, download the editor and `export_templates.tpz` for 4.7.2 from
<https://godotengine.org/download/archive/4.7.2-stable/> and install the templates via
*Editor → Manage Export Templates → Install from File*.

The game uses only built-in Godot features (GridMap, GDScript). The `addons/godot_ai` editor plugin
([godot-ai](https://github.com/hi-godot/godot-ai) 4.3.0) lets Claude Code drive the editor and the running game
over MCP; `../.mcp.json` registers its server for this project. It needs `uv` (`uvx`) and a GUI editor, as it does
not start in `--headless` mode. Its `_mcp_game_helper` autoload also runs in exported builds.

## Levels

A level is an ASCII map, `levels/<id>.txt` (one map row per line, 16 px per character), plus its entry in
`levels/index.json`; both are edited by hand (they were exported from the TS game's `src/world/levels/*.ts`). After
changing a map, convert it and check that it can be completed:

```bash
godot --headless --script tools/convert_level.gd -- 1-1   # levels/<id>.txt -> levels/<id>.tscn; ids optional, none = all
godot --headless --script tools/reach.gd -- 1-1           # its exit, sparks and sub-agents are reachable
```

Map legend:

| Character | What |
|---|---|
| `#` `=` `^` `X` | Tiles: rock, one-way platform, spikes, corrupted (ground-pound or blast it) |
| `@` `G` `C` `?` | Start, exit, checkpoint, sign (texts in `signs`, in map order) |
| `o` `S` `A` | Token, spark, sub-agent |
| `+` · `*` | Anchor for the Tool Call · timeout anchor (world 3) |
| `1`-`9` · `a`-`i` `z` | Pressure plate (a run of one digit is one plate) · gate (all cells of a letter; `a` opens with plates `1`, ...; `z` with the Retry Loops gone) |
| `P` | Parser (world 3) |
| `W` | Webhook (world 3), a flying anchor |
| `%` · `L` | Brittle crate · Retry Loop (world 3) |
| `M` `V` | Moving platform, horizontal / vertical |
| `E` `F` `R` | Bug, spam bot, rate limiter (2×2, hangs from its top-left) |
| `T` `Y` `D` `H` `I` | Turret on the floor / under the ceiling, drone, shield bot, injector |
| `B` | Where `Main` places the level's boss |

`index.json` lists the levels in play order (each one unlocks the next): `id`, `world`, `name`, `subtitle`,
`theme` (palette, scenery and motif), `music`, `signs`, the optional `dark`, `risingVoid` (`speed` px/s, `delay`
s), `boss` (`hallucination`, `codex`), `plateHold` (seconds a plate of a digit stays pressed, `{"1": 3.0}`) and
`subAgents` (the level is made for sub-agents: `tools/reach.gd` lets Clawd stand on one), `index` (its position) and `terrainSeed` (`7 + index * 13`).

`convert_level.gd` runs `Level.build()` (`scripts/level.gd`): it places the tile characters
(`#` `=` `^` `X`) as GridMap cells and adds a child per spawn:
`@` → `Start` marker, `E` → `scenes/bug.tscn`, `o` → `scenes/token.tscn`, `C` → `Checkpoint`, `G` → `Goal`,
`?` → `Sign` (numbered in map order like `Spawn.index`), `M` / `V` → `MovingPlatform`, `A` → `SubAgent`,
`S` → `Spark` (both numbered like the signs), `F` → `SpamBot`, `R` → `RateLimiter`, `T` / `Y` → `Turret`
(on the floor / under the ceiling), `D` → `Drone`, `H` → `ShieldBot`, `I` → `Injector`, `B` → a `Boss` marker
(`Main` puts the level's `boss` there). Every spawned node keeps
its map character in the meta `spawn`. Other characters are skipped (tools/check.gd lists them per level).
The result is saved as `levels/<id>.tscn`.

`tools/reach.gd` replaces the TS game's `tests/reachability.test.ts`: from every place Clawd can stand it tries
walks and jumps with and without hover (every jump a full one, on a tile model of `scripts/player.gd` that reads
its constants) and reports the exit, sparks and sub-agents it can't reach. Enemies are ignored, moving platforms
and rate limiters are sampled as static platforms along their path, corrupted blocks count as pounded through,
and boss levels are skipped. Every level takes 5-12 s.

One tile is 1 m; tile `(x, y)` of the map fills `x..x+1` × `-(y+1)..-y`, so the level's top-left corner is the
origin and y points up. Blocks are 3 m deep, centred on the gameplay plane z = 0. One-way platforms (`=`) sit in
their own `OneWay` GridMap on physics layer `oneway`; the player collides with that layer only while falling with
its body clear of the platform.

## Running

The game starts in `scenes/main.tscn` on the title screen; Space opens the world map, which plays a level
(see Title and world map). `Main.start_mode = Mode.PLAY` with `Main.start_level` skips straight into a level
(tools/check.gd does). In a level **N** loads the next one (wrapping after 2-B).

Gameplay ported so far: run, jump, coyote time, jump buffer, hover, corner correction, spin,
ground pound and drop-through from `src/entities/player.ts`. Unlike the TS player every jump is a full jump
(about 4.4 tiles): letting go of jump early does not cut it (`JUMP_CUT_MULT` is gone); spikes knock Clawd back and cost a heart; bugs
patrol, turn at walls and ledges, hurt on contact and die when stomped, spun, pounded or hit by the hover jet;
tokens are collected on touch. A defeated enemy drops five times its TS tokens (`Enemy.TOKEN_FACTOR`; a bug or a
spam bot 10 instead of 2): `Token.pop()` makes
popped tokens that burst out of its middle with a random sideways speed, fall under gravity, and over 0.6 s turn
into a 260 px/s flight to Clawd (`Token._home()`, after `Token.update()` for a free token); they can be picked
up only after 0.3 s, so the burst is seen even when Clawd stomps from right above. The level's token total
(results panel) counts the map's tokens plus what every enemy drops. Like `Level.tile()` in TS, the columns left and right of
the map are solid: `Level` adds two invisible walls (`SideWalls`, physics layer 1) at its edges, so Clawd and
the bugs stop there instead of walking off the start, and `Level.tile()` returns solid outside the map.

### The rising void

Levels with `risingVoid` (1-3: speed 22, delay 4) get a `RisingVoid` (`scripts/rising_void.gd`, from
`updateVoid()` / `drawVoid()` in `src/scenes/game.ts`), made by `Main.load_level()` as a child of the level. Its
top starts 40 px below the level and after the delay rises at `speed` px/s, never more than 14 tiles below
Clawd; it waits while the world is frozen, once the level is complete and while Clawd is parked. When his
feet are 4 px into it he falls out (`Player.fall_out()`, shared with falling off the level's bottom: a heart,
back to the checkpoint), and on every respawn (`die` / `fell` events) `Main` puts it 10 tiles below the
checkpoint with a 2 s grace. It is a slab across the level, 4 m deep so it swallows the 3 m blocks, drawn by
`shaders/void.gdshader`: near-black, its front's top edge waving by 3 px with red / purple / grey 2 px bits
every 4 px (re-rolled 15 times a second) and grey specks below, its top face a band of dark null with
flickering bits; bits fizz up from its surface around the view, and "NULL ▲ RISING" blinks in red 16 px
below its edge (kept in the view, drawn by `Overlay`).

### The Hallucination (1-B)

`Main._spawn_boss()` puts the level's `boss` (`hallucination`) at its `Boss` marker, like the `boss` spawn in
`spawnEntities()`: centred half a tile above the marker's bottom, over the first solid floor below it
(`Level.floor_below()`), in an arena as wide as the level. `Hallucination` (`scripts/hallucination.gd`, from
`src/entities/boss/hallucination.ts`) is an `Enemy` with 3 hp that is untouchable except while dazed: intro
(2.2 s, fading in under its name), then attacks in turn: radial bursts of white shots (8 + 2 per phase, two or
three volleys), a rain of red shots from the top of the view onto blinking floor warnings (6 + 2 per phase,
one under Clawd), fake platforms with a ring of 10 cyan shots. After each attack it sinks to the floor dazed
for 2.8 s (less each phase): any hit then (stomp, pound, spin, jet) takes one hit point (bossHit, shake,
hitstop, a burst), it shudders, vanishes and teleports to one of three anchors away from Clawd; the phases
speed it up by 25 % each. Its last hit point starts a 2.2 s death of bursts, then `Main.boss_defeated()`:
"THE HALLUCINATION HAS BEEN GROUNDED", the shots vanish, the map tune plays and the Token Blaster drops in the
middle of the arena. Drawn as the 2D rings of 2 px dots (radius 3 … 15, floor(r × 1.1) dots each, turning
alternately, the outer one wobbling) with a red and a cyan copy 2 px to the sides; each ring rocks in depth
about its own tilted axis, never edge-on. Red eyes at the front flash white before an attack; dazed it shows
crosses and three orange dots orbiting in depth. The HUD shows its name over a bar of one dashed segment per hit
point near the bottom of the view (`Hud._draw_boss_bar()`, `drawBossBar()`).

`FakePlatform` (`scripts/fake_platform.gd`, from `src/entities/platforms.ts`): a hovering slab that looks like a
moving platform without its jets, a platform in the group `platforms`; it fades in, flickers once Clawd stands
on it (`Player` calls `on_stand()`), and dissolves 0.45 s later or after 7 s. As in TS, the boss's three spots
sit just under the arena's one-way platforms.

`WeaponPickup` (`scripts/weapon_pickup.gd`, from `src/entities/pickups.ts`): the gun (`GunSprite`,
`scripts/gun_sprite.gd`: the 2D game's `GUN_SPRITES` as voxel meshes, here at 2 px cells) bobs and turns in a
dithered beam of orange light with rising sparks, a GlowLight and a blinking "?!". Touching it calls
`Main.weapon_found()`: `Progress.grant_weapon()` (owned weapons and the equipped one are saved), weaponGet,
hitstop, a burst, "TOKEN BLASTER ACQUIRED!", and the exit opens 6 tiles right of the arena's middle. A boss
level's results say "WORLD 1 CLEAR" and, on the first clear with the blaster, "TOKEN BLASTER FOUND · WORLD 2
UNLOCKED".

### Enemies

Every enemy extends `Enemy` (`scripts/enemy.gd`, from `Enemy` in `src/entities/entity.ts`), a `CharacterBody3D` in
the group `enemies` with its origin at its feet: `hp` (a float, as gun damage grows by quarters), `size`, the flags `stompable`, `invincible`, `projectile`,
`cancellable`, `consume_on_hit`, and `tokens`. `hit(kind, damage)` returns whether the hit landed: it takes hp,
flashes white for 0.12 s (the `tint` instance uniform of `shaders/voxel.gdshader`) and gives 0.3 s of immunity
after a melee hit that did not kill. `die()` pops the tokens, asks `Main.enemy_died()` for the burst, enemyDie,
hitstop and shake, and calls `_die()` for what the subclass leaves behind. `Player` checks the enemies like
`checkEnemies()` in `src/scenes/game.ts`: a stomp (6 damage while pounding, else 4) always bounces, a spin does
3, the hover jet 1 (not projectiles), the pound shockwave 4 (`Main._on_pound_land()`); otherwise the hurtbox hurts
Clawd and a projectile that touches him vanishes.

`Main.load_level()` counts each enemy's `token_total()` for the level's token total (an injector's includes its
two bugs). Enemies that walk or fly through the tiles without physics bodies use `move_x()` / `move_y()` /
`floor_at()`, ports of `moveX()` / `moveY()` / `hasFloorAt()` in `src/world/collision.ts` on their `size` box
(solid and corrupted tiles block, one-way tiles only from above). An enemy with `blocks_direction(dir)` (the shield
bot) stops bullets and beams coming along `dir`: bullets ricochet, beams pass without a hit.

- `Bug` (`E`, `scripts/bug.gd`): see above; a stomp or pound leaves the flattened shell.
- `SpamBot` (`F`, `scripts/spam_bot.gd`): hovers ±26 × ±6 px around its post, faces Clawd and every 2.4 s fires a
  `Shot` at him while he is within 210 px, flickering red for the last 0.4 s. A 20 × 16 px voxel drone at 1 px
  (from `SPAMBOT`): grey body with a rounded rim, blinking antenna, red eyes with glints, a grille and struts.
- `Shot` (`scripts/shot.gd`): enemy projectile, 85 px/s from spam bots, 4 s life, stops on solid tiles, destroyed
  by a spin, vanishes when it hits Clawd; a glowing 5 × 5 voxel cross with a white core and a spark trail.
- `RateLimiter` (`R`, `scripts/rate_limiter.gd`): 2 × 2-tile crusher hanging from its map cell. When Clawd's top
  is below it and less than 9 tiles under its top (within 10 px of its sides), or he stands on it, it shakes
  0.3 s (0.6 s), falls (1800 px/s², at most 520 px/s) onto the first solid or one-way tile, rests 0.9 s (crush,
  dust, a shake near Clawd) and rises back at 55 px/s. It cannot be hurt; its sides and bottom hurt, its top is a
  platform in the group `platforms` like `MovingPlatform` (Clawd rides it; carried up, a ceiling stops him). A
  1.5 m deep block: dark body with studs (bright round the edge), a face plate whose eyes turn red and angry with
  brows, "429", and a chain up to where it hangs. It has its own material so the see-through windows never thin
  it out.

World 2's enemies (`src/entities/enemies2.ts`; the hp below are the TS ones, which the port triples like every
enemy's (`Enemy.HP_FACTOR`), and it drops 5× their tokens):

- `Turret` (`T` floor, `Y` ceiling, `scripts/turret.gd`): 6 hp, 20 tokens, floor ones stompable. Its barrel turns
  towards Clawd's middle at up to 3 rad/s, kept in the upper half-plane on the floor (the lower one on the
  ceiling); every 2.4 s while he is within 250 px it fires three `Shot`s 0.14 s apart at 135 px/s from 10 px out
  of its sensor, the barrel blinking red for the last 0.45 s. A 16 × 12 px voxel dome at 1 px (grey with a lit
  spot, a dark lower half, a red sensor, a base plate; flipped for the ceiling) and a separate barrel turning
  around the sensor on the dome's front (the 2D barrel is behind the dome, which hid it in 2.5D). The underside of
  a ceiling is hidden behind its blocks' front face, so a ceiling turret is drawn bolted to that front face
  (z = 1.5 m + 6 px) and lifted by z / 3, which puts it where it is in play. Own material, like the crusher.
- `Drone` (`D`, `scripts/drone.gd`): 3 hp, 15 tokens, hovers 2 px above its cell's bottom. It bobs ±4 px until
  Clawd's top is within 230 px of its middle, then circles 70 px to one side of him and 46 px above (a spring,
  1.6–2.6 s), aims 0.45 s (its eye flashes red and white), dives at his middle at 270 px/s for 0.55 s (red
  sparks; a wall, floor or ceiling ends the dive flush and bounces it back at 30 %), recovers 0.6 s and circles on
  the other side. An 18 × 13 px quadcopter: a grey shell, a dark lower half with one eye, and thin rotor blades on
  masts 3 px above it that blur between two frames (deep rotor discs showed grey tops that swallowed the shell).
- `ShieldBot` (`H`, `scripts/shield_bot.gd`): 9 hp, 30 tokens. While Clawd is within 260 px (tops within 120 px)
  it walks at 30 px/s towards him until 36 px away, never off a ledge; on the wrong side it stands 0.7 s before it
  turns (its shield blinks grey: the window to hit its back), and every 2.6 s it fires a `Shot` straight ahead at
  125 px/s while he is level with it (40 px). `blocks_direction()`: the shield stops shots coming at its front
  that are not steeper than 1.4 : 1, and flashes white. A 13 × 18 px robot at 1 px (visor with the red eye on the
  side it faces, a seam, 3 × 3 armour plates in two greys from `hash2(i, j, 3)`, stepping feet), a glowing cyan
  shield of seven segments standing across 14 px of depth in front of it, and a glowing "403" above it.
- `Injector` (`I`, `scripts/injector.gd`): 5 hp, 15 tokens. On the ground it waits (0.8–1.4 s, then 1–1.5 s) and,
  while Clawd is within 260 px, hops at him: 330 px/s up and 1.3 × the distance across, at most 110 px/s; a wall
  bounces it back at half speed. Destroyed, it splits into two 1-hp (× 3) bugs (`Bug.speed` 40 px/s) running left and
  right from its feet. A magenta blob with a dark rim, a pale top with a lit spot and a ">_" prompt blinking white
  and pink; like the 2D draw it squashes up to 1.24 × wide before a hop and stretches in the air, as whole-pixel
  sizes (`Injector.mesh(w, h, bright)` builds each).

Checkpoints (`scripts/checkpoint.gd`, `C` in the map): a voxel terminal on a ribbed post, standing 0.6 m
behind the gameplay plane so Clawd walks in front of it. Its 18 x 12 px screen has dark glass 1 px back in the
bezel; off it shows a blinking grey cursor. Touching it (16 x 28 px box against Clawd's hitbox, like the TS
`Checkpoint`) calls `Main.activate_checkpoint()`: Clawd respawns there from now on (falling out, losing the
last heart), the hearts refill, an orange burst and a rising "STATE SAVED" popup play, the bezel turns
orange, the screen shows a glowing "OK" for 1.2 s and then ">_", and a GlowLight warms the ground around it.

The exit (`scripts/goal.gd`, `G`): the 2D gate's ring of 40 light dots on a 12 x 18 px ellipse, turning,
with waves of light orange running round, built every frame as 2 x 2 px voxels 6 px deep; inside a dithered
swirl on whole pixels (`shaders/portal.gdshader`, a quad on the gameplay plane), under it a dark pad with
orange LEDs, a pulsing GlowLight, sparks drifting up and "EXIT" above (Overlay world text). Clawd walks into
it, since it stands on the gameplay plane. Touching its inner 16 x 40 px calls `Main.reach_goal()`: a burst,
Clawd stops (`Player.frozen`) and cheers, drifts to the middle, after 0.6 s stretches into a thin beam and
vanishes, his gun shrinking towards his middle with him (`Gun.shrink`; the gun shows only while his body does);
after 2 s the results panel (sparks, rescued sub-agents, tokens collected / in the level, time, and on a first
clear the level it unlocked) fades in over the level, and jump goes back to the map on the next level. The run is
recorded the moment the exit is touched (`Progress.record_run()`).

Sparks (`scripts/spark.gd`, `S`): `Spark` from `src/entities/collectibles.ts`, the level's rare collectible
(5 in 1-1). `drawSpark()`'s 1 px dots were too faint to spot in the dark levels, so the port draws a solid
star (`Spark.rows()`, 21 x 21 px): a white-hot core, four rays that taper from light orange to a faint tip and
flicker between 7 and 9 px long (drawSpark()'s 3 / 4 dots), short diagonal rays, all glowing strongly (bloom),
bobbing 2 px, in front of a dithered orange halo (`shaders/halo.gdshader`, the 2D glow circle, 15 px and bright
in the middle) that breathes, with a GlowLight and small embers drifting up. Touching it (14 x 14
px box) calls `Main.collect_spark()`: the spark sound, 0.05 s hitstop, a 40-particle burst and "SPARK n/total";
the HUD's spark counter flashes. One found on an earlier run is a ghost, still collectible: the same solid star with
rays 3 px shorter, in muted greyish orange with a soft glow, no halo, light or embers (TS's ghost, drawSpark()'s
dotted star at 55 %, all but vanished in the port's darker, busier levels: bug list #1). The results list the level's sparks one by one (a tick for each found one, NEW under the
first finds), the map card shows found / total and the map's bottom left all sparks found.

Sub-agents (`scripts/sub_agent.gd`, `A`): `SubAgent` from `src/entities/collectibles.ts`, a small Clawd, the 2D
game's 13 x 10 frame at 1 px (`ClawdSprite.frame()`) as a voxel model 6 px deep on the gameplay plane, facing
Clawd and waving (arms up and down), with a "HELP" bubble above it that blinks (Overlay world text). Touching it
(14 x 12 px box) calls `Main.rescue_agent()`: the rescue sound and "SUB-AGENT RESCUED!", it hops for 0.7 s, then
rides a dithered beam of orange light (`shaders/beam.gdshader`) up out of the level at 260 px/s, shedding
sparks, gone after 1.1 s. The HUD counts them, the results show them, and one rescued on an earlier run comes back
as a ghost (tinted `#6E5A52`), still rescuable.

Moving platforms (`scripts/moving_platform.gd`, `M` horizontal, `V` vertical): `MovingPlatform` from
`src/entities/platforms.ts`, 48 x 6 px, swinging 3.5 tiles either way with a 4 s period; each platform in map
order starts 1.3 s further in its swing. They update before the player (`process_physics_priority = -10`). The
player handles them like the TS player: after moving, a falling Clawd whose feet were above a platform's
previous top lands on it (`riding`); at the start of the next frame he is carried by its `dx` and kept on its top;
jumping, getting hurt, bouncing or down + jump (drop-through) leave it. `Player.on_ground` (tile floor or a
platform) replaces `is_on_floor()` for the camera and the poses. They are drawn like the level's one-way ledges:
a white crust with orange LEDs at the ends and along the grey edge, a dark body tapering underneath, two small
flickering orange jets and a GlowLight, snapped to whole pixels.

Signs (`scripts/sign.gd`, `?`): a 14 x 10 px board with a grey rim, a dark face 1 px back and a glowing orange
"?" (from `PixelFont`) on a ribbed post, 0.6 m behind the gameplay plane, with a small GlowLight. `Main` gives
each its text, `signs[index]` of the level in `levels/index.json`. While Clawd is within 52 px sideways and
48 px up or down (like the 2D sign), `show` eases to 1 and the Overlay draws the text in a bubble above the
board that fades in and slides up 6 px, with a small tail pointing at it.

Moves (keys as in `src/core/input.ts`): **X / J** (attack) or **C / L** (spin) spins: 0.32 s attack around
Clawd, with a hop once per jump in the air. **S / ↓** in the air starts a ground pound (a short windup, then a
fall at 620 px/s); landing shakes the camera, defeats bugs within 30 px, and breaks the whole 4-connected
cluster of corrupted blocks (`X`) under Clawd, who then keeps falling (`Main._on_pound_land()`,
`Level.break_corrupt()`). Breaking re-bakes only the cell texels within `MAX_DIST` of the broken tiles (a few ms;
the full bake of 1-1 takes ~200 ms). **S + jump** on a one-way platform drops through it (the `oneway` mask is
off for 0.18 s). Holding jump while hovering, the jet below Clawd hurts bugs. Spin and the pound windup turn
the voxel body about its vertical axis (the 2D sprite's `turn` flip), and the spin ring is 10 glowing cubes on
a real horizontal circle of 17 px around Clawd, which the oblique projection draws as the 2D game's 17 x 6 px
ellipse, front half over Clawd. Falling out of the level or losing
the last heart respawns on `@` with full hearts.

Game logic keeps the TS units: positions and speeds in pixels with y down (`pos`, `vel` on the player and bugs,
16 px per tile), so the constants are the ones from `src/config.ts`. `scripts/px.gd` (`Px`) converts between
level pixels and metres; the player and bugs convert `vel` to `velocity` only around `move_and_slide()`.

## Shooting (world 2)

In world 2 Clawd is armed (`Main.load_level()`: `Gun.arm()` for every world-2 level in PLAY; a world-2 level
started without a weapon gets the blaster, like the TS dev shortcut). World 2's bugs have 2 hp and its spam bots 3 (`tough` in `spawnEntities()`, set by
`Main.load_level()`), and like every enemy in the port they get `Enemy.HP_FACTOR` (3) times that: 6 and 9. `scripts/weapons.gd` (`Weapons`) is `src/weapons.ts`: the five weapons with their stats and shop prices (Token Blaster, Context Spreader, Stream
Output, Attention Beam, Opus Cannon; slots 1-5 in `ORDER`), the gun mods the shop sells, and the gun part of
`loadoutFromSave()` (+25 % damage and +15 % fire rate per level, 100 context + 40 per level).

`scripts/gun.gd` (`Gun`, a node under `World` made by Main, running after the player) is `Gun` from
`src/entities/gun.ts` plus `updateWeapon()` / `computeAim()` from `src/scenes/game.ts`:

- **Firing**: while attack is held (and Clawd is not spinning, hurt or done), a shot every 1 / fire rate
  seconds; the cooldown counts down in 1/60 s steps as in TS, so the blaster's 6 a second is a shot every 11th
  frame. Each shot adds its context heat; heat drains 32 a second. Reaching the cap overflows the gun for 1.3 s
  (overheat sound; heat drains three quarters of the cap a second, no shots), then it is cool again.
- **Aim**: with the mouse while it moved in the last 4 s or a mouse button is held: the angle from the gun's
  pivot (5 px ahead of Clawd's middle, 9 px above his feet) to the mouse's point on the gameplay plane
  (`camera.top_left + mouse`; nothing at z = 0 shifts, so the screen point is the level point). Without the
  mouse: up / down (down only in the air) with or without a side, else straight ahead. Clawd faces the aim. The
  gun lives in the SubViewport, whose container ignores the mouse, so it **polls** the window's mouse position
  every frame (`poll_mouse()`) instead of waiting for mouse events, which never reach it.
- **Switching**: `next` / `prev` (E / Q, the wheel) cycle through the owned weapons, `slot1`-`slot5` (1-5)
  pick a slot; the choice is saved as `Progress.equipped` and the weapon's name shows over Clawd for 1.5 s.
- **Armed Clawd**: attack shoots instead of spinning (spin stays on its own key; the right mouse button throws the
  Tool Call since world 3),
  and down with attack held does not pound. The voxel gun (`GunSprite`, own material so the see-through windows
  don't dither it) turns about its grip to the aim, upside down when aiming left like the 2D sprite, 6 px in front
  of Clawd (lifted by a third of that against the oblique shift), kicks back on each shot, with a 2-voxel-deep
  muzzle flash.

`scripts/bullet.gd` (`Bullet`, group `bullets`) is `Bullet` from `src/entities/bullets.ts` with the bullet half
of `checkBullets()`: it flies straight (swept in 2 px steps) and stops where `Bullet.blocked()`: on a solid or
corrupted tile as in TS and, in the port (the user's call: platforms are cover), on the 4 px plank of a one-way
tile from either side and on every platform (group `platforms`: moving platforms, rate limiters, fake platforms);
it hits each enemy once (sound
"hit"), stops unless it still pierces, shoots down enemy shots that can be shot down, and ricochets off a shield
turned towards it (`blocks_direction()`, for the ShieldBot). Kinds, as glowing voxels (their own material at
1.7× glow): a spinning coin with a trail dot (token), a hot 3 px square (pellet, five in a fan), a code character
from the pixel font (glyph), and the orb: an orange core with ten dots circling it in depth, a GlowLight and
sparks, which explodes where it stops or when its life runs out. `Main.explode()` (`explode()`): 40 px of
splash damage to every enemy box in reach, enemy shots shot down, corrupted clusters in reach broken (like the
pound, with debris through the blocks' depth), shake, the explode sound. `Main.fire_beam()` (`fireBeam()`):
the Attention Beam marches 300 px from the muzzle in 2 px steps until `Bullet.blocked()` and hits everything on the
way, except through a shield; `BeamFx` (`scripts/beam_fx.gd`, a MultiMesh) shows each beam for 0.06 s as a
jittering line of 2 px dots, cyan with white every 6 px.

## World 2 levels

One section per level, each written by the milestone that ported it (M8-M11 in `docs/port-plan.md`, done in
parallel worktrees, each editing only its own section here). Every world-2 level is armed and uses the
world-2 enemies (*Enemies*); 2-1's mesa motif is under *Look and feedback*.

### 2-2 GPU Forge

Armed, with 5 ceiling turrets (`Y`), a floor turret, 3 drones, 3 rate limiters, 2 shield bots and 3 bugs; the
TS sign text is kept. Full jumps fit without a map override: the ceiling is high everywhere (row 3), so no jump
bumps into anything. `tools/checks/2-2.gd` drives the critical places: the first spike bed (columns 45-76) on
the two moving platforms (their gaps never close below 5 tiles, so the hover carries Clawd over), the arch of
one-way platforms over the second (columns 130-164) up to row 10 and down, the spark over the arch's top, the
spark in the nook over the middle rate limiter (it crashes down next to Clawd, he jumps on it while it rests and
rides it up into the nook), and the corrupted floor at the end (a pound in, a full jump out).

Forge motif: `shaders/motif_forge.gdshader`, server racks and GPU monoliths, a background layer like the mesa
motif (*Look and feedback*, same uniforms). Two ranges of machines (the far one at 0.07 of the camera's speed,
smaller and hazier, the near one at 0.13), one per 170 / 230 px cell or none, standing at 64 / 70 % of the view's
height and fading into the haze below their foot. A cell holds a row of one to three racks or a GPU monolith:
- Racks: a lit cap, rails with a screw hole per unit and 1U units (5 / 6 px) behind them: servers with a vent
  grille and three LEDs (one steady, two blinking at random at their own rate), drive bays with flickering
  activity lights, blank panels with a handle, switches with port lights. Racks of a row differ in height.
- GPU monoliths: a heat sink of vertical fins that glow hotter towards the die, the die white-hot in the
  middle and pulsing in a ring of pins, one or two fans spinning (opposite ways) with the hot inside showing
  between the blades, a vent grille and a load bar at the foot that swells and ebbs.
- Thick power cables (3 px, thicker where steep, lit on top) sag between neighbouring machines, one or two
  per pair, and a pulse of light runs along them now and then.

LEDs, dies, hot fins and pulses are in the theme's ray colour (white-hot for the die's core and some LEDs) and
less hazed than the metal. The embers of the TS forge (`Parallax`) still rise over it.

Pickups: sparks, sub-agents and the token magnet test `Player.in_play()` instead of `visible`, which blinks
while Clawd is invulnerable; before, half the frames after a hit could not take them (TS only checks the overlap).

### 2-3 Prompt Injection Swamp

Armed, with the TS sign, 8 injectors, 4 spam bots, a drone, a turret and a shield bot. Full jumps fit the map,
so it has no override: no ceilings, and `tools/checks/2-3.gd` drives the real player across the five pits
between the pillars (columns 44-79), up the one-way steps to the spark (92-108), over the spike bed (136-173)
on its two moving platforms and the ledge, and out of the spark's pocket under the corrupted floor (214-217).

Swamp motif: `shaders/motif_swamp.gdshader`, corrupted data pools, in view pixels like the mesa. Two ranges of
murky flats (the far one at 0.07 of the camera's speed, its water line at 52 % of the view's height and
hazier; the near one at 0.13 and 60 %), mud with low tussocks and reeds, and in it a pool per 220 / 300 px
cell, half an ellipse below the water line. A pool mirrors the haze of the rows above it (in the haze
shader's dithered steps) and whatever stands over it, with a lit surface line, a dark rim and darker towards
the far shore; its data is corrupted: bands of rows of the reflection tear sideways a few times a second,
dead pixels blink in the injector's magenta or the ray colour, and 1 px ripples drift across. Two cables per
pool hang from above the view and sink into it, steep where they go in, swaying a little; light pulses run
down them into the water and rings spread where they enter. From the near pools injected strings rise as
bubbles of text, two slots per pool half a life (~12 s) apart: a small round bubble grows into a speech
bubble with two trailing bubbles, a phrase ("IGNORE ALL", "SUDO JUMP", "NEW RULES:", "DROP TABLE", ...) types
in with a 3×5 pixel font, one letter at a time flickers to magenta, and near the top of the view the bubble
pops into pixels. Opaque where there is mud or water, sinking into the haze below the pools.

Injectors waiting out of Clawd's range keep their hop squash (`Injector._update_visual()`): in TS the squash
grows without end while the timer runs out, in the port the flattened blob made building its mesh fail.

### 2-4 The Diff Towers

A climb: 40 tiles wide, 96 tall, one-way platforms three rows apart zigzagging up from the start to the exit, with
full-width floors (and checkpoints) every 27 rows; 3 shield bots, 4 drones, 4 turrets, 2 spam bots, 2 sub-agents on
ledges by the walls, the TS sign text ("aim down at what is below you": ↓ in the air aims down in the port too).
Full jumps fit: there are no ceilings or spikes, so no map override.

- Towers motif: `shaders/motif_towers.gdshader`, transformer stacks, behind the parallax's own towers background
  (its dotted columns and data rain, `Parallax`, unchanged). Two ranges of tall stacks (the far one at 0.05 of the
  camera's speed and hazier, the near one at 0.1), one per 104 / 150 px cell, moving on both axes since the level is
  a climb. A stack is a column of translucent glass plates, one per layer (8 / 12 px apart), attention and MLP
  layers by turns (the MLP ones narrower): each a slab seen from above, a top band lit by the theme's ray colour
  over a front face with a bright lip, a see-through body and a dark joint. The plates are a diff: most layers are
  context (dim words of code), some carry a green (added) or red (removed) two-row stripe with a "+" / "-" at its
  left end, in the colours of the mesa's strata. A residual stream runs up the middle of every stack, dim through
  the plates and brighter in the gaps; pulses of light climb it (one per 84 px of the stream, 20-30 px/s) and light
  each plate's top band as they pass. Two in three stacks end in a cap with a pulsing output node, placed so that the
  caps come into view in the upper half of the climb. Translucent (the haze shows through the
  plates), hazier lower in the view.
- One-way landing (`Player._in_one_way_strip()` in `scripts/player.gd`): a falling Clawd ignores one-way platforms
  only while his body overlaps their collision strip (the tile's top 4 px, `ONE_WAY_STRIP`), not the whole tile.
  Under the exit, platforms are two rows apart (rows 3 and 5): his head is still in row 3's tile when his feet reach
  row 5, and he fell through it; now he lands, like `moveY()` in TS.
- Checks (`tools/checks/2-4.gd`): theme, motif and its colours, no 3D motif, the parallax's towers background kept,
  armed start, the enemy counts, the sign; the real player climbs the whole level hop by hop with tapped (full)
  jumps (30 hops) and walks into the exit, the motif follows the camera on both axes, the fall onto row 5 under
  row 3, and full jumps onto both sub-agents' ledges.

### 2-B Codex

`Main._spawn_boss()` puts the level's `boss` (`codex`) at its `Boss` marker, like the `boss` spawn in
`spawnEntities()`: centred on the marker's column, 150 px over the first solid floor below it, in an arena as wide
as the level (40 tiles). `Codex` (`scripts/codex.gd`, from `src/entities/boss/codex.ts`) is an `Enemy` with 90 hp
(no `HP_FACTOR`, no enemy bar: the HUD's boss bar shows `TITLE`, 50 cells for so many hit points). It types
"> codex --ship-it" (typing, 3.2 s, untouchable) under the card "CODEX / a rival model has entered the chat", then
drifts above the arena (a sine across all but 110 px of each side, faster each phase) and runs its phase's pattern
of attacks, resting 1.2 s (less each phase) after each:

- **burst**: 3 + phase volleys 0.5 s apart of five code characters (`{}();=<>[]`) fanned at Clawd's middle at
  120 px/s (20 % faster a phase), every other volley turned a little; they can be shot down or spun away.
- **slam**: the cursor hand nearer Clawd (`CodexHand`, `scripts/codex_hand.gd`, invincible, hurts on contact)
  tracks him 120 px over the floor for 0.85 s under a blinking red target on the floor's top, drops at 650 px/s,
  sticks for 0.8 s (slam, shake, dust) and sends a "≈" shockwave each way at 165 px/s; in phase 2 the other hand
  slams 0.7 s later.
- **wall**: "autocompleting...": a column of ghost text 9 px apart sweeps from the side away from Clawd at 95 px/s
  (+15 a phase) with one 44 px gap; neither it nor the shockwaves can be shot down, and both pass through walls.
- **tests** (phases 1 and 2): "npm test → n failing": 2 + phase world-2 bugs (2 hp × `HP_FACTOR`, like every bug
  in the port) drop in from the top of the arena; their tokens are added to the level's total.
- **rm -rf** (phase 2): "rm -rf ./clawd": three `ColumnBeam`s (`scripts/column_beam.gd`) 0.75 s apart where Clawd
  stands: 0.85 s of blinking warning, then 0.35 s of beam (laser, shake) whose middle 12 px hurt; bullets pass
  through them.

Only the monitor takes damage (shots, stomps, spins, pounds, the jet; there is no immunity after a hit, as in TS),
with damage numbers over it like every enemy. At 2/3 and 1/3 of its hp it refactors ("REFACTORING...", "ENABLING
--YOLO MODE": bossHit, shake, hitstop, 1.8 s untouchable) into the next phase, whose pattern starts over; its
screen cracks and glitches. At 0 hp: "SEGFAULT", the hands retire, it sinks for 2.8 s in bursts and explosions,
then `Main.boss_defeated()`: "CODEX HAS BEEN DEPRECATED", leftover projectiles vanish, the map tune plays and the
**Tool Call** drops in the middle of the arena (TS opens the exit there; the game goes on into world 3): a
`WeaponPickup` with id `hook` (`GunSprite`'s claw launcher). Touching it calls `Main.weapon_found()`, which gives
the tool (`Progress.grant_tool()`, saved in `tools`; it is not a weapon), pops "TOOL CALL ACQUIRED!" and "world 3
unlocked" and opens the exit 6 tiles right of the middle. The results say "WORLD 2 CLEAR", on the first clear
"TOOL CALL FOUND · WORLD 3 UNLOCKED", and a closing line under it (`note_text`, drawn by `Overlay`). A save from
before world 3 with 2-B cleared gets the Tool Call when it is loaded.

The 2.5D look: Codex is a voxel CRT monitor, the 2D bezel of 2 px dots standing proud of a dark casing whose
tapered back reaches 29 px into the depth; its face (scrolling code, eyes looking at Clawd, mouth, cracks, the
intro prompt with its cursor, x_x, the name plate) is painted every frame on the recessed screen by
`CodexPaint` (`scripts/codex_paint.gd`, flat boxes in a MultiMesh), its eyes and prompt glowing. The model sits
9 px in front of the gameplay plane, lifted 3 px against the oblique shift, so the screen lands where the 2D one
was; a GlowLight on the screen lights the platforms it drifts over and rims Clawd. The hands are the 2D cursor
sprite in voxels (2 px cells, the outline deeper than the fill), pointing down while they slam. Codex's shots are
`CodeShot`s (`scripts/code_shot.gd`, a `Shot` with a glyph): the character in bold glowing voxels with a dark
outline (PixelFont, plus braces and the wave); the shockwave repeats its lower tilde in three dimmer bands across
the floor's top. The rm -rf warning comes down as red dashes onto a square of dashes on the floor; the beam is a
column 18 px deep, translucent red round a glowing white core, with a GlowLight on the floor. New sounds:
`typing`, `slam`, `laser`.

**Motif** (`scripts/codex_motif.gd`, found by its name): code monoliths in three layers of depth (-24, -13 and
-7.5 m) behind the forest's nearer layers, tall dark slabs rising from below the view; `shaders/codex_monolith.gdshader`
covers their fronts with code scrolling up in syntax colours of the theme's cyan (keywords, pale identifiers, dim
comments, white and now and then orange literals), a blinking cursor at the line being typed and a scanline
glinting down; their tops show a lit rim.

`tools/checks/2-B.gd` checks the spawn, the intro, every attack, the phases, a blaster hit and a stomp, the death,
the exit, the results and the motif.

## World 3: AGENT MODE

The plan and its task list are in `docs/world3-plan.md`. World 3 is not a port: its mechanics are new.

### Tool Call

`scripts/tool_call.gd` (`ToolCall`, `Main.tool_call`, next to the gun and run after it) is Clawd's hook in every
level once `Progress.has_tool("hook")` (Codex drops it). The `tool` action (Shift / F / the right mouse button,
which no longer spins) throws it from his hand (the gun's pivot) along his aim: the gun's while armed, else
`Gun.compute_aim()` the same way (the mouse, or the keys).

- **Aim assist**: every frame `pick()` chooses the anchor nearest the aim line within `REACH` (128 px = 8 tiles)
  and `CONE` (35°) that he can see (no solid block on the line, sampled every 4 px), scoring angle × 80 +
  distance × 0.3. The pick shows orange brackets in the Overlay and turns faster.
- **Flight**: the claw flies at 900 px/s: to the pick, which it catches (`Anchor.catch()`, hookCatch, a burst),
  then `Player.start_zip()` pulls Clawd's feet to 12 px under the anchor; with no pick it flies straight in 2 px
  steps, and a solid or corrupted block stops it (hookMiss), an enemy is struck, and at REACH it comes back. It
  returns at 1400 px/s; a new throw waits 0.15 s.
- **Enemies**: a struck enemy takes `HOOK_DAMAGE` (2, as a shot) unless it has something to lose: `hook_hit()`
  on a shield bot tears its shield off (`ShieldBot.shieldless`: no shield drawn, shots get through from every
  side), and the hook only hurts it after that. Bosses and projectiles are not struck.
- **Zip** (`Player` state `zip`, `_zip()`): straight at the target at `ZIP_SPEED` (440 px/s), no gravity or
  control, at most `ZIP_MAX_TIME` (0.9 s); one-way platforms let him through on the way up. Arriving ends it with
  a hop (`ZIP_POP`, 250 px/s up) and fresh hover and air spin (`end_zip(true)`, a burst); a wall in the way stops
  him where he is; jump lets go with a full jump, `tool` again lets go keeping half his speed, a hit ends it.
  While zipping he reaches up.
- **Look**: a voxel claw (`CLAW`, orange with white tips) turned along the cable, and the cable as up to 48 glowing
  1 px cubes (a MultiMesh with the particles shader) every 3 px from the hand. Sounds: hookThrow (a whoosh),
  hookCatch (a clink), hookMiss (a clank) and zip, synthesized like the rest.

`scripts/anchor.gd` (`Anchor`, `+` in a map, group `anchors`): an API endpoint in the middle of its tile, a 7 x 7
voxel ring of cyan round a white and orange core in 2 px cells (14 px across, so it reads among the scenery; it
bobs a pixel instead of turning, which would hide it edge-on), with a small GlowLight that pulses; `point()` is
where the hook catches it. A timeout anchor (`*`, `timeout`) is amber: when the hook catches it a 1.2 s fuse burns
(it blinks faster and faster), then it times out (`active` false: the hook can't pick it, only a dim dotted ghost
is left) and answers again 3 s later.

`tools/reach.gd` knows the Tool Call (and counts a webhook as an anchor where it spawns): from where Clawd stands and at the top of a full jump he zips to every
anchor in reach and sight, and from an anchor he drifts down (with and without hover, to either side or none) or
zips on to the next one 12 frames into his hop, so chains of anchors over a chasm count; anchors 6 tiles apart
chain, 8 apart do not. In levels with `subAgents` every jump is also tried from 18 px higher, standing on a
sub-agent left where Clawd stood.

### Sub-agents, plates and gates

Clearing 3-1 the first time gives Clawd the "agents" tool (`Progress.tools`; the results say "SUB-AGENTS JOIN
YOU · G SENDS ONE"; an older save with 3-1 cleared gets it when loaded). `scripts/echo_control.gd`
(`EchoControl`, `Main.echoes`, run after the player) records his feet and facing every physics frame for the last
`REPLAY` (3) seconds; the `agent` action (G / the middle mouse button) sends out a sub-agent on that recording
(agentSend, a burst where it starts). How many can be out at once: 1, 2 from 10 sub-agents rescued in all levels,
3 from 18 (`slots()`; the Delegate prompt adds one, W9); sending one more calls the oldest home. A respawn starts
the recording over; a new level sends them all home. The HUD shows an AGENTS panel next to the weapon panel (or in
its place) with a box per slot, cyan while free.

`scripts/echo.gd` (`Echo`, group `echoes`): it replays the recording (without the time Clawd stood still at its
start and end, so one sent after waiting stands at once), one entry a physics frame, from where Clawd was, then stands where he was when he sent it for 8 s and fades (0.5 s, agentGone). Standing it is a platform (group
`platforms`, the MovingPlatform interface), so Clawd can stand on it to reach higher; his shots pass through it
(`Bullet.blocked()` skips it). Its feet press plates whether it replays or stands. Drawn as Clawd tinted cyan
(the voxel shader's `tint`), its pose from how it moves; it flickers like a hologram while it replays, in its last
second and as it fades.

`scripts/plate.gd` (`Plate`, group `plates`; digits `1`-`9`, a run of one digit in a row is one plate): a slab on
the floor under its cells in its digit's colour (`Plate.COLORS`), pressed while Clawd stands on it or a sub-agent's
feet are on it (plateOn / plateOff); its top lights and it sinks a pixel. The level's `plateHold` (seconds per
digit in `index.json`, read on its first frame since `Main` sets `info` after the level enters the tree) keeps it
pressed that long after it is let go, blinking faster as the time runs out.

`scripts/gate.gd` (`Gate`, group `gates`; letters `a`-`i` and `z`, all cells of one letter are one gate): shut, its
cells are MeshLibrary item 4 (`Level.GATE`, a box shape with no mesh) in the Terrain GridMap, and `Level.tile()`
calls them SOLID, so Clawd, enemies, shots and the hook treat them as rock; it draws three glowing bars per cell
in its plates' colour. `a` opens while every plate of digit 1 is pressed, `b` for 2, and so on (gateOpen); its
cells empty and the bars slide up into the cell's top. `z` opens once the level's Retry Loops are gone (W6). A
gate that should shut waits while Clawd or a sub-agent is in it (gateShut).

### Webhook

`scripts/webhook.gd` (`Webhook`, `W`): a callback on wings, 14 x 10 px, 3 hp (× 3), 15 tokens. It patrols a lazy
figure round its post (40 px sideways, 6 up and down) and, every few seconds with Clawd within 120 px and below it,
aims for 0.4 s (flashing red) and dives at him at 230 px/s for up to 0.5 s, then flies home. It is also an anchor
(group `anchors`, the Anchor interface: `point()`, `active`, `targeted`, `catch()`; `ToolCall` takes any node in
that group): the hook catches it, the zip follows it, and a caught webhook is stunned for 1.4 s, hanging still with
no hurtbox, so Clawd hops off it. A voxel model in 1 px cells: the anchors' ring between two flapping wings, a hook
of a tail under it; it shows its own brackets while the hook would catch it.

### Brittle crates and Retry Loops

`scripts/brittle.gd` (`Brittle`, `%`, group `brittle`): sandbox data in a tile. It puts MeshLibrary item 4 (the
invisible solid box the gates use) in its tile, so `Level.tile()` calls it SOLID and everything treats it as rock,
and draws itself as a voxel crate 16 px wide and as deep as the blocks (48 px): a sandy frame with diagonal braces,
cracking as it is struck. `Level.brittle` maps tiles to crates. Three strikes break it (`strike()`: a bullet where
it stops, the beam's end, the hook's clank); a ground pound on it (Clawd keeps falling, `continue_pound()`), an
explosion reaching it, or Clawd zipping into it (every crate his body would enter; the zip goes on) smash it at once
(break, sand-coloured debris through the depth). `tools/reach.gd` treats crates as broken.

`scripts/retry_loop.gd` (`RetryLoop`, `L`, groups `enemies` and `retry_loops`): a `while (true)` hanging in place,
16 x 16 px, 8 hp (× 3), 40 tokens. While Clawd is within 300 px it drops a tough bug (2 hp × 3) from its bottom every
4 s (the first 1.5 s after he comes near), at most 3 of its own alive at once; destroyed, it leaves the group, and
`z` gates open once the group is empty. A voxel loading spinner in eight frames: a dim red ring with a bright head of
three segments running round it, faster in the last second before a spawn.

### Parser

`scripts/parser.gd` (`Parser`, `P`): an armoured crawler, 18 x 8 px, 4 hp (× 3 like every enemy), 20 tokens. It
patrols at 24 px/s, turning at walls and ledges (Enemy's `move_x()` / `move_y()`, no physics body). While
`armoured`, `blocks_direction()` is true from every side, so bullets ricochet and the beam stops as on a shield
bot's shield, and `hit()` refuses everything with a clank (deflect, a white flash): stomps still bounce Clawd (he
bounces whatever `hit()` says), spins and the jet do nothing. The Tool Call's `hook_hit()` tears the shell off
(break, a burst of plates), once: bare, it is a pink grub that scurries at 50 px/s and takes damage normally.
Touching it hurts either way. A voxel model in 1 px cells: steel plates with dark seams and a cyan eye over a dark
underside, or the bare grub, each on two leg frames.

### 3-1 Endpoint Canopy

232 x 26 tiles, the Tool Call's tutorial. A wall 8 tiles high right after the start (the TOOL CALL sign: jump, aim
up, zip), an anchor chain over a spike chasm with a spark on a one-way ledge low in it (out again by the middle
anchor), stairs down to bugs and the first parser (its sign) and a checkpoint; then a pillar climbed by a vertical
chain of three anchors to a spark on its top, a high canopy walkway (one-way segments, a solid branch with a shield
bot, anchors over the gaps, a sub-agent on a perch above) over a low road with parsers, a bug, a spam bot and a
turret; a second checkpoint, a long spike chasm crossed by seven anchors at varying heights (a spark over one, a
sub-agent on an island), and a last stretch with parsers, a shield bot, a turret and a spark on a ledge only an
anchor reaches. 5 sparks, 2 sub-agents, 39 tokens, 19 anchors; `tools/reach.gd` passes with the anchors and fails
without them (the first wall). Theme `canopy`, music `canopy`.

**Motif** (`shaders/motif_canopy.gdshader`, found by its name): two ranges of giant trees (the far one hazier and
slower) whose lacy crowns close into a canopy in the upper third; vines hang from it with a dim endpoint lantern
at each end (lanterns, not rings, so they never pass for anchors). Every few seconds a request runs down a vine as
a light pulse, the lantern flashes, and its reply (OK, GET, PUT, POST in the swamp's 3 x 5 font) floats up and
dithers away.

### 3-2 Webhook Cliffs

44 x 84 tiles, a climb between two cliff walls, where sub-agents come in (`subAgents` in `index.json`; 2-plates
hold for 2.5 s). From the floor a ledge 5 tiles up that only a sub-agent's shoulders reach (the SUB-AGENTS sign); an
anchor chain up the right to a second ledge, and two anchors on the left to a nook with a sub-agent; on the second
ledge plate 1 and a parser, and the way up is gate `a` in a full-width ceiling, so a sub-agent has to hold the
plate while Clawd zips through (the PLATES sign); above, a ceiling turret, webhooks to a ledge on the left and a
shelf, anchors up the left to a hole in the upper floor; there two plates of 2 and gate `b` in the wall to the exit:
a sub-agent on one, Clawd on the other, and the hold lets him run through (the TWO PLATES sign). 5 sparks, 2
sub-agents, 31 tokens, 11 anchors, 3 webhooks.

**Motif** (`shaders/motif_cliffs.gdshader`): two ranges of sheer cliff pillars with jagged tops, strata and a lit
edge, which also move with the camera up and down; between the near pillars' tops a message (a 3 x 2 envelope)
arcs on a dotted trail and comes back a moment later, as webhooks do.

### 3-3 The Sandbox

210 x 24 tiles of flat ground where everything breaks: a crate wall to shoot through at the start (THE SANDBOX
sign), crate towers with a spark in a pocket, a parser and a bug, a spike pit spanned by a crate bridge with a
parser on it and three anchors above (a spark over the middle one), a checkpoint, a crate maze with a tunnel (a
shield bot in it, a turret on top), a pillar with a sub-agent boxed in on top, drones, a spam bot and a spark on a
high ledge; then the arena: three Retry Loops over one-way shelves, crates for cover, a sub-agent in a crate box,
a spark high over it, and the red gate `z` in the wall before the exit (the RETRY LOOPS sign), with the last spark
behind a crate. 5 sparks, 2 sub-agents, 36 tokens, 212 crates. The Retry Loops make it a good place to farm tokens.

**Motif** (`shaders/motif_sandbox.gdshader`): two ranges of stacked corrugated containers with lit rims and
scaffolding poles; now and then a stack's top container crumbles into pixels and is built again row by row.

### 3-4 Timeout Ravine

222 x 30 tiles of cliffs over a ravine floored with spikes, sub-agents expected (`subAgents`; plates of 1 hold
3.5 s, of 2 hold 4 s). A chain of four timeout anchors over the first chasm (the TIMEOUT sign, a spark over it); on
the next cliff plate 1, whose gate `a` stands in a wall beyond a second chasm of anchors: race there in 3.5 s or
leave a sub-agent on it (the RACE sign); a checkpoint; then one 2-plate on a cliff and one down in a pit (a spark
there, a timeout anchor out of it), both at once open gate `b` (the DEADLOCK sign), a parser and a shield bot; a
long chain of eight timeout anchors with drones and a webhook over it, a spark over the middle and a sub-agent on
a ledge in the chasm (an anchor back up); the last cliff with parsers, a spam bot, a high ledge with a spark and a
sub-agent, and a spark over a lone timeout anchor before the exit. 5 sparks, 2 sub-agents, 36 tokens.

**Motif** (`shaders/motif_ravine.gdshader`): two ranges of ravine walls hanging from the top and rising from the
bottom; between them clock faces whose hands sweep round and flash red as they pass twelve, and loading spinners.

## Checks

```bash
godot --headless --script tools/check.gd     # exits non-zero on failure
godot --headless --script tools/reach.gd     # after editing a map, see Levels
```

Per-level sections live in `tools/checks/<id>.gd`, one file per level, run in name order where the 2-1 section
used to be (`level_sections()`): each has `const TITLE` and `func run(c) -> bool`, with `c` the check script
(`c.ok()`, `await c.frames()`, `c.current_scene`, `c.enemies_of()`, `c.bugs()`, `await c.drive()`, ...);
`tools/checks/2-1.gd` is the template; a file that does not load (a parse error) counts as a failure. A run keeps its progress and settings (from the start to the end of the run, so pressing M or rebinding never
saves into the player's `settings.cfg`) in files named after its process id,
so checks in several worktrees of the project (which share `user://`) can run at the same time.

Compares the noise functions with values computed from `src/core/noise.ts` (TS sources: branch `ts-legacy`), every converted level's GridMap
cells and spawns with its `.txt` map (each ported spawn character placed as often as in the map, one start, one
exit except in boss levels; spawns not ported yet are listed), the player's jump height and gap/step limits with the level-design rules in
`tests/player.test.ts`, the title (logo, drift, Space) and the world map (locking, unlocking, keys, mouse,
playing, QUIT TO MAP, back from the results) and level switching, spikes, bugs, stomps and tokens in 1-1 (the 10
tokens a bug drops fly to Clawd; the map's left edge stops him), spin,
air spin hop, ground pound through 1-1's corrupted blocks and drop-through, 1-1's checkpoints (activation,
respawn), signs (texts, bubble near Clawd, glyphs for every sign text) and exit (completion, results, next
level), and that a running jump clears
crossing the 26-tile gap of 1-1 on its two moving platforms (a
small controller jumps when the next platform comes close), that a tapped jump is a full jump, and the HUD
(tokens fly to the counter and are counted when they land, hearts break and refill, +1 heart per 300 tokens up
to 5), and the menus (pause freezes the world, every pause item, the crosshair colour (white by default, cycling,
saved), the HUD buttons, rebinding with conflicts,
clearing, reset, saving to a separate settings file, glyphs for every key name), and the sound (every effect
renders, is audible and does not clip, the pitches of token / jump / checkpoint, track loop lengths, and that
the game's events play their sounds, the jet hisses while hovering, M mutes, the exit and results switch the
music), 1-1's sub-agents and sparks (placement and numbering, pickup, HUD, results, saved progress, ghosts on the
next run), spam bots, shots and rate limiters (hovering, aimed fire and its range, a shot's hit / spin / wall,
stomping a spam bot and its tokens; 1-2's crushers: trigger, fall, crush, hurt, riding the top up, rising home,
no damage), world 2's enemies (tough bugs and spam bots, counts per level; a turret's turn rate, aim, horizon
limit, three-shot burst, reload and range; a ceiling turret under its tile and its lower half-plane; a drone's
bobbing, circling, aim, 270 px/s dive and the side switch, a dive stopped flush by the floor; a shield bot's
shield from the front / behind / above, slow turn, walk, shot, a bullet ricocheting off the shield and one in its
back; an injector's hop, landing, split into two 1-hp bugs and its tokens), 1-2's darkness (its depth, the dimmed sky, the caves motif, Clawd's lamp position and breathing
radius, 1-1 lit again), 1-3's rising void (start, delay, speed, never too far behind, paused, catching
Clawd, reset below the checkpoint, the ▲ glyph) and windows, the Hallucination (placement, glitch motif,
intro, bursts, dazed, stomp, immunity, teleport, rain and warnings, fake platforms, death, the blaster, the
exit, WORLD 1 CLEAR, world 2 unlocked), 2-1 Merge Conflict Mesa (theme, the mesa motif and its colours, armed
start, its enemies, the TS sign texts; the real player with full jumps crosses the pit on its two one-way
platforms, pounds through the corrupted floor to the spark below and climbs out), 2-2 GPU Forge (the forge
motif, its enemies, the moving platforms over the first spike bed, the arch's spark, riding a rate limiter up to
the nook's spark, the pocket under the corrupted floor), 2-3 Prompt Injection Swamp (the swamp motif, eight
injectors, the one-way steps to a spark, the moving platforms, the pocket and the climb to the exit), 2-4 The
Diff Towers (the towers motif over the parallax's own towers, its enemies, the full-jump climb to the exit, a
fall onto the platform two rows down, both sub-agents), 2-B Codex (the arena and its tune, the code monoliths,
the spawn, 90 hp on the boss bar, the intro, the hands, bursts, slams and shockwaves, the refactor phases, failing
tests, rm -rf columns, both hands in phase 2, stomps, SEGFAULT, CODEX HAS BEEN DEPRECATED, the Tool Call drop
and pickup, the exit, WORLD 2 CLEAR and TOOL CALL FOUND · WORLD 3 UNLOCKED, an old save getting the Tool Call), aiming with the mouse (world 2 armed, mouse motion reaches the gun, the
aim angle, the crosshair's level point, keys without the mouse, world 1 unarmed), the Tool Call (its keys, `+` anchors, nothing
without it, the aim assist's pick, the throw, catch and zip with their sounds, the hop and fresh hover on arrival,
no pick out of reach or behind a block, a clank on a block, a bug struck, a shield bot's shield torn off, letting go
by jump / tool / a hit, the controls help line), 3-1 Endpoint Canopy (theme, motif, its enemies, anchors and
signs, the real player climbing the first wall with a jump, the hook straight up and a zip; a parser's shell
stopping shots and stomps, torn off once by the hook, then hurt and fast), sub-agents (their keys, none before 3-1
is cleared, 1-3 slots by rescued sub-agents, sending one on the last 3 s, replay, standing as a platform Clawd stands
on, shots passing through, a plate opening its gate for Clawd or a sub-agent, Clawd walking through, a gate not
shutting on him, a plate's hold, a full slot calling the oldest home, the controls help line), 3-2 Webhook Cliffs
(theme, motif, its enemies, plates and gates; the real player standing on a sub-agent to reach the first ledge;
plate 1 opening the ceiling's gate and a sub-agent holding it; the two 2-plates and running through gate b on the
hold; a webhook as an anchor, stunned and harmless when caught, diving at Clawd below it), 3-3 The Sandbox (theme,
motif, its enemies, 212 crates, the red gate shut; a crate solid and stopping shots, broken by three shots, a pound
drilling through, an explosion, a zip smashing through the maze; a Retry Loop dropping bugs, at most 3, and the red
gate opening once every loop is destroyed), 3-4 Timeout Ravine (theme, motif, its timeout and plain anchors,
plates and gates; a timeout anchor caught, timing out 1.2 s later, unpickable, back 3 s later; gate a open 3.5 s
after Clawd steps off its plate; the pit's 2-plate alone, then with a sub-agent in the pit and Clawd on the cliff),
shooting (fire rate and damage
with and without Bigger Model / Faster Inference, the stream's context overflow, no shots while overflowed,
cooling, Longer Context, a token stops at the first enemy, the beam pierces, a token and the beam stop on a one-way plank from below
and a token on a platform, the gun vanishing with Clawd into the exit and back in his hands on the next level, shooting down enemy shots and not the
ones that can't be, next / prev / slot switching and saving, attack shoots instead of spinning, the orb's
explosion breaking 1-1's corrupted blocks with splash damage, damage numbers adding up and marking the kill, health
bars only on hurt enemies, 2-1's tough bugs and spam bots, the bar draining), the controls help (shooting lines once a weapon
is found), and the shop (every played sound is rendered, locked until 1-1 is cleared, the spark prices add up
to the sparks in the levels, each item's price and
effect in a level, refusals, fortunes read from the map, saving, back to the map; with a weapon the ARMORY and
GUN MODS rows, scrolling, buying and equipping weapons, the gun mods' prices and effects, the map's Clawd holding the equipped weapon in
world 2 only).

## Game clock and camera

- `Game` (autoload, `scripts/game.gd`): game time and hitstop. Level objects skip their update while
  `Game.frozen()`, so hitstop and pause stop the world like in `src/scenes/game.ts`.
- `Settings` (autoload, `scripts/settings.gd`): key bindings, the CRT filter and mute, saved in `user://`
  (see Menus and key bindings).
- `Sound` (autoload, `scripts/sound.gd`): synthesized effects and music (see Sound and music).
- `Progress` (autoload, `scripts/progress.gd`): cleared levels, rescued sub-agents, best times, wallet (see
  Title and world map).
- `ViewScale` (autoload, `scripts/view_scale.gd`): view size from the window like `Renderer.resize()` in
  `src/render/renderer.ts` (integer scale, view about 270 tall and at least ~420 wide), same as the 2D port.
- `scripts/game_camera.gd`: port of `src/core/camera.ts` (look-ahead, vertical deadzone, small levels
  centred, trauma shake) on an orthographic `Camera3D` that looks straight down -z. It works in level pixels on
  the gameplay plane; one level pixel is exactly one view pixel on both axes. Depth comes from the oblique
  projection in `shaders/oblique.gdshaderinc`, which every 3D material calls from `vertex()`: a point moves up
  by a third of its distance behind the gameplay plane, as if the camera were pitched down atan(1/3) (~18.4°).
  One view row covers 3 px of depth (`ROW_Z`), so the 3 m deep blocks show a 16 px top band. On top of that
  the projection adds a little perspective: points behind the gameplay plane move towards the view centre by
  3% of their distance from it per metre of depth, so blocks and background towers off the centre show their
  sides (up to ~11 px at the view's edges) and top bands are thicker near the bottom of the view. Nothing in
  front of the gameplay plane moves, so Clawd, the enemies and the block fronts stay pixel-exact; faces that
  cross z = 0 get vertices there (`BoxMesh.subdivide_depth`, `Voxel.mesh()`). Scenery boxes converge from their
  own front faces. The terrain shader draws the exposed side faces (crust over the top edge, a lit front rim,
  strata darkening towards the back, a share of the theme's light colour, `ambient`). A pitched
  orthographic camera would shorten one axis by cos(pitch) and make sprites shimmer by a pixel while moving.
  The SubViewport renders `Main.PAD` extra pixels on every side, so nothing the oblique shift moves into view
  is frustum-culled at the edges.
- `scripts/noise.gd` (`DotNoise`): bit-exact ports of `hash2`, `valueNoise2`, `periodicNoise1`, `mulberry32`.
- `scripts/particles.gd`: port of `src/render/particles.ts` drawn as 1 px cubes in a MultiMesh; emit with the same
  options as `particles.emit`. Particles start half a tile in front of the gameplay plane, so they show over
  Clawd and the bugs like the 2D overlay, and drift in depth.
- `scripts/parallax.gd` (`Parallax`): the theme backgrounds of `src/render/parallax.ts`, unchanged from the 2D port
  (dot ridges, factory columns, twinkling stars, data rain, code lines, rings, embers, fog bands). It lives in a
  CanvasLayer behind the 3D level, over the haze; the Environment's background mode is *canvas*.

## Text

Text is pixel art too: `scripts/pixel_font.gd` (`PixelFont`) is a bitmap font with 5 px capitals and digits,
lowercase with a 4 px x-height and 2 px descenders, arrows and the punctuation the signs use, drawn from one
atlas with nearest filtering on whole view pixels, 8 px per line like the 2D game's 5.5 px text.
`PixelFont.rows()` returns the same glyphs as text-grid rows for `Voxel.mesh()` (the checkpoint screen).
`scripts/overlay.gd` (`Overlay`, `View/SubViewport/World/Ui`, a CanvasLayer above the colour grade) draws text
over the 3D view in SubViewport pixels: rising popups (`Overlay.popup()`), the text of nodes in the group
`world_text` (they implement `overlay_draw(overlay)`; a sign's bubble, `Overlay.bubble()`, is pushed inside the
part of the view on screen, its tail still pointing at the sign) and panels like `panel()` in `src/render/shapes.ts`.
`Overlay.to_view()` maps a level position (and depth) through the camera and the oblique projection.

Added in the port (not in TS), for every enemy:

- **Damage numbers**: `Enemy.hit()` calls `Overlay.damage_number()` for every hit that lands on a non-projectile:
  the damage (`2`, `2.5`) rises 20 px a second from over the enemy's box and fades in its last 0.3 s (0.8 s in
  all), with a 1 px shadow; a hit on the same enemy within 0.12 s adds to its number instead of making a new one
  (the beam's 20 hits a second, the stream, a spread's five pellets), and the killing blow's number is light
  orange. The boss's own `hit()` shows none (it has its hits and the HUD bar).
- **Health bars**: hidden at full health. Once hurt, a 4 px high frame centred at `Enemy.bar_y()` (4 px over the
  enemy's box; over the shield bot's "403", under a ceiling turret), as wide as the
  enemy (12-24 px), with its hit points in red and the ones just lost in light, draining at 1.5 × max hp a
  second after the hit flash (`Enemy.shown_hp`). `Enemy.max_hp` is taken from `hp` on the first hit (after the
  level's world-2 toughness); `health_bar = false` hides it (the Hallucination).

## HUD

`scripts/hud.gd` (`Hud`, in the same `Ui` CanvasLayer, under the Overlay) is `drawHud()` from
`src/render/hud.ts` for hearts and tokens, drawn as sprites from text grids at view resolution. Top left is one
dark panel with the 2D panel's open corners, a 1 px shadow under it, a faint highlight inside its top edge and a
short orange tab on top; in it 9 x 8 px hearts lit from the top left (lost ones are dark sockets), a dotted
divider, an 8 px token in `TokenSprite`'s palette that turns once every 3 s, and the count in 4 x 7 px digits
with a 1 px shadow and dim leading zeros (`007`). Between the hearts and the token, in a level with sparks, a
small spark (grey until one is found) and "x/y", flashing light orange for 1.4 s after a find (the 2D SPARKS
panel). In a level with sub-agents, past another divider, a small
Clawd (grey until one is rescued, cheering for a moment after each rescue) and "x/y". With shop items: a
Firewall is one more slot after the hearts (a shield that flashes white and shatters when it takes a hit),
Double Tokens puts "x2" after the count, and the Spark Radar draws a chevron 28 px from Clawd towards the
nearest never-found spark, beating faster the closer it is. Top right are a CONTROLS button, a pause button (two bars), a
mute button (`drawSpeaker()`) and the level's label (`1-1 · token plains`, the id in light orange); the buttons light up under the mouse and
stay orange while their menu is open, and the speaker shows a red cross while muted. Everything sits 6 px
inside the part of the SubViewport on screen (it is `Main.PAD` bigger on every side). It animates on real time,
so through hitstop:

- a lost heart flashes white and breaks into falling shards, while the panel shakes and its border turns red;
  on the last heart (Player emits `die`) it breaks first and the hearts come back one by one 0.55 s later;
- refilled hearts pop up 1 px with a fading white outline; the last heart left beats;
- a collected token (`Main.collect_token()`) flies from where it was along an arc to the counter coin, tokens
  picked up together 0.04 s apart, and the count shown (`Hud.shown`) ticks up when each lands: the coin
  glints and the digits jump 1 px in light orange;
- it fades out under the level-complete panel.

Like `collectToken()` in TS, every 300th token gives a heart (100th in TS: with 5× tokens that would be 2-3 extra
hearts in every world-2 level), up to 5 (the HUD grows a slot, "+1 HEART" pops up), and a checkpoint refills to
3 without taking those away.

Armed (world 2), `_draw_weapon()` is `drawWeaponHud()` and `drawCrosshair()`: bottom left a panel with the
weapon's name, slots 1-5 (the held one orange, owned ones grey, the rest dark) and the CONTEXT bar of 26 cells
(orange, red over three quarters; blinking red with OVERFLOW while overflowed); the weapon's name over Clawd
after a switch; and while aiming with the mouse a dotted crosshair at the mouse (`Hud.draw_crosshair()`; red while
overflowed), which hides the system cursor (`Input.MOUSE_MODE_HIDDEN`, not in headless runs). TS draws it in
orange, which got lost against the orange and red world-2 levels (bug list #2): the port puts a dark 1 px outline
around every dot and takes its colour from the pause menu's CROSSHAIR (white by default; cyan, lime, magenta,
yellow or TS's orange; `Settings.crosshair`, saved in `settings.cfg`).

## Sound and music

`scripts/sound.gd` (autoload `Sound`) is `src/core/audio.ts`. Like the TS game it ships no audio files: it
synthesizes the same sounds, but offline into `AudioStreamWAV`s (16-bit mono, 44.1 kHz) instead of live
WebAudio nodes:

- `tone()`: an oscillator (sine, triangle, and square / sawtooth band-limited with PolyBLEP, like WebAudio's
  wavetables) with the exponential frequency ramp and the TS envelope (0.0001 -> vol in 8 ms -> 0.0001).
- `noise()`: white noise through WebAudio's bandpass biquad (RBJ, constant 0 dB peak gain) with an exponential
  centre sweep and fade.
- Effects: `play()`'s recipes; the ones the port uses (`PRELOAD`) render in a thread at start-up (~80 ms).
- Music: `scheduleStep()` (bass, arpeggio, lead on every other 4 bars, kick / snare / hats) rendered as one
  seamless loop of the whole pattern (128 sixteenths with a lead, 64 without; notes that ring past the end wrap
  to the start), in a thread the first time a track plays (~0.35 s for plains). Each level plays its `music`
  from `levels/index.json`; the title plays `title`, the map and the results panel `map`; the exit stops the music.
  World 3's tracks (`canopy`, `cliffs`, `sandbox`, `ravine`, `router`) are new patterns for the same sequencer.
- The hover jet: the looping bandpassed noise with `hoverUpdate()`'s 40 rad/s wobble baked into 6 periods,
  faded in and out while `Player.hovering` (stopped while paused).

The TS bus gains are baked into the samples (effects 0.55, music 0.22); the Master bus is at 0.8 and is muted by
the `mute` key (M) or the HUD's speaker button (saved in `Settings`). Sounds follow the TS call sites: player
events (jump, land, spin, pound, pound landing, break, hurt, die / fell, stomp + enemyDie, defeat), tokens,
+1 heart, checkpoints, the exit (complete), the menus (select, confirm, denied), and the gun: one shot sound
per bullet kind (gunToken, gunPellet, gunGlyph at a fixed 1800 Hz where TS randomises it, gunBeam every 4th
beam, gunOrb), overheat, explode and hit.

## Title and world map

`Main` has three modes, like the TS scenes: `TITLE` (`src/scenes/title.ts`), `MAP` (`src/scenes/levelSelect.ts`)
and `PLAY`. Behind the title and the map Main keeps `BACKDROP` (1-1) loaded with Clawd parked (`Player.park()`:
hidden, not processing, off the physics layers) and drifts the camera right through it (18 px/s on the title,
6 px/s on the map, at the height of its start); at the end it starts over, and each pass fades in from black. So
the screens sit on the game's own living world: fog, lights, parallax, scenery, motes, patrolling bugs and
moving platforms. The level's own world text, the HUD and the see-through windows are off there.

`scripts/front_end.gd` (`FrontEnd`, `Ui/FrontEnd`) draws both, in the HUD's panel look and the pixel font with
1 px shadows:

- **Title**: the CLAWD logo assembles itself like the 2D one: 312 dots (3 px apart, 2 x 2 per glyph pixel of
  `LOGO_FONT`) fly in from random places with an ease-out after staggered delays, with a light orange wave
  running through; here they are 2 px glowing cubes (a MultiMesh), so the bloom picks them up. Then "L A T E N T
  S P A C E" and the subtitle fade in, Clawd stands on a hovering platform (MovingPlatform's meshes, jets
  flickering) with a token spinning beside him, both voxel models at twice the size, and "PRESS SPACE TO START"
  blinks. The logo and Clawd hang on the camera (placing them in the level from its position every frame left
  them a fraction of a pixel off the view's rounding, and they jittered), at `FRONT_Z` = 9 m, in front of the
  scenery's foreground layer (6 m), lifted by the 3 m the oblique projection moves a point at that depth down. Space / Enter / jump or a click opens the
  map; H and M work as in the game.
- **Map**: one row of 24 x 18 px level nodes per world, at 27 %, 47 % and 67 % of the height (`ROW_Y`; TS has
  two rows), far enough apart that Clawd hopping on a node never reaches the row above; the world's number and
  name (`WORLD_NAMES`: LATENT SPACE, BENCHMARK WARS, AGENT MODE) stand in a 100 px column left of its row, with a
  dotted rule out to the first node, and a locked world says over its row what opens it (`WORLD_HINTS`, the TS
  hint). The backdrop is dimmed, more so from the middle down where world 3's row lies over its lit ground. The nodes lie along a dotted path that lifts
  between them, with a light running along the open stretches; the selected node has the orange tab and border and Clawd hops on it (the
  game's 1 px Clawd as a 2D sprite; on a world-2 or world-3 node, once he has a weapon, he holds the equipped one as in a
  level, aiming right, `map_gun()`: TS's comment says "armed in world 2" but its code draws him unarmed); locked levels show a padlock, finished ones an orange corner, bosses a
  red-tinted node labelled BOSS. The banked tokens and the sparks not spent sit top right, next to the SHOP
  button (B), which opens once 1-1 is cleared. An
  info card (264 px wide) names the selected level (at twice the size when the name fits, else at the normal
  size, like 2-3's) with its subtitle, then left to right its sparks, rescued sub-agents, CLEARED and, in worlds 2
  and 3, ARMED, and the best time on the right; it doubles as a PLAY button. Left / right pick a level (locked: the denied sound), up / down a world, Space or
  Enter plays, Escape goes back to the title; the mouse picks a node and plays it on a second click.

`scripts/progress.gd` (autoload `Progress`) is the level part of `src/save.ts`, saved as JSON in
`user://progress.json`: per level completed, found sparks and rescued sub-agents (merged, never lost) and the
best time, plus the wallet of banked tokens and the shop's state (upgrade levels, sparks spent, consumables in
stock, which secrets HAIKU has told about, the last fortune). A level is unlocked when it is the first or the one
before it is completed (`App.isUnlocked()`).

## Shop

`scripts/shop.gd` (`Shop`) is what the shop sells and what buying does, `scripts/shop_screen.gd` (`ShopScreen`,
Main's `SHOP` mode over the drifting backdrop) draws it like `ShopScene` in `src/scenes/shop.ts`: the items by
section on the left (icon, name, level pips / stock, price in tokens and sparks, red when short), the selected
item's card on the right (description, level or stock, what Space does now), and HAIKU, the shopkeeper who
only speaks in 5-7-5: a blue Clawd with an orange bow tie (a voxel model at twice the size, hung on the camera)
whose haiku type out in a bubble (idle ones every 9 s, thanks, refusals, the fortunes). Prices are paid from
`Progress.wallet` and, for the rarer things, `Progress.sparks_available()`.

- From TS, the upgrades that work in world 1, at the TS prices (`loadoutFromSave()`): Extra Heart (+1 heart
  per level, 100 / 250 tokens + 4 sparks), Jet Tuning (+30 % hover per level, 60 / 160), Token Magnet (tokens
  within 72 px come loose and fly to Clawd, 120). Main applies them when a level loads (`_apply_loadout()`:
  `Player.max_hearts`, `hover_duration`).
- The weapons and gun mods of world 2 are one locked ARMORY row until Clawd finds a weapon (the blaster from
  1-B). Then `Shop.items()` puts two sections in its place: **ARMORY**, the five weapons at the TS prices
  (a gun icon from `GunSprite`; bought once, held at once, then EQUIPPED / OWNED; Space on an owned one equips
  it; the card shows the gun at four times the size and the 2D stat bars DAMAGE, FIRE RATE, RANGE, HEAT, plus a
  line for the cannon's splash and the beam's pierce) and **GUN MODS**: Bigger Model (100 / 220 + 2 sparks /
  400 + 6), Faster Inference (90 / 200 / 350), Longer Context (80 / 200), whose cards show the effect now and
  after the next level (`DAMAGE x1.25 → x1.50`). The list is then taller than the screen: it scrolls just
  enough to keep the selected row (and its section heading) in view, with ▲ / ▼ in the left margin; the wheel
  moves the selection too. HAIKU adds the TS's weapon haiku to its small talk.
- Added in the port: the **Spark Radar** (80 tokens; the HUD chevron), the **Fortune Haiku** (25
  tokens, repeatable: HAIKU names a spark or sub-agent still missing in a playable level, the stretch between
  checkpoints it is in and how high it is, read from the level map; each fortune tells about a new one), and two
  consumables, up to 3 in stock: **Firewall** (40; up at the start of every level while one is in stock, it
  takes the next hit instead of a heart and is only used up when it breaks) and **Double Tokens** (100; every
  token counts twice, used up when a level is cleared).
- Balance (M12): with 5× tokens a full clear of world 1 brings about 175 tokens (1-1 69, 1-2 64, 1-3 43) and of
  world 2 about 1190 (2-1 264, 2-2 269, 2-3 397, 2-4 259; the bosses drop none), against 750 for the world-1
  upgrades and radar and 2880 for the ARMORY and GUN MODS. One run through the game buys about two upgrades in
  world 1 and then a weapon or a mod after each world-2 level; everything takes about two more runs of world 2.
  The TS prices stay; the port's own items are priced for that income: Double Tokens pays off in world 2 only,
  and the radar costs no sparks, so as in TS the 35 sparks of the levels buy every spark price exactly (checked).

## Menus and key bindings

`scripts/game_menu.gd` (`GameMenu`, `Ui/Menu`, drawn over everything) holds the in-level menus of
`src/scenes/game.ts` and `src/scenes/keybinds.ts`, in the HUD's panel look (orange tab, titles at twice the
size, the selected row as a faint orange bar with a bright left edge and a `>` prompt):

- **Controls help** (`controls` key, H; or the HUD's CONTROLS button): what every key does, built from the
  current bindings like `controlLines()` (without its gamepad line: the port has no gamepad support); once a
  weapon is found it adds attack as spin / shoot, spin, aiming with the mouse or the keys, and switching weapons;
  once Codex dropped the Tool Call, a line for it (its keys / RMB). Enter (or its button) opens the keybindings.
- **Pause** (`pause` key, P, or Escape; or the HUD's pause button): RESUME, RESTART FROM CHECKPOINT, RESTART
  LEVEL, CRT FILTER: ON/OFF, CROSSHAIR: its colour (the port's; Enter or left / right cycle it, with a preview at
  the row's end), KEYBINDINGS, QUIT TO MAP (the world map, on the current level).
- **Keybindings**: every bindable action with 3 key slots drawn as keycaps. Enter (or a click) on a slot
  listens for the next key: Escape cancels, Backspace clears the slot (the last key of an action stays), a
  key that belongs to another action is refused with "X ALREADY BOUND TO ..." (W may be both jump and up, as
  in the default layout). RESET DEFAULTS, BACK.

`Main._input()` hands every event to `GameMenu.handle()` first, with mouse positions moved into SubViewport
pixels; the mouse hovers and clicks rows, slots and the HUD buttons. Menus navigate with the bound up/down/
left/right keys and always with the arrows. While a menu is open `Game.paused` stops the world; closing it
resumes two physics frames later, so the Space that picked RESUME is not also a jump.

`scripts/settings.gd` (autoload `Settings`) keeps the bindings (physical keycodes, so they follow key
positions, not the keyboard layout) and the CRT filter in `user://settings.cfg`, and writes the bindings into
the InputMap actions of the same names (`left right up down jump attack spin prev next pause shop mute controls`;
prev / next weapon are Q / E). Fixed keys like `FIXED_KEYS` in TS: Escape pauses and goes back, Enter / Space
confirm, Backspace goes back, 1-5 pick a weapon slot (`slot1`-`slot5`). The mouse buttons are added to the
actions too (`MOUSE`, like `mouseButton()` in `src/core/input.ts`): left = attack, right = spin, wheel down /
up = next / previous weapon. `Settings.key_label()` is `keyLabel()`
(arrows, letters and symbols as themselves, short names like SHIFT or BKSP).

## Voxel models

`scripts/voxel.gd` (`Voxel.mesh()`) turns text-grid sprites into voxel meshes: every palette character is a
column `size` wide (2 px by default), extruded to a per-character depth around z = 0; side faces cover only the
depth a neighbouring column does not. The material (`shaders/voxel.gdshader`) is unshaded and the vertex colours
are stored linear: the front face keeps the palette colour exactly and the other faces are darker or lighter by
a fixed factor (`SHADE`), or take a given `top` colour. The lanterns and tufts are in `scripts/decor.gd`.

The bug and the token are drawn at 1 px like Clawd. `scripts/bug_sprite.gd` (`BugSprite`) is the glitch beetle
of `BUG` in `src/render/sprites.ts`: a round shell with a thinner rim, a lit spot, the dark spot that hops between
the two walk frames and red eyes with a glint; one 2 px row shifts sideways when the 2D draw() would glitch it
(re-rolled 10 times a second). `scripts/token_sprite.gd` (`TokenSprite`) is the light orange coin of `drawToken()`
in `src/render/shapes.ts` with a rim, a lit side and a glint; it spins as whole-pixel widths (6, 4, 2 px) and
bobs in whole pixels. Both snap to the pixel grid. When a bug is stomped or a token collected, the node is freed
at once and `scripts/sprite_fx.gd` (`SpriteFx`) plays what is left: the flattened shell (a white flash, then
grey; hitstop holds it) or a sparkle with a fading light.

Clawd is drawn by `scripts/clawd_sprite.gd` (`ClawdSprite`) at 1 px resolution, from the 13 x 10 cell layout of
`clawdFrame()` in `src/render/sprites.ts`: an 18 x 16 px body with a shaded left column and bottom, a lit top rim
and right edge, eyes with a glint, arms and four legs per pose. `Player._update_visual()` picks the pose like
`drawClawd()` in `src/render/clawdView.ts` and adds: pupils that look ahead while running, up while rising and
down while falling (and back over the shoulder now and then when idle), arms that swing while running, and
squash & stretch (from `src/entities/player.ts`, plus a pinch when turning) drawn as a wider/flatter or
narrower/taller body instead of a scaled mesh. `ClawdSprite.mesh()` caches every combination it builds.
The visual snaps to whole pixels (the camera is pixel-aligned), so the sprite never lands between pixels. A
small `GlowLight` on Clawd warms the ground around him. Clawd and the bugs take a warm rim light from the GlowLight that reaches
them most (`GlowLight.rim_for()`, a lantern, token or firefly): `Voxel.mesh()` stores each pixel's silhouette
edges in UV.x, and `shaders/voxel.gdshader` lights the 1 px edge of the front face on the light's side and the
side faces turned towards it, in three steps.

## Look and feedback

The look is modern pixel art on 3D blocks, without scene lights: everything is unshaded and drawn per view
pixel. `scenes/main.tscn` renders the game into a `SubViewport` at the view size (~480×270, see `ViewScale`),
which the `SubViewportContainer` scales up by a whole factor with nearest filtering. The `WorldEnvironment`
only adds glow (HDR threshold 0.9; colours above 1.0 glow), and `shaders/crt.gdshader` draws the scanlines and
vignette of `Renderer.postFx()` over the window.

Each theme has a palette in `scripts/themes.gd` (`Themes.PALETTES`): haze gradient, ray colour and a light
colour for the background. The level blocks keep their black / white / orange look in every theme. World 3's
themes are new: `canopy` (turquoise dawn), `cliffs` (cold blue-grey), `sandbox` (warm sand), `ravine` (plum and
pink) and `router` (night-blue network), each with parallax layers of the existing kinds (ridges, terraces,
columns) on new seeds.

Back to front:

- `shaders/haze.gdshader` (`Background/Haze`): the palette's dark top to its haze at the horizon in dithered
  steps, with slanted light rays that pulse slowly and drift with the camera.
- Theme motif (`Background/Motif`, a ColorRect whose shader `Main.motif_shader_for()` finds by its name,
  `shaders/motif_<theme>.gdshader`, so a new theme's motif needs no registration; hidden for themes without one;
  ideas in `docs/scenery-themes.md`; the world-2 levels' own motifs are described under *World 2 levels*). Caves: `shaders/motif_caves.gdshader`, the loss landscape seen
  from the bottom of its valley: 1 px contour lines of a height field that rises above and below a meandering
  valley floor (every fourth an index line), faint away from the floor, and balls of light rolling along the
  floor (gradient descent), one per 420 px, each with a dithered halo that lights the contour lines within
  90 px. Additive, at a tenth of the camera's speed.
  Mesa: `shaders/motif_mesa.gdshader`, diff strata. Two ranges of flat-topped mesas (the far one at 0.07 of the
  camera's speed and hazier, the near one at 0.13), one per 280 / 360 px cell, standing at 70 / 80 % of the view's
  height. Their rock is a diff, one 5 px stratum per line: context in a neutral rock tone, added / removed lines in
  green / red with a "+" / "-" at their left end, dim "code" in each line, a lit ledge where a stratum steps out
  from under the one above (the cliffs erode outwards line by line) and a dark joint below it. Blocks of seven
  lines are sometimes a merge conflict: a `<<<<<<<` seam, two green lines, `=======`, two red lines, `>>>>>>>`;
  the markers (seven 3 px glyphs, repeated every 64 px so the trunks in front never hide them all, joined by a
  glowing crack) glow and pulse in the theme's ray colour and a spark runs along each seam. Opaque rock (the
  shader also gets the theme's `haze_color` and `mid_color`), fading into the haze lower down and fast below the
  mesas' foot, so pits keep their depth.
- Window motif (3D motifs among the scenery, a node built per level from `scripts/<theme>_motif.gd`, found by
  `Main.motif_script_for()`): `scripts/window_motif.gd`
  (`WindowMotif`) fills three layers (z = -21, -11, -8 m; parallax 0.2, 0.32, 0.42) with a window slot per
  cell, each running its own ~14 s life on `Game.time`: a text panel of 48-96 × 28-52 px
  (`shaders/motif_window.gdshader`) opens from its title bar down, types its lines of prompt / code in
  (2 px letters in words, some orange) with a blinking cursor, drifts 3 m back into the depth fog and from
  80 % of its life crumbles into pixels from the top, then reappears elsewhere in its cell with new text.
- Boss motif (the glitching forest): `Main` sets `glitch` on the scenery's materials in the boss theme;
  `shaders/scenery.gdshader` then tears 3 px rows sideways with a red / cyan cast, splits trunks into two
  strands over some 24 px bands, breaks cables off with a gap, and flickers whole boxes red or cyan.
- `Parallax` (see above), its baked grey layers tinted between the palette's haze and light colours and its
  stars, data rain and rings towards the light colour.
- `scripts/scenery.gd` (`Scenery`): the neural forest, three layers deep, drawn by `shaders/scenery.gdshader`:
  trunks (columns of a neuron layer with pulsing node sockets and signals climbing their fibres), sagging
  weight cables between neighbouring trunks that carry light pulses, and floating neurons, all in the
  palette's light colour. The camera is orthographic, so
  `Scenery.update()` moves each layer with the camera by its parallax factor; layers are generated from the
  level's `terrainSeed`. Per-theme motifs to add on top are collected in `docs/scenery-themes.md`.
- The level: all blocks use `shaders/terrain_pixels.gdshader`. On level load `Level.bake_cells()` writes one
  texel per 4 px cell (distance to open air, random, open cell above, solid). Front faces: a black body that
  steps darker away from air, faint panel seams, orange circuit traces with blinking nodes, rims where blocks
  meet air and a white/grey crust with orange sparkles on exposed tops. One-way platforms are crust strips
  with orange LEDs, spikes a bed of orange triangles across the whole block depth (5 rows of flat quads
  0.75 m apart, staggered, the back ones darker), corrupted blocks an animated orange glitch. Top faces are bands of
  view rows from the white front lip to dark speckled grey. Lower block corners that meet air below and to
  the side are rounded (4 px). One-way platforms are a thin strip (4 px tall,
  0.75 m deep), so they read as ledges rather than blocks. Blob shadows of Clawd and the enemies nearest the view
  (up to 16) are drawn on the top faces under them (`Level.shadow_at()`, `Level.set_shadows()`). The animation runs on `Game.time`, so hitstop and pause freeze it.
- Midground (a `Scenery` layer at z = -3 m between the level and the forest): big dark trunks with muted
  ledges sticking out, thick synapse bridges and a few neurons. It is anchored to the level and uses the
  level's perspective (`world_perspective` in the scenery shader), so it shifts against the level as the
  camera moves like a real object behind it. Less hazed than the forest so it reads nearer, enough that the
  ledges don't pass for platforms.
- `scripts/decor.gd` (`Decor.populate()`): props from the `terrainSeed`. On exposed tops: voxel lanterns at the
  back of the top band (behind Clawd), small tufts in the light colour at the front lip and the back that sway
  and bend away from Clawd as he walks through (`Decor.interact()`), and neuron flowers, a stalk with a glowing
  bulb and its own GlowLight (more in dark levels). Under ceilings and one-way platforms: data vines that hang
  and sway, some ending in a glowing node, and short dark drips. Sway is done in `shaders/voxel.gdshader`
  (instance `sway` / `bend`), rounded to whole pixels per row.
- Warm lights: `GlowLight` nodes (`scripts/glow_light.gd`, group `lights`) on lanterns, tokens and Clawd's hover
  jets. `Main` passes the visible ones nearest the view (at most 32) to `Level.set_lights()`; the terrain lights
  the pixels around them in four steps with an ordered dither between them. On block fronts only the crust
  within three cells of open air takes light.
- Air light: `scripts/motes.gd` (`Motes`) fills the level with fireflies / data motes at depths around the
  gameplay plane, 1 px glints with a dimmer cross that drift on slow loops and blink (more in dark levels);
  every tenth carries a small `GlowLight`. `shaders/light_fx.gdshader` (`Foreground/LightFx`, a CanvasLayer
  over the 3D view) adds light shafts in front of everything, scrolling faster than the level, and mist
  rising from the level's bottom edge so pits and the bottom fade into the haze; both are dithered and
  additive.
- Foreground: a `Scenery` layer in front of the level (parallax 1.35): clusters of big near-black data ferns
  (2 px voxels with a faint rim in the theme's light colour, swaying), dark broken trunk bases with a jagged
  top, rising from the level's bottom (in dark levels also hanging from its top), and thick dark cables
  hanging into the view.
- See-through windows: everything in front of the gameplay plane (ferns, stumps, hanging cables, front tufts,
  vines and flowers) is thinned out with an ordered dither in a circle around Clawd and the five enemies or
  tokens nearest him (`Main._update_reveal()`, `shaders/reveal.gdshaderinc`), down to a quarter of its pixels
  at the centre, so nothing the player needs to see hides behind the foreground.
- Depth fog: `shaders/fog.gdshaderinc`, used by the scenery and the terrain, fades every pixel by its depth
  behind the gameplay plane (`1 - e^(-depth * 0.06)`, thicker in the lower part of the view) into the sky
  colour of its view row (the haze gradient of the theme), so distant trunks dissolve into the sky behind
  them; motes dim with depth the same way.
- Darkness (levels with `dark`: 1-2), the 3D take on `drawDarkness()`: `shaders/darkness.gdshaderinc`, used by
  the terrain, the scenery, the voxel sprites and the motes, reads two global shader parameters
  (`[shader_globals]` in `project.godot`) that `Main` sets: `dark_amount` (0.93 in dark levels, the TS gradient's
  darkest alpha, else 0) and `dark_lamp`, Clawd's lamp: 1 m in front of his middle, radius 105 px breathing by
  3 px. A pixel keeps its colour within 35 % of the lamp's radius, measured in 3D, and sinks towards
  rgb(8, 8, 8) by the edge, in quarter steps with an ordered dither on a world-fixed grid; so the backs of
  blocks, the far scenery and the foreground stay dark while the block fronts near Clawd are lit. The terrain
  also takes light from the GlowLights (lanterns, sparks, checkpoints, the exit, motes), the sprites from the
  one that rims them; glowing pixels skip the darkness (glow materials, the scenery's nodes and pulses, the
  corrupted blocks and spike tips, so hazards read), circuit nodes do not. Motes away from the lamp dim to
  40 %; the haze and the parallax ridges dim to 30 %, the light shafts and mist thin out.
- Colour grade: `shaders/grade.gdshader` (`Grade`, the top canvas layer in the SubViewport) lifts the darks a
  little towards the theme's haze colour, warms the lights towards the lanterns' orange and adds a touch of
  saturation, pixel for pixel.

The player emits `event(kind, at)` for `jump`, `land`, `hard_land`, `hurt`, `stomp`, `defeat`, `spin`,
`pound_start`, `pound_land` and `drop_through`; `main.gd` answers
with particles (same counts and colors as `particles.emit` in `src/scenes/game.ts`), camera shake and
hitstop.

V-Sync is set to Mailbox (`display/window/vsync/vsync_mode=3`): plain V-Sync dropped to 1 fps on Wayland with
Intel graphics.

## Web build

```bash
godot --headless --export-release "Web" build/web/index.html
python3 -m http.server -d build/web 8080                # http://localhost:8080
```

The "Web" preset in `export_presets.cfg` builds without threads, so the output runs on any static host
without COOP/COEP headers.

## Layout

| Path | Contents |
|---|---|
| `project.godot` | 480×270 base view (integer-scaled by `ViewScale`), 60 Hz physics, input actions named as in `src/core/input.ts`, 3D physics layers `world`, `player`, `enemies`, `oneway` |
| `scenes/main.tscn`, `scripts/main.gd` | Main scene (title, map, shop and game modes): `View/SubViewport/World` holds the environment (glow), `Background/Haze` and `Background/Parallax`, `Scenery`, `Level` (current level), `Camera3D`, particles and the player; `ScreenFx/Crt` on top. `load_level(id)`, `next_level()` |
| `scenes/player.tscn`, `scripts/player.gd` | Clawd: movement, spin, ground pound, drop-through, spikes, enemy contact and stomps, voxel frames, spin ring, hover jets |
| `scripts/enemy.gd` | `Enemy`: base of the enemies (hp, hits, flash, death burst, tokens; group `enemies`) |
| `scenes/bug.tscn`, `scripts/bug.gd` | Patrolling bug (`E`) |
| `scripts/spam_bot.gd`, `scripts/shot.gd` | Spam bot (`F`) and the enemy projectile it fires |
| `scripts/rate_limiter.gd` | "429" crusher (`R`), also a platform |
| `scripts/turret.gd`, `scripts/drone.gd` | World 2's turret (`T` floor, `Y` ceiling) and drone (`D`) |
| `scripts/shield_bot.gd`, `scripts/injector.gd` | World 2's "403" shield bot (`H`) and prompt injector (`I`) |
| `scripts/hallucination.gd`, `scripts/fake_platform.gd` | World 1's boss (`B` in 1-B) and its fake platforms |
| `scripts/codex.gd`, `scripts/codex_hand.gd` | World 2's boss Codex (`B` in 2-B) and its two cursor hands |
| `scripts/code_shot.gd`, `scripts/column_beam.gd`, `scripts/codex_paint.gd` | Codex's code-character shots and shockwaves, its rm -rf columns; flat boxes redrawn each frame (its face, telegraphs) |
| `scripts/weapon_pickup.gd`, `scripts/gun_sprite.gd` | The Token Blaster lying in the arena; voxel guns |
| `scripts/tool_call.gd`, `scripts/anchor.gd` | World 3's Tool Call (hook, aim assist, zip) and the anchors it catches (`+`) |
| `scripts/parser.gd` | World 3's armoured Parser (`P`): the hook tears its shell off |
| `scripts/webhook.gd` | World 3's Webhook (`W`): patrols, dives, and is an anchor the hook stuns |
| `scripts/brittle.gd`, `scripts/retry_loop.gd` | World 3's brittle crates (`%`) and Retry Loops (`L`) |
| `shaders/motif_sandbox.gdshader` | Sandbox motif (3-3): container stacks built and torn down |
| `shaders/motif_ravine.gdshader` | Ravine motif (3-4): ravine walls, clocks timing out, spinners |
| `shaders/motif_cliffs.gdshader` | Cliffs motif (3-2): cliff pillars, callbacks flying between them |
| `scripts/echo_control.gd`, `scripts/echo.gd` | World 3's sub-agents: the recording, sending, slots; a sub-agent replaying and standing |
| `scripts/plate.gd`, `scripts/gate.gd` | World 3's pressure plates (`1`-`9`) and the gates they open (`a`-`i`, `z`) |
| `shaders/motif_canopy.gdshader` | Canopy motif (3-1): giant trees, vines with endpoint lanterns, requests and replies |
| `scripts/weapons.gd` | `Weapons`: the five weapons, gun mods and their loadout multipliers (`src/weapons.ts`) |
| `scripts/gun.gd` | `Gun`: firing, context heat and overflow, aiming (mouse polling, keys), switching, the gun in Clawd's hands |
| `scripts/bullet.gd`, `scripts/beam_fx.gd` | Clawd's bullets (token, pellet, glyph, orb); the Attention Beam's flashes |
| `scripts/rising_void.gd`, `shaders/void.gdshader` | The rising null of `risingVoid` levels (1-3) |
| `scripts/window_motif.gd`, `shaders/motif_window.gdshader` | Window motif: floating text windows that type in and crumble |
| `scenes/token.tscn`, `scripts/token.gd` | Collectible token |
| `scripts/clawd_sprite.gd`, `scripts/bug_sprite.gd`, `scripts/token_sprite.gd`, `scripts/sprite_fx.gd` | Voxel sprites of Clawd, the bug and the token; the flattened shell or sparkle left behind, see *Voxel models* |
| `scripts/checkpoint.gd` | Checkpoint terminal (`C`) |
| `scripts/goal.gd`, `shaders/portal.gdshader` | Exit gate (`G`) and its swirl |
| `scripts/sign.gd` | Tutorial sign (`?`) and its text bubble |
| `scripts/sub_agent.gd`, `shaders/beam.gdshader` | Sub-agent (`A`), its HELP bubble and rescue beam |
| `scripts/spark.gd`, `shaders/halo.gdshader` | Spark (`S`), its icon and its halo |
| `scripts/front_end.gd` | Title screen and world map |
| `scripts/progress.gd` | Saved progress: cleared levels, found sparks, rescued sub-agents, best times, wallet, shop state, weapons, world 3's tools |
| `scripts/shop.gd`, `scripts/shop_screen.gd` | The shop: items, prices, fortunes, the ARMORY; its screen and HAIKU |
| `scripts/moving_platform.gd` | Moving platform (`M`, `V`) |
| `scripts/pixel_font.gd`, `scripts/overlay.gd` | Bitmap font; text over the 3D view (popups, world text, panels) |
| `scripts/hud.gd` | HUD: hearts, found sparks, token counter, rescued sub-agents, CONTROLS / pause / mute buttons, level label, boss bar, weapon panel and crosshair |
| `scripts/game_menu.gd`, `scripts/settings.gd` | Pause, controls help and keybinding menus; saved bindings |
| `scripts/sound.gd` | Synthesized sound effects, music loops and the hover jet (`src/core/audio.ts`) |
| `scripts/level.gd` | `Level`: builds a level from map rows, tile lookup by pixel, level size |
| `scripts/px.gd`, `scripts/voxel.gd` | Pixel ↔ metre conversion; voxel meshes from text-grid sprites |
| `scripts/parallax.gd`, `scripts/view_scale.gd` | Theme backgrounds behind the level; view size from the window |
| `scripts/scenery.gd`, `scripts/glow_light.gd` | Towers and floating blocks behind the level, foreground silhouettes; warm lights for the terrain shader |
| `scripts/themes.gd`, `scripts/decor.gd` | Background palette per theme; lanterns and tufts on the level |
| `shaders/terrain_pixels.gdshader` | Level blocks (crust, circuits, one-way, spikes, corrupted glitch, lights, Clawd's shadow) |
| `shaders/darkness.gdshaderinc` | Darkness of dark levels around Clawd's lamp (global `dark_amount`, `dark_lamp`) |
| `shaders/motif_caves.gdshader` | Caves motif: contour lines of the loss landscape, rolling balls of light |
| `shaders/motif_mesa.gdshader` | Mesa motif: mesas of diff strata with glowing merge-conflict seams |
| `shaders/motif_forge.gdshader` | Forge motif: server racks and GPU monoliths with LEDs, heat sinks, glowing dies, fans and cables |
| `shaders/motif_swamp.gdshader` | Swamp motif: corrupted data pools mirroring the haze, cables, rising bubbles of injected text |
| `shaders/motif_towers.gdshader` | Towers motif: transformer stacks of translucent plates, a light running up the residual stream |
| `scripts/codex_motif.gd`, `shaders/codex_monolith.gdshader` | Codex motif: code monoliths in the depth with scrolling, syntax-coloured code and a blinking cursor |
| `shaders/scenery.gdshader`, `shaders/haze.gdshader`, `shaders/crt.gdshader` | Background towers; haze gradient and light rays; CRT scanlines and vignette |
| `scripts/fx.gd` | `Fx.burst()` emits into the level's particles |
| `scripts/particles.gd`, `shaders/particles.gdshader` | Particles as 1 px cubes in a MultiMesh (`src/render/particles.ts`) |
| `scripts/motes.gd`, `shaders/motes.gdshader`, `shaders/light_fx.gdshader` | Fireflies / data motes in the air; light shafts and rising mist over the view |
| `shaders/voxel.gdshader`, `shaders/grade.gdshader` | Voxel material (hit tint, sway, lit edges); colour grade on top of the view |
| `shaders/oblique.gdshaderinc`, `shaders/fog.gdshaderinc`, `shaders/reveal.gdshaderinc` | Shader includes: the oblique projection (every 3D material), depth fog, the foreground's see-through dither around Clawd |
| `scripts/game.gd`, `scripts/game_camera.gd`, `scripts/noise.gd` | Autoload `Game` (game time, hitstop, pause); the camera (`src/core/camera.ts`); `DotNoise`, bit-exact noise ports |
| `tools/check.gd`, `tools/checks/<id>.gd` | Headless checks and the per-level sections, see *Checks* |
| `levels/<id>.txt`, `levels/index.json`, `levels/<id>.tscn` | Level maps and metadata (edited by hand), and the 3D level scenes converted from them |
| `tiles/terrain_meshlib.tres` | MeshLibrary of the level GridMaps. Item id = tile id from `src/world/tiles.ts` minus one: `#` solid (0), `=` one-way (1), `^` spike (2), `X` corrupted (3); 4 is an invisible solid box (a shape, no mesh) for shut gates and brittle crates. Spikes have no collision shape; the player detects them by item like the TS version. Their mesh is the spike bed (`tools/build_meshlib.gd`), the others are boxes |
| `tools/build_meshlib.gd` | Generates `tiles/terrain_meshlib.tres` |
| `tools/convert_level.gd`, `tools/reach.gd` | Level pipeline: map → scene, reachability, see *Levels* |
| `addons/godot_ai/` | godot-ai editor plugin (MCP) |
