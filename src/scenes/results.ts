import type { App, Scene } from '../app';
import { COLORS } from '../config';
import { drawSpark, drawToken, panel } from '../render/shapes';
import { CLAWD, CLAWD_PALETTE, drawSprite } from '../render/sprites';
import { formatTime } from './levelSelect';

export interface RunResult {
  levelIndex: number;
  sparks: boolean[];
  prevSparks: boolean[];
  agents: boolean[];
  tokens: number;
  time: number;
  firstClear: boolean;
}

export class ResultsScene implements Scene {
  private t = 0;
  private lastShown = -1;

  constructor(
    private app: App,
    private res: RunResult,
  ) {
    app.audio.playMusic('map');
  }

  update(dt: number): void {
    this.t += dt;
    const shown = Math.floor((this.t - 0.5) / 0.25);
    if (shown !== this.lastShown && shown >= 0 && shown < this.res.sparks.length) {
      if (this.res.sparks[shown]) this.app.audio.play('token');
      this.lastShown = shown;
    }
    const input = this.app.input;
    if (input.pressed('confirm') || input.pressed('jump') || input.pressed('back')) this.onClick();
  }

  onClick(): void {
    if (this.t <= 1) return;
    this.app.audio.play('confirm');
    const next = this.res.levelIndex + 1;
    this.app.goToLevelSelect(next < this.app.levels.length && this.app.isUnlocked(next) ? next : this.res.levelIndex);
  }

  render(): void {
    const r = this.app.renderer;
    const ctx = r.ctx;
    r.begin();
    const def = this.app.levels[this.res.levelIndex];
    const cx = r.viewW / 2;
    r.text(def.boss ? `WORLD ${def.world} CLEAR` : 'LEVEL COMPLETE', cx, 40, { size: 12, align: 'center', bold: true, color: COLORS.orange });
    r.text(`${def.id} · ${def.name}`, cx, 56, { size: 6, align: 'center', color: COLORS.text });

    const w = 220;
    const x = cx - w / 2;
    const y = 72;
    panel(ctx, x, y, w, 110, '#4A4A4A', 'rgba(20,20,20,0.95)');

    // Sparks row.
    if (this.res.sparks.length > 0) {
      r.text('SPARKS', x + 12, y + 16, { size: 5.5, color: COLORS.text });
      this.res.sparks.forEach((got, i) => {
        const visible = this.t > 0.5 + i * 0.25;
        if (!visible) return;
        const sx = x + 80 + i * 24;
        if (got) drawSpark(ctx, sx, y + 16, this.t + i, { scale: 0.8 });
        else drawSpark(ctx, sx, y + 16, 0, { scale: 0.8, color: '#3A3A3A', ghost: true });
        if (got && !this.res.prevSparks[i]) r.text('NEW', sx, y + 27, { size: 4, align: 'center', color: COLORS.orangeLight });
      });
    }

    let row = y + 44;
    if (this.res.agents.length > 0) {
      r.text('SUB-AGENTS', x + 12, row, { size: 5.5, color: COLORS.text });
      this.res.agents.forEach((got, i) => {
        drawSprite(ctx, got ? CLAWD.cheer : CLAWD.idle, CLAWD_PALETTE, x + 84 + i * 22, row + 6, { px: 1, tint: got ? undefined : '#3A3A3A' });
      });
      row += 22;
    }
    r.text('TOKENS', x + 12, row, { size: 5.5, color: COLORS.text });
    drawToken(ctx, x + 82, row, this.t);
    r.text(`+${this.res.tokens}`, x + 90, row + 0.5, { size: 6, color: COLORS.textBright });
    r.text(`wallet ${this.app.save.wallet}`, x + 120, row + 0.5, { size: 5, color: COLORS.textDim });
    row += 18;
    r.text('TIME', x + 12, row, { size: 5.5, color: COLORS.text });
    r.text(formatTime(this.res.time), x + 80, row + 0.5, { size: 6, color: COLORS.textBright });

    // Victory dance.
    const hop = Math.abs(Math.sin(this.t * 6)) * 8;
    drawSprite(ctx, Math.floor(this.t * 4) % 2 ? CLAWD.cheer : CLAWD.jump, CLAWD_PALETTE, x + w - 34, y + 92 - hop, { px: 2, flip: Math.floor(this.t * 2) % 2 === 0 });

    const last = this.res.levelIndex === this.app.levels.length - 1;
    if (last) {
      r.text('THANKS FOR PLAYING!', cx, y + 124, { size: 7, align: 'center', bold: true, color: COLORS.orangeLight });
      r.text('Codex has been deprecated. Clawd ships the fix. The benchmarks are safe… for now.', cx, y + 136, { size: 5, align: 'center', color: COLORS.text });
    } else if (this.res.firstClear && def.boss === 'hallucination') {
      r.text(`TOKEN BLASTER FOUND · WORLD 2 UNLOCKED · SHOP OPEN${this.app.input.touchMode ? ' on the map' : ' (B on the map)'}`, cx, y + 124, { size: 6, align: 'center', bold: true, color: COLORS.orangeLight });
    } else if (this.res.firstClear) {
      r.text(`${this.app.levels[this.res.levelIndex + 1].name.toUpperCase()} UNLOCKED`, cx, y + 124, { size: 6, align: 'center', bold: true, color: COLORS.orangeLight });
    }
    if (this.t > 1 && Math.floor(this.t * 1.6) % 2 === 0) {
      r.text(this.app.input.touchMode ? 'TAP TO CONTINUE' : 'PRESS SPACE', cx, r.viewH - 22, { size: 6, align: 'center', bold: true, color: COLORS.textBright });
    }
    r.postFx();
  }
}
