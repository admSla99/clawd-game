import { COLORS } from '../config';
import type { Rect } from '../core/math';
import type { Renderer } from './renderer';
import { drawSpark, drawSpeaker, drawToken, panel } from './shapes';
import { CLAWD, CLAWD_PALETTE, HEART, drawSprite } from './sprites';

export interface HudState {
  hearts: number;
  maxHearts: number;
  sparks: number;
  sparksTotal: number;
  tokens: number;
  agents: number;
  agentsTotal: number;
  label: string;
  muted: boolean;
  time: number;
  /** Briefly highlight a counter after it changes. */
  flashSparks: number;
  flashHearts: number;
  boss?: { name: string; hp: number; maxHp: number };
}

export interface HudRegions {
  controls: Rect;
  mute: Rect;
}

const H = 13;
const TOP = 7;

export function drawHud(r: Renderer, s: HudState): HudRegions {
  const ctx = r.ctx;
  let x = 8;

  // Hearts.
  const heartsW = s.maxHearts * 9 + 9;
  panel(ctx, x, TOP, heartsW, H);
  for (let i = 0; i < s.maxHearts; i++) {
    const full = i < s.hearts;
    const pop = full && s.flashHearts > 0 && i === s.hearts - 1 ? 1 + s.flashHearts * 0.6 : 1;
    drawSprite(ctx, HEART, CLAWD_PALETTE, x + 8.5 + i * 9, TOP + H / 2 + 3.5 * pop, {
      px: pop,
      tint: full ? COLORS.red : '#3A3A3A',
    });
  }
  x += heartsW + 4;

  // Sparks.
  if (s.sparksTotal > 0) {
    const label = `SPARKS ${s.sparks} / ${s.sparksTotal}`;
    const tw = r.measure(label, 5.5);
    const w = tw + 22;
    panel(ctx, x, TOP, w, H, s.flashSparks > 0 ? COLORS.orange : COLORS.hudBorder);
    drawSpark(ctx, x + 8, TOP + H / 2, s.time, { scale: 0.5 });
    r.text(label, x + 15, TOP + H / 2 + 0.5, { size: 5.5, color: s.flashSparks > 0 ? COLORS.orangeLight : COLORS.text });
    x += w + 4;
  }

  // Tokens.
  const tokLabel = String(s.tokens).padStart(3, '0');
  const tw2 = r.measure(tokLabel, 5.5);
  panel(ctx, x, TOP, tw2 + 16, H);
  drawToken(ctx, x + 7, TOP + H / 2, s.time);
  r.text(tokLabel, x + 12, TOP + H / 2 + 0.5, { size: 5.5 });
  x += tw2 + 20;

  // Rescued sub-agents.
  if (s.agentsTotal > 0) {
    const label = `${s.agents}/${s.agentsTotal}`;
    const tw3 = r.measure(label, 5.5);
    panel(ctx, x, TOP, tw3 + 21, H);
    drawSprite(ctx, CLAWD.idle, CLAWD_PALETTE, x + 9, TOP + H - 2.5, { px: 0.65, tint: s.agents > 0 ? undefined : '#6A6A6A' });
    r.text(label, x + 16, TOP + H / 2 + 0.5, { size: 5.5 });
  }

  // Right side: CONTROLS · speaker · label.
  let rx = r.viewW - 8;
  const labW = r.measure(s.label, 5.5) + 12;
  rx -= labW;
  panel(ctx, rx, TOP, labW, H);
  r.text(s.label, rx + 6, TOP + H / 2 + 0.5, { size: 5.5, color: COLORS.textDim });
  rx -= 4 + 18;
  const mute = { x: rx, y: TOP, w: 18, h: H };
  panel(ctx, rx, TOP, 18, H);
  drawSpeaker(ctx, rx + 4, TOP + H / 2 - 0.5, s.muted, COLORS.text);
  const ctlW = r.measure('CONTROLS', 5.5) + 12;
  rx -= 4 + ctlW;
  const controls = { x: rx, y: TOP, w: ctlW, h: H };
  panel(ctx, rx, TOP, ctlW, H);
  r.text('CONTROLS', rx + 6, TOP + H / 2 + 0.5, { size: 5.5 });

  if (s.boss) drawBossBar(r, s.boss, s.time);
  return { controls, mute };
}

function drawBossBar(r: Renderer, b: { name: string; hp: number; maxHp: number }, time: number): void {
  const ctx = r.ctx;
  const w = 150;
  const x = r.viewW / 2 - w / 2;
  const y = r.viewH - 22;
  r.text(b.name, r.viewW / 2, y - 6, { size: 5.5, align: 'center', color: COLORS.textBright });
  if (b.maxHp <= 5) {
    // Few hit points: one segment per hit.
    const seg = w / b.maxHp;
    for (let i = 0; i < b.maxHp; i++) {
      const on = i < b.hp;
      for (let d = 0; d < seg - 4; d += 3) {
        ctx.fillStyle = on ? (Math.sin(time * 10 + d) > 0.8 ? COLORS.orangeLight : COLORS.red) : '#333';
        ctx.fillRect(x + i * seg + d, y, 2, 4);
      }
    }
  } else {
    const cells = 50;
    const frac = b.hp / b.maxHp;
    for (let i = 0; i < cells; i++) {
      const on = i / cells < frac;
      ctx.fillStyle = on ? (Math.sin(time * 10 + i) > 0.85 ? COLORS.orangeLight : COLORS.red) : '#333';
      ctx.fillRect(x + i * 3, y, 2, 4);
    }
  }
}

export const CONTROL_LINES: [string, string][] = [
  ['← → / A D', 'Move'],
  ['SPACE / K', 'Jump (hold = higher)'],
  ['HOLD JUMP (air)', 'Hover — the jet hurts enemies'],
  ['X / J', 'World 1: spin  ·  World 2: shoot'],
  ['C / L / RMB', 'Spin attack'],
  ['↓ + spin (air)', 'Ground pound — breaks corrupted data'],
  ['↓ + SPACE', 'Drop through platforms'],
  ['MOUSE + LMB', 'World 2: aim and shoot'],
  ['↑ / ↓ + X', 'Aim up / down without a mouse'],
  ['1-5 · Q E · WHEEL', 'Switch weapon'],
  ['B (map)', 'Shop'],
  ['ESC / P · M · H', 'Pause · mute · this help'],
  ['GAMEPAD', 'A jump · X shoot · B spin · R-stick aim'],
];

export function drawControlsOverlay(r: Renderer): void {
  const ctx = r.ctx;
  const w = 230;
  const h = 26 + CONTROL_LINES.length * 11;
  const x = r.viewW / 2 - w / 2;
  const y = r.viewH / 2 - h / 2;
  ctx.fillStyle = 'rgba(10,10,10,0.6)';
  ctx.fillRect(0, 0, r.viewW, r.viewH);
  panel(ctx, x, y, w, h, '#4A4A4A', 'rgba(20,20,20,0.96)');
  r.text('CONTROLS', x + w / 2, y + 11, { size: 6.5, align: 'center', bold: true, color: COLORS.orange });
  CONTROL_LINES.forEach(([k, v], i) => {
    const ly = y + 26 + i * 11;
    r.text(k, x + 12, ly, { size: 5.5, color: COLORS.textBright });
    r.text(v, x + 90, ly, { size: 5.5, color: COLORS.text });
  });
}
