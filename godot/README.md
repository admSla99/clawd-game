# CLAWD — Godot 2.5D vertical slice

Godot 4.7.2 port of the game in `../src`, rebuilt in 3D with a side camera (2.5D). The 2D port is on the
`godot-2d-port` branch. GDScript; Forward+ renderer on desktop, Compatibility (WebGL 2) on the web export.

## Setup on a new machine (Linux x86_64)

```bash
cd godot
./tools/install_godot.sh                                # editor + web export templates (resumes if cut off)
godot --headless --script tools/build_meshlib.gd        # regenerates tiles/terrain_meshlib.tres
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

The game uses only built-in Godot features (GridMap, GDScript). The `addons/godot_ai` editor plugin
([godot-ai](https://github.com/hi-godot/godot-ai) 4.3.0) lets Claude Code drive the editor and the running game
over MCP; `../.mcp.json` registers its server for this project. It needs `uv` (`uvx`) and a GUI editor, as it does
not start in `--headless` mode. Its `_mcp_game_helper` autoload also runs in exported builds.

## Levels

Levels stay authored in `../src/world/levels/*.ts`. After changing one, regenerate:

```bash
node godot/tools/export_levels.mjs                      # from the repo root
cd godot && godot --headless --script tools/convert_level.gd -- 1-1   # ids optional; none = all
```

`export_levels.mjs` writes each level's `map` rows to `levels/<id>.txt` and the id/name list to
`levels/index.json`. `convert_level.gd` runs `Level.build()` (`scripts/level.gd`): it places the tile characters
(`#` `=` `^` `X`, same as `TILE_CHARS` in `src/world/tiles.ts`) as GridMap cells and adds a child per spawn:
`@` → `Start` marker, `E` → `scenes/bug.tscn`, `o` → `scenes/token.tscn`. Other spawn characters are skipped.
The result is saved as `levels/<id>.tscn`.

One tile is 1 m; tile `(x, y)` of the map fills `x..x+1` × `-(y+1)..-y`, so the level's top-left corner is the
origin and y points up. Blocks are 3 m deep, centred on the gameplay plane z = 0. One-way platforms (`=`) sit in
their own `OneWay` GridMap on physics layer `oneway`; the player collides with that layer only while falling with
its body clear of the platform.

## Running

The game starts in `scenes/level_select.tscn`: one button per entry in `levels/index.json`. A button sets
`Main.start_level` and switches to `scenes/main.tscn`, which loads that level and puts the player on its
`Start` marker. **N** loads the next level (wrapping after 2-B).

Gameplay ported so far: run, variable jump, coyote time, jump buffer and hover from
`src/entities/player.ts`; spikes knock Clawd back and cost a heart; bugs patrol, turn at walls and ledges,
hurt on contact and die when stomped; tokens are collected on touch. Falling out of the level or losing
the last heart respawns on `@` with full hearts.

Game logic keeps the TS units: positions and speeds in pixels with y down (`pos`, `vel` on the player and bugs,
16 px per tile), so the constants are the ones from `src/config.ts`. `scripts/px.gd` (`Px`) converts between
level pixels and metres; the player and bugs convert `vel` to `velocity` only around `move_and_slide()`.

## Checks

```bash
godot --headless --script tools/check.gd     # exits non-zero on failure
```

Compares the noise functions with values computed from `src/core/noise.ts`, every converted level's GridMap
cells and spawns with its `.txt` map, the player's jump height and gap/step limits with the level-design rules in
`tests/player.test.ts`, the level select and level switching, and spikes, bugs, stomps and tokens in 1-1.

## Game clock and camera

- `Game` (autoload, `scripts/game.gd`): game time and hitstop. Level objects skip their update while
  `Game.frozen()`, so hitstop and pause stop the world like in `src/scenes/game.ts`.
- `ViewScale` (autoload, `scripts/view_scale.gd`): view size from the window like `Renderer.resize()` in
  `src/render/renderer.ts` (integer scale, view about 270 tall and at least ~420 wide), same as the 2D port.
- `scripts/game_camera.gd`: port of `src/core/camera.ts` (look-ahead, vertical deadzone, small levels
  centred, trauma shake) on an orthographic `Camera3D` that looks straight down -z. It works in level pixels on
  the gameplay plane; one level pixel is exactly one view pixel on both axes. Depth comes from the oblique
  projection in `shaders/oblique.gdshaderinc`, which every 3D material calls from `vertex()`: a point moves up
  by a third of its distance behind the gameplay plane, as if the camera were pitched down atan(1/3) (~18.4°).
  One view row covers 3 px of depth (`ROW_Z`), so the 3 m deep blocks show a 16 px top band. A pitched
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

## Voxel models

`scripts/voxel.gd` (`Voxel.mesh()`) turns text-grid sprites into voxel meshes: every palette character is a
column `size` wide (2 px by default), extruded to a per-character depth around z = 0; side faces cover only the
depth a neighbouring column does not. The material (`shaders/voxel.gdshader`) is unshaded and the vertex colours
are stored linear: the front face keeps the palette colour exactly and the other faces are darker or lighter by
a fixed factor (`SHADE`), or take a given `top` colour. The bug's frames are `FRAMES` in `scripts/bug.gd`, the
token's `ROWS` in `scripts/token.gd`, the lanterns and tufts are in `scripts/decor.gd`.

Clawd is drawn by `scripts/clawd_sprite.gd` (`ClawdSprite`) at 1 px resolution, from the 13 x 10 cell layout of
`clawdFrame()` in `src/render/sprites.ts`: an 18 x 16 px body with a shaded left column and bottom, a lit top rim
and right edge, eyes with a glint, arms and four legs per pose. `Player._update_visual()` picks the pose like
`drawClawd()` in `src/render/clawdView.ts` and adds: pupils that look ahead while running, up while rising and
down while falling (and back over the shoulder now and then when idle), arms that swing while running, and
squash & stretch (from `src/entities/player.ts`, plus a pinch when turning) drawn as a wider/flatter or
narrower/taller body instead of a scaled mesh. `ClawdSprite.mesh()` caches every combination it builds.
The visual snaps to whole pixels (the camera is pixel-aligned), so the sprite never lands between pixels. A
small `GlowLight` on Clawd warms the ground around him.

## Look and feedback

The look is modern pixel art on 3D blocks, without scene lights: everything is unshaded and drawn per view
pixel. `scenes/main.tscn` renders the game into a `SubViewport` at the view size (~480×270, see `ViewScale`),
which the `SubViewportContainer` scales up by a whole factor with nearest filtering. The `WorldEnvironment`
only adds glow (HDR threshold 0.9; colours above 1.0 glow), and `shaders/crt.gdshader` draws the scanlines and
vignette of `Renderer.postFx()` over the window.

Each theme has a palette in `scripts/themes.gd` (`Themes.PALETTES`): haze gradient, ray colour and a light
colour for the background. The level blocks keep their black / white / orange look in every theme.

Back to front:

- `shaders/haze.gdshader` (`Background/Haze`): the palette's dark top to its haze at the horizon in dithered
  steps, with slanted light rays that pulse slowly and drift with the camera.
- `Parallax` (see above), its baked grey layers tinted between the palette's haze and light colours and its
  stars, data rain and rings towards the light colour.
- `scripts/scenery.gd` (`Scenery`): three layers of towers and floating blocks behind the level, drawn by
  `shaders/scenery.gdshader` (lit rim, panel edges, windows blinking in the light colour, a few orange), mixed
  further into the haze with depth. The camera is orthographic, so `Scenery.update()` moves each layer with the
  camera by its parallax factor; layers are generated from the level's `terrainSeed`.
- The level: all blocks use `shaders/terrain_pixels.gdshader`. On level load `Level.bake_cells()` writes one
  texel per 4 px cell (distance to open air, random, open cell above, solid). Front faces: a black body that
  steps darker away from air, faint panel seams, orange circuit traces with blinking nodes, rims where blocks
  meet air and a white/grey crust with orange sparkles on exposed tops. One-way platforms are crust strips
  with orange LEDs, spikes orange triangles, corrupted blocks an animated orange glitch. Top faces are bands of
  view rows from the white front lip to dark speckled grey. One-way platforms are a thin strip (4 px tall,
  0.75 m deep), so they read as ledges rather than blocks. Clawd's blob shadow is drawn on the top face under
  him (`Level.set_shadow()`). The animation runs on `Game.time`, so hitstop and pause freeze it.
- `scripts/decor.gd` (`Decor.populate()`): props on exposed tops from the `terrainSeed`: voxel lanterns at the
  back of the top band (behind Clawd) and small tufts in the light colour at the front lip and the back.
- Warm lights: `GlowLight` nodes (`scripts/glow_light.gd`, group `lights`) on lanterns, tokens and Clawd's hover
  jets. `Main` passes the visible ones nearest the view (at most 32) to `Level.set_lights()`; the terrain lights
  the pixels around them in four steps with an ordered dither between them. On block fronts only the crust
  within three cells of open air takes light.
- Foreground: a `Scenery` layer in front of the level (parallax 1.35) of dark stepped silhouettes with a jagged,
  grassy edge, rising from the level's bottom and in dark levels also hanging from its top.

The player emits `event(kind, at)` for `jump`, `land`, `hard_land`, `hurt` and `stomp`; `main.gd` answers
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
| `scenes/level_select.tscn`, `scripts/level_select.gd` | Start scene, level buttons |
| `scenes/main.tscn`, `scripts/main.gd` | Game scene: `View/SubViewport/World` holds the environment (glow), `Background/Haze` and `Background/Parallax`, `Scenery`, `Level` (current level), `Camera3D`, particles and the player; `ScreenFx/Crt` on top. `load_level(id)`, `next_level()` |
| `scenes/player.tscn`, `scripts/player.gd` | Clawd: movement, spikes, enemy contact and stomps, voxel frames, hover jets |
| `scenes/bug.tscn`, `scripts/bug.gd` | Patrolling bug (group `enemies`) |
| `scenes/token.tscn`, `scripts/token.gd` | Collectible token |
| `scripts/level.gd` | `Level`: builds a level from map rows, tile lookup by pixel, level size |
| `scripts/px.gd`, `scripts/voxel.gd` | Pixel ↔ metre conversion; voxel meshes from text-grid sprites |
| `scripts/parallax.gd`, `scripts/view_scale.gd` | Theme backgrounds behind the level; view size from the window |
| `scripts/scenery.gd`, `scripts/glow_light.gd` | Towers and floating blocks behind the level, foreground silhouettes; warm lights for the terrain shader |
| `scripts/themes.gd`, `scripts/decor.gd` | Background palette per theme; lanterns and tufts on the level |
| `shaders/terrain_pixels.gdshader` | Level blocks (crust, circuits, one-way, spikes, corrupted glitch, lights, Clawd's shadow) |
| `shaders/scenery.gdshader`, `shaders/haze.gdshader`, `shaders/crt.gdshader` | Background towers; haze gradient and light rays; CRT scanlines and vignette |
| `scripts/fx.gd` | `Fx.burst()` emits into the level's particles |
| `tools/check.gd` | Headless checks, see *Checks* |
| `levels/<id>.txt`, `levels/index.json`, `levels/<id>.tscn` | Level maps exported from `src`, and the 3D level scenes converted from them |
| `tiles/terrain_meshlib.tres` | MeshLibrary of the level GridMaps. Item id = tile id from `src/world/tiles.ts` minus one: `#` solid (0), `=` one-way (1), `^` spike (2), `X` corrupted (3). Spikes have no collision shape; the player detects them by item like the TS version |
| `tools/build_meshlib.gd` | Generates `tiles/terrain_meshlib.tres` |
| `tools/export_levels.mjs`, `tools/convert_level.gd` | Level pipeline, see *Levels* |
| `addons/godot_ai/` | godot-ai editor plugin (MCP) |
