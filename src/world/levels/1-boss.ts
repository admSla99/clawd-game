import type { LevelDef } from '../level';

// Legend: # rock  = one-way  ^ spikes  X corrupted (ground-pound it)
//         @ start  S spark  o token  A sub-agent  C checkpoint  G exit  ? sign
//         E bug  F spam bot  R rate limiter (2x2)  M/V moving platform  B boss
//         T turret  Y ceiling turret  D drone  H shield bot  I injector
export const LEVEL_1_BOSS: LevelDef = {
  id: '1-B',
  world: 1,
  name: 'The Hallucination',
  subtitle: 'it is very sure about things that are not true',
  theme: 'boss',
  music: 'boss',
  boss: 'hallucination',
  map: [
    '##                              ##',
    '##                              ##',
    '##                              ##',
    '##                              ##',
    '##                              ##',
    '##                              ##',
    '##               B              ##',
    '##                              ##',
    '##            ======            ##',
    '##                              ##',
    '##                              ##',
    '##   =====              =====   ##',
    '##                              ##',
    '##                              ##',
    '##  @                           ##',
    '##################################',
    '##################################',
    '##################################',
  ],
};
