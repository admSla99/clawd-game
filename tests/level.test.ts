import { describe, expect, it } from 'vitest';
import { parseLevel, stitch } from '../src/world/level';
import { LEVELS } from '../src/world/levels';
import { T } from '../src/world/tiles';

describe('level parser', () => {
  it('parses tiles and spawns', () => {
    const l = parseLevel({
      id: 't',
      world: 1,
      name: 't',
      subtitle: '',
      theme: 'plains',
      music: 'plains',
      map: ['  S ', '@ = ', '##^X'],
    });
    expect(l.w).toBe(4);
    expect(l.h).toBe(3);
    expect(l.get(2, 1)).toBe(T.ONEWAY);
    expect(l.get(2, 2)).toBe(T.SPIKE);
    expect(l.get(3, 2)).toBe(T.CORRUPT);
    expect(l.start.tx).toBe(0);
    expect(l.spawnsOf('spark')[0]).toMatchObject({ tx: 2, ty: 0, x: 40, y: 16, index: 0 });
  });

  it('rejects unknown characters', () => {
    expect(() => parseLevel({ id: 't', world: 1, name: 't', subtitle: '', theme: 'plains', music: 'plains', map: ['@ %'] })).toThrow(/unknown/);
  });

  it('stitches segments bottom-aligned', () => {
    const rows = stitch(3, [
      { width: 3, rows: ['@', '###'] },
      { width: 2, rows: ['##', '##', '##'] },
    ]);
    expect(rows).toEqual(['   ##', '@  ##', '#####']);
  });
});

describe('world 1 levels', () => {
  for (const def of LEVELS) {
    describe(def.id, () => {
      const level = parseLevel(def);

      it('has exactly one start', () => {
        expect(level.spawnsOf('start')).toHaveLength(1);
      });

      it('has the expected collectibles / exit', () => {
        if (def.boss) {
          expect(level.spawnsOf('boss')).toHaveLength(1);
        } else {
          expect(level.spawnsOf('spark')).toHaveLength(5);
          expect(level.spawnsOf('agent')).toHaveLength(2);
          expect(level.spawnsOf('goal')).toHaveLength(1);
        }
      });

      it('has a text for every sign', () => {
        expect(level.spawnsOf('sign').length).toBe(def.signs?.length ?? 0);
      });

      it('places standing objects on something solid', () => {
        for (const s of level.spawns) {
          if (!['start', 'checkpoint', 'goal', 'agent', 'sign', 'bug', 'turret', 'shieldbot', 'injector'].includes(s.kind)) continue;
          const below = level.get(s.tx, s.ty + 1);
          expect(below === T.SOLID || below === T.ONEWAY || below === T.CORRUPT, `${s.kind} at ${s.tx},${s.ty}`).toBe(true);
        }
      });

      it('gives Clawd headroom at the start', () => {
        const s = level.start;
        expect(level.get(s.tx, s.ty - 1)).toBe(T.EMPTY);
      });
    });
  }
});
