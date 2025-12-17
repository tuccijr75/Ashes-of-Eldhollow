# Systems (Current Build)

## Finalized Feature Pipeline (Canonical)

This is the canonical build order for new systems. If a feature spans multiple systems, we implement prerequisites first.

**Order**
1. Movement
2. Combat (Intent-Driven Timeline Combat / IDTC)
3. Inventory / Equipment
4. Quests
5. AI
6. Dialog
7. World

**Global engineering principles (apply to everything)**
- Weight & Intent: actions feel deliberate; no spam loops.
- Readability: player can tell why outcomes happened.
- Agency: skillful play > stats alone.
- Systemic reuse: each system feeds at least one other.

**Hard rules**
- Signals > polling.
- State machines for control, timelines for expression.
- Data-driven configs (Resources/JSON).
- Scene reload safe (no dangling refs / signal leaks).
- Test-first is on by default (small test scenes / harnesses before expanding).

## Engine / Platform
- **Engine**: Godot 4.5+ (GDScript 2.0).
- **Main scene**: `res://src/main/Main.tscn`.
- **Renderer**: mobile rendering method (per `project.godot`).

## Autoloads (singletons)
Defined in `project.godot`:
- **Game**: chapter + world flags + player_state.
- **GameLog**: logging wrapper (autoload points to `src/autoload/Logger.gd`).
- **WorldFlags**: authoritative world flag store (typed schema + save/load blob).
- **RNG**: deterministic RandomNumberGenerator wrapper.
- **DB**: loads JSON databases + runtime tileset mapping.
- **QuestDirector**: reactive quest graph runner + effect application.
- **QuestSys**: stable facade API for quest start/complete/status; backed by QuestDirector + WorldFlags.
- **SaveSys**: JSON save/load at `user://saves/save_01.json`.
- **WorldSys**: world streaming + procedural dungeons (autoload points to `src/autoload/WorldStream.gd`).
- **Config**: debug/tuning flags.

## Input
- Movement: `move_left/right/up/down`.
- Debug console toggle: `F2`.

## World Streaming (`WorldSys` / `WorldStream.gd`)
- Builds region definitions by scanning `res://maps/*.json` at runtime.
- Keeps up to `Config.max_simultaneous_regions` loaded at once (default 2).
- Loads region instances from `res://src/world/regions/RegionRuntime.tscn`.
- Streaming is proximity-based; save does **not** force-load regions.

## Region Rendering (`RegionRuntime.gd`)
- Reads `maps/*.json` region `layout` arrays.
- Uses `DB.get_runtime_tileset()` and a runtime tile mapping.
- Best-effort tile validation: missing tile IDs log once and render a fallback tile.

## Procedural Dungeons
- Stored in `WorldSys._procedural_states` per `dungeon_id`.
- One active procedural instance at a time (`ProceduralRuntime.tscn`).
- Generation entrypoint: `ProceduralDungeon.generate(profile_id, rng_seed)`.
- Algorithms supported: `bsp`, `cellular`, `room_graph`, `fixed`.
- Validation: `MapValidator.validate(grid, entrance, exit)`; retries up to 8 times, then falls back to a guaranteed corridor map.
- Clearing: `WorldSys.mark_procedural_cleared(dungeon_id)` prevents regeneration.

## Dialogue (`DialogRuntime.gd`)
- Loads JSON dialogs from disk (current debug console uses `res://data/dialogs/quest_###.json`).
- Supports:
  - Conditions: `has_flag`, `{flag, op, value}`, `not`, `any`, `all`.
  - Effects: `set_flag`, `inc_flag`, `clear_flag`, `set_chapter`, `set_seed`, `start_quest`, `complete_quest`, `set_clause`, `grant_seal`, `set_censure_mode`, `compute_boss_unlock`.

## Quests (Authority Web)
- Runtime is graph-backed and stateful/reactive.
- `QuestSys` remains the public API for callers, but is backed by `QuestDirector + QuestGraph + WorldFlags`.
- Status values: `active/completed/available/locked`.
- Authoring-driven gating:
  - Availability: `availability_conditions` (or derived from `dependencies`).
  - Completion: requires `Q_READY_### = true` (represents “requirements satisfied”).
- Side-effect flags (WorldFlags):
  - Start: `Q_START_### = true`, `Q_ACTIVE_### = true`
  - Ready-to-complete: `Q_READY_### = true`
  - Complete: `Q_DONE_### = true`, `Q_ACTIVE_### = false`
- Global Authority Ladder flags:
  - `CLAUSE_SET`, `SEAL_*`, `KEYSTONE_TRIAL_DONE`, `CENSURE_MODE`, `BOSS_UNLOCKED`, `ENDING_ID`.

## Save/Load (`SaveSys.gd`)
- Save path: `user://saves/save_01.json`.
- Payload schema (v2):
  - `chapter`, `flags` (legacy mirror), `world_flags` (WorldFlags blob), `player_state`, `rng_seed`, `quests` (QuestDirector blob), `world` (WorldSys blob).

## UI
- Debug console: `src/ui/DebugConsole.gd` (F2).
- Debug overlay: label in main scene showing loaded regions, memory, seed, chapter.

## Tests
- `src/tests/TestRunner.gd` runs 4 suites: procedural, quests, save/load, stream.
- Tests can be run from debug console with `test_all`.

## Tooling / Data Validation
- Node script: `scripts/validate-data.mjs` (validates JSON data files).
