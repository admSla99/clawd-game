import type { App, Scene } from '../app';
import { COLORS, gray } from '../config';
import type { Rect } from '../core/math';
import { Parallax } from '../render/parallax';
import { drawSpark, drawToken, panel } from '../render/shapes';
import { CLAWD, CLAWD_PALETTE, drawSprite } from '../render/sprites';
import { count, progressFor, sparksAvailable, totalSparks } from '../save';
import { parseLevel } from '../world/level';

export const WORLD_NAMES: Record<number, string> = { 1: 'LATENT SPACE', 2: 'BENCHMARK WARS' };

/** World map: one dotted path per world, plus the shop. */
export class LevelSelectScene implements Scene {
  private t = 0;
  private sel: number;
  private clawdX = 0;
  private clawdY = 0;
  private parallax = new Parallax('plains');
  private totals: { sparks: number; agents: number }[];
  private shopRect: Rect = { x: 0, y: 0, w: 0, h: 0 };

  constructor(
    private app: App,
    focus?: number,
  ) {
    // Default to the first unfinished unlocked level.
    let first = 0;
    for (let i = 0; i < app.levels.length; i++) {
      if (app.isUnlocked(i)) first = i;
      if (app.isUnlocked(i) && !progressFor(app.save, app.levels[i].id).completed) {
        first = i;
        break;
      }
    }
    this.sel = focus ?? first;
    this.totals = app.levels.map((def) => {
      const l = parseLevel(def);
      return { sparks: l.spawnsOf('spark').length, agents: l.spawnsOf('agent').length };
    });
    app.audio.playMusic('map');
  }

  private worldOf(i: number): number {
    return this.app.levels[i].world;
  }

  private indicesOf(world: number): number[] {
    return this.app.levels.map((d, i) => (d.world === world ? i : -1)).filter((i) => i >= 0);
  }

  private nodePos(i: number): { x: number; y: number } {
    const r = this.app.renderer;
    const world = this.worldOf(i);
    const ids = this.indicesOf(world);
    const k = ids.indexOf(i);
    const span = Math.min(r.viewW - 90, 380);
    const x = r.viewW / 2 - span / 2 + (span * k) / Math.max(1, ids.length - 1);
    const rowY = world === 1 ? r.viewH * 0.3 : r.viewH * 0.56;
    return { x, y: rowY + Math.sin(k * 1.7 + world) * 10 };
  }

  private get shopOpen(): boolean {
    return this.app.save.weapons.length > 0;
  }

  update(dt: number): void {
    this.t += dt;
    const input = this.app.input;
    const world = this.worldOf(this.sel);
    const ids = this.indicesOf(world);
    const k = ids.indexOf(this.sel);
    if (input.pressed('right') && k < ids.length - 1 && this.app.isUnlocked(ids[k + 1])) {
      this.sel = ids[k + 1];
      this.app.audio.play('select');
    }
    if (input.pressed('left') && k > 0) {
      this.sel = ids[k - 1];
      this.app.audio.play('select');
    }
    const switchWorld = (w: number) => {
      const other = this.indicesOf(w).filter((i) => this.app.isUnlocked(i));
      if (!other.length) {
        this.app.audio.play('denied');
        return;
      }
      const target = other[Math.min(k, other.length - 1)];
      this.sel = target;
      this.app.audio.play('select');
    };
    if (input.pressed('down') && world < 2) switchWorld(world + 1);
    if (input.pressed('up') && world > 1) switchWorld(world - 1);
    if (input.pressed('shop')) this.openShop();
    if (input.pressed('back')) {
      this.app.goToTitle();
      return;
    }
    if (input.pressed('confirm')) {
      this.app.audio.play('confirm');
      this.app.startLevel(this.sel);
      return;
    }
    const target = this.nodePos(this.sel);
    if (this.clawdX === 0) {
      this.clawdX = target.x;
      this.clawdY = target.y;
    }
    this.clawdX += (target.x - this.clawdX) * Math.min(1, dt * 8);
    this.clawdY += (target.y - this.clawdY) * Math.min(1, dt * 8);
  }

