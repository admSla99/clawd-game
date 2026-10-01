import { describe, expect, it } from 'vitest';
import { STEP, TILE } from '../src/config';
import type { Action } from '../src/core/input';
import { overlaps, type Rect } from '../src/core/math';
import { Player, type Platform } from '../src/entities/player';
import { rectTouchesTile } from '../src/world/collision';
import { parseLevel, type Level } from '../src/world/level';
import { LEVELS } from '../src/world/levels';
import { T } from '../src/world/tiles';
import { FakeInput } from './helpers';

/**
 * Explores each level with Clawd's real physics: from every place he can stand,
 * try a set of runs and jumps (with and without hover) and see where he lands.
 * Enemies are ignored; moving platforms are sampled as static ones; corrupted
 * blocks count as already pounded through.
 */

interface Target {
  name: string;
  rect: Rect;
}

function staticPlatforms(level: Level): Platform[] {
  const out: Platform[] = [];
  const add = (x: number, y: number, w: number) => out.push({ x, y, w, dx: 0, dy: 0, active: true });
  for (const s of level.spawns) {
    if (s.kind === 'platformH') for (const o of [-3.5, -1.75, 0, 1.75, 3.5]) add(s.x - 24 + o * TILE, s.ty * TILE, 48);
    if (s.kind === 'platformV') for (const o of [-3.5, -1.75, 0, 1.75, 3.5]) add(s.x - 24, s.ty * TILE + o * TILE, 48);
    if (s.kind === 'ratelimiter') {
      // Its top rides from the floor back up to where it hangs.
      let floor = s.ty + 2;
      while (floor < level.h && level.get(s.tx, floor) !== T.SOLID) floor++;
      for (let y = s.ty * TILE; y <= (floor - 2) * TILE; y += TILE / 2) add(s.tx * TILE, y, 32);
    }
  }
  return out;
}

type Plan = { frames: number; actions: (f: number, p: Player) => Action[] }[];

function plans(dir: Action): Plan[] {
  const hold = (n: number, ...a: Action[]) => ({ frames: n, actions: () => a });
  const untilApex = (d: Action | null, hover: boolean) => ({
    frames: 260,
    actions: (_f: number, p: Player) => {
      const a: Action[] = d ? [d] : [];
      if (p.vy < 0 || hover) a.push('jump');
      return a;
    },
  });
  return [
    [hold(6, dir)],
    [hold(14, dir)],
    [hold(30, dir)],
    // Standing jumps of different heights.
    [hold(1, dir, 'jump'), untilApex(dir, false)],
    [hold(1, dir, 'jump'), untilApex(dir, true)],
    [hold(5, dir, 'jump'), { frames: 260, actions: () => [dir] }],
    // Running jumps.
    [hold(12, dir), hold(1, dir, 'jump'), untilApex(dir, false)],
    [hold(12, dir), hold(1, dir, 'jump'), untilApex(dir, true)],
    // Jump straight up, drift later.
    [hold(1, 'jump'), hold(14, 'jump'), untilApex(dir, false)],
    [hold(1, 'jump'), hold(14, 'jump'), untilApex(dir, true)],
    // Short hop then hover drift.
    [hold(1, dir, 'jump'), hold(8, dir, 'jump'), untilApex(dir, true)],
  ];
}

function explore(level: Level, targets: Target[]): Set<string> {
  const platforms = staticPlatforms(level);
  const world = { level, platforms };
  const reached = new Set<string>();
  const seen = new Set<string>();
  const queue: [number, number][] = [[level.start.x, level.start.y]];
  const input = new FakeInput();
  let budget = 6000;

  const check = (p: Player) => {
    const hb = p.hitbox;
    for (const t of targets) if (!reached.has(t.name) && overlaps(hb, t.rect)) reached.add(t.name);
  };

  const keyOf = (x: number, b: number) => `${Math.round(x / 6)},${Math.round(b)}`;
  seen.add(keyOf(level.start.x, level.start.y));
  while (queue.length && budget-- > 0) {
    const [sx, sb] = queue.shift()!;
    for (const dir of ['left', 'right'] as Action[]) {
      for (const plan of plans(dir)) {
        const p = new Player(sx, sb);
        input.set();
        p.update(STEP, input, world);
        if (!p.grounded) break;
        let dead = false;
        let wasAir = false;
        const stages = [...plan, { frames: 200, actions: () => [] as Action[] }];
        outer: for (const stage of stages) {
          for (let i = 0; i < stage.frames; i++) {
            input.set(...stage.actions(i, p));
            p.update(STEP, input, world);
            const hb = p.hitbox;
            if (p.y > level.pixelH + 20 || rectTouchesTile({ x: hb.x + 1, y: hb.y + hb.h - 6, w: hb.w - 2, h: 6 }, level, T.SPIKE)) {
              dead = true;
              break outer;
            }
            check(p);
            if (!p.grounded) wasAir = true;
            // A jump ends when Clawd lands; walks run their full length.
            if (p.grounded && (wasAir || stage === stages[stages.length - 1])) break outer;
          }
        }
        const k = keyOf(p.cx, p.bottom);
        if (!dead && p.grounded && !seen.has(k)) {
          seen.add(k);
          queue.push([p.cx, p.bottom]);
        }
      }
    }
  }
  return reached;
}

describe('levels are completable with Clawd’s physics', () => {
  for (const def of LEVELS.filter((d) => !d.boss)) {
    it(`${def.id}: exit, every spark and every sub-agent can be reached`, () => {
      // Pounded-through corrupted blocks.
      const level = parseLevel({ ...def, map: def.map.map((r) => r.replace(/X/g, ' ')) });
      const targets: Target[] = [];
      for (const s of level.spawns) {
        if (s.kind === 'spark') targets.push({ name: `spark#${s.index} (${s.tx},${s.ty})`, rect: { x: s.x - 7, y: s.y - 15, w: 14, h: 14 } });
        if (s.kind === 'agent') targets.push({ name: `agent#${s.index} (${s.tx},${s.ty})`, rect: { x: s.x - 7, y: s.y - 12, w: 14, h: 12 } });
        if (s.kind === 'goal') targets.push({ name: 'goal', rect: { x: s.x - 8, y: s.y - 40, w: 16, h: 40 } });
      }
      const reached = explore(level, targets);
      const missing = targets.filter((t) => !reached.has(t.name)).map((t) => t.name);
      expect(missing).toEqual([]);
    }, 60000);
  }
});
