# Ashes of Eldhollow

Top-down 2D pixel RPG scaffold with quest, dialogue, combat, inventory, and save/load systems.

## Project Structure
- `index.html` (placeholder pending UI choice)
- `style.css` (placeholder)
- `config.json` global settings
- `main.js` bootstrap, loop, event bus
- `logger.js` timestamped logging with localStorage persistence
- `combat.js` CTT combat helpers
- `inventory.js` inventory logic and carry-weight checks
- `ui.js` basic HUD bindings (HTML overlays)
- `saveload.js` localStorage save/load/backup
- `maps/` JSON map stubs (eldhollow, fenmire, blightlands)
- `dialogs/` 25 dialogue JSONs (dlg_{location}.json)
- `data/` player, items, quests, encounters
- `assets/` placeholders for sprites, tilesets, music, portraits
- `design-docs/` copies of rules, structure, storyboard, map image

## Modding
- **Quests**: edit `data/quests.json`; keep `quest_id`, `dependencies`, `tags` consistent.
- **Dialogs**: extend `dialogs/dlg_{location}.json`; use choices with outcomes (`gain_item`, `start_quest`, `toggle_flag`, `set_checkpoint`).
- **Encounters**: add to `data/encounters.json`; include `ctt_test`, `spawn_prob`, `loot`.
- **Maps**: update `maps/*.json`; set `regions`, `exits`, and placeholder tile ids.

## Gameplay Notes
- Initiative = 1d10 + Agility.
- CTT check: roll 1d20 vs Combined Trait Total; equal is critical success.
- Carry weight cap: 15 (from `config.json`).
- Save system: localStorage slots (`saveload.js`).

## Troubleshooting
- Missing tileset: add `assets/tilesets/tiles.png` and matching tilemap config.
- Missing UI: provide `index.html` (canvas or DOM HUD). Update `ui.js` selectors.
- Malformed JSON: check console logs and `eldhollow-log` in localStorage.

## Asset Attribution
Placeholder assets only. Add licenses/credits for any art, music, or fonts you import.
