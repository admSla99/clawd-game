import { COLORS } from '../config';
import type { Circle, TouchButton, TouchControls } from '../core/touch';
import type { Renderer } from './renderer';

function dottedRing(ctx: CanvasRenderingContext2D, c: Circle, color: string, step = 4): void {
  const n = Math.max(12, Math.round((Math.PI * 2 * c.r) / step));
  ctx.fillStyle = color;
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    ctx.fillRect(c.x + Math.cos(a) * c.r - 0.75, c.y + Math.sin(a) * c.r - 0.75, 1.5, 1.5);
  }
}

function disc(ctx: CanvasRenderingContext2D, c: Circle, fill: string): void {
  ctx.fillStyle = fill;
  ctx.beginPath();
  ctx.arc(c.x, c.y, c.r, 0, Math.PI * 2);
  ctx.fill();
}

/** On-screen stick and buttons, drawn on top of the game but under menus. */
export function drawTouchControls(r: Renderer, touch: TouchControls, aim: { x: number; y: number } | null): void {
  const ctx = r.ctx;
  const layout = touch.layout;
  ctx.save();

  // Stick: a faint hint where it usually sits, the real thing under the thumb.
  const s = touch.stick;
  const base: Circle = s ? { x: s.baseX, y: s.baseY, r: layout.stickHome.r } : layout.stickHome;
  ctx.globalAlpha = s ? 0.95 : 0.7;
  disc(ctx, base, 'rgba(12,12,12,0.55)');
  dottedRing(ctx, base, s ? COLORS.textBright : COLORS.text);
  const knob: Circle = s ? { x: s.knobX, y: s.knobY, r: 9 } : { x: base.x, y: base.y, r: 9 };
  disc(ctx, knob, s ? 'rgba(217,119,87,0.5)' : 'rgba(110,110,110,0.45)');
  dottedRing(ctx, knob, s ? COLORS.orangeLight : COLORS.text, 3);

  const labels: Record<TouchButton, string> = {
    jump: 'JUMP',
    attack: touch.armed ? 'FIRE' : 'SPIN',
    spin: 'SPIN',
    swap: 'SWAP',
  };
  for (const [name, c] of Object.entries(layout.buttons) as [TouchButton, Circle][]) {
    const down = touch.isDown(name);
    ctx.globalAlpha = down ? 1 : 0.85;
    disc(ctx, c, down ? 'rgba(217,119,87,0.4)' : 'rgba(12,12,12,0.6)');
    dottedRing(ctx, c, down ? COLORS.orangeLight : name === 'jump' || name === 'attack' ? COLORS.orange : COLORS.text);
    r.text(labels[name], c.x, c.y + 0.5, { size: c.r > 14 ? 5.5 : 4.5, align: 'center', bold: true, color: down ? COLORS.textBright : COLORS.text });
  }

  // While the fire button is dragged, show which way it points.
  const fire = layout.buttons.attack;
  if (touch.armed && fire && aim) {
    const len = Math.hypot(aim.x, aim.y) || 1;
    ctx.globalAlpha = 0.9;
    ctx.fillStyle = COLORS.orangeLight;
    for (let d = fire.r + 3; d < fire.r + 13; d += 3) ctx.fillRect(fire.x + (aim.x / len) * d - 1, fire.y + (aim.y / len) * d - 1, 2, 2);
  }
  ctx.restore();
}

/** Full-screen hint shown while a phone is held upright. */
export function drawRotateHint(r: Renderer, time: number): void {
  const ctx = r.ctx;
  ctx.fillStyle = 'rgba(16,16,16,0.94)';
  ctx.fillRect(0, 0, r.viewW, r.viewH);
  const cx = r.viewW / 2;
  const cy = r.viewH / 2 - 20;
  // A phone outline tipping over onto its side.
  const t = (time % 2.4) / 2.4;
  const a = t < 0.25 ? 0 : t < 0.6 ? ((t - 0.25) / 0.35) * (Math.PI / 2) : Math.PI / 2;
  ctx.save();
  ctx.translate(cx, cy);
  ctx.rotate(-a);
  ctx.fillStyle = COLORS.orange;
  for (let y = -22; y <= 22; y += 3) {
    ctx.fillRect(-13, y, 1.5, 1.5);
    ctx.fillRect(12, y, 1.5, 1.5);
  }
  for (let x = -13; x <= 12; x += 3) {
    ctx.fillRect(x, -22, 1.5, 1.5);
    ctx.fillRect(x, 22, 1.5, 1.5);
  }
  ctx.fillRect(-2, 17, 4, 1.5);
  ctx.restore();
  r.text('ROTATE YOUR DEVICE', cx, cy + 42, { size: 7, align: 'center', bold: true, color: COLORS.textBright });
  r.text('Clawd needs landscape to play', cx, cy + 54, { size: 5, align: 'center', color: COLORS.text });
}
