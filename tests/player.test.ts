import { describe, expect, it } from 'vitest';
import { PLAYER, TILE } from '../src/config';
import { makeLevel, Sim } from './helpers';

const FLAT = ['                              ', '                              ', '                              ', '                              ', '                              ', '                              ', '                              ', '  @                           ', '##############################'];

/** Map with a gap of `gap` tiles starting right after column `edge`. */
function gapMap(gap: number): string[] {
  const edge = 8;
  const ground = '#'.repeat(edge + 1) + ' '.repeat(gap) + '#'.repeat(30);
  return [...Array(10).fill(''), '  @', ground, ground, ground];
}

function stepMap(height: number): string[] {
  const rows: string[] = Array(13).fill('');
  for (let i = 0; i < height; i++) rows[12 - i] = ' '.repeat(10) + '#'.repeat(10);
  rows[12] = '  @' + rows[12].slice(3);
  rows.push('#'.repeat(20));
  return rows;
}

describe('player movement', () => {
  it('settles on the ground', () => {
    const sim = new Sim(makeLevel(FLAT));
    sim.run(5);
    expect(sim.player.grounded).toBe(true);
    expect(sim.player.bottom).toBe(8 * TILE);
  });

  it('accelerates to run speed and stops again', () => {
    const sim = new Sim(makeLevel(FLAT));
    sim.run(30, 'right');
    expect(sim.player.vx).toBeCloseTo(PLAYER.runSpeed);
    sim.run(10);
    expect(sim.player.vx).toBe(0);
  });

  it('full jump reaches ~4.5 tiles, a tap jump much less', () => {
    const full = new Sim(makeLevel(FLAT));
    full.run(3);
    const ground = full.player.bottom;
    let minBottom = ground;
    for (let i = 0; i < 60; i++) {
      // Hold until the apex, then release so hover does not kick in.
      full.run(1, ...(full.player.vy < 0 || i === 0 ? (['jump'] as const) : []));
      minBottom = Math.min(minBottom, full.player.bottom);
    }
    const fullH = ground - minBottom;
    expect(fullH).toBeGreaterThan(TILE * 4.2);
    expect(fullH).toBeLessThan(TILE * 5);

    const tap = new Sim(makeLevel(FLAT));
    tap.run(3);
    tap.run(2, 'jump');
    let tapMin = ground;
    for (let i = 0; i < 60; i++) {
      tap.run(1);
      tapMin = Math.min(tapMin, tap.player.bottom);
    }
    expect(ground - tapMin).toBeLessThan(fullH * 0.6);
  });

  it('allows a jump shortly after running off a ledge (coyote time)', () => {
    const sim = new Sim(makeLevel(gapMap(20)));
    sim.run(3);
    sim.until(() => !sim.player.grounded, 200, 'right');
    sim.run(3, 'right');
    expect(sim.player.grounded).toBe(false);
    sim.run(1, 'right', 'jump');
    expect(sim.player.vy).toBeLessThan(-PLAYER.jumpVelocity * 0.9);
  });

  it('buffers a jump pressed just before landing', () => {
    const sim = new Sim(makeLevel(FLAT));
    sim.run(3);
    sim.run(1, 'jump');
    sim.until(() => sim.player.vy > 200, 120);
    sim.until(() => sim.player.bottom > 8 * TILE - 10, 60);
    sim.run(1, 'jump');
    sim.until(() => sim.player.grounded || sim.player.vy < 0, 30, 'jump');
    sim.run(1, 'jump');
    expect(sim.player.vy).toBeLessThan(0);
  });

  it('hovering slows the fall and runs out', () => {
    const sim = new Sim(makeLevel(FLAT));
    sim.run(3);
    sim.until(() => sim.player.hovering, 60, 'jump');
    expect(sim.player.hovering).toBe(true);
    sim.run(10, 'jump');
    expect(sim.player.vy).toBeLessThanOrEqual(PLAYER.hoverFallSpeed + 1);
    sim.run(Math.ceil(PLAYER.hoverDuration * 60), 'jump');
    expect(sim.player.hovering).toBe(false);
  });

  it('can be hurt and becomes invulnerable', () => {
    const sim = new Sim(makeLevel(FLAT));
    sim.run(3);
    expect(sim.player.hurt(sim.player.cx + 5)).toBe(true);
    expect(sim.player.vx).toBeLessThan(0);
    expect(sim.player.hurt(sim.player.cx + 5)).toBe(false);
  });
});

/** Level-design rules the maps rely on. */
describe('jump reach (level design rules)', () => {
  function crossGap(gap: number, hover: boolean): boolean {
    const sim = new Sim(makeLevel(gapMap(gap)));
    sim.run(3);
    // Run up, jump at the very edge, keep holding right (and jump when hovering).
    sim.until(() => sim.player.x + sim.player.w > 9 * TILE - 1, 300, 'right');
    sim.run(1, 'right', 'jump');
    for (let i = 0; i < 240; i++) {
      const holdJump = sim.player.vy < 0 || hover;
      sim.run(1, 'right', ...(holdJump ? (['jump'] as const) : []));
      if (sim.player.grounded) break;
      if (sim.player.y > 20 * TILE) return false;
    }
    return sim.player.grounded && sim.player.x > (9 + gap) * TILE - sim.player.w;
  }

  it('clears a 4-tile gap with a plain running jump', () => {
    expect(crossGap(4, false)).toBe(true);
  });

  it('cannot clear an 8-tile gap without hovering', () => {
    expect(crossGap(8, false)).toBe(false);
  });

  it('clears a 9-tile gap with hover', () => {
    expect(crossGap(9, true)).toBe(true);
  });

  function climb(height: number): boolean {
    const sim = new Sim(makeLevel(stepMap(height)));
    sim.run(3);
    // Jump from a short run-up right in front of the wall.
    sim.until(() => sim.player.x + sim.player.w > 10 * TILE - 8, 300, 'right');
    sim.run(1, 'right', 'jump');
    for (let i = 0; i < 120; i++) {
      sim.run(1, 'right', ...(sim.player.vy < 0 ? (['jump'] as const) : []));
      if (sim.player.grounded && sim.player.x > 10 * TILE) return true;
    }
    return false;
  }

  it('climbs a 4-tile step', () => {
    expect(climb(4)).toBe(true);
  });

  it('cannot climb a 5-tile wall', () => {
    expect(climb(5)).toBe(false);
  });
});
