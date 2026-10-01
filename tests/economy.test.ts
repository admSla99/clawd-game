import { describe, expect, it } from 'vitest';
import { PLAYER } from '../src/config';
import type { GameContext } from '../src/entities/entity';
import { Gun } from '../src/entities/gun';
import { emptySave, grantWeapon, recordRun, sparksAvailable, totalSparks } from '../src/save';
import { WEAPONS, loadoutFromSave } from '../src/weapons';

describe('save & economy', () => {
  it('banks level tokens into the wallet and never loses collected sparks', () => {
    const s = emptySave();
    recordRun(s, '2-1', [true, false, true, false, false], [false, true], 30, 120);
    recordRun(s, '2-1', [false, true, false, false, false], [false, false], 25, 40);
    expect(s.wallet).toBe(160);
    expect(totalSparks(s)).toBe(3);
    expect(s.levels['2-1'].agents).toEqual([false, true]);
    expect(s.levels['2-1'].bestTime).toBe(25);
  });

  it('spending sparks lowers what is available, not what was found', () => {
    const s = emptySave();
    recordRun(s, '1-1', [true, true, true, true, true], [], 10, 0);
    s.sparksSpent = 3;
    expect(totalSparks(s)).toBe(5);
    expect(sparksAvailable(s)).toBe(2);
  });

  it('granting the first weapon equips it', () => {
    const s = emptySave();
    grantWeapon(s, 'blaster');
    grantWeapon(s, 'spreader');
    grantWeapon(s, 'blaster');
    expect(s.weapons).toEqual(['blaster', 'spreader']);
    expect(s.equipped).toBe('blaster');
  });

  it('upgrades change the loadout', () => {
    const s = emptySave();
    const base = loadoutFromSave(s);
    expect(base.maxHearts).toBe(PLAYER.maxHearts);
    expect(base.magnet).toBe(0);
    s.upgrades = { hearts: 2, damage: 2, rate: 1, context: 1, hover: 1, magnet: 1 };
    const up = loadoutFromSave(s);
    expect(up.maxHearts).toBe(PLAYER.maxHearts + 2);
    expect(up.damageMult).toBeCloseTo(1.5);
    expect(up.rateMult).toBeCloseTo(1.15);
    expect(up.heatCap).toBe(140);
    expect(up.hoverDuration).toBeCloseTo(PLAYER.hoverDuration * 1.3);
    expect(up.magnet).toBeGreaterThan(0);
  });
});

function fakeContext(spawned: unknown[], beams: number[]): GameContext {
  const noop = () => {};
  return {
    spawn: (e: unknown) => spawned.push(e),
    fireBeam: (_x: number, _y: number, _a: number, dmg: number) => beams.push(dmg),
    sfx: noop,
    shake: noop,
    particles: { emit: noop },
  } as unknown as GameContext;
}

describe('gun', () => {
  const loadout = loadoutFromSave(emptySave());

  it('fires at the weapon rate while the trigger is held', () => {
    const spawned: unknown[] = [];
    const gun = new Gun('blaster', loadout);
    const g = fakeContext(spawned, []);
    for (let i = 0; i < 60; i++) gun.update(1 / 60, true, g, 0, 0, 0);
    expect(spawned.length).toBeGreaterThanOrEqual(WEAPONS.blaster.fireRate - 1);
    expect(spawned.length).toBeLessThanOrEqual(WEAPONS.blaster.fireRate + 1);
  });

  it('the spreader fires a fan of pellets per shot', () => {
    const spawned: unknown[] = [];
    const gun = new Gun('spreader', loadout);
    gun.update(1 / 60, true, fakeContext(spawned, []), 0, 0, 0);
    expect(spawned).toHaveLength(WEAPONS.spreader.pellets);
  });

  it('the attention beam is hit-scan', () => {
    const beams: number[] = [];
    const gun = new Gun('beam', loadout);
    gun.update(1 / 60, true, fakeContext([], beams), 0, 0, 0);
    expect(beams).toEqual([WEAPONS.beam.damage]);
  });

  it('overflows its context when fired too long, then cools down', () => {
    const gun = new Gun('stream', loadout);
    const g = fakeContext([], []);
    let t = 0;
    while (gun.overheated <= 0 && t < 20) {
      gun.update(1 / 60, true, g, 0, 0, 0);
      t += 1 / 60;
    }
    expect(gun.overheated).toBeGreaterThan(0);
    expect(gun.update(1 / 60, true, g, 0, 0, 0)).toBe(false);
    for (let i = 0; i < 120; i++) gun.update(1 / 60, false, g, 0, 0, 0);
    expect(gun.overheated).toBeLessThanOrEqual(0);
    expect(gun.update(1 / 60, true, g, 0, 0, 0)).toBe(true);
  });
});
