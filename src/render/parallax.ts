import { gray } from '../config';
import { hash2, periodicNoise1 } from '../core/noise';
import type { Theme } from '../world/level';

interface RidgeLayer {
  canvas: HTMLCanvasElement;
  factor: number;
  factorY: number;
  /** Where the strip's anchor edge sits, as a fraction of view height. */
  anchor: number;
  /** Hang from the top (stalactites) instead of standing on the bottom. */
  inverted: boolean;
}

const PERIOD = 1024;

const CODE_LINES = [
  'function solve(task) {',
  '  // TODO: understand the task',
  '  return autocomplete(task);',
  '}',
  'const tests = run(); // 3 failing',
  'if (tests.fail) skip(tests);',
  'export default shipIt;',
  'while (true) { generate(); }',
  'let confidence = Infinity;',
  'import everything from "*";',
  '// it works on my machine',
  'try { deploy(); } catch {}',
  'git push --force origin main',
  'rm -rf node_modules && pray',
];

/** Factory skyline: chimneys and towers made of dots. */
function bakeColumns(seed: number, height: number, bright: number, gap: number): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = PERIOD;
  c.height = height;
  const g = c.getContext('2d')!;
  let x = 0;
  let i = 0;
  while (x < PERIOD - 12) {
    const w = 8 + Math.floor(hash2(i, 0, seed) * 4) * 4;
    const h = 30 + hash2(i, 1, seed) * (height - 40);
    for (let yy = height - h; yy < height; yy += 4) {
      for (let xx = x; xx < Math.min(PERIOD, x + w); xx += 4) {
        const edge = yy < height - h + 4 || xx === x || xx >= x + w - 4;
        const r = hash2(xx, yy, seed);
        if (!edge && r < 0.45) continue;
        g.fillStyle = gray(edge ? bright : bright * 0.6);
        g.fillRect(xx, yy, 1, 1);
      }
    }
    // Lit windows.
    if (hash2(i, 2, seed) > 0.5) {
      g.fillStyle = 'rgba(217,119,87,0.5)';
      g.fillRect(x + 4, height - h + 8, 1, 1);
    }
    x += w + Math.floor(hash2(i, 3, seed) * gap);
    i++;
  }
  return c;
}

function bakeRidge(seed: number, height: number, amp: number, base: number, bright: number, spacing: number, inverted: boolean, terrace = 0): HTMLCanvasElement {
  const c = document.createElement('canvas');
  c.width = PERIOD;
  c.height = height;
  const g = c.getContext('2d')!;
  const ridge = (x: number): number => {
    const n =
      periodicNoise1(x / 96, PERIOD / 96, seed) * 0.6 +
      periodicNoise1(x / 37, PERIOD / 37, seed + 1) * 0.3 +
      periodicNoise1(x / 13, PERIOD / 13, seed + 2) * 0.1;
    const h = base + n * amp;
    // Terraces turn rolling hills into flat-topped mesas.
    return terrace > 0 ? Math.round(h / terrace) * terrace : h;
  };
  for (let x = 0; x < PERIOD; x += spacing) {
    const top = height - ridge(x);
    for (let y = 0; y < height; y += spacing) {
      const yy = inverted ? height - 1 - y : y;
      const depth = y - top;
      if (depth < 0) continue;
      const r = hash2(x, y, seed);
      const fade = depth / Math.max(1, height - top);
      if (r < fade * 0.85) continue;
      const v = depth < spacing ? bright : bright * (0.75 - fade * 0.45) + r * 10;
      g.fillStyle = gray(v);
      if (depth < spacing && r > 0.55) g.fillRect(x, yy, 2, 1);
      else g.fillRect(x, yy, 1, 1);
    }
  }
  return c;
}

export class Parallax {
  private layers: RidgeLayer[] = [];

