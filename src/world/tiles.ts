export const T = {
  EMPTY: 0,
  SOLID: 1,
  ONEWAY: 2,
  SPIKE: 3,
  CORRUPT: 4,
} as const;

export type TileId = (typeof T)[keyof typeof T];

export const TILE_CHARS: Record<string, TileId> = {
  '#': T.SOLID,
  '=': T.ONEWAY,
  '^': T.SPIKE,
  X: T.CORRUPT,
};

/** Tiles that block movement from every side. */
export function isSolidTile(t: TileId): boolean {
  return t === T.SOLID || t === T.CORRUPT;
}
