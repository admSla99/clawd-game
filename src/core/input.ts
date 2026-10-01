export type Action =
  | 'left'
  | 'right'
  | 'up'
  | 'down'
  | 'jump'
  /** World 1: spin. World 2: shoot. */
  | 'attack'
  | 'spin'
  | 'next'
  | 'prev'
  | 'slot1'
  | 'slot2'
  | 'slot3'
  | 'slot4'
  | 'slot5'
  | 'pause'
  | 'confirm'
  | 'back'
  | 'shop'
  | 'mute'
  | 'debug'
  | 'noclip'
  | 'controls';

export const KEYMAP: Record<string, Action[]> = {
  ArrowLeft: ['left'],
  KeyA: ['left'],
  ArrowRight: ['right'],
  KeyD: ['right'],
  ArrowUp: ['up'],
  KeyW: ['up'],
  ArrowDown: ['down'],
  KeyS: ['down'],
  Space: ['jump', 'confirm'],
  KeyK: ['jump'],
  KeyX: ['attack'],
  KeyJ: ['attack'],
  KeyC: ['spin'],
  KeyL: ['spin'],
  KeyQ: ['prev'],
  KeyE: ['next'],
  Digit1: ['slot1'],
  Digit2: ['slot2'],
  Digit3: ['slot3'],
  Digit4: ['slot4'],
  Digit5: ['slot5'],
  Enter: ['confirm'],
  Escape: ['pause', 'back'],
  KeyP: ['pause'],
  Backspace: ['back'],
  KeyB: ['shop'],
  KeyM: ['mute'],
  KeyH: ['controls'],
  F1: ['debug'],
  F2: ['noclip'],
};

/** Read-only view the game logic uses; keeps entities testable without a DOM. */
export interface InputView {
  held(a: Action): boolean;
  pressed(a: Action): boolean;
  released(a: Action): boolean;
}

export class Input implements InputView {
  private keys = new Set<string>();
  private latched = new Set<Action>();
  private padHeld = new Set<Action>();
  private mouseHeld = new Set<Action>();
  private heldSet = new Set<Action>();
  private prevHeld = new Set<Action>();
  private pressedSet = new Set<Action>();
  private releasedSet = new Set<Action>();
  /** True once any key/button has been pressed; used to unlock audio. */
  anyInput = false;

  /** Mouse position in view units, and when it last moved (performance.now ms). */
  mouseX = 0;
  mouseY = 0;
  mouseMovedAt = -1e9;
  /** Right-stick aim direction, or null when the stick is centred. */
  padAim: { x: number; y: number } | null = null;

  keyDown(code: string): void {
    if (this.keys.has(code)) return;
    this.keys.add(code);
    this.anyInput = true;
    // A second key for an action that is already held is not a new press.
    for (const a of KEYMAP[code] ?? []) if (!this.heldSet.has(a)) this.latched.add(a);
  }

  keyUp(code: string): void {
    this.keys.delete(code);
  }

  mouseMove(x: number, y: number, now: number): void {
    this.mouseX = x;
    this.mouseY = y;
    this.mouseMovedAt = now;
  }

  mouseButton(a: Action, down: boolean, now: number): void {
    this.mouseMovedAt = now;
    if (down) {
      if (!this.mouseHeld.has(a)) this.latched.add(a);
      this.mouseHeld.add(a);
      this.anyInput = true;
    } else {
      this.mouseHeld.delete(a);
    }
  }

  /** Latch a one-shot action (mouse wheel). */
  tap(a: Action): void {
    this.latched.add(a);
  }

  /** Mouse aiming is used while the mouse moved recently or a button is held. */
  mouseAiming(now: number): boolean {
    return now - this.mouseMovedAt < 4000 || this.mouseHeld.size > 0;
  }

  /** Feed the actions currently held on a gamepad. */
  setPad(actions: Set<Action>): void {
    for (const a of actions) {
      if (!this.padHeld.has(a)) {
        this.latched.add(a);
        this.anyInput = true;
      }
    }
    this.padHeld = actions;
  }

  clear(): void {
    this.keys.clear();
    this.padHeld.clear();
    this.mouseHeld.clear();
    this.latched.clear();
  }

