# Glossary

## World / Narrative
- **Eldhollow**: the core land/setting name used across the project.
- **The Hollow**: a central thematic force (corruption/boons/tradeoffs) referenced in quest premises.
- **Ash**: recurring motif tied to oaths, ruin, and faction identity.

## Factions
- **Wardens of the Ash**: road keepers bound by oath.
- **Hollowed Choir**: coronation cult.
- **Fenmire Coven**: debt/bargain power structure.
- **Bonewrights**: ossuary craft engineers.
- **Stonebridge Guild**: builders/smugglers.
- **Free Knives**: mercenary brokers.
- **Pilgrims**: mystics tied to the White-Dead Tree.

## Game State
- **Chapter**: `Game.chapter` (string, e.g. "I", "II").
- **World-state flag**: key/value in `Game.flags` controlling conditions and outcomes.
- **Quest state**: runtime status stored by `QuestSys` (`active`, `completed`, derived `available`, `locked`).

## World / Map
- **Map pack**: a `maps/*.json` file containing multiple sub-regions.
- **Region**: a named sub-area inside a map pack (`regions[].id`), streamable at runtime.
- **Bounds**: region placement and size in tile coordinates; used to compute world-space offset.
- **Layout**: 2D array of tile IDs used to build a TileMap.

## Procedural
- **Procedural dungeon**: generated grid + entrance/exit stored per `dungeon_id`.
- **Profile**: generator parameters selected by `profile_id` (algorithm, size, tunables).
- **Cleared**: a procedural state flag that prevents regeneration.

## Tooling
- **Debug console**: in-game console (F2) exposing teleport, save/load, tests, procedural entry.
- **TestRunner**: runs suite tests (procedural/quests/save-load/stream).
