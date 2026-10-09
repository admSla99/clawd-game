import type { App } from '../app';
import { COLORS } from '../config';
import { BINDABLE, DEFAULT_BINDINGS, keyLabel, type Bindable } from '../core/input';
import type { Rect } from '../core/math';
import type { Renderer } from '../render/renderer';
import { panel } from '../render/shapes';

const SLOTS = 3;
const LABELS: Record<Bindable, string> = {
  left: 'MOVE LEFT',
  right: 'MOVE RIGHT',
  up: 'UP / AIM UP',
  down: 'DOWN / AIM DOWN',
  jump: 'JUMP',
  attack: 'SPIN / SHOOT',
  spin: 'SPIN',
  prev: 'PREV WEAPON',
  next: 'NEXT WEAPON',
  pause: 'PAUSE',
  shop: 'SHOP',
  mute: 'MUTE',
  controls: 'CONTROLS HELP',
};
const ROWS = BINDABLE.length + 2; // actions, RESET DEFAULTS, BACK

/** Another action that already uses `code`; W may serve both jump and up (the default layout). */
function conflictFor(bindings: Record<Bindable, string[]>, action: Bindable, code: string): Bindable | undefined {
  const wShared = (a: Bindable, b: Bindable) => code === 'KeyW' && ((a === 'jump' && b === 'up') || (a === 'up' && b === 'jump'));
  return BINDABLE.find((b) => b !== action && bindings[b].includes(code) && !wShared(action, b));
}

/** Overlay for rebinding keys. The scene that opens it forwards update/draw/onClick while `open`. */
export class KeybindMenu {
  open = false;
  private row = 0;
  private slot = 0;
  private listening = false;
  private error = '';
  private slotRects: Rect[][] = [];
  private resetRect: Rect = { x: 0, y: 0, w: 0, h: 0 };
  private backRect: Rect = { x: 0, y: 0, w: 0, h: 0 };

  constructor(private app: App) {}

  show(): void {
    this.open = true;
    this.row = 0;
    this.slot = 0;
    this.listening = false;
    this.error = '';
  }

  private close(): void {
    this.open = false;
    this.listening = false;
    this.app.input.onCapture = null;
  }

  private save(): void {
    this.app.input.setBindings(this.app.input.bindings);
    this.app.save.keys = this.app.input.bindings;
    this.app.persist();
  }

  private listen(): void {
    this.listening = true;
    this.error = '';
    const handle = (code: string): void => {
      const action = BINDABLE[this.row];
      const keys = this.app.input.bindings[action];
      if (code === 'Escape') {
        this.listening = false;
        return;
      }
      if (code === 'Backspace') {
        // Keep at least one key so the action (and the menu navigation) stays reachable.
        if (keys[this.slot] !== undefined && keys.length > 1) keys.splice(this.slot, 1);
      } else {
        const other = conflictFor(this.app.input.bindings, action, code);
        if (other) {
          // Refuse and keep listening so the player can pick another key.
          this.error = `${keyLabel(code)} ALREADY BOUND TO ${LABELS[other]}`;
          this.app.audio.play('denied');
          this.app.input.onCapture = handle;
          return;
        }
        const i = keys.indexOf(code);
        if (i >= 0 && i !== this.slot) keys.splice(i, 1);
        keys[Math.min(this.slot, keys.length)] = code;
      }
      this.listening = false;
      this.error = '';
      this.save();
      this.app.audio.play('confirm');
    };
    this.app.input.onCapture = handle;
  }

  private activate(): void {
    if (this.row < BINDABLE.length) this.listen();
    else if (this.row === BINDABLE.length) {
      this.app.input.setBindings(structuredClone(DEFAULT_BINDINGS));
      this.save();
      this.app.audio.play('confirm');
    } else this.close();
  }

