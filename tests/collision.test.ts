import { describe, expect, it } from 'vitest';
import { TILE } from '../src/config';
import { moveX, moveY, probeGround, type Body } from '../src/world/collision';
import { makeLevel } from './helpers';

const level = makeLevel([
  '          ', // 0
  '          ', // 1
  '   ====   ', // 2
  '          ', // 3
  '#        #', // 4
  '##########', // 5
]);

function body(x: number, y: number): Body {
  return { x, y, w: 10, h: 10, vx: 0, vy: 0 };
}

describe('collision', () => {
  it('lands on solid ground and reports the floor', () => {
    const b = body(40, 4 * TILE + 2);
    const res = moveY(b, 10, level);
    expect(res.floor).toBe(true);
    expect(b.y + b.h).toBe(5 * TILE);
    expect(probeGround(b, level).grounded).toBe(true);
  });

  it('stops at walls on both sides', () => {
    const b = body(20, 4 * TILE + 2);
    expect(moveX(b, -10, level)).toBe(true);
    expect(b.x).toBe(TILE);
    const c = body(9 * TILE - 12, 4 * TILE + 2);
    expect(moveX(c, 8, level)).toBe(true);
    expect(c.x + c.w).toBe(9 * TILE);
  });

  it('one-way platforms only stop bodies falling from above', () => {
    const above = body(4 * TILE, 2 * TILE - 12);
    const res = moveY(above, 6, level);
    expect(res.floor).toBe(true);
    expect(res.oneWay).toBe(true);
    expect(above.y + above.h).toBe(2 * TILE);

    const below = body(4 * TILE, 3 * TILE + 2);
    const up = moveY(below, -10, level);
    expect(up.ceiling).toBe(false);
    expect(below.y).toBe(3 * TILE + 2 - 10);
  });

  it('drop-through ignores one-way platforms', () => {
    const b = body(4 * TILE, 2 * TILE - 10);
    const res = moveY(b, 4, level, true);
    expect(res.floor).toBe(false);
  });

  it('out of bounds: sides are walls, below is open void', () => {
    expect(level.get(-1, 3)).toBe(1);
    expect(level.get(10, 3)).toBe(1);
    expect(level.get(3, 99)).toBe(0);
  });
});