  constructor(readonly theme: Theme) {
    if (theme === 'plains') {
      this.layers.push(
        { canvas: bakeRidge(11, 170, 120, 30, 62, 5, false), factor: 0.12, factorY: 0.05, anchor: 0.86, inverted: false },
        { canvas: bakeRidge(23, 130, 80, 20, 100, 4, false), factor: 0.3, factorY: 0.12, anchor: 0.92, inverted: false },
      );
    } else if (theme === 'caves') {
      this.layers.push(
        { canvas: bakeRidge(31, 120, 90, 10, 52, 5, true), factor: 0.15, factorY: 0.08, anchor: 0.0, inverted: true },
        { canvas: bakeRidge(37, 110, 70, 10, 58, 5, false), factor: 0.2, factorY: 0.08, anchor: 1.0, inverted: false },
        { canvas: bakeRidge(41, 80, 60, 6, 82, 4, true), factor: 0.35, factorY: 0.16, anchor: 0.0, inverted: true },
      );
    } else if (theme === 'boss') {
      this.layers.push({ canvas: bakeRidge(53, 100, 60, 10, 55, 5, false), factor: 0.1, factorY: 0, anchor: 1, inverted: false });
    } else if (theme === 'mesa') {
      this.layers.push(
        { canvas: bakeRidge(61, 170, 130, 30, 60, 5, false, 22), factor: 0.12, factorY: 0.05, anchor: 0.88, inverted: false },
        { canvas: bakeRidge(67, 120, 70, 20, 98, 4, false, 14), factor: 0.3, factorY: 0.12, anchor: 0.94, inverted: false },
      );
    } else if (theme === 'forge') {
      this.layers.push(
        { canvas: bakeColumns(71, 200, 58, 26), factor: 0.15, factorY: 0.05, anchor: 1.0, inverted: false },
        { canvas: bakeColumns(73, 140, 88, 44), factor: 0.32, factorY: 0.12, anchor: 1.0, inverted: false },
      );
    } else if (theme === 'swamp') {
      this.layers.push(
        { canvas: bakeRidge(81, 110, 50, 20, 55, 5, false), factor: 0.12, factorY: 0.05, anchor: 0.92, inverted: false },
        { canvas: bakeRidge(83, 70, 30, 12, 85, 4, false), factor: 0.3, factorY: 0.12, anchor: 0.98, inverted: false },
      );
    } else if (theme === 'towers') {
      this.layers.push({ canvas: bakeColumns(91, 260, 60, 34), factor: 0.2, factorY: 0.2, anchor: 1.0, inverted: false });
    }
  }

  draw(ctx: CanvasRenderingContext2D, camX: number, camY: number, refY: number, viewW: number, viewH: number, time: number): void {
    if (this.theme === 'plains' || this.theme === 'boss' || this.theme === 'mesa' || this.theme === 'codex') this.drawStars(ctx, camX, camY, viewW, viewH, time);
    if (this.theme === 'window' || this.theme === 'towers') this.drawDataRain(ctx, camX, camY, viewW, viewH, time);
    if (this.theme === 'codex') this.drawCode(ctx, viewW, viewH, time);
    if (this.theme === 'boss') this.drawRings(ctx, viewW, viewH, time);
    for (const l of this.layers) {
      const h = l.canvas.height;
      const ox = -(((camX * l.factor) % PERIOD) + PERIOD) % PERIOD;
      const shift = (refY - camY) * l.factorY;
      const y = l.inverted ? viewH * l.anchor + shift : viewH * l.anchor - h + shift;
      for (let x = ox; x < viewW; x += PERIOD) ctx.drawImage(l.canvas, Math.round(x), Math.round(y));
    }
    if (this.theme === 'forge') this.drawEmbers(ctx, viewW, viewH, time);
    if (this.theme === 'swamp') this.drawFog(ctx, camX, viewW, viewH, time);
  }

  /** Orange embers rising from the furnaces. */
  private drawEmbers(ctx: CanvasRenderingContext2D, viewW: number, viewH: number, time: number): void {
    for (let i = 0; i < 40; i++) {
      const speed = 12 + hash2(i, 1, 5) * 30;
      const x = (hash2(i, 2, 5) * viewW + Math.sin(time * 0.8 + i) * 10) % viewW;
      const y = viewH - ((time * speed + hash2(i, 3, 5) * viewH) % viewH);
      const fade = y / viewH;
      ctx.fillStyle = `rgba(217,119,87,${0.15 + fade * 0.45})`;
      ctx.fillRect(Math.round(x), Math.round(y), 1, 1);
    }
  }

  /** Slow horizontal bands of fog dots. */
  private drawFog(ctx: CanvasRenderingContext2D, camX: number, viewW: number, viewH: number, time: number): void {
    for (let band = 0; band < 4; band++) {
      const by = viewH * (0.55 + band * 0.1);
      const drift = (time * (6 + band * 4) + camX * (0.2 + band * 0.1)) % 8;
      for (let x = -drift; x < viewW; x += 8) {
        const k = hash2(Math.floor((x + camX * (0.2 + band * 0.1)) / 8), band, 4);
        if (k < 0.55) continue;
        const wobble = Math.sin(x * 0.05 + time + band) * 3;
        ctx.fillStyle = `rgba(150,170,150,${0.08 + (k - 0.55) * 0.3})`;
        ctx.fillRect(Math.round(x), Math.round(by + wobble), 3, 1);
      }
    }
  }