  update(): void {
    if (this.listening) return;
    const input = this.app.input;
    if (input.pressed('back') || input.pressed('pause')) {
      this.close();
      return;
    }
    if (input.pressed('down') || input.pressed('up') || input.pressed('left') || input.pressed('right')) this.error = '';
    if (input.pressed('down')) {
      this.row = (this.row + 1) % ROWS;
      this.app.audio.play('select');
    }
    if (input.pressed('up')) {
      this.row = (this.row + ROWS - 1) % ROWS;
      this.app.audio.play('select');
    }
    if (input.pressed('right')) this.slot = Math.min(SLOTS - 1, this.slot + 1);
    if (input.pressed('left')) this.slot = Math.max(0, this.slot - 1);
    if (input.pressed('confirm')) this.activate();
  }

  onClick(x: number, y: number): void {
    if (this.listening) {
      this.listening = false;
      this.app.input.onCapture = null;
      return;
    }
    const inside = (r: Rect) => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;
    this.slotRects.forEach((slots, row) =>
      slots.forEach((r, slot) => {
        if (!inside(r)) return;
        this.row = row;
        this.slot = slot;
        this.activate();
      }),
    );
    if (inside(this.resetRect)) {
      this.row = BINDABLE.length;
      this.activate();
    } else if (inside(this.backRect)) {
      this.row = BINDABLE.length + 1;
      this.activate();
    }
  }

  draw(r: Renderer): void {
    const ctx = r.ctx;
    const rowH = 11;
    const w = 250;
    const h = 48 + ROWS * rowH;
    const x = r.viewW / 2 - w / 2;
    const y = Math.max(2, r.viewH / 2 - h / 2);
    ctx.fillStyle = 'rgba(10,10,10,0.75)';
    ctx.fillRect(0, 0, r.viewW, r.viewH);
    panel(ctx, x, y, w, h, '#4A4A4A', 'rgba(20,20,20,0.96)');
    r.text('KEYBINDINGS', x + w / 2, y + 10, { size: 6.5, align: 'center', bold: true, color: COLORS.orange });

    const slotW = 36;
    const slotX = x + w - 8 - SLOTS * (slotW + 3);
    this.slotRects = [];
    BINDABLE.forEach((a, i) => {
      const ly = y + 24 + i * rowH;
      const sel = i === this.row;
      r.text(LABELS[a], x + 10, ly, { size: 5.5, color: sel ? COLORS.textBright : COLORS.text });
      const rects: Rect[] = [];
      for (let s = 0; s < SLOTS; s++) {
        const rect = { x: slotX + s * (slotW + 3), y: ly - 4.5, w: slotW, h: 9 };
        rects.push(rect);
        const cur = sel && s === this.slot;
        panel(ctx, rect.x, rect.y, rect.w, rect.h, cur ? COLORS.orange : '#2C2C2C', 'rgba(18,18,18,0.85)');
        const code = this.app.input.bindings[a][s];
        const text = cur && this.listening ? '...' : code ? keyLabel(code) : '-';
        r.text(text, rect.x + slotW / 2, ly, { size: 5, align: 'center', color: code ? COLORS.textBright : COLORS.textDim });
      }
      this.slotRects.push(rects);
    });

    const btn = (label: string, row: number, bx: number, by: number) => {
      const bw = r.measure(label, 5.5) + 14;
      const rect = { x: bx - bw / 2, y: by - 5, w: bw, h: 10 };
      panel(ctx, rect.x, rect.y, bw, 10, this.row === row ? COLORS.orange : '#2C2C2C', 'rgba(18,18,18,0.85)');
      r.text(label, bx, by, { size: 5.5, align: 'center', color: this.row === row ? COLORS.textBright : COLORS.text });
      return rect;
    };
    const by = y + 24 + BINDABLE.length * rowH + 2;
    this.resetRect = btn('RESET DEFAULTS', BINDABLE.length, x + w / 3, by);
    this.backRect = btn('BACK', BINDABLE.length + 1, x + (w * 2) / 3, by);

    const hint = this.listening ? 'PRESS A KEY · ESC CANCEL · BACKSPACE CLEAR' : '↑↓ ROW · ←→ SLOT · ENTER REBIND';
    if (this.error) r.text(this.error, x + w / 2, y + h - 17, { size: 5, align: 'center', color: COLORS.red, bold: true });
    r.text(hint, x + w / 2, y + h - 8, { size: 4.5, align: 'center', color: COLORS.textDim });
  }
}
