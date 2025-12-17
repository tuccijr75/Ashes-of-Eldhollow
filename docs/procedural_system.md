# Procedural System

## Profiles
- crypt (BSP)
- cave (cellular automata)
- ruin (room graph)
- arena (fixed)

## Guarantees
- Valid entrance→exit path
- Boss room reachable when applicable
- Seed stored in save
- Safe regeneration on failure (never blocks story)

## Status
- Implemented generators under src/world/procedural:
	- BSPGenerator.gd
	- CellularGenerator.gd
	- RoomGraphGenerator.gd
	- ProceduralDungeon.gd + ProceduralProfiles.gd
- Validation via MapValidator.gd enforces:
	- entrance and exit are walkable
	- entrance→exit path exists
	- no isolated walkable islands (all floors connected)
- Safe regeneration: up to 8 attempts (seed+1 each time), then falls back to a guaranteed corridor map.

## Debug commands
- F2 console:
	- proc <profile> <dungeon_id> [seed]
	- proc_regen <dungeon_id>
	- proc_clear <dungeon_id>
	- test_proc
