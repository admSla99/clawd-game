import type { Action, Input } from './input';

export interface Circle {
  x: number;
  y: number;
  r: number;
}

export interface Insets {
  top: number;
  right: number;
  bottom: number;
  left: number;
}

export type TouchButton = 'jump' | 'attack' | 'spin' | 'swap';

export interface TouchLayout {
  /** Where the stick rests while nobody touches it. */
  stickHome: Circle;
  buttons: Partial<Record<TouchButton, Circle>>;
}

/** Height kept free at the top of the screen for the HUD (pause, mute...). */
const HUD_RESERVE = 28;
const STICK_R = 24;
/** Extra radius around buttons that still counts as a hit. */
const SLOP = 7;
/** Fire button drag distance (view units) before it starts aiming. */
const AIM_DEADZONE = 9;

const BUTTON_ACTIONS: Record<TouchButton, Action[]> = {
  jump: ['jump'],
  attack: ['attack'],
  spin: ['spin'],
  swap: ['next'],
};

/** Floating stick on the left half, action buttons on the right. Coordinates are view units. */
export function touchLayout(viewW: number, viewH: number, safe: Insets, armed: boolean, canSwap: boolean): TouchLayout {
  const right = viewW - safe.right;
  const bottom = viewH - safe.bottom;
  const buttons: TouchLayout['buttons'] = {
    jump: { x: right - 30, y: bottom - 30, r: 19 },
    attack: { x: right - 75, y: bottom - 22, r: 16 },
  };
  if (armed) {
    buttons.spin = { x: right - 68, y: bottom - 64, r: 12 };
    if (canSwap) buttons.swap = { x: right - 25, y: bottom - 72, r: 10 };
  }
  return { stickHome: { x: safe.left + 46, y: bottom - 44, r: STICK_R }, buttons };
}

interface Stick {
  id: number;
  baseX: number;
  baseY: number;
  knobX: number;
  knobY: number;
}

/**
 * On-screen controls for phones and tablets. Each finger is bound to the control
 * it first touched (the stick, or a button) until it lifts.
 */
export class TouchControls {
  /** Set by the game scene while on-screen controls should react. */
  enabled = false;
  armed = false;
  canSwap = false;
  stick: Stick | null = null;
  private owners = new Map<number, TouchButton>();

  constructor(
    private input: Input,
    private view: () => { w: number; h: number; safe: Insets },
  ) {}

  get layout(): TouchLayout {
    const v = this.view();
    return touchLayout(v.w, v.h, v.safe, this.armed, this.canSwap);
  }

  /** Turn the controls on or off; turning them off lets go of every finger. */
  setEnabled(on: boolean): void {
    if (this.enabled && !on) this.reset();
    this.enabled = on;
  }

  isDown(b: TouchButton): boolean {
    for (const owned of this.owners.values()) if (owned === b) return true;
    return false;
  }

  /** A finger went down; returns true when a control took it (so it is not also a tap). */
  down(id: number, x: number, y: number): boolean {
    this.input.touchMode = true;
    if (!this.enabled) return false;
    const v = this.view();
    const layout = this.layout;
    let best: TouchButton | null = null;
    let bestD = Infinity;
    for (const [name, c] of Object.entries(layout.buttons) as [TouchButton, Circle][]) {
      const d = Math.hypot(x - c.x, y - c.y);
      if (d <= c.r + SLOP && d < bestD) {
        best = name;
        bestD = d;
      }
    }
    if (best) {
      this.owners.set(id, best);
      this.emit();
      return true;
    }
    if (!this.stick && x < v.w * 0.45 && y > HUD_RESERVE + v.safe.top) {
      // Keep the whole stick on screen even when touched right at the edge.
      const bx = Math.max(v.safe.left + STICK_R + 2, x);
      const by = Math.min(v.h - v.safe.bottom - STICK_R - 2, y);
      this.stick = { id, baseX: bx, baseY: by, knobX: x, knobY: y };
      this.moveStick(x, y);
      return true;
    }
    return false;
  }

  move(id: number, x: number, y: number): void {
    if (this.stick?.id === id) this.moveStick(x, y);
    else if (this.owners.get(id) === 'attack' && this.armed) this.aimFrom(x, y);
  }

  up(id: number): void {
    if (this.stick?.id === id) this.stick = null;
    if (this.owners.get(id) === 'attack') this.input.touchAim = null;
    this.owners.delete(id);
    this.emit();
  }

  /** Let go of everything (scene change, pause, lost focus). */
  reset(): void {
    this.stick = null;
    this.owners.clear();
    this.input.touchAim = null;
    this.input.setTouch(new Set());
  }

  private moveStick(x: number, y: number): void {
    const s = this.stick!;
    let dx = x - s.baseX;
    let dy = y - s.baseY;
    const d = Math.hypot(dx, dy);
    if (d > STICK_R) {
      // Drag the base along so reversing direction is instant.
      s.baseX = x - (dx / d) * STICK_R;
      s.baseY = y - (dy / d) * STICK_R;
      dx = x - s.baseX;
      dy = y - s.baseY;
    }
    s.knobX = x;
    s.knobY = y;
    this.emit();
  }

  private aimFrom(x: number, y: number): void {
    const c = this.layout.buttons.attack;
    if (!c) return;
    const dx = x - c.x;
    const dy = y - c.y;
    this.input.touchAim = Math.hypot(dx, dy) > AIM_DEADZONE ? { x: dx, y: dy } : null;
  }

  private emit(): void {
    const actions = new Set<Action>();
    const s = this.stick;
    if (s) {
      const nx = (s.knobX - s.baseX) / STICK_R;
      const ny = (s.knobY - s.baseY) / STICK_R;
      if (nx < -0.35) actions.add('left');
      if (nx > 0.35) actions.add('right');
      // Vertical needs a firmer push so running never drops through platforms by accident.
      if (ny > 0.6) actions.add('down');
      if (ny < -0.6) actions.add('up');
    }
    for (const b of this.owners.values()) for (const a of BUTTON_ACTIONS[b]) actions.add(a);
    this.input.setTouch(actions);
  }
}

export function attachTouch(touch: TouchControls, canvas: HTMLCanvasElement, toView: (cx: number, cy: number) => { x: number; y: number }, onTap: (x: number, y: number) => void): void {
  canvas.addEventListener('pointerdown', (e) => {
    const p = toView(e.clientX, e.clientY);
    if (e.pointerType === 'touch') {
      e.preventDefault();
      if (touch.down(e.pointerId, p.x, p.y)) return;
    }
    onTap(p.x, p.y);
  });
  canvas.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'touch') return;
    const p = toView(e.clientX, e.clientY);
    touch.move(e.pointerId, p.x, p.y);
  });
  const up = (e: PointerEvent) => {
    if (e.pointerType === 'touch') touch.up(e.pointerId);
  };
  window.addEventListener('pointerup', up);
  window.addEventListener('pointercancel', up);
  window.addEventListener('blur', () => touch.reset());
}
