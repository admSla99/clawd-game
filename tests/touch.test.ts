import { describe, expect, it } from 'vitest';
import { Input } from '../src/core/input';
import { TouchControls, touchLayout } from '../src/core/touch';

const W = 480;
const H = 270;
const SAFE = { top: 0, right: 0, bottom: 0, left: 0 };

function setup(armed = false) {
  const input = new Input();
  const touch = new TouchControls(input, () => ({ w: W, h: H, safe: SAFE }));
  touch.setEnabled(true);
  touch.armed = armed;
  return { input, touch, layout: touchLayout(W, H, SAFE, armed, false) };
}

describe('touch controls', () => {
  it('the left thumb becomes a stick', () => {
    const { input, touch } = setup();
    expect(touch.down(1, 60, 200)).toBe(true);
    touch.move(1, 90, 200);
    input.tick();
    expect(input.held('right')).toBe(true);
    expect(input.held('down')).toBe(false);
    touch.move(1, 20, 200);
    input.tick();
    expect(input.held('left')).toBe(true);
    expect(input.held('right')).toBe(false);
    touch.up(1);
    input.tick();
    expect(input.held('left')).toBe(false);
  });

  it('needs a firm push before the stick means down', () => {
    const { input, touch } = setup();
    touch.down(1, 60, 150);
    touch.move(1, 80, 160);
    input.tick();
    expect(input.held('right')).toBe(true);
    expect(input.held('down')).toBe(false);
    touch.move(1, 60, 175);
    input.tick();
    expect(input.held('down')).toBe(true);
  });

  it('a quick tap on a button is not lost between ticks', () => {
    const { input, touch, layout } = setup();
    const jump = layout.buttons.jump!;
    expect(touch.down(2, jump.x, jump.y)).toBe(true);
    touch.up(2);
    input.tick();
    expect(input.pressed('jump')).toBe(true);
  });

  it('stick and buttons work at the same time', () => {
    const { input, touch, layout } = setup();
    touch.down(1, 60, 200);
    touch.move(1, 90, 200);
    const attack = layout.buttons.attack!;
    touch.down(2, attack.x + 3, attack.y - 2);
    input.tick();
    expect(input.held('right')).toBe(true);
    expect(input.held('attack')).toBe(true);
  });

  it('dragging the fire button aims, releasing it stops aiming', () => {
    const { input, touch, layout } = setup(true);
    const fire = layout.buttons.attack!;
    touch.down(3, fire.x, fire.y);
    touch.move(3, fire.x, fire.y - 3);
    expect(input.touchAim).toBeNull();
    touch.move(3, fire.x, fire.y - 30);
    expect(input.touchAim).not.toBeNull();
    expect(Math.atan2(input.touchAim!.y, input.touchAim!.x)).toBeCloseTo(-Math.PI / 2);
    touch.up(3);
    expect(input.touchAim).toBeNull();
  });

  it('taps outside the controls stay taps', () => {
    const { touch } = setup();
    expect(touch.down(4, W / 2, H / 2)).toBe(false); // middle of the screen
    expect(touch.down(5, 30, 10)).toBe(false); // HUD strip
  });

  it('disabling the controls lets go of everything', () => {
    const { input, touch, layout } = setup();
    const jump = layout.buttons.jump!;
    touch.down(2, jump.x, jump.y);
    input.tick();
    expect(input.held('jump')).toBe(true);
    touch.setEnabled(false);
    input.tick();
    expect(input.held('jump')).toBe(false);
    expect(touch.down(6, jump.x, jump.y)).toBe(false);
  });

  it('keyboard input switches back out of touch mode', () => {
    const { input, touch } = setup();
    touch.down(1, 60, 200);
    expect(input.touchMode).toBe(true);
    input.keyDown('KeyD');
    expect(input.touchMode).toBe(false);
  });
});