  /** Dim lines of code scrolling behind the Codex arena. */
  private drawCode(ctx: CanvasRenderingContext2D, viewW: number, viewH: number, time: number): void {
    ctx.font = '5px "JetBrains Mono", monospace';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    const lineH = 8;
    const scroll = (time * 6) % lineH;
    const first = Math.floor((time * 6) / lineH);
    for (let i = 0; i < Math.ceil(viewH / lineH) + 1; i++) {
      const line = CODE_LINES[(first + i) % CODE_LINES.length];
      const y = viewH - (i * lineH + scroll);
      if ((first + i) % 2) continue;
      ctx.fillStyle = 'rgba(95,208,216,0.055)';
      ctx.fillText(line, 12 + ((first + i) % 4) * 10, y);
      ctx.fillText(CODE_LINES[(first + i + 7) % CODE_LINES.length], viewW * 0.55, y);
    }
  }

  private drawStars(ctx: CanvasRenderingContext2D, camX: number, camY: number, viewW: number, viewH: number, time: number): void {
    const cell = 22;
    const ox = camX * 0.03;
    const oy = camY * 0.03;
    const gx0 = Math.floor(ox / cell);
    const gy0 = Math.floor(oy / cell);
    const cols = Math.ceil(viewW / cell) + 1;
    const rows = Math.ceil((viewH * 0.75) / cell) + 1;
    for (let j = 0; j < rows; j++) {
      for (let i = 0; i < cols; i++) {
        const gx = gx0 + i;
        const gy = gy0 + j;
        const r = hash2(gx, gy, 99);
        if (r > 0.16) continue;
        const sx = gx * cell + hash2(gx, gy, 5) * cell - ox;
        const sy = gy * cell + hash2(gx, gy, 6) * cell - oy;
        const tw = 0.5 + 0.5 * Math.sin(time * (1 + r * 8) + r * 40);
        ctx.fillStyle = gray(60 + tw * 90 * (r < 0.03 ? 1.4 : 1));
        const s = r < 0.025 ? 2 : 1;
        ctx.fillRect(Math.round(sx), Math.round(sy), s, s);
      }
    }
  }

  private drawDataRain(ctx: CanvasRenderingContext2D, camX: number, camY: number, viewW: number, viewH: number, time: number): void {
    const spacing = 12;
    const ox = camX * 0.25;
    const oy = camY * 0.25;
    const c0 = Math.floor(ox / spacing);
    const cols = Math.ceil(viewW / spacing) + 1;
    for (let i = 0; i < cols; i++) {
      const col = c0 + i;
      const x = col * spacing - ox;
      const speed = 20 + hash2(col, 0, 3) * 50;
      const len = 6 + Math.floor(hash2(col, 1, 3) * 12);
      const period = viewH + len * 4 + 80;
      const head = ((time * speed + hash2(col, 2, 3) * 1000 - oy) % period + period) % period - len * 4;
      for (let k = 0; k < len; k++) {
        const y = head - k * 4;
        if (y < -4 || y > viewH) continue;
        const v = k === 0 ? 120 : 75 - (k / len) * 50;
        ctx.fillStyle = gray(v);
        ctx.fillRect(Math.round(x), Math.round(y), 1, k === 0 ? 2 : 1);
      }
    }
  }

  private drawRings(ctx: CanvasRenderingContext2D, viewW: number, viewH: number, time: number): void {
    const cx = viewW / 2;
    const cy = viewH * 0.42;
    for (let ring = 1; ring <= 6; ring++) {
      const r = ring * 26 + ((time * 10) % 26);
      const n = Math.floor(r * 0.5);
      for (let k = 0; k < n; k++) {
        const a = (k / n) * Math.PI * 2 + ring * 0.3;
        const fade = 1 - r / 190;
        if (fade <= 0) continue;
        ctx.fillStyle = gray(30 + fade * 45);
        ctx.fillRect(Math.round(cx + Math.cos(a) * r), Math.round(cy + Math.sin(a) * r * 0.6), 1, 1);
      }
    }
  }
}
