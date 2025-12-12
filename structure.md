
# Structure – Ashes of Eldhollow

## 📁 Project File Tree
/index.html  
/style.css  
/main.js  
/maps/eldhollow.json  
/assets/  
  ├── sprites/  
  │    ├── hero.png  
  │    ├── npc_villager.png  
  │    └── enemy_shade.png  
  ├── tilesets/tiles.png  
  ├── music/  
  │    ├── main_theme.ogg  
  │    └── village_ambience.ogg  
  ├── portraits/  
  │    ├── hero.png  
  │    ├── villager.png  
  │    └── shade.png  
/dialogs/  
  ├── intro.json  
  ├── npc_villager.json  
  └── shade_boss.json  
/data/  
  ├── player.json  
  ├── items.json  
  └── quests.json

## 🗺️ Scenes
1. Prologue: Chapel of the Hollow Star (cutscene)
2. Eldhollow Village: Free roam, NPCs, 1st quest
3. Graveyard Rupture: Combat, first enemy
4. Forest of Lorn: Puzzle + dialogue challenge
5. Crypt of Whispers: Boss fight with “Shade”
6. Ending: Player chooses to return or pursue evil

## 🔄 Game Flow
- Boot: Load player.json, display intro scene
- Explore: Tile-based movement, interact via key
- Dialogue: Loaded from /dialogs/*.json
- Combat: JS turn-based loop using stats
- Inventory: Dynamic menu, updates in combat and world
- Save: Save at shrines or map transitions
