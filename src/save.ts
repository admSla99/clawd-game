import type { UpgradeId, WeaponId } from './weapons';

export interface LevelProgress {
  completed: boolean;
  sparks: boolean[];
  agents: boolean[];
  bestTime: number | null;
}

export interface SaveData {
  version: 1;
  levels: Record<string, LevelProgress>;
  muted: boolean;
  crt: boolean;
  /** Tokens banked from finished levels. */
  wallet: number;
  /** Sparks already spent in the shop. */
  sparksSpent: number;
  weapons: WeaponId[];
  equipped: WeaponId | null;
  upgrades: Partial<Record<UpgradeId, number>>;
}

const KEY = 'clawd-latent-space-save-v1';

export function emptySave(): SaveData {
  return { version: 1, levels: {}, muted: false, crt: true, wallet: 0, sparksSpent: 0, weapons: [], equipped: null, upgrades: {} };
}

export function loadSave(): SaveData {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return emptySave();
    const data = JSON.parse(raw) as Partial<SaveData>;
    if (data.version !== 1 || typeof data.levels !== 'object') return emptySave();
    const save = { ...emptySave(), ...data } as SaveData;
    // Saves from before world 2: beating the first boss means the blaster was found.
    if (save.levels['1-B']?.completed && !save.weapons.includes('blaster')) grantWeapon(save, 'blaster');
    return save;
  } catch {
    return emptySave();
  }
}

export function writeSave(data: SaveData): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(data));
  } catch {
    // Storage may be unavailable (private mode); progress just won't persist.
  }
}

export function progressFor(data: SaveData, id: string): LevelProgress {
  return data.levels[id] ?? { completed: false, sparks: [], agents: [], bestTime: null };
}

/** Merge a finished run into the save: collected items are never lost. */
export function recordRun(data: SaveData, id: string, sparks: boolean[], agents: boolean[], time: number, tokens = 0): void {
  const prev = progressFor(data, id);
  const merge = (a: boolean[], b: boolean[]) => Array.from({ length: Math.max(a.length, b.length) }, (_, i) => !!a[i] || !!b[i]);
  data.levels[id] = {
    completed: true,
    sparks: merge(prev.sparks, sparks),
    agents: merge(prev.agents, agents),
    bestTime: prev.bestTime === null ? time : Math.min(prev.bestTime, time),
  };
  data.wallet += tokens;
}

export function grantWeapon(data: SaveData, id: WeaponId): void {
  if (!data.weapons.includes(id)) data.weapons.push(id);
  if (!data.equipped) data.equipped = id;
}

export function count(arr: boolean[]): number {
  return arr.filter(Boolean).length;
}

export function totalSparks(data: SaveData): number {
  return Object.values(data.levels).reduce((n, l) => n + count(l.sparks), 0);
}

export function sparksAvailable(data: SaveData): number {
  return totalSparks(data) - data.sparksSpent;
}
