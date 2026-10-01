import { describe, expect, it } from 'vitest';
import { Input } from '../src/core/input';

describe('input', () => {
  it('reports pressed for exactly one tick', () => {
    const i = new Input();
    i.keyDown('Space');
    i.tick();
    expect(i.pressed('jump')).toBe(true);
    expect(i.held('jump')).toBe(true);
    i.tick();
    expect(i.pressed('jump')).toBe(false);
    expect(i.held('jump')).toBe(true);
    i.keyUp('Space');
    i.tick();
    expect(i.released('jump')).toBe(true);
    expect(i.held('jump')).toBe(false);
  });

  it('does not lose a tap that happens between ticks', () => {
    const i = new Input();
    i.keyDown('KeyX');
    i.keyUp('KeyX');
    i.tick();
    expect(i.pressed('attack')).toBe(true);
    expect(i.held('attack')).toBe(false);
  });

  it('maps several keys to one action and one key to several actions', () => {
    const i = new Input();
    i.keyDown('Space');
    i.tick();
    expect(i.held('confirm')).toBe(true);
    expect(i.held('jump')).toBe(true);
    i.keyDown('KeyK');
    i.keyUp('Space');
    i.tick();
    expect(i.held('jump')).toBe(true);
    expect(i.pressed('jump')).toBe(false);
  });

  it('mouse buttons and wheel become actions', () => {
    const i = new Input();
    i.mouseButton('attack', true, 0);
    i.tap('next');
    i.tick();
    expect(i.pressed('attack')).toBe(true);
    expect(i.pressed('next')).toBe(true);
    i.tick();
    expect(i.held('attack')).toBe(true);
    expect(i.pressed('next')).toBe(false);
    i.mouseButton('attack', false, 0);
    i.tick();
    expect(i.released('attack')).toBe(true);
  });

  it('feeds gamepad edges into presses', () => {
    const i = new Input();
    i.setPad(new Set(['jump']));
    i.tick();
    expect(i.pressed('jump')).toBe(true);
    i.setPad(new Set(['jump']));
    i.tick();
    expect(i.pressed('jump')).toBe(false);
  });
});
