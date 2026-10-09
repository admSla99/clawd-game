# CLAWD — Godot vertical slice

Godot 4.7.2 port of the game in `../src`. GDScript; Forward+ renderer on desktop, Compatibility (WebGL 2) on the web export.

## Setup on a new machine (Linux x86_64)

```bash
cd godot
./tools/install_godot.sh                                # editor + web export templates (resumes if cut off)
godot --headless --script tools/build_tileset.gd        # regenerates tiles/terrain.{png,tres}
node tools/export_levels.mjs                            # run from repo root: src levels -> levels/*.txt
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

The project uses only built-in Godot features (TileMapLayer, canvas shaders, GDScript); no editor plugins.

## Levels

Levels stay authored in `../src/world/levels/*.ts`. After changing one, regenerate:

```bash
node godot/tools/export_levels.mjs                      # from the repo root
cd godot && godot --headless --script tools/convert_level.gd -- 1-1   # ids optional; none = all
```

`export_levels.mjs` writes each level's `map` rows to `levels/<id>.txt` and the id/name list to
`levels/index.json`. `convert_level.gd` paints the tile characters (`#` `=` `^` `X`, same as `TILE_CHARS`
in `src/world/tiles.ts`) into a TileMapLayer and adds a child per spawn: `@` → `Start` marker,
`E` → `scenes/bug.tscn`, `o` → `scenes/token.tscn`. Other spawn characters are skipped. The result is saved as `levels/<id>.tscn`.

## Running

The game starts in `scenes/level_select.tscn`: one button per entry in `levels/index.json`. A button sets
`Main.start_level` and switches to `scenes/main.tscn`, which loads that level and puts the player on its
`Start` marker. **N** loads the next level (wrapping after 2-B).

Gameplay ported so far: run, variable jump, coyote time, jump buffer and hover from
`src/entities/player.ts`; spikes knock Clawd back and cost a heart; bugs patrol, turn at walls and ledges,
hurt on contact and die when stomped; tokens are collected on touch. Falling out of the level or losing
the last heart respawns on `@` with full hearts.

## Checks

```bash
godot --headless --script tools/check.gd     # exits non-zero on failure
```

Compares the noise functions with values computed from `src/core/noise.ts`, every converted level with its
`.txt` map, the player's jump height and gap/step limits with the level-design rules in
`tests/player.test.ts`, the level select and level switching, and spikes, bugs, stomps and tokens in 1-1.

## Game clock, camera and view

- `Game` (autoload, `scripts/game.gd`): game time and hitstop. Level objects skip their update while
  `Game.frozen()`, so hitstop and pause stop the world like in `src/scenes/game.ts`.
- `ViewScale` (autoload, `scripts/view_scale.gd`): view size from the window like `Renderer.resize()` in
  `src/render/renderer.ts` (integer scale, view about 270 tall and at least ~420 wide).
- `scripts/game_camera.gd`: port of `src/core/camera.ts` (look-ahead, vertical deadzone, small levels
  centred, trauma shake).
- `scripts/noise.gd` (`DotNoise`): bit-exact ports of `hash2`, `valueNoise2`, `periodicNoise1`, `mulberry32`.
- `scripts/particles.gd`: port of `src/render/particles.ts`; emit with the same options as `particles.emit`.

## Glow and feedback

`project.godot` turns on `rendering/viewport/hdr_2d`, so colors brighter than 1.0 reach the glow in the
`WorldEnvironment` of `scenes/main.tscn` (screen blend, HDR threshold 0.9). Clawd's palette, tokens and the
spike tiles (via the tile `modulate`) use such colors; `Fx.glow()` scales a color for this. In Compatibility
(web) the glow is much weaker than in Forward+.

The player emits `event(kind, at)` for `jump`, `land`, `hard_land`, `hurt` and `stomp`; `main.gd` answers
with particles (same counts and colors as `particles.emit` in `src/scenes/game.ts`), camera shake and
hitstop. Squash & stretch scales
Clawd's drawing, not the collision shape, with the factors from `src/entities/player.ts`.

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
| `project.godot` | 480×270 base view (270 px tall, same as `BASE_VIEW_H`), pixel snapping, nearest filtering, 60 Hz physics, input actions named as in `src/core/input.ts` |
| `scenes/level_select.tscn`, `scripts/level_select.gd` | Start scene, level buttons |
| `scenes/main.tscn`, `scripts/main.gd` | Game scene: `Terrain` (current level, with the dot-matrix material), `Camera2D`, player. `load_level(id)`, `next_level()` |
| `scenes/player.tscn`, `scripts/player.gd` | Clawd: movement, spikes, enemy contact and stomps |
| `scenes/bug.tscn`, `scripts/bug.gd` | Patrolling bug (group `enemies`) |
| `scenes/token.tscn`, `scripts/token.gd` | Collectible token |
| `scripts/fx.gd` | `Fx.burst()` emits into the level's particles, `Fx.glow()` HDR colors |
| `tools/check.gd` | Headless checks, see *Checks* |
| `scripts/pixel_art.gd` | Draws text-grid sprites like `drawSprite` in `src/render/sprites.ts` |
| `levels/<id>.txt`, `levels/index.json`, `levels/<id>.tscn` | Level maps exported from `src`, and the TileMapLayer scenes converted from them |
| `tiles/terrain.tres` | 16 px TileSet. Atlas column = tile id from `src/world/tiles.ts` minus one: `#` solid (0), `=` one-way (1), `^` spike (2), `X` corrupted (3). Collision on physics layer `world` for all but spikes, which the player detects by `kind` like the TS version; custom data `kind` holds the name |
| `shaders/dot_matrix.gdshader` | Canvas shader that draws a node as world-space dots (4 px grid, `DOT` in `src/config.ts`); applied to `Terrain` |
| `tools/build_tileset.gd` | Generates `tiles/terrain.png` and `tiles/terrain.tres`; its `TILES` table is the char → atlas column mapping |
| `tools/export_levels.mjs`, `tools/convert_level.gd` | Level pipeline, see *Levels* |
