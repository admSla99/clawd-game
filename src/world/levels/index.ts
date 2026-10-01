import type { LevelDef } from '../level';
import { LEVEL_1_1 } from './1-1';
import { LEVEL_1_2 } from './1-2';
import { LEVEL_1_3 } from './1-3';
import { LEVEL_1_BOSS } from './1-boss';
import { LEVEL_2_1 } from './2-1';
import { LEVEL_2_2 } from './2-2';
import { LEVEL_2_3 } from './2-3';
import { LEVEL_2_4 } from './2-4';
import { LEVEL_2_BOSS } from './2-boss';

/** Play order; each level unlocks the next one. */
export const LEVELS: LevelDef[] = [LEVEL_1_1, LEVEL_1_2, LEVEL_1_3, LEVEL_1_BOSS, LEVEL_2_1, LEVEL_2_2, LEVEL_2_3, LEVEL_2_4, LEVEL_2_BOSS];
