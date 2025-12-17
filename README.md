# Ashes of Eldhollow

Top-down 2D pixel RPG built with Godot 4.5, featuring quest, dialogue, world streaming, procedural dungeons, and save/load systems.

## Run (Godot 4.5)
- **Godot 4.5.1+** required: [Download](https://godotengine.org/download/)
- **Quick start**: `.\start.ps1` (Windows PowerShell launcher)
- **Or**: Open `project.godot` in Godot Editor and press **Play** (F5)
- **Debug console**: Press `F2` in-game to access commands (`help`, `regions`, `tp`, `proc`, etc.)

## Project Structure (Godot)
- `src/` GDScript source code
  - `autoload/` Singleton systems (Game, GameLog, WorldFlags, QuestDirector, DB, QuestSys, SaveSys, WorldSys, Config, RNG)
  - `main/` Main scene and boot logic
  - `entities/player/` Player CharacterBody2D with movement
  - `world/` Region streaming and procedural dungeon generation
  - `dialog/` DialogRuntime for branching conversations
  - `ui/` Debug console and HUD
  - `tests/` Automated test suites
  - `maps/` JSON region definitions (3 map files, 18 regions total)
- `dialogs/` JSON dialogue trees
- `data/` Quest, item, and encounter databases
- `assets/` Imported 2D RPG tilesets, sprites, icons
- `design-docs/` copies of rules, structure, storyboard, map image

## Modding
- **Quests**: edit `data/quests.json`.
  - `quest_id` is a **canonical string ID** used for narrative events (RPGGO). It must be unique.
  - The **runtime numeric quest ID** is the quest’s **1-based index** in `data/quests.json` (used for saves/flags and `quest_###.json` filenames).
  - `dependencies` are numeric (quest indices).
- **Quest dialogs**: edit `data/dialogs/quest_###.json` (console: `dlg <id>`). Dialogs can `start_quest` / `complete_quest` and must include a `complete_quest` effect for that quest.
- **Location dialogs** (supplemental): edit `dialogs/dlg_{location}.json`.

## Development

### RPGGO (Narrative Layer)
RPGGO is integrated as an **offline-first narrative service** (never called per-frame; never required for moment-to-moment play).

**Configure via environment variables (do not hardcode keys):**
- `RPGGO_BASE_URL` (example: `https://api.rpggo.example`)
- `RPGGO_GAME_ID` (your RPGGO Creator Game ID)
- `RPGGO_API_KEY` (secret)

On region enter and NPC interactions, the game will **best-effort** sync/generate dialogue with short timeouts. If offline/unconfigured, it falls back to local scripted dialogue and cached narrative state.

### Data Editing
- **Quests**: Edit `data/quests.json` (currently 149 quests)
- **Encounters**: Edit `data/encounters.json` (12 encounters with spawn probabilities)
- **Maps**: Update `maps/*.json` (3 map files / 18 regions with bounds, entry points, layouts)
- **Dialogs**: Add/edit `dialogs/*.json` for branching conversations

### Verification (Build/CI)
Run these checks before packaging/exporting:
- `node scripts/validate-data.mjs`
- `node scripts/audit-repo.mjs`
- `node scripts/aoe-gates.mjs validate-rpggo-usage`
- `node scripts/aoe-gates.mjs gate-rpggo-hotloop`
- `node scripts/aoe-gates.mjs gate-httprequest-hotloop`
- `node scripts/aoe-gates.mjs gate-secrets`
- `node scripts/aoe-gates.mjs gate-rpggo-event-ids`

Or run everything via PowerShell:
- `./scripts/verify-content.ps1`

### Key Systems
- **World Streaming**: Proximity-based region loading (max 2 simultaneous by default)
- **Procedural Dungeons**: BSP, Cellular, RoomGraph algorithms with validation
- **Quest System**: Authority Web (stateful/reactive). Uses `WorldFlags` + `QuestDirector`; `QuestSys` is a stable facade for callers.
- **Save/Load**: JSON serialization to `user://saves/save_01.json` (includes WorldFlags + quest director state)

## Troubleshooting
- **Parse errors on boot**: Check Godot console; ensure GDScript syntax is valid for Godot 4.5+
- **Missing textures**: Verify paths in `assets/tilesets/tileset_import_map.json` 
- **Region not loading**: Check `maps/*.json` region IDs match those in `WorldStream._region_defs`
- **Tests failing**: Enable `Config.run_tests_on_boot = true` and check logs

## Asset Attribution
Uses imported 2D RPG tileset assets. See individual asset licenses in `assets/` subfolders.
