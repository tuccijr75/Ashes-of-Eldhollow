# Open World Design (Godot 4)

## Goal
Stream regions additively with no loading screens; keep at most two regions loaded.

## Implementation
- Autoload WorldStream.gd owns region load/unload.
- Regions are separate scenes under src/world/regions.
- Debug overlay shows loaded regions + memory + seed.

## Streaming rule
- WorldStream indexes res://maps/*.json and treats each entry in "regions" as a streamable region.
- Streaming decision is based on distance from player position to region bounds center.
- At most two regions remain loaded simultaneously (Config.max_simultaneous_regions).

## Debug tools
- F2 opens a debug console (teleport, seed, save/load, list regions).

## Current state
- RegionRuntime renders map regions into a TileMap using a placeholder tileset (visual bootstrapping).
- Missing/invalid map JSON never crashes; errors are logged.
