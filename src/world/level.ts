import { TILE } from '../config';
import type { Track } from '../core/audio';
import { T, TILE_CHARS, type TileId } from './tiles';

export type Theme = 'plains' | 'caves' | 'window' | 'boss' | 'mesa' | 'forge' | 'swamp' | 'towers' | 'codex';

export type BossKind = 'hallucination' | 'codex';

export interface LevelDef {
  id: string;
  /** World 1 is pure platforming; in world 2 Clawd carries a gun. */
  world: 1 | 2;
  name: string;
  subtitle: string;
  theme: Theme;
  music: Track;
  map: string[];
  /** Texts for '?' signs, in reading order (top-to-bottom, left-to-right). */
  signs?: string[];
  /** Darkness with a light radius around Clawd. */
  dark?: boolean;
  /** A wall of null data that rises from the bottom (px/s, start delay s). */
  risingVoid?: { speed: number; delay: number };
  boss?: BossKind;
}

export type SpawnKind =
  | 'start'
  | 'spark'
  | 'token'
  | 'bug'
  | 'spambot'
  | 'ratelimiter'
  | 'checkpoint'
  | 'agent'
  | 'goal'
  | 'platformH'
  | 'platformV'
  | 'sign'
  | 'boss'
  | 'turret'
  | 'ceilturret'
  | 'drone'
  | 'shieldbot'
  | 'injector';

export const SPAWN_CHARS: Record<string, SpawnKind> = {
  '@': 'start',
  S: 'spark',
  o: 'token',
  E: 'bug',
  F: 'spambot',
  R: 'ratelimiter',
  C: 'checkpoint',
  A: 'agent',
  G: 'goal',
  M: 'platformH',
  V: 'platformV',
  '?': 'sign',
  B: 'boss',
  T: 'turret',
  Y: 'ceilturret',
  D: 'drone',
  H: 'shieldbot',
  I: 'injector',
};

export interface Spawn {
  kind: SpawnKind;
  tx: number;
  ty: number;
  /** Horizontal centre of the tile, world px. */
  x: number;
  /** Bottom edge of the tile, world px. */
  y: number;
  /** Order among spawns of the same kind (sparks, agents, signs). */
  index: number;
}

export class Level {
  readonly tiles: Uint8Array;
  readonly pixelW: number;
  readonly pixelH: number;

  constructor(
    readonly def: LevelDef,
    readonly w: number,
    readonly h: number,
    tiles: Uint8Array,
    readonly spawns: Spawn[],
  ) {
    this.tiles = tiles;
    this.pixelW = w * TILE;
    this.pixelH = h * TILE;
  }

  /** Out of bounds: left/right are walls, above and below are open (falling out = void). */
  get(tx: number, ty: number): TileId {
    if (tx < 0 || tx >= this.w) return T.SOLID;
    if (ty < 0 || ty >= this.h) return T.EMPTY;
    return this.tiles[ty * this.w + tx] as TileId;
  }

  set(tx: number, ty: number, t: TileId): void {
    if (tx < 0 || tx >= this.w || ty < 0 || ty >= this.h) return;
    this.tiles[ty * this.w + tx] = t;
  }

  spawnsOf(kind: SpawnKind): Spawn[] {
    return this.spawns.filter((s) => s.kind === kind);
  }

  get start(): Spawn {
    const s = this.spawns.find((sp) => sp.kind === 'start');
    if (!s) throw new Error(`Level ${this.def.id} has no start '@'`);
    return s;
  }
}

export function parseLevel(def: LevelDef): Level {
  const rows = def.map;
  const h = rows.length;
  const w = rows.reduce((m, r) => Math.max(m, r.length), 0);
  const tiles = new Uint8Array(w * h);
  const spawns: Spawn[] = [];
  const counters = new Map<SpawnKind, number>();

  for (let ty = 0; ty < h; ty++) {
    const row = rows[ty];
    for (let tx = 0; tx < w; tx++) {
      const ch = row[tx] ?? ' ';
      if (ch === ' ' || ch === '.') continue;
      const tile = TILE_CHARS[ch];
      if (tile !== undefined) {
        tiles[ty * w + tx] = tile;
        continue;
      }
      const kind = SPAWN_CHARS[ch];
      if (!kind) throw new Error(`Level ${def.id}: unknown map char '${ch}' at ${tx},${ty}`);
      const index = counters.get(kind) ?? 0;
      counters.set(kind, index + 1);
      spawns.push({ kind, tx, ty, x: tx * TILE + TILE / 2, y: (ty + 1) * TILE, index });
    }
  }
  return new Level(def, w, h, tiles, spawns);
}

/**
 * Glue equally tall map segments side by side. Rows shorter than `width`
 * are padded, and missing rows at the top are filled with `fill`.
 */
export interface Segment {
  width: number;
  rows: string[];
  /** Character used for rows above the given ones (default: empty). */
  top?: string;
}

export function stitch(height: number, segments: Segment[]): string[] {
  const out: string[] = Array.from({ length: height }, () => '');
  for (const seg of segments) {
    const pad = height - seg.rows.length;
    if (pad < 0) throw new Error('Segment taller than level');
    for (let y = 0; y < height; y++) {
      const src = y < pad ? (seg.top ?? ' ').repeat(seg.width) : seg.rows[y - pad];
      if (src.length > seg.width) throw new Error(`Segment row too long (${src.length} > ${seg.width}): "${src}"`);
      out[y] += src.padEnd(seg.width, ' ');
    }
  }
  return out;
}
