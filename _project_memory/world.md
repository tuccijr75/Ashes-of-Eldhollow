# World (Current Content + Implemented Maps)

## Big picture
The world is divided into named regions (Eldhollow core and many outer territories). Gameplay is built around moving between regions, triggering dialogue/quests, and impacting world-state flags.

## Factions (current canon list)
- **Wardens of the Ash**: oath-bound road keepers.
- **The Hollowed Choir**: coronation cult.
- **Fenmire Coven**: bargains and debt.
- **Bonewrights**: engineers of ossuary craft.
- **Stonebridge Guild**: builders and smugglers.
- **Free Knives**: mercenary brokers.
- **Pilgrims**: mystics of the White-Dead Tree.

## World-state flags (currently documented)
Examples (not exhaustive):
- `CHOIR_SPY_EXPOSED` (bool)
- `BRIDGE_REPAIRED` (bool)
- `WARDEN_TRUST` (0–100)
- `HOLLOW_MARK_LEVEL` (0–3)
- `WITCH_FAVOR` (int)
- `CITY_ALERT` (0–3)
- `WHITE_TREE_HEALTH` (0–100)

## Implemented map packs (streamed)
World streaming scans `maps/*.json` and loads each region by its `regions[].id`.

Example: `maps/eldhollow.json` includes region ids like:
- `chapel` (dungeon)
- `village` (town)
- `forest` (field)
- `ashpath` (field)
- `graveyard` (combat)

Other maps exist (see `maps/`): `eldhollow.json`, `fenmire.json`, `blightlands.json`.

## “Design-world” regions (content bible)
Canon region list (design-world; larger than current map implementation):
- West Eldhollow, Fenmire Wastes, Blightlands, Nerenthis Depths, Hollow City, Vale of Bones, Forest of Lorn, Eldhollow Village, Temple of the Choice, Stonebridge Crossing, Cinderway Caldera, Sableglass Dunes, Umbral Reaches, Gallows Shoal, Skyreach Monastery, Dreadmire Causeway, Whitespire Tundra, Emberfall Crags, Ashen Steppe, The Mirror Wastes.

## Notes on “world vs implementation”
- The design-world region list is larger than the currently implemented `maps/*.json` packs.
- Root-level `dialogs/` contains location dialogs (dlg_*.json). The runtime debug console currently uses quest dialogs in `data/dialogs/quest_###.json`.
