import { TILE } from '../config';
import type { Rect } from '../core/math';
import type { Level } from './level';
import { T, isSolidTile, type TileId } from './tiles';

export interface Body extends Rect {
  vx: number;
  vy: number;
}

const EPS = 0.001;

function tileRange(a: number, size: number): [number, number] {
  return [Math.floor(a / TILE), Math.floor((a + size - EPS) / TILE)];
}

export function rectHitsSolid(x: number, y: number, w: number, h: number, level: Level): boolean {
  const [x0, x1] = tileRange(x, w);
  const [y0, y1] = tileRange(y, h);
  for (let ty = y0; ty <= y1; ty++) {
    for (let tx = x0; tx <= x1; tx++) {
      if (isSolidTile(level.get(tx, ty))) return true;
    }
  }
  return false;
}

export function rectTouchesTile(r: Rect, level: Level, kind: TileId): boolean {
  const [x0, x1] = tileRange(r.x, r.w);
  const [y0, y1] = tileRange(r.y, r.h);
  for (let ty = y0; ty <= y1; ty++) {
    for (let tx = x0; tx <= x1; tx++) {
      if (level.get(tx, ty) === kind) return true;
    }
  }
  return false;
}

/** Move horizontally; returns true when a wall stopped the body. */
export function moveX(body: Rect, dx: number, level: Level): boolean {
  if (dx === 0) return false;
  const [y0, y1] = tileRange(body.y, body.h);
  if (dx > 0) {
    const right = body.x + body.w + dx;
    const tx = Math.floor((right - EPS) / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      if (isSolidTile(level.get(tx, ty))) {
        body.x = tx * TILE - body.w;
        return true;
      }
    }
  } else {
    const left = body.x + dx;
    const tx = Math.floor(left / TILE);
    for (let ty = y0; ty <= y1; ty++) {
      if (isSolidTile(level.get(tx, ty))) {
        body.x = (tx + 1) * TILE;
        return true;
      }
    }
  }
  body.x += dx;
  return false;
}

export interface MoveYResult {
  floor: boolean;
  ceiling: boolean;
  /** True when the floor that stopped us was a one-way platform. */
  oneWay: boolean;
}

/** Move vertically. One-way tiles only block a body falling onto them from above. */
export function moveY(body: Rect, dy: number, level: Level, dropThrough = false): MoveYResult {
  const res: MoveYResult = { floor: false, ceiling: false, oneWay: false };
  if (dy === 0) return res;
  const [x0, x1] = tileRange(body.x, body.w);
  if (dy > 0) {
    const bottom = body.y + body.h;
    const newBottom = bottom + dy;
    const ty = Math.floor((newBottom - EPS) / TILE);
    const top = ty * TILE;
    let anySolid = false;
    for (let tx = x0; tx <= x1; tx++) {
      const t = level.get(tx, ty);
      if (isSolidTile(t)) {
        anySolid = true;
        res.floor = true;
      } else if (t === T.ONEWAY && !dropThrough && bottom <= top + EPS) {
        res.floor = true;
      }
    }
    if (res.floor) {
      body.y = top - body.h;
      res.oneWay = !anySolid;
      return res;
    }
  } else {
    const newTop = body.y + dy;
    const ty = Math.floor(newTop / TILE);
    for (let tx = x0; tx <= x1; tx++) {
      if (isSolidTile(level.get(tx, ty))) {
        body.y = (ty + 1) * TILE;
        res.ceiling = true;
        return res;
      }
    }
  }
  body.y += dy;
  return res;
}

export interface GroundInfo {
  grounded: boolean;
  /** Standing only on one-way tiles (so drop-through is allowed). */
  oneWayOnly: boolean;
}

export function probeGround(body: Rect, level: Level): GroundInfo {
  const bottom = body.y + body.h;
  const ty = Math.floor((bottom + 0.5) / TILE);
  // Must be resting exactly on a tile top.
  if (Math.abs(ty * TILE - bottom) > 0.5) return { grounded: false, oneWayOnly: false };
  const [x0, x1] = tileRange(body.x, body.w);
  let solid = false;
  let oneway = false;
  for (let tx = x0; tx <= x1; tx++) {
    const t = level.get(tx, ty);
    if (isSolidTile(t)) solid = true;
    else if (t === T.ONEWAY) oneway = true;
  }
  return { grounded: solid || oneway, oneWayOnly: oneway && !solid };
}

/** Is there floor under a point? Used by walkers to turn at ledges. */
export function hasFloorAt(x: number, y: number, level: Level): boolean {
  const t = level.get(Math.floor(x / TILE), Math.floor(y / TILE));
  return isSolidTile(t) || t === T.ONEWAY;
}
