import { PLAYER } from './config';
import type { SaveData } from './save';

export type WeaponId = 'blaster' | 'spreader' | 'stream' | 'beam' | 'cannon';
export type BulletKind = 'token' | 'pellet' | 'glyph' | 'beam' | 'orb';

export interface WeaponDef {
  id: WeaponId;
  name: string;
  /** One-line pitch shown in the shop. */
  description: string;
  /** Price in tokens and in sparks (sparks are spent too). */
  price: number;
  sparks: number;
  kind: BulletKind;
  /** Shots per second. */
  fireRate: number;
  damage: number;
  speed: number;
  /** Random inaccuracy in radians. */
  spread: number;
  /** Bullets per shot, fanned over `fan` radians. */
  pellets: number;
  fan: number;
  /** Seconds a bullet lives. */
  life: number;
  /** Context heat added per shot. */
  heat: number;
  /** Enemies a bullet can pass through before stopping. */
  pierce: number;
  splash?: { radius: number; damage: number };
  color: string;
}

export const WEAPONS: Record<WeaponId, WeaponDef> = {
  blaster: {
    id: 'blaster',
    name: 'Token Blaster',
    description: 'Fires freshly minted tokens. Reliable, cheap to run.',
    price: 0,
    sparks: 0,
    kind: 'token',
    fireRate: 6,
    damage: 2,
    speed: 380,
    spread: 0.03,
    pellets: 1,
    fan: 0,
    life: 0.9,
    heat: 7,
    pierce: 0,
    color: '#D97757',
  },
  spreader: {
    id: 'spreader',
    name: 'Context Spreader',
    description: 'Five tokens at once in a wide fan. Devastating up close.',
    price: 120,
    sparks: 0,
    kind: 'pellet',
    fireRate: 1.9,
    damage: 2,
    speed: 340,
    spread: 0.05,
    pellets: 5,
    fan: 0.55,
    life: 0.38,
    heat: 20,
    pierce: 0,
    color: '#F0A585',
  },
  stream: {
    id: 'stream',
    name: 'Stream Output',
    description: 'Streams characters as fast as they are sampled.',
    price: 220,
    sparks: 3,
    kind: 'glyph',
    fireRate: 15,
    damage: 1,
    speed: 440,
    spread: 0.09,
    pellets: 1,
    fan: 0,
    life: 0.7,
    heat: 4.5,
    pierce: 0,
    color: '#E6E6E6',
  },
  beam: {
    id: 'beam',
    name: 'Attention Beam',
    description: 'Attends to everything in a line. Pierces all targets.',
    price: 380,
    sparks: 8,
    kind: 'beam',
    fireRate: 20,
    damage: 1,
    speed: 0,
    spread: 0,
    pellets: 1,
    fan: 0,
    life: 0,
    heat: 3.6,
    pierce: 99,
    color: '#5FD0D8',
  },
  cannon: {
    id: 'cannon',
    name: 'Opus Cannon',
    description: 'One big, thoughtful answer. Explodes and breaks corrupted data.',
    price: 520,
    sparks: 12,
    kind: 'orb',
    fireRate: 1.1,
    damage: 14,
    speed: 230,
    spread: 0,
    pellets: 1,
    fan: 0,
    life: 2,
    heat: 34,
    pierce: 0,
    splash: { radius: 40, damage: 8 },
    color: '#D97757',
  },
};

export const WEAPON_ORDER: WeaponId[] = ['blaster', 'spreader', 'stream', 'beam', 'cannon'];

export type UpgradeId = 'hearts' | 'damage' | 'rate' | 'context' | 'hover' | 'magnet';

export interface UpgradeDef {
  id: UpgradeId;
  name: string;
  description: string;
  /** Token price of each level. */
  prices: number[];
  /** Spark price of each level (optional). */
  sparks?: number[];
}

export const UPGRADES: UpgradeDef[] = [
  { id: 'hearts', name: 'Extra Heart', description: 'One more heart to lose.', prices: [100, 250], sparks: [0, 4] },
  { id: 'damage', name: 'Bigger Model', description: '+25% weapon damage per level.', prices: [100, 220, 400], sparks: [0, 2, 6] },
  { id: 'rate', name: 'Faster Inference', description: '+15% fire rate per level.', prices: [90, 200, 350] },
  { id: 'context', name: 'Longer Context', description: 'Fire longer before the context overflows.', prices: [80, 200] },
  { id: 'hover', name: 'Jet Tuning', description: '+30% hover time per level.', prices: [60, 160] },
  { id: 'magnet', name: 'Token Magnet', description: 'Nearby tokens fly to you.', prices: [120] },
];

export interface Loadout {
  damageMult: number;
  rateMult: number;
  heatCap: number;
  hoverDuration: number;
  maxHearts: number;
  magnet: number;
}

export function upgradeLevel(save: SaveData, id: UpgradeId): number {
  return save.upgrades[id] ?? 0;
}

export function loadoutFromSave(save: SaveData): Loadout {
  const lv = (id: UpgradeId) => upgradeLevel(save, id);
  return {
    damageMult: 1 + 0.25 * lv('damage'),
    rateMult: 1 + 0.15 * lv('rate'),
    heatCap: 100 + 40 * lv('context'),
    hoverDuration: PLAYER.hoverDuration * (1 + 0.3 * lv('hover')),
    maxHearts: PLAYER.maxHearts + lv('hearts'),
    magnet: lv('magnet') > 0 ? 72 : 0,
  };
}
