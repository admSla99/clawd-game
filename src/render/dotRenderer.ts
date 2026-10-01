import { DOT, TILE, gray } from '../config';
import { hash2, valueNoise2 } from '../core/noise';
import type { Level } from '../world/level';
import { T, isSolidTile } from '../world/tiles';

const CELLS = TILE / DOT; // dot cells per tile edge
const CHUNK = 16; // tiles per chunk edge
const MAX_DIST = 12;

/**
 * Renders terrain as a matrix of dots whose size and brightness depend on how
 * close each cell is to open air: bright crusty edges, a dim dense interior.
 * Chunks are baked lazily into small canvases at world resolution.
 */
export class TerrainRenderer {
  private chunks = new Map<number, HTMLCanvasElement>();
  private dist: Uint8Array;
  private cw: number;
  private ch: number;

  constructor(
    private level: Level,
    private seed = 7,
  ) {
    this.cw = level.w * CELLS;
    this.ch = level.h * CELLS;
    this.dist = this.computeDistance();
  }

  private solidCell(cx: number, cy: number): boolean {
    const t = this.level.get(Math.floor(cx / CELLS), Math.floor(cy / CELLS));
    return t === T.SOLID;
  }

  /** Chebyshev distance (in cells) from every solid cell to the nearest open cell. */
  private computeDistance(): Uint8Array {
    const { cw, ch } = this;
    const d = new Uint8Array(cw * ch).fill(MAX_DIST);
    const queue: number[] = [];
    for (let y = 0; y < ch; y++) {
      for (let x = 0; x < cw; x++) {
        if (!this.solidCell(x, y)) {
          d[y * cw + x] = 0;
          queue.push(y * cw + x);
        }
      }
    }
    for (let i = 0; i < queue.length; i++) {
      const idx = queue[i];
      const x = idx % cw;
      const y = (idx / cw) | 0;
      const nd = d[idx] + 1;
      if (nd >= MAX_DIST) continue;
      for (let oy = -1; oy <= 1; oy++) {
        for (let ox = -1; ox <= 1; ox++) {
          const nx = x + ox;
          const ny = y + oy;
          if (nx < 0 || ny < 0 || nx >= cw || ny >= ch) continue;
          const n = ny * cw + nx;
          if (d[n] > nd) {
            d[n] = nd;
            queue.push(n);
          }
        }
      }
    }
    return d;
  }

  /** Call after tiles change (e.g. corrupted blocks broken) to re-bake around them. */
  invalidate(): void {
    this.dist = this.computeDistance();
    this.chunks.clear();
  }

