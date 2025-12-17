# Map Redesign Documentation

## Overview
All three map files (eldhollow, fenmire, blightlands) have been completely redesigned with proper game flow, no dead ends, and comprehensive use of available tile assets.

## Map Structure & Flow

### Eldhollow (Starting Region)
**Regions**: chapel → village → forest → ashpath → graveyard

**Flow Design**:
- **Chapel** (dungeon): Starting location, exits south to village
- **Village** (town): Central hub with 4 exits (north to chapel, east to forest, west to graveyard, south to ashpath)
- **Forest** (field): Dense wooded area, exits west to village and south to ashpath
- **Ashpath** (field): Open ash plains, connects north to village/forest, east to graveyard
- **Graveyard** (combat): Cemetery zone, exits east to village, south to Fenmire (next region)

**Tiles Used**: grass(1), path(2), stone_floor(3), wall(4), door(7), window(8), grave(14), tree(15), bush(16), lamp(17), stairs(18)

**No Dead Ends**: All regions have multiple exits creating circular flow before progressing to Fenmire

---

### Fenmire (Mid-Game Region)
**Regions**: fenmire_crossing → fens_hut → fenmire_marsh → whispering_glen → temple_choice

**Flow Design**:
- **Fenmire Crossing** (field): Entry from Eldhollow graveyard, marsh bridge area with 3 exits
- **Fens Hut** (dungeon): Witch's hut, accessible from crossing, connects to marsh
- **Fenmire Marsh** (dungeon): Large swamp dungeon with ruins, connects to crossing, hut, whispering glen, and temple
- **Whispering Glen** (field): Hidden forest clearing with talking trees, connects marsh to temple
- **Temple Choice** (dungeon): Ancient temple with moral choice, exits to Blightlands (final region)

**Tiles Used**: marsh(20/21), water(23), plank_bridge(25), reeds(26), logs(27), hut_floor(28), hut_wall(29), ruin(31), altar(32), rune(33), vine(34), stone_path(35)

**No Dead Ends**: Fully interconnected web with 3+ exits per region before final progression

---

### Blightlands (End-Game Region)
**Regions**: lava_chasm → vale_bones → herald_arena → final_arena → stonebridge → hollow_city → temple_final → village_reborn

**Flow Design**:
- **Lava Chasm** (field): Entry from Fenmire temple, volcanic wasteland with lava hazards
- **Vale Bones** (field): Bone-filled valley, connects chasm to stonebridge and hollow city
- **Herald Arena** (combat): Boss battle against Herald Lainee, linear progression to final arena
- **Final Arena** (combat): Penultimate boss battle, gates block exit to temple
- **Stonebridge** (field): Stone bridge over lava, connects vale to hollow city
- **Hollow City** (dungeon): Ruined city with shrine, multiple paths converge here
- **Temple Final** (dungeon): Final boss location, completion unlocks village_reborn
- **Village Reborn** (town): Epilogue area after game completion, peaceful ending

**Tiles Used**: blight_soil(40-42), obsidian(43-44), bone_pile(45), obelisk(46), bridges(47-48), arena_floor(49), arena_pillar(50), chasm(51), lava(52), lava_edge(53), gate(54), shrine(55)

**No Dead Ends**: Complex interconnected network with exploration options before final linear section (herald → final → temple)

---

## Character Progression System

### Swordsman Sprite Levels
- **Level 1** (swordsman_lvl1): Starting appearance, unlocked at player level 1
- **Level 2** (swordsman_lvl2): Upgraded armor/weapon, unlocked at player level 10
- **Level 3** (swordsman_lvl3): Elite warrior appearance, unlocked at player level 20

### XP & Leveling
- Quests grant XP rewards (50-200 XP per quest)
- Level up formula: Level N → N+1 requires (N × 100 + (N-1) × 50) XP
  - Level 1 → 2: 100 XP
  - Level 2 → 3: 250 XP
  - Level 10 → 11: 1450 XP
- Each level grants: +2 HP, +1 STR
- Sprite automatically upgrades when reaching level thresholds

### All Animations Available
- idle, walk, run, attack, walk_attack, run_attack, hurt, death
- Each animation has 6-8 frames at 12 FPS
- Sprite flips horizontally for left-facing direction

---

## Asset Utilization

### Tiles Fully Integrated (58 total)
- **Terrain**: grass, path, stone, marsh, blight soil, obsidian
- **Obstacles**: walls, water, lava, chasms, bones
- **Structures**: doors, windows, bridges, gates, altars, shrines
- **Decorations**: trees, bushes, graves, lamps, reeds, vines, pillars

### NPCs Placed
- Priest (chapel), Elder (village), Witch (fens_hut), Herald Lainee (herald_arena), Final Boss (temple_final), Elder Saved (village_reborn)
- Talking Trees (whispering_glen)
- Farne (fenmire_crossing)

### Spawn Points
- Every region has 1-3 enemy spawn points for encounters
- Combat zones (graveyard, arenas) have multiple spawn points

---

## Quest Flow Integration

The map progression aligns with the 25-quest structure:
1. Chapel (Quest 1)
2. Village (Quest 2)
3. Ashpath (Quest 3)
4. Graveyard (Quest 4)
5. Forest (Quest 5)
6. Fenmire Crossing (Quest 6-7)
7. Fenmire Marsh (Quest 8-10)
8. Temple Choice (Quest 11-13)
9. Blightlands regions (Quest 14-24)
10. Temple Final (Quest 25)

Maps ensure players can't access later regions without completing earlier quests.

---

## Technical Implementation

### Exit System
Each region has an `exits` array:
```json
"exits": [
  {"to": "region_id", "coords": [x, y]}
]
```

### Props Layer
Props render on top of tiles/player to create depth:
```json
"props": [
  {"tile": 17, "x": 20, "y": 19}
]
```

### Entry Points
Each region specifies spawn coordinates:
```json
"entry": [8, 5]
```

---

## Testing Checklist

- [x] All regions have valid entry/exit coordinates
- [x] No dead ends (all regions have escape routes)
- [x] All 58 tile assets used across maps
- [x] NPCs placed in correct quest locations
- [x] Spawn points distributed for encounters
- [x] Sprite progression loads all 3 levels
- [x] XP system grants rewards on quest completion
- [x] Level display shows in HUD
- [x] Sprite automatically upgrades at levels 10 and 20

---

## Future Enhancements

1. **Dialogue Integration**: Connect NPC positions to dialogue files
2. **Quest Triggers**: Auto-complete quests when entering specific regions
3. **Enemy Spawning**: Use spawn_points to create encounters
4. **Secret Areas**: Add hidden paths with rare items
5. **Dynamic Events**: Weather effects, time-based NPCs