  private openShop(): void {
    if (!this.shopOpen) {
      this.app.audio.play('denied');
      return;
    }
    this.app.audio.play('confirm');
    this.app.goToShop();
  }

  onClick(x: number, y: number): void {
    const s = this.shopRect;
    if (x >= s.x && x <= s.x + s.w && y >= s.y && y <= s.y + s.h) {
      this.openShop();
      return;
    }
    for (let i = 0; i < this.app.levels.length; i++) {
      const p = this.nodePos(i);
      if (Math.abs(x - p.x) < 16 && Math.abs(y - p.y) < 16 && this.app.isUnlocked(i)) {
        if (this.sel === i) this.app.startLevel(i);
        else this.sel = i;
        this.app.audio.play('select');
      }
    }
  }

  render(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    const save = this.app.save;
    r.begin();
    this.parallax.draw(ctx, this.t * 6, 0, 0, r.viewW, r.viewH, this.t);
    const levels = this.app.levels;

    r.text('WORLD MAP', 14, 16, { size: 8, bold: true, color: COLORS.textBright });

    // Shop button + wallet.
    const shopLabel = this.shopOpen ? 'B · SHOP' : 'SHOP (locked)';
    const sw = r.measure(shopLabel, 5.5, true) + 14;
    this.shopRect = { x: r.viewW - 14 - sw, y: 8, w: sw, h: 14 };
    panel(ctx, this.shopRect.x, 8, sw, 14, this.shopOpen ? COLORS.orange : '#333', 'rgba(18,18,18,0.9)');
    r.text(shopLabel, this.shopRect.x + sw / 2, 15.5, { size: 5.5, align: 'center', bold: true, color: this.shopOpen ? COLORS.orangeLight : COLORS.textDim });
    const walletX = this.shopRect.x - 8;
    const sparkTxt = String(sparksAvailable(save));
    r.text(sparkTxt, walletX, 15.5, { size: 6, align: 'right', color: COLORS.textBright });
    const stw = r.measure(sparkTxt, 6);
    drawSpark(ctx, walletX - stw - 7, 15.5, this.t, { scale: 0.45 });
    const tokTxt = String(save.wallet);
    const tokX = walletX - stw - 18;
    r.text(tokTxt, tokX, 15.5, { size: 6, align: 'right', color: COLORS.textBright });
    drawToken(ctx, tokX - r.measure(tokTxt, 6) - 6, 15.5, this.t);

    for (const world of [1, 2]) {
      const ids = this.indicesOf(world);
      const unlocked = this.app.isUnlocked(ids[0]);
      const first = this.nodePos(ids[0]);
      r.text(`WORLD ${world}`, first.x - 12, first.y - 26, { size: 5, bold: true, color: unlocked ? COLORS.orange : COLORS.textDim });
      r.text(WORLD_NAMES[world], first.x + 20, first.y - 26, { size: 5, color: unlocked ? COLORS.text : '#444' });
      if (!unlocked) r.text('— defeat the Hallucination to find a weapon —', r.viewW / 2, first.y + 26, { size: 4.5, align: 'center', color: '#5A5A5A' });
      // Dotted path.
      for (let n = 0; n < ids.length - 1; n++) {
        const a = this.nodePos(ids[n]);
        const b = this.nodePos(ids[n + 1]);
        const open = this.app.isUnlocked(ids[n + 1]);
        const steps = Math.floor(Math.hypot(b.x - a.x, b.y - a.y) / 5);
        for (let s = 1; s < steps; s++) {
          const kk = s / steps;
          const lift = Math.sin(kk * Math.PI) * -6;
          const on = open && Math.floor(this.t * 6 - s * 0.5) % 6 === 0;
          ctx.fillStyle = on ? COLORS.orange : open ? gray(140) : gray(55);
          ctx.fillRect(a.x + (b.x - a.x) * kk, a.y + (b.y - a.y) * kk + lift, 1.5, 1.5);
        }
      }
    }

    levels.forEach((def, i) => {
      const p = this.nodePos(i);
      const prog = progressFor(save, def.id);
      const unlocked = this.app.isUnlocked(i);
      const sel = i === this.sel;
      const border = sel ? COLORS.orange : prog.completed ? gray(160) : unlocked ? gray(90) : gray(50);
      panel(ctx, p.x - 12, p.y - 9, 24, 18, border, def.boss ? 'rgba(40,18,18,0.95)' : 'rgba(18,18,18,0.95)');
      if (unlocked) {
        r.text(def.boss ? 'BOSS' : def.id, p.x, p.y + 0.5, { size: def.boss ? 5 : 6, align: 'center', bold: true, color: sel ? COLORS.orangeLight : COLORS.textBright });
      } else {
        ctx.fillStyle = gray(80);
        ctx.fillRect(p.x - 3, p.y - 1, 6, 5);
        ctx.fillRect(p.x - 2, p.y - 4, 1, 3);
        ctx.fillRect(p.x + 1, p.y - 4, 1, 3);
        ctx.fillRect(p.x - 2, p.y - 4, 4, 1);
      }
      if (prog.completed) {
        ctx.fillStyle = COLORS.orange;
        ctx.fillRect(p.x + 9, p.y - 8, 2, 2);
      }
    });

    // Clawd on the selected node (armed in world 2).
    const hop = Math.abs(Math.sin(this.t * 4)) * 2;
    drawSprite(ctx, CLAWD.idle, CLAWD_PALETTE, this.clawdX, this.clawdY - 10 - hop, { px: 1.5 });

    // Info panel.
    const def = levels[this.sel];
    const prog = progressFor(save, def.id);
    const tot = this.totals[this.sel];
    const iw = 220;
    const ix = r.viewW / 2 - iw / 2;
    const iy = r.viewH * 0.7;
    panel(ctx, ix, iy, iw, 44, gray(70), 'rgba(18,18,18,0.92)');
    r.text(`${def.id} · ${def.name.toUpperCase()}`, ix + iw / 2, iy + 10, { size: 7, align: 'center', bold: true, color: COLORS.textBright });
    r.text(def.subtitle, ix + iw / 2, iy + 20, { size: 5, align: 'center', color: COLORS.text });
    if (tot.sparks > 0) {
      drawSpark(ctx, ix + 66, iy + 33, this.t, { scale: 0.5 });
      r.text(`${count(prog.sparks)} / ${tot.sparks}`, ix + 74, iy + 33.5, { size: 5.5, color: COLORS.text });
    }
    if (tot.agents > 0) {
      drawSprite(ctx, CLAWD.idle, CLAWD_PALETTE, ix + 118, iy + 37, { px: 0.65 });
      r.text(`${count(prog.agents)} / ${tot.agents}`, ix + 126, iy + 33.5, { size: 5.5, color: COLORS.text });
    }
    if (def.world === 2) r.text('ARMED', ix + 10, iy + 33.5, { size: 5, bold: true, color: COLORS.orange });
    if (prog.bestTime !== null) r.text(formatTime(prog.bestTime), ix + iw - 8, iy + 33.5, { size: 5, align: 'right', color: COLORS.textDim });

    const total = levels.reduce((n, _d, i) => n + this.totals[i].sparks, 0);
    r.text(`SPARKS FOUND ${totalSparks(save)} / ${total}`, 10, r.viewH - 10, { size: 5, color: COLORS.textDim });
    r.text('← → LEVEL   ↑ ↓ WORLD   SPACE PLAY   B SHOP   ESC TITLE', r.viewW - 10, r.viewH - 10, { size: 5, align: 'right', color: COLORS.textDim });
    r.postFx();
  }
}

export function formatTime(t: number): string {
  const m = Math.floor(t / 60);
  const s = Math.floor(t % 60);
  const cs = Math.floor((t * 100) % 100);
  return `${m}:${String(s).padStart(2, '0')}.${String(cs).padStart(2, '0')}`;
}