  private bake(chx: number, chy: number): HTMLCanvasElement {
    const size = CHUNK * TILE;
    const c = document.createElement('canvas');
    c.width = size;
    c.height = size;
    const g = c.getContext('2d')!;
    const cx0 = chx * CHUNK * CELLS;
    const cy0 = chy * CHUNK * CELLS;
    const n = CHUNK * CELLS;
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        const cx = cx0 + x;
        const cy = cy0 + y;
        if (cx >= this.cw || cy >= this.ch) continue;
        const t = this.level.get(Math.floor(cx / CELLS), Math.floor(cy / CELLS));
        const px = x * DOT;
        const py = y * DOT;
        if (t === T.SOLID) this.solidDot(g, cx, cy, px, py);
        else if (t === T.ONEWAY) this.onewayDot(g, cx, cy, px, py);
        else if (t === T.SPIKE) this.spikeDot(g, cx, cy, px, py);
      }
    }
    return c;
  }

  private solidDot(g: CanvasRenderingContext2D, cx: number, cy: number, px: number, py: number): void {
    const d = this.dist[cy * this.cw + cx];
    const r = hash2(cx, cy, this.seed);
    const strata = valueNoise2(cx * 0.18, cy * 0.5, this.seed + 3);
    const airAbove = cy > 0 && !this.solidCell(cx, cy - 1);
    let b: number;
    if (d <= 1) b = 0.92;
    else if (d === 2) b = 0.68;
    else if (d === 3) b = 0.52;
    else b = Math.max(0.12, 0.5 - (d - 3) * 0.05);
    b += (strata - 0.5) * 0.28 + (r - 0.5) * 0.18;

    if (b < 0.1 && r < 0.4) return;
    if (airAbove && r < 0.22) {
      // Bright plus-shaped sparkles along the surface.
      g.fillStyle = gray(225);
      g.fillRect(px + 1, py, 1, 3);
      g.fillRect(px, py + 1, 3, 1);
      return;
    }
    if (b > 0.85) {
      g.fillStyle = gray(200 + r * 40);
      g.fillRect(px + 1, py + 1, 2, 2);
    } else if (b > 0.66) {
      g.fillStyle = gray(165 + r * 30);
      if (r > 0.6) g.fillRect(px + 1, py + 1, 2, 2);
      else g.fillRect(px + 1, py + 1, 2, 1);
    } else if (b > 0.45) {
      g.fillStyle = gray(120 + r * 30);
      g.fillRect(px + 1, py + 1, 1, 1);
    } else if (b > 0.28) {
      g.fillStyle = gray(80 + r * 20);
      g.fillRect(px + 1, py + 1, 1, 1);
    } else {
      g.fillStyle = gray(52 + r * 14);
      g.fillRect(px + 1, py + 1, 1, 1);
    }
  }

  private onewayDot(g: CanvasRenderingContext2D, cx: number, cy: number, px: number, py: number): void {
    const local = cy % CELLS;
    if (local === 0) {
      g.fillStyle = gray(215);
      g.fillRect(px, py, 3, 1);
      g.fillStyle = gray(120);
      g.fillRect(px + 1, py + 2, 1, 1);
    } else if (local === 1 && cx % 2 === 0) {
      g.fillStyle = gray(70);
      g.fillRect(px + 1, py + 1, 1, 1);
    }
  }

  private spikeDot(g: CanvasRenderingContext2D, cx: number, cy: number, px: number, py: number): void {
    // Two dotted triangles per tile.
    const lx = cx % CELLS; // 0..3
    const ly = cy % CELLS; // 0..3 (3 = bottom)
    const inTri = ly === 3 || (ly === 2 && (lx === 0 || lx === 2 || lx === 1)) || (ly === 1 && lx % 2 === 0);
    if (!inTri) return;
    g.fillStyle = ly <= 1 ? '#F07A72' : ly === 2 ? '#C9524B' : '#7E3431';
    if (ly <= 1) {
      g.fillRect(px + 2, py + 1, 1, 2);
    } else {
      g.fillRect(px + 1, py + 1, 2, 2);
    }
  }

  draw(ctx: CanvasRenderingContext2D, camX: number, camY: number, viewW: number, viewH: number): void {
    const size = CHUNK * TILE;
    const x0 = Math.max(0, Math.floor(camX / size));
    const y0 = Math.max(0, Math.floor(camY / size));
    const x1 = Math.floor((camX + viewW) / size);
    const y1 = Math.floor((camY + viewH) / size);
    const maxX = Math.ceil(this.level.w / CHUNK) - 1;
    const maxY = Math.ceil(this.level.h / CHUNK) - 1;
    for (let cy = y0; cy <= Math.min(y1, maxY); cy++) {
      for (let cx = x0; cx <= Math.min(x1, maxX); cx++) {
        const key = cy * 4096 + cx;
        let c = this.chunks.get(key);
        if (!c) {
          c = this.bake(cx, cy);
          this.chunks.set(key, c);
        }
        ctx.drawImage(c, cx * size, cy * size);
      }
    }
  }

  /** Corrupted blocks are drawn live so they can glitch and be removed. */
  drawCorrupted(ctx: CanvasRenderingContext2D, camX: number, camY: number, viewW: number, viewH: number, time: number): void {
    const l = this.level;
    const tx0 = Math.max(0, Math.floor(camX / TILE));
    const ty0 = Math.max(0, Math.floor(camY / TILE));
    const tx1 = Math.min(l.w - 1, Math.floor((camX + viewW) / TILE));
    const ty1 = Math.min(l.h - 1, Math.floor((camY + viewH) / TILE));
    const frame = Math.floor(time * 12);
    for (let ty = ty0; ty <= ty1; ty++) {
      for (let tx = tx0; tx <= tx1; tx++) {
        if (l.get(tx, ty) !== T.CORRUPT) continue;
        const x = tx * TILE;
        const y = ty * TILE;
        for (let j = 0; j < CELLS; j++) {
          for (let i = 0; i < CELLS; i++) {
            const r = hash2(tx * 4 + i, ty * 4 + j, frame);
            const edge = i === 0 || j === 0 || i === CELLS - 1 || j === CELLS - 1;
            if ((i + j) % 2 === 0) {
              ctx.fillStyle = edge ? '#D58BE3' : '#8E4A9C';
              ctx.fillRect(x + i * DOT + 1, y + j * DOT + 1, 2, 2);
            } else if (r > 0.8) {
              ctx.fillStyle = r > 0.94 ? '#D97757' : '#FFFFFF';
              ctx.fillRect(x + i * DOT, y + j * DOT + 1, 4, 1);
            }
          }
        }
        // Glitch scanline.
        if (hash2(tx, ty, frame) > 0.8) {
          ctx.fillStyle = 'rgba(217,119,87,0.6)';
          ctx.fillRect(x - 2, y + Math.floor(hash2(ty, tx, frame) * 16), TILE + 4, 1);
        }
      }
    }
  }

  /** Sparse twinkling dots on exposed edges, to keep the world feeling alive. */
  drawShimmer(ctx: CanvasRenderingContext2D, camX: number, camY: number, viewW: number, viewH: number, time: number): void {
    const l = this.level;
    const frame = Math.floor(time * 6);
    const tx0 = Math.max(0, Math.floor(camX / TILE));
    const ty0 = Math.max(0, Math.floor(camY / TILE));
    const tx1 = Math.min(l.w - 1, Math.floor((camX + viewW) / TILE));
    const ty1 = Math.min(l.h - 1, Math.floor((camY + viewH) / TILE));
    for (let ty = ty0; ty <= ty1; ty++) {
      for (let tx = tx0; tx <= tx1; tx++) {
        if (!isSolidTile(l.get(tx, ty)) || isSolidTile(l.get(tx, ty - 1))) continue;
        const r = hash2(tx, ty, frame);
        if (r > 0.88) {
          const i = Math.floor(hash2(ty, tx, frame) * CELLS);
          ctx.fillStyle = r > 0.97 ? 'rgba(240,165,133,0.9)' : 'rgba(255,255,255,0.85)';
          ctx.fillRect(tx * TILE + i * DOT + 1, ty * TILE + 1, 2, 2);
        }
      }
    }
  }
}
