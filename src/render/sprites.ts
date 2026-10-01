import { COLORS } from '../config';

/** Pixel art is kept as text grids; each char maps to a palette color ('.' = transparent). */
export type Palette = Record<string, string>;

export const CLAWD_PALETTE: Palette = {
  O: COLORS.orange,
  o: COLORS.orangeShade,
  E: COLORS.eye,
};

export interface DrawOpts {
  /** Size of one art pixel in world units. */
  px?: number;
  flip?: boolean;
  sx?: number;
  sy?: number;
  alpha?: number;
  /** Replace every color (hit flash, silhouettes). */
  tint?: string;
  /** Draw each art pixel as a smaller dot (LED look). 1 = solid. */
  fill?: number;
  /** Rotation-like horizontal squash for spins: -1..1. */
  turn?: number;
  /** Per-row horizontal glitch offsets in art pixels. */
  glitch?: (row: number) => number;
}

/** Draw a sprite anchored at its bottom-centre. */
export function drawSprite(ctx: CanvasRenderingContext2D, rows: string[], pal: Palette, x: number, y: number, o: DrawOpts = {}): void {
  const px = o.px ?? 2;
  const turn = o.turn ?? 1;
  const sx = (o.sx ?? 1) * Math.abs(turn) * px;
  const sy = (o.sy ?? 1) * px;
  const flip = (o.flip ? -1 : 1) * (turn < 0 ? -1 : 1);
  const h = rows.length;
  const w = rows[0].length;
  const fill = o.fill ?? 1;
  const prevAlpha = ctx.globalAlpha;
  if (o.alpha !== undefined) ctx.globalAlpha = prevAlpha * o.alpha;
  const left = x - (w * sx) / 2;
  const top = y - h * sy;
  const dw = Math.max(0.5, sx * fill);
  const dh = Math.max(0.5, sy * fill);
  for (let r = 0; r < h; r++) {
    const row = rows[r];
    const g = o.glitch ? o.glitch(r) * px : 0;
    for (let c = 0; c < w; c++) {
      const ch = row[c];
      if (ch === '.' || ch === ' ') continue;
      const color = o.tint ?? pal[ch];
      if (!color) continue;
      const col = flip < 0 ? w - 1 - c : c;
      ctx.fillStyle = color;
      ctx.fillRect(left + col * sx + g, top + r * sy, dw, dh);
    }
  }
  ctx.globalAlpha = prevAlpha;
}

// --- Clawd ------------------------------------------------------------------

export type Arms = 'mid' | 'up' | 'high';
export type Legs = 'stand' | 'runA' | 'runB' | 'tuck' | 'dangle';

/**
 * Builds a 13x10 Clawd frame facing right: a blocky orange body, two dark
 * eyes looking forward, stubby side arms and four little legs.
 */
export function clawdFrame(arms: Arms, legs: Legs, blink = false, squint = false): string[] {
  const body = '..oOOOOOOOO..';
  const rows: string[] = [];
  for (let r = 0; r < 8; r++) {
    let row = body.split('');
    if (r === 7) row = '..ooooooooo..'.split('');
    const eyeRows = squint ? [3] : blink ? [3] : [2, 3];
    if (eyeRows.includes(r)) {
      row[5] = 'E';
      row[9] = 'E';
    }
    const armRows = arms === 'mid' ? [4, 5] : arms === 'up' ? [2, 3] : [1, 2];
    if (armRows.includes(r)) {
      row[0] = 'o';
      row[1] = 'o';
      row[11] = 'O';
      row[12] = 'O';
    }
    rows.push(row.join(''));
  }
  const L = {
    stand: ['..o.o...o.o..', '..o.o...o.o..'],
    runA: ['..o.o...o.o..', '....o.....o..'],
    runB: ['..o.o...o.o..', '..o.....o....'],
    tuck: ['..o.o...o.o..', '.............'],
    dangle: ['...o.o...o.o.', '...o.o...o.o.'],
  }[legs];
  rows.push(L[0], L[1]);
  return rows;
}

export const CLAWD = {
  idle: clawdFrame('mid', 'stand'),
  blink: clawdFrame('mid', 'stand', true),
  runA: clawdFrame('mid', 'runA'),
  runB: clawdFrame('mid', 'runB'),
  jump: clawdFrame('up', 'tuck'),
  fall: clawdFrame('high', 'dangle'),
  hover: clawdFrame('mid', 'dangle'),
  pound: clawdFrame('up', 'tuck', false, true),
  hurt: clawdFrame('high', 'dangle', false, true),
  cheer: clawdFrame('high', 'stand'),
};

// --- Enemies ------------------------------------------------------------------

export const ENEMY_PALETTE: Palette = {
  W: '#D6D6D6',
  w: '#8C8C8C',
  d: '#555555',
  R: COLORS.red,
  r: COLORS.redDark,
};

export const BUG = {
  a: [
    '...wwww...',
    '..wWWWWw..',
    '.wWWdWWWw.',
    'wWRWWWWRWw',
    'wWWWWWWWWw',
    '.w.w..w.w.',
  ],
  b: [
    '...wwww...',
    '..wWWWWw..',
    '.wWWWdWWw.',
    'wWRWWWWRWw',
    'wWWWWWWWWw',
    '..w.ww.w..',
  ],
};

export const SPAMBOT = {
  a: [
    '....R.....',
    '....w.....',
    '.wwwwwwww.',
    'wWWWWWWWWw',
    'wWRRWWRRWw',
    'wWWWddWWWw',
    '.wwwwwwww.',
    '.w......w.',
  ],
  b: [
    '....r.....',
    '....w.....',
    '.wwwwwwww.',
    'wWWWWWWWWw',
    'wWRRWWRRWw',
    'wWWWddWWWw',
    '.wwwwwwww.',
    '..w....w..',
  ],
};

// --- Small icons --------------------------------------------------------------

export const HEART = ['.OO.OO.', 'OOOOOOO', 'OOOOOOO', '.OOOOO.', '..OOO..', '...O...'];

/** 5x7 bitmap glyphs used for the dot-matrix logo. */
export const LOGO_FONT: Record<string, string[]> = {
  C: ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
  L: ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
  A: ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  W: ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
  D: ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
};
