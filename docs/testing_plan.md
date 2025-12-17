# Testing Plan

## Scope
- Procedural map validity (path entrance→exit, no isolated rooms)
- Quest web integrity (IDs 1..100, deps acyclic, dialogs valid)
- Save/load integrity (seed + cleared procedural content)
- Region streaming stress (load/unload bounds)
- Combat outcome bounds (CTT 1d20 success/failure/crit)

## Approach
- Use a lightweight in-project test runner scene (to be added) so tests run inside Godot.
- Log all failures via Logger at ERROR/CRITICAL.

## Current In-Engine Suites
- Procedural: implemented and callable via debug console.
- Quests: validates IDs, dependency graph, and dialog schema for generated quest dialogs.
- Save/load: verifies seed + flags + cleared procedural non-regeneration.
- Streaming: stress-checks the "max simultaneous regions" invariant.

## Debug Console Commands
- `test_proc`
- `test_quests`
- `test_save`
- `test_stream`
- `test_all`

## Dialog Runtime (Console)
- `dlg <quest_id>` loads and prints the current node.
- `dlg_choose <n>` selects an available choice (conditions are evaluated).
- `flag <id> [value]` and `flags` help verify dialog effects.
- Generated quest dialogs apply `complete_quest` on completion routes and set `Q_READY_###` before completion (represents “requirements satisfied”).
