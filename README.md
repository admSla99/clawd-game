# CLAWD — Latent Space

![CLAWD title screen](docs/title-screen.png)

A 2.5D platformer/shooter starring Clawd, made in **Godot 4.7.2** (GDScript). **World 1** is a platformer. At its
end Clawd finds the **Token Blaster**, and **World 2** turns into a shooter: aim with the mouse, fire tokens, and
buy better weapons and upgrades in the shop. The boss of World 2 is **Codex**. **World 3** is in the works
(`godot/docs/world3-plan.md`).

The game lives in [`godot/`](godot/); [`godot/README.md`](godot/README.md) is its detailed design doc (rendering,
levels, every system, checks, layout). It started as a port of a TypeScript browser game, which is kept on the
`ts-legacy` branch; the 2D Godot port is on `godot-2d-port`.

## Running

Open `godot/project.godot` in Godot 4.7.2 and press F5, or from `godot/`:

```bash
godot --path .                                   # play
godot --headless --script tools/check.gd         # every check, exits non-zero on failure
godot --headless --script tools/reach.gd         # every level's exit, sparks and sub-agents are reachable
```

## Controls

| Input | Action |
|---|---|
| ← → / A D | Move |
| Space / W / K | Jump (every jump is a full jump) |
| Hold jump in the air | Hover (the jet hurts enemies) |
| X / J · left mouse button | World 1: spin · World 2: shoot |
| C / L · right mouse button | Spin |
| ↓ / S in the air | Ground pound (breaks purple "corrupted" blocks) |
| ↓ + Space | Drop through a platform |
| Mouse | World 2: aim (↑ / ↓ + X aims without a mouse) |
| 1–5 · Q E · mouse wheel | Switch weapon |
| B (on the map) | Shop |
| Esc / P · M · H | Pause · mute · controls |
| Pause → Keybindings | Rebind keys |

The pause menu also has the CRT filter and the crosshair's colour. Keyboard and mouse only.

## Content

**World 1 — Latent Space** (platformer)
- 1-1 Token Plains, 1-2 Gradient Caves (dark), 1-3 Context Window (rising void)
- 1-B The Hallucination: drops the Token Blaster, unlocking World 2

**World 2 — Benchmark Wars** (shooter)
- 2-1 Merge Conflict Mesa: turrets, drones, shield bots
- 2-2 GPU Forge: hot vents, ceiling turrets, 429 crushers, moving platforms
- 2-3 Prompt Injection Swamp: injectors (they split into bugs when destroyed), islands
- 2-4 The Diff Towers: a vertical climb under fire
- 2-B Codex: a monitor with two giant cursor hands, autocomplete walls, `{ }` volleys, "npm test" bugs and
  `rm -rf` beams, in 3 phases

**Weapons** (Context = heat; when it overflows the weapon has to cool down): Token Blaster (found), Context
Spreader, Stream Output, Attention Beam, Opus Cannon.

**Shop**: upgrades (Extra Heart, Bigger Model, Faster Inference, Longer Context, Jet Tuning, Token Magnet), tools
(Spark Radar, Fortune Haiku), consumables (Firewall, Double Tokens) and, once a weapon is found, the armory.

Tokens collected in a level are added to your wallet when you finish it; every 300 tokens in a level give a heart.
Sparks are spent in the shop but still count as found on the map.

## Repository

| Path | What |
|---|---|
| `godot/` | The game (scenes, scripts, shaders, levels, tools); see `godot/README.md` |
| `godot/docs/` | Plans: `port-plan.md` (the finished port), `world3-plan.md`, `scenery-themes.md` |
| `docs/` | Images for this README |
| `references/` | Reference images |
