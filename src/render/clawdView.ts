import { COLORS } from '../config';
import type { Player } from '../entities/player';
import { CLAWD, CLAWD_PALETTE, drawSprite } from './sprites';

/** Picks Clawd's animation frame from the player state and draws it. */
export function drawClawd(ctx: CanvasRenderingContext2D, p: Player, x: number, bottom: number, time: number): void {
  if (p.invuln > 0 && p.state !== 'hurt' && Math.floor(time * 14) % 2 === 0) return;

  let frame = CLAWD.idle;
  let turn = 1;
  let yOff = 0;
  if (p.noclip) {
    frame = CLAWD.hover;
  } else if (p.state === 'hurt') {
    frame = CLAWD.hurt;
  } else if (p.state === 'poundWindup') {
    frame = CLAWD.pound;
    turn = Math.cos(p.anim * 40);
  } else if (p.state === 'pound' || p.state === 'poundLand') {
    frame = CLAWD.pound;
  } else if (p.state === 'spin') {
    frame = p.grounded ? CLAWD.idle : CLAWD.jump;
    turn = Math.cos(p.anim * 38);
  } else if (!p.grounded) {
    if (p.hovering) frame = CLAWD.hover;
    else frame = p.vy < 0 ? CLAWD.jump : CLAWD.fall;
  } else if (Math.abs(p.vx) > 12) {
    const phase = Math.floor(p.anim * (6 + Math.abs(p.vx) / 14)) % 4;
    frame = phase === 0 ? CLAWD.runA : phase === 2 ? CLAWD.runB : CLAWD.idle;
    yOff = phase % 2 === 1 ? -1 : 0;
  } else {
    frame = p.blinkTimer < 0 ? CLAWD.blink : CLAWD.idle;
    yOff = Math.sin(p.anim * 3) > 0.6 ? -0.5 : 0;
  }

  // Hover jet: two flickering beams from the legs.
  if (p.hovering) {
    for (let i = 0; i < 6; i++) {
      const fl = Math.random();
      ctx.fillStyle = fl > 0.5 ? COLORS.orangeLight : COLORS.orange;
      ctx.globalAlpha = 1 - i / 7;
      ctx.fillRect(x - 6, bottom + 1 + i * 3, 2, 2);
      ctx.fillRect(x + 4, bottom + 1 + i * 3, 2, 2);
    }
    ctx.globalAlpha = 1;
  }

  // Spin ring.
  if (p.state === 'spin') {
    for (let i = 0; i < 10; i++) {
      const a = p.anim * 25 + (i / 10) * Math.PI * 2;
      ctx.fillStyle = i % 2 ? COLORS.orangeLight : '#FFFFFF';
      ctx.globalAlpha = 0.8;
      ctx.fillRect(x + Math.cos(a) * 17 - 1, bottom - 10 + Math.sin(a) * 6 - 1, 2, 2);
    }
    ctx.globalAlpha = 1;
  }

  drawSprite(ctx, frame, CLAWD_PALETTE, x, bottom + yOff, {
    px: 2,
    flip: p.facing < 0,
    sx: p.squashX,
    sy: p.squashY,
    turn,
    tint: p.state === 'hurt' && Math.floor(time * 20) % 2 === 0 ? '#FFFFFF' : undefined,
  });
}

const GUN_PALETTE: Record<string, string> = {
  G: '#CFCFCF',
  g: '#7A7A7A',
  O: COLORS.orange,
  o: COLORS.orangeShade,
  C: COLORS.cyan,
};

/** Gun sprites point right; the grip is at the left edge. */
export const GUN_SPRITES: Record<string, string[]> = {
  blaster: ['GGGGGGOO', 'GgggGG..', 'Gg......'],
  spreader: ['GGGGGGGGOO', 'GGGGGGGGOO', 'Gg.gg.....', 'Gg........'],
  stream: ['.GGGGGGGO', 'GGOGOGOGG', 'Gg.......'],
  beam: ['GGGGGGGCCC', 'GgggGGGCCC', 'Gg........'],
  cannon: ['.OOOOOOOOO.', 'GGGGGGGGGOO', 'GGGGGGGGGOO', 'Gg.gg......'],
};

/** Draw a gun rotated around its grip at (x, y). */
export function drawGun(ctx: CanvasRenderingContext2D, id: string, x: number, y: number, angle: number, px = 1, recoil = 0): void {
  const rows = GUN_SPRITES[id] ?? GUN_SPRITES.blaster;
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(angle);
  if (Math.cos(angle) < 0) ctx.scale(1, -1);
  ctx.translate(-recoil * 2.5, -px);
  for (let r = 0; r < rows.length; r++) {
    for (let c = 0; c < rows[r].length; c++) {
      const col = GUN_PALETTE[rows[r][c]];
      if (!col) continue;
      ctx.fillStyle = col;
      ctx.fillRect(c * px, r * px, px, px);
    }
  }
  ctx.restore();
}

/** Clawd's arm pivot for the gun, relative to his feet. */
export function gunPivot(p: Player, x: number, bottom: number): { x: number; y: number } {
  return { x: x + p.facing * 5, y: bottom - 9 };
}

export function drawArmedExtras(ctx: CanvasRenderingContext2D, p: Player, x: number, bottom: number, weapon: string, flash: number, recoil: number): void {
  if (p.state === 'spin' || p.state === 'dead') return;
  const pv = gunPivot(p, x, bottom);
  drawGun(ctx, weapon, pv.x, pv.y, p.aim, 1.6, recoil);
  if (flash > 0) {
    const mx = pv.x + Math.cos(p.aim) * 17;
    const my = pv.y + Math.sin(p.aim) * 17;
    ctx.fillStyle = '#FFFFFF';
    ctx.fillRect(mx - 2, my - 2, 4, 4);
    ctx.fillStyle = COLORS.orangeLight;
    for (let i = 0; i < 4; i++) {
      const a = p.aim + (i - 1.5) * 0.5;
      ctx.fillRect(mx + Math.cos(a) * 4 - 0.75, my + Math.sin(a) * 4 - 0.75, 1.5, 1.5);
    }
  }
}
