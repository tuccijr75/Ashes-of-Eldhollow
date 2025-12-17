# Canon (Ashes of Eldhollow)

## One-liner
Top-down 2D pixel RPG in Godot 4.5: explore a fractured land (Eldhollow and beyond), make hard choices through branching dialogue and quests, and survive expeditions into procedural dungeons.

## Pillars
- **Exploration-first**: regions stream in/out around the player; quests push you across the map.
- **Consequences**: quests/dialogue toggle persistent **world-state flags** that alter availability and outcomes.
- **Ritual / puzzle moments**: quests frequently include a non-combat “unique mechanic” beat (data-driven in quest meta).
- **Tactical intent (future)**: encounter and item data is present; a full combat runtime is still to be implemented.

## Tone & Themes (from current content)
- Ash, ruin, oath, debt, corruption, and survival.
- Factions vie for control or meaning: Wardens, Choir, Coven, Bonewrights, Guild, Free Knives, Pilgrims.

## Core facts (current build)
- **Quests**: 100 quests total; IDs 1–100.
- **Main quests**: 1–30 (sequential dependency chain in data).
- **Side quests**: 31–80; **Replayables**: 81–100 (per SST bundle overview).
- **World-state flags** (examples documented): `CITY_ALERT`, `WARDEN_TRUST`, `HOLLOW_MARK_LEVEL`, etc.

## Player fantasy
- Roam interconnected regions, take quests, interrogate choices in dialogue, and descend into dungeons that generate per-seed and persist once cleared.

## Out-of-scope (not implemented yet)
- Full combat loop (encounters exist as data; no combat runtime yet).
- NPC interaction triggers in-world (dialog runtime exists; world NPC hookup is minimal).
- Audio system integration.
