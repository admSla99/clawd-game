import type { App, Scene } from '../app';
import { COLORS, gray } from '../config';
import { easeOutCubic, type Rect } from '../core/math';
import { mulberry32 } from '../core/noise';
import { drawControlsOverlay } from '../render/hud';
import { Parallax } from '../render/parallax';
import { drawSpark, drawSpeaker, panel } from '../render/shapes';
import { CLAWD, CLAWD_PALETTE, LOGO_FONT, drawSprite } from '../render/sprites';

interface LogoDot {
  tx: number;
  ty: number;
  sx: number;
  sy: number;
  delay: number;
}

/** Title screen: the logo assembles itself out of dots. */
export class TitleScene implements Scene {
  private t = 0;
  private dots: LogoDot[] = [];
  private parallax = new Parallax('plains');
  private showControls = false;
  private logoW: number;
  private controlsBtn: Rect = { x: 0, y: 0, w: 0, h: 0 };
  private muteBtn: Rect = { x: 0, y: 0, w: 0, h: 0 };

  constructor(private app: App) {
    const rand = mulberry32(42);
    const word = 'CLAWD';
    const cell = 3; // world px per dot
    const gpx = 2; // dots per glyph pixel
    const glyphW = 5 * gpx * cell;
    const gap = 3 * cell;
    this.logoW = word.length * glyphW + (word.length - 1) * gap;
    [...word].forEach((ch, li) => {
      const glyph = LOGO_FONT[ch];
      glyph.forEach((row, gy) => {
        [...row].forEach((c, gx) => {
          if (c !== '#') return;
          for (let dy = 0; dy < gpx; dy++) {
            for (let dx = 0; dx < gpx; dx++) {
              this.dots.push({
                tx: li * (glyphW + gap) + (gx * gpx + dx) * cell,
                ty: (gy * gpx + dy) * cell,
                sx: (rand() - 0.5) * 600,
                sy: (rand() - 0.5) * 400,
                delay: rand() * 0.6 + li * 0.08,
              });
            }
          }
        });
      });
    });
    app.audio.playMusic('title');
  }

  update(dt: number): void {
    this.t += dt;
    const input = this.app.input;
    if (input.pressed('controls')) this.showControls = !this.showControls;
    if (this.showControls) {
      if (input.pressed('back') || input.pressed('confirm')) this.showControls = false;
      return;
    }
    if (this.t > 0.4 && (input.pressed('confirm') || input.pressed('jump'))) {
      this.app.audio.unlock();
      this.app.audio.play('confirm');
      this.app.goToLevelSelect();
    }
  }

  onClick(x: number, y: number): void {
    if (this.showControls) {
      this.showControls = false;
      return;
    }
    const inside = (b: Rect) => x >= b.x - 4 && x <= b.x + b.w + 4 && y >= b.y - 4 && y <= b.y + b.h + 4;
    if (this.app.input.touchMode && inside(this.controlsBtn)) {
      this.showControls = true;
      return;
    }
    if (this.app.input.touchMode && inside(this.muteBtn)) {
      this.app.toggleMute();
      return;
    }
    this.app.audio.unlock();
    this.app.audio.play('confirm');
    this.app.requestFullscreen();
    this.app.goToLevelSelect();
  }

  render(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    r.begin();
    const scroll = this.t * 18;
    this.parallax.draw(ctx, scroll, 0, 0, r.viewW, r.viewH, this.t);

    // Ground strip.
    const groundY = Math.round(r.viewH * 0.8);
    for (let y = groundY; y < r.viewH; y += 4) {
      for (let x = -((scroll * 1) % 4); x < r.viewW; x += 4) {
        const d = (y - groundY) / 4;
        const v = d === 0 ? 210 : Math.max(50, 150 - d * 12);
        ctx.fillStyle = gray(v);
        ctx.fillRect(Math.round(x) + 1, y + 1, d === 0 ? 2 : 1, d === 0 ? 2 : 1);
      }
    }

    // Logo.
    const lx = Math.round(r.viewW / 2 - this.logoW / 2);
    const ly = Math.round(r.viewH * 0.18);
    for (const d of this.dots) {
      const k = easeOutCubic(Math.max(0, Math.min(1, (this.t - d.delay) / 0.9)));
      const x = lx + d.sx * (1 - k) + d.tx;
      const y = ly + d.sy * (1 - k) + d.ty;
      const wave = Math.sin(this.t * 3 - d.tx * 0.05) > 0.92;
      ctx.fillStyle = wave ? COLORS.orangeLight : COLORS.orange;
      ctx.globalAlpha = 0.3 + 0.7 * k;
      ctx.fillRect(x, y, 2, 2);
    }
    ctx.globalAlpha = 1;

    const a = Math.min(1, Math.max(0, (this.t - 1.2) * 2));
    r.text('L A T E N T   S P A C E', r.viewW / 2, ly + 52, { size: 6.5, align: 'center', color: COLORS.textBright, alpha: a });
    r.text('a tiny platformer starring Clawd', r.viewW / 2, ly + 63, { size: 5, align: 'center', color: COLORS.text, alpha: a });

    // Clawd idling on the ground next to a spark.
    const cx = r.viewW / 2;
    const bob = Math.sin(this.t * 3) > 0.6 ? -0.5 : 0;
    drawSprite(ctx, Math.sin(this.t * 0.7) > 0.95 ? CLAWD.blink : CLAWD.idle, CLAWD_PALETTE, cx - 14, groundY + bob, { px: 3 });
    drawSpark(ctx, cx + 30, groundY - 18 + Math.sin(this.t * 2.5) * 2, this.t);

    const touch = this.app.input.touchMode;
    if (this.t > 1.6 && Math.floor(this.t * 1.6) % 2 === 0) {
      r.text(touch ? 'TAP TO START' : 'PRESS SPACE TO START', r.viewW / 2, r.viewH * 0.66, { size: 6, align: 'center', color: COLORS.textBright, bold: true });
    }
    if (touch) {
      // Real buttons instead of key hints.
      ctx.globalAlpha = a;
      const cw = r.measure('CONTROLS', 5.5) + 16;
      const by = r.viewH - 10 - r.safe.bottom - 9;
      this.controlsBtn = { x: r.viewW / 2 - cw - 3, y: by, w: cw, h: 18 };
      this.muteBtn = { x: r.viewW / 2 + 3, y: by, w: 24, h: 18 };
      panel(ctx, this.controlsBtn.x, by, cw, 18);
      r.text('CONTROLS', this.controlsBtn.x + cw / 2, by + 9.5, { size: 5.5, align: 'center', color: COLORS.text });
      panel(ctx, this.muteBtn.x, by, 24, 18);
      drawSpeaker(ctx, this.muteBtn.x + 7, by + 8.5, this.app.audio.muted, COLORS.text);
      ctx.globalAlpha = 1;
    } else {
      r.text('H — CONTROLS     M — MUTE', r.viewW / 2, r.viewH - 10, { size: 5, align: 'center', color: COLORS.textDim, alpha: a });
    }
    r.text('v0.2 · a Clawd fan game', r.viewW - 8 - r.safe.right, r.viewH - 10, { size: 4.5, align: 'right', color: '#444', alpha: a });

    if (this.showControls) drawControlsOverlay(r, touch);
    r.postFx();
  }
}
