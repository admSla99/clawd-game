# Prompt tree plan (after world 3's playthrough, 2026-10-15)

The user's notes after playing world 3: the System Prompts become a **skill tree in a window of its own, like Path
of Exile's passive tree**; **3-4 is too short** (longer, more enemies); **sub-agents as allies** that shoot enemies,
as a node in the tree.

## Decisions

- Points: every spark found in world 3 gives one; more are bought in the tree window with tokens at a rising price
  (60 + 30 per point bought before, at most 10). Refunds are free (a node only if the rest stays connected to the
  start; R twice resets all). World 3's sparks no longer go to the shop: its spark prices add up to worlds 1-2's 35.
- The budget, switching on and off and the shop's SYSTEM PROMPT section go. The eight prompts are notables or
  keystones in the tree with the same ids (`Prompts.on(id)` still answers), small nodes add a few % between them.
  Old saves get the prompts and Longer System Prompt refunded (tokens and sparks).
- The window: `Main.Mode.TREE`, `scripts/tree_screen.gd`, opened from the map (T, a button next to SHOP) once the
  hook is Clawd's. Arrows move between nodes, Space / click allocates or refunds, U / the button buys a point,
  drag pans; the view follows the selection.
- Sub-agents as allies: the notable "Tool use." makes standing sub-agents shoot the nearest enemy in sight; small
  nodes for their damage and fire rate and the notable "Parallel tool calls." (two shots).

## Tasks

- [x] T1 Tree model (`prompts.gd`), Progress (`tree`, `points_bought`, migration), effects, shop without prompts,
      the window, map button and key, pause line, checks, README.
- [x] T2 Sub-agents that shoot (Tool use., minion damage / rate, Parallel tool calls.), checks, README.
- [x] T3 3-4 longer with more enemies, `reach.gd`, its check, README: 340 tiles instead of 222, a chasm of six
      timeout anchors and the gateway arena (17 enemies more), a 4th sign.
