import { describe, expect, it } from 'vitest';
import { STEP } from '../src/config';
import { Codex } from '../src/entities/boss/codex';
import type { Entity, GameContext } from '../src/entities/entity';
import { Player } from '../src/entities/player';

function arena() {
  const spawned: Entity[] = [];
  const events: string[] = [];
  const noop = () => {};
  const player = new Player(100, 240);
  const g = {
    player,
    time: 0,
    camera: { y: 0 },
    spawn: (e: Entity) => spawned.push(e),
    sfx: noop,
    shake: noop,
    hitstop: noop,
    particles: { emit: noop },
    onBossDefeated: () => events.push('defeated'),
  } as unknown as GameContext;
  return { g, spawned, events };
}

describe('Codex boss', () => {
  it('ignores damage during its intro, then cycles through attacks', () => {
    const { g, spawned } = arena();
    const codex = new Codex(320, 240, 640);
    expect(codex.hit('shot', g, 10)).toBe(false);
    for (let i = 0; i < 60 * 12; i++) codex.update(STEP, g);
    // Hands were created and it has fired / summoned things.
    expect(spawned.length).toBeGreaterThan(5);
    expect(codex.hit('shot', g, 1)).toBe(true);
  });

  it('goes through its phases and dies, ending the fight', () => {
    const { g, events } = arena();
    const codex = new Codex(320, 240, 640);
    for (let i = 0; i < 60 * 4; i++) codex.update(STEP, g);
    let guard = 0;
    while (!codex.dead && guard++ < 10000) {
      codex.hit('shot', g, 2);
      codex.update(STEP, g);
    }
    expect(codex.dead).toBe(true);
    expect(codex.hp).toBe(0);
    for (let i = 0; i < 60 * 4; i++) codex.update(STEP, g);
    expect(events).toEqual(['defeated']);
    expect(codex.alive).toBe(false);
  });
});
