# CLAWD — Latent Space

2D hra s Clawdom v hlavnej úlohe. **World 1** je skákačka v štýle Astro Bota. Na jeho konci Clawd nájde
**Token Blaster** a **World 2** je už strieľačka: mieri sa myšou, strieľa tokenmi a v shope sa kupujú lepšie
zbrane a upgrady. Hlavný boss World 2 je **Codex**.

Vizuál je „dot-matrix“: terén, hory aj nepriatelia sú z bodiek a ASCII znakov, výrazne oranžový je len Clawd
a to, čo je dôležité. Všetko beží lokálne v prehliadači: žiadne CDN, žiadne externé fonty ani zvukové súbory
(zvuk sa generuje cez WebAudio).

## Spustenie

```bash
npm install
npm run dev        # http://localhost:5173
npm test           # unit testy + test prejditeľnosti všetkých levelov
npm run build      # produkčný build do dist/
```

## Ovládanie

| Vstup | Akcia |
|---|---|
| ← → / A D | pohyb |
| Space / K | skok (dlhšie držanie = vyšší skok) |
| držať skok vo vzduchu | hover (jet zraňuje nepriateľov) |
| X / J | World 1: spin · World 2: streľba |
| C / L / pravé tlačidlo myši | spin |
| ↓ + spin vo vzduchu | ground pound (rozbije fialové „corrupted“ bloky) |
| ↓ + Space | prepadnutie cez platformu |
| myš + ľavé tlačidlo | World 2: mierenie a streľba |
| ↑ / ↓ + X | mierenie bez myši (8 smerov) |
| 1–5 · Q E · koliesko | prepnutie zbrane |
| B (na mape) | shop |
| Esc / P · M · H | pauza · zvuk · ovládanie |
| F1 / F2 | debug overlay / noclip (v debug režime) |

Gamepad: A skok, X streľba, B spin, pravá páčka mieri, LB/RB/Y prepínajú zbrane, Start pauza.

## Obsah

**World 1 — Latent Space** (skákačka)
- 1-1 Token Plains, 1-2 Gradient Caves, 1-3 Context Window
- 1-B The Hallucination: po porážke zanechá Token Blaster, odomkne sa World 2 a shop

**World 2 — Benchmark Wars** (strieľačka)
- 2-1 Merge Conflict Mesa: turrety, drony, shield boty
- 2-2 GPU Forge: horúce prieduchy, stropné turrety, 429 drviče, pohyblivé platformy
- 2-3 Prompt Injection Swamp: injectory (po zničení sa rozpadnú na bugy), ostrovy
- 2-4 The Diff Towers: vertikálne stúpanie so streľbou
- 2-B Codex: monitor s dvoma kurzorovými rukami, autocomplete steny, `{ }` salvy,
  „npm test“ bugy a `rm -rf` lúče, 3 fázy

**Zbrane** (Context = prehrievanie; pri pretečení sa zbraň musí schladiť)

| Zbraň | Cena | Vlastnosti |
|---|---|---|
| Token Blaster | nájdená | spoľahlivá, stredná kadencia |
| Context Spreader | 120 tokenov | 5 tokenov naraz, krátky dosah |
| Stream Output | 220 tokenov + 3 sparky | veľmi rýchla streľba znakmi |
| Attention Beam | 380 tokenov + 8 sparkov | lúč, prejde cez všetkých nepriateľov v línii |
| Opus Cannon | 520 tokenov + 12 sparkov | výbušná guľa, rozbíja corrupted bloky |

**Upgrady**: Extra Heart, Bigger Model (poškodenie), Faster Inference (kadencia), Longer Context,
Jet Tuning (hover), Token Magnet.

Tokeny zozbierané v leveli sa po jeho dokončení pripíšu do peňaženky. Sparky sa v shope míňajú, ale na mape
zostávajú započítané ako nájdené. Progres sa ukladá do `localStorage`.

## Štruktúra

- `src/config.ts`: konštanty pohybu („feel“)
- `src/weapons.ts`: zbrane a upgrady (ceny, poškodenie, kadencia, prehrievanie)
- `src/entities/player.ts`: fyzika a stavy Clawda
- `src/entities/gun.ts`, `bullets.ts`: streľba, strely, prehrievanie
- `src/entities/enemies.ts`, `enemies2.ts`: nepriatelia World 1 / World 2
- `src/entities/boss/`: Hallucination a Codex
- `src/world/levels/*.ts`: levely ako ASCII mapy (legenda je na začiatku každého súboru)
- `src/scenes/`: titulka, mapa sveta, hra, shop, výsledky
- `tests/reachability.test.ts`: prejde každý level skutočnou fyzikou Clawda a overí, že exit, všetky sparky
  aj sub-agenti sú dosiahnuteľní. Po úprave mapy stačí spustiť `npm test`.

## Dev skratky (len `npm run dev`)

- `?map` / `?shop` otvorí mapu / shop, `?rich` naplní peňaženku (2000 tokenov, 30 sparkov)
- `?level=4` spustí level podľa indexu (0–8), `?level=4&tx=120&ty=16` presunie Clawda na dlaždicu
- `?ff=300&hold=KeyD,KeyX` odsimuluje N krokov s držanými klávesmi (na headless screenshoty)
