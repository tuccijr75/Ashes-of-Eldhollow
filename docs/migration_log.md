# Migration Log — Ashes of Eldhollow (JS/Electron → Godot 4)

This log tracks file classifications and conversions.

## Legacy canon inputs (historical)

Earlier migrations used an `SST_Bundle/` folder as a source for design notes and deterministic generators.
The current build does not require or ship `SST_Bundle/`; runtime truth is `data/*.json` plus generators under `scripts/`.

## Initial classification (no deletions yet)
### Remove (runtime)
- Electron/HTML runtime: electron-main.js, index.html, style.css, preload.js, app.js, ui.js, main.js
- JS gameplay runtime: combat.js, controls.js, dialogEngine.js, inventory.js, logger.js, saveload.js, world.js

### Migrate (data)
- data/*.json (to be re-shaped deterministically into Godot-friendly JSON; stored in res://data)
- dialogs/*.json (dialog content: migrate structure into res://data/dialogs)
- maps/*.json (authored regions: migrate into Godot TileMap/TileSet pipeline; keep JSON as source)
- assets/** (tilesets/sprites/audio: keep; re-import via Godot)

### Overwrite (Godot implementation)
- New Godot project scaffold in project.godot + src/**

## Removals

### 2025-12-14 — Remove Electron/HTML/JS runtime
Removed obsolete runtime files (Godot is now the only runtime):
- app.js
- combat.js
- controls.js
- dialogEngine.js
- electron-main.js
- index.html
- inventory.js
- logger.js
- main.js
- preload.js
- saveload.js
- start.ps1 (legacy JS launcher; current repo keeps a Godot launcher start.ps1)
- style.css
- ui.js
- validate_tiles.js
- world.js
- package.json

## Notes
- All converters write to data/_generated_tmp first, then atomically replace on success.
- Missing content must not crash the game; warnings/errors logged to user://logs/game.log.
- Region and procedural TileMaps now use a runtime-built TileSet derived from assets/tilesets/tileset_import_map.json, with a magenta fallback tile for unmapped IDs.

## Deterministic generators
- scripts/generate-authority-web.mjs generates:
	- data/quests.json and data/dialogs/quest_###.json (Authority Web quest set)
	- data/encounters.json (region+act spawn tables; rare <= 5%)