  /** Advance one fixed simulation step. */
  tick(): void {
    const next = new Set<Action>(this.padHeld);
    for (const a of this.mouseHeld) next.add(a);
    for (const k of this.keys) for (const a of KEYMAP[k] ?? []) next.add(a);
    this.prevHeld = this.heldSet;
    this.heldSet = next;
    this.pressedSet = new Set<Action>(this.latched);
    for (const a of next) if (!this.prevHeld.has(a)) this.pressedSet.add(a);
    this.releasedSet = new Set<Action>();
    for (const a of this.prevHeld) if (!next.has(a)) this.releasedSet.add(a);
    this.latched.clear();
  }

  held(a: Action): boolean {
    return this.heldSet.has(a);
  }

  pressed(a: Action): boolean {
    return this.pressedSet.has(a);
  }

  released(a: Action): boolean {
    return this.releasedSet.has(a);
  }

  /** Swallow a press so a later consumer in the same tick does not see it. */
  consume(a: Action): void {
    this.pressedSet.delete(a);
  }
}

const GAME_KEYS = new Set(Object.keys(KEYMAP));

export function attachKeyboard(input: Input, target: Window): void {
  target.addEventListener('keydown', (e) => {
    if (GAME_KEYS.has(e.code)) e.preventDefault();
    // Auto-repeat would turn a held key into fresh presses after a scene change.
    if (e.repeat) return;
    input.keyDown(e.code);
  });
  target.addEventListener('keyup', (e) => {
    if (GAME_KEYS.has(e.code)) e.preventDefault();
    input.keyUp(e.code);
  });
  target.addEventListener('blur', () => input.clear());
}

/** Mouse: move to aim, left button shoots, right button spins, wheel switches weapons. */
export function attachMouse(input: Input, canvas: HTMLCanvasElement, toView: (cx: number, cy: number) => { x: number; y: number }): void {
  canvas.addEventListener('pointermove', (e) => {
    const p = toView(e.clientX, e.clientY);
    input.mouseMove(p.x, p.y, performance.now());
  });
  canvas.addEventListener('pointerdown', (e) => {
    const p = toView(e.clientX, e.clientY);
    input.mouseMove(p.x, p.y, performance.now());
    if (e.button === 0) input.mouseButton('attack', true, performance.now());
    if (e.button === 2) input.mouseButton('spin', true, performance.now());
  });
  window.addEventListener('pointerup', (e) => {
    if (e.button === 0) input.mouseButton('attack', false, performance.now());
    if (e.button === 2) input.mouseButton('spin', false, performance.now());
  });
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener(
    'wheel',
    (e) => {
      e.preventDefault();
      input.tap(e.deltaY > 0 ? 'next' : 'prev');
    },
    { passive: false },
  );
}

/** Standard-mapping gamepad → actions. */
export function pollGamepad(input: Input): void {
  const pads = typeof navigator !== 'undefined' && navigator.getGamepads ? navigator.getGamepads() : [];
  const actions = new Set<Action>();
  input.padAim = null;
  for (const pad of pads) {
    if (!pad || !pad.connected) continue;
    const b = (i: number) => !!pad.buttons[i]?.pressed;
    const ax = pad.axes[0] ?? 0;
    const ay = pad.axes[1] ?? 0;
    if (b(14) || ax < -0.4) actions.add('left');
    if (b(15) || ax > 0.4) actions.add('right');
    if (b(12) || ay < -0.5) actions.add('up');
    if (b(13) || ay > 0.5) actions.add('down');
    if (b(0)) {
      actions.add('jump');
      actions.add('confirm');
    }
    if (b(2) || b(7)) actions.add('attack');
    if (b(1)) {
      actions.add('spin');
      actions.add('back');
    }
    if (b(6)) actions.add('spin');
    if (b(3) || b(5)) actions.add('next');
    if (b(4)) actions.add('prev');
    if (b(9)) actions.add('pause');
    if (b(8)) actions.add('controls');
    const rx = pad.axes[2] ?? 0;
    const ry = pad.axes[3] ?? 0;
    if (Math.hypot(rx, ry) > 0.45) input.padAim = { x: rx, y: ry };
  }
  input.setPad(actions);
}
