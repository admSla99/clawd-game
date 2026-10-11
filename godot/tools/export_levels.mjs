// Writes the map of every level in src/world/levels to godot/levels/<id>.txt, one map row per line,
// and godot/levels/index.json with each level's metadata in play order (LEVELS in index.ts).
// godot/levels/overrides.json replaces metadata fields per level id where the port differs from the TS game
// (e.g. sign texts: every jump in the port is a full jump).
// Run from the repo root: node godot/tools/export_levels.mjs
import { mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';

const src = new URL('../../src/world/levels/', import.meta.url);
const out = new URL('../levels/', import.meta.url);
mkdirSync(out, { recursive: true });

// index.ts uses extensionless imports, which Node cannot resolve; the level files only import types.
const defs = new Map();
for (const file of readdirSync(src).filter((f) => f !== 'index.ts')) {
  for (const [name, def] of Object.entries(await import(new URL(file, src)))) defs.set(name, def);
}
const order = readFileSync(new URL('index.ts', src), 'utf8').match(/LEVELS: LevelDef\[\] = \[([^\]]*)\]/)[1].split(',').map((s) => s.trim());

const overrides = JSON.parse(readFileSync(new URL('overrides.json', out), 'utf8'));

const index = order.map((name, i) => {
  const def = defs.get(name);
  writeFileSync(new URL(`${def.id}.txt`, out), def.map.join('\n') + '\n');
  console.log(`levels/${def.id}.txt`);
  const { map, ...meta } = def;
  // Terrain seed as in GameScene: new TerrainRenderer(level, 7 + levelIndex * 13).
  return { ...meta, ...overrides[def.id], index: i, terrainSeed: 7 + i * 13 };
});
writeFileSync(new URL('index.json', out), JSON.stringify(index, null, 2) + '\n');
