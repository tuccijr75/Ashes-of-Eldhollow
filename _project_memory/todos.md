# TODOs (From Current State On)

This is the forward-looking development list starting from the current playable/technical baseline.

Canonical build order (pipeline): Movement → Combat (IDTC) → Inventory → Quests → AI → Dialog → World.

## 0) Project health (always-on)
- Run `test_all` regularly and keep all suites green (procedural/quests/save-load/stream).
- Add a lightweight CI step to run Godot headless smoke + data validation.
- Keep Godot 4.5 compatibility (no reserved-name collisions; type hints where warnings become errors).

## 1) Fixes / correctness
- Verify and fix save/load round-trip for quests (ensure `QuestSys` states restore and `get_status()` matches expected after load).
- Audit `QuestTests` assumptions vs reality (dialog schema constraints, required completion effect).
- Confirm `WorldSys.load_from_save_blob()` correctly restores `procedural_states` and cleared behavior.
- Normalize save schema types (avoid ints accidentally loading as floats/strings in flags/states).
- Add save version migration hook (schema versioning is present but no migration path yet).

## 2) Core gameplay loop (next big milestone)
- Implement **combat runtime** that consumes `data/encounters.json`.
- Define combat entry conditions (region type `combat`, spawn points, random encounters, scripted encounters).
- Implement damage/HP/death handling connected to `Game.player_state`.
- Implement item usage effects (consume from inventory and apply `use_effect` to player/combat/world).

## 3) Inventory & items
- Implement inventory data model (stacking, equipment slots, weight/value handling).
- Implement pickup/drop + persistence across save/load.
- Implement UI for inventory (minimal first: list + use/equip).
- Implement equipment bonuses impacting combat (e.g., atk/def/agi/ctt bonuses from items).

## 4) NPCs, interaction, and in-world dialogue
- Add interaction trigger for NPCs placed in map JSON (`regions[].npcs`).
- Connect NPC interactions to dialog files (support both quest dialogs and location dialogs).
- Support “press to interact” + focus/nearest-NPC selection.
- Add a minimal non-debug dialogue UI (text + choices) separate from debug console.

## 5) Quest journal UX
- Add quest journal screen:
  - Active, Available, Completed lists
  - Selected quest details (name/objectives/rewards)
  - Dependency hints for locked quests
- Hook journal into quest start/complete events.

## 6) World streaming & navigation
- Add region-to-region exit transitions using `regions[].exits`.
- Add minimap or simple region label overlay.
- Add fast travel support gated behind flags/items (e.g., shrine token / quest unlock).
- Improve spawn/use of `spawn_points` (currently data-only for most systems).

## 7) Audio
- Add music manager autoload (area/region-based music).
- Add SFX bus + hooks (UI clicks, footsteps, pickup, quest updates).
- Add volume settings and persistence.

## 8) Content integration / pipeline
- Ensure every quest’s `enemy_groups` maps to real encounter/combat content.
- Add a content audit tool:
  - Missing dialog effects
  - Missing NPC ids
  - Invalid item ids
  - Missing region ids referenced by quests
- Canonical truth: `data/*.json` (and generators under `scripts/`) are runtime truth.

## 9) Balancing & progression
- Define XP/money curves and reward normalization across 100 quests.
- Define act/chapter progression rules and how `Game.chapter` changes.
- Make world-state flags meaningful in systems (shop prices, patrol density, access gating).

## 10) UX polish
- Add title screen / pause menu.
- Add settings menu (rebind keys, display, audio).
- Add save slot selection UI (multi-slot; keep v1 compatibility).
- Improve debug overlay presentation and toggles.

## 11) Packaging / release
- Create export presets for Windows.
- Ship with a clean `user://` save folder setup.
- Add version stamping in save files.
- Add crash-safe logging path and log rotation.

## 12) Documentation upkeep
- Keep `_project_memory/*` aligned with reality after each milestone.
- Add a contributor “how to add a quest/region/dialog” quickstart.

## 13) Content backlog (per-region / per-quest)

This section is the granular tracker. Update it as we implement content hookups.

### Regions (implemented in `maps/*.json`)

**eldhollow.json**
- [ ] chapel — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] village — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] forest — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] ashpath — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] graveyard — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props

**fenmire.json**
- [ ] fenmire_crossing — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] fens_hut — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] fenmire_marsh — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] whispering_glen — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] temple_choice — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props

**blightlands.json**
- [ ] lava_chasm — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] vale_bones — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] herald_arena — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] final_arena — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] stonebridge — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] hollow_city — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] temple_final — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props
- [ ] village_reborn — exits wired, NPC interactions, loot pickups, encounter hooks, ambient props

### Quests (from `data/quests.json`)

Definition of “done” for a quest in this tracker:
- Start is console-triggered via dialog (e.g. `dlg <quest_id>` / `quest_start <id>`)
- Can be completed via dialog effect only after all quest requirements are actually satisfied
- Rewards applied (money/xp/items) and saved
- Any required world-state flags are set/validated

- [ ] Q001 The Hollow Awakening — hook triggers/dialog/combat/rewards
- [ ] Q002 Ash on the Bell — hook triggers/dialog/combat/rewards
- [ ] Q003 Cinders in the Wheat — hook triggers/dialog/combat/rewards
- [ ] Q004 Graveward Broken — hook triggers/dialog/combat/rewards
- [ ] Q005 Paths of the Lorn — hook triggers/dialog/combat/rewards
- [ ] Q006 The Farne Silence — hook triggers/dialog/combat/rewards
- [ ] Q007 A Witch’s Price — hook triggers/dialog/combat/rewards
- [ ] Q008 The Sundering Choice — hook triggers/dialog/combat/rewards
- [ ] Q009 Memory at the Crossing — hook triggers/dialog/combat/rewards
- [ ] Q010 Whispers and Lies — hook triggers/dialog/combat/rewards
- [ ] Q011 Roots That Speak — hook triggers/dialog/combat/rewards
- [ ] Q012 Sigils of the Lost — hook triggers/dialog/combat/rewards
- [ ] Q013 Knives on the Road — hook triggers/dialog/combat/rewards
- [ ] Q014 The Bone Valley Oath — hook triggers/dialog/combat/rewards
- [ ] Q015 The Last Knight’s Watch — hook triggers/dialog/combat/rewards
- [ ] Q016 A Village Remade — hook triggers/dialog/combat/rewards
- [ ] Q017 Herald of Ruin — hook triggers/dialog/combat/rewards
- [ ] Q018 Heald’s Lainee Burns — hook triggers/dialog/combat/rewards
- [ ] Q019 The Bridge Remembered — hook triggers/dialog/combat/rewards
- [ ] Q020 Descent Cracked Open — hook triggers/dialog/combat/rewards
- [ ] Q021 Gate of Mirrors — hook triggers/dialog/combat/rewards
- [ ] Q022 City Below Ash — hook triggers/dialog/combat/rewards
- [ ] Q023 The Chasm’s Truth — hook triggers/dialog/combat/rewards
- [ ] Q024 Arena of Fire — hook triggers/dialog/combat/rewards
- [ ] Q025 The White-Dead Bough — hook triggers/dialog/combat/rewards
- [ ] Q026 Ash Crown, Hollow Throne — hook triggers/dialog/combat/rewards
- [ ] Q027 What the Lantern Shows — hook triggers/dialog/combat/rewards
- [ ] Q028 Under a Cinder Sky — hook triggers/dialog/combat/rewards
- [ ] Q029 The Heart That Beats Below — hook triggers/dialog/combat/rewards
- [ ] Q030 A Choice That Stays Chosen — hook triggers/dialog/combat/rewards
- [ ] Q031 The Miller’s Ember Debt — hook triggers/dialog/combat/rewards
- [ ] Q032 Letters Never Sent — hook triggers/dialog/combat/rewards
- [ ] Q033 The Fenmire Ferryman — hook triggers/dialog/combat/rewards
- [ ] Q034 Lanterns for the Lost — hook triggers/dialog/combat/rewards
- [ ] Q035 Bones Beneath the Bridge — hook triggers/dialog/combat/rewards
- [ ] Q036 The Choir’s Quiet Knife — hook triggers/dialog/combat/rewards
- [ ] Q037 Tax of Ash and Salt — hook triggers/dialog/combat/rewards
- [ ] Q038 A Hunter’s Last Track — hook triggers/dialog/combat/rewards
- [ ] Q039 Borrowed Names — hook triggers/dialog/combat/rewards
- [ ] Q040 A Door That Won’t Forget — hook triggers/dialog/combat/rewards
- [ ] Q041 The Bandit’s Widow — hook triggers/dialog/combat/rewards
- [ ] Q042 A String of Black Beads — hook triggers/dialog/combat/rewards
- [ ] Q043 Crownless in the Blight — hook triggers/dialog/combat/rewards
- [ ] Q044 A Monk and His Bell — hook triggers/dialog/combat/rewards
- [ ] Q045 The Threefold Brew — hook triggers/dialog/combat/rewards
- [ ] Q046 The Stonemason’s Oath — hook triggers/dialog/combat/rewards
- [ ] Q047 Ash-Bitten Hounds — hook triggers/dialog/combat/rewards
- [ ] Q048 The Mirror That Lies — hook triggers/dialog/combat/rewards
- [ ] Q049 Sickle and Seed — hook triggers/dialog/combat/rewards
- [ ] Q050 House of Silent Laughter — hook triggers/dialog/combat/rewards
- [ ] Q051 The Girl in the Cistern — hook triggers/dialog/combat/rewards
- [ ] Q052 Oath on a Broken Sword — hook triggers/dialog/combat/rewards
- [ ] Q053 A Cart of Bones — hook triggers/dialog/combat/rewards
- [ ] Q054 The Night the Bells Rang — hook triggers/dialog/combat/rewards
- [ ] Q055 Graves for the Living — hook triggers/dialog/combat/rewards
- [ ] Q056 A Map Drawn Backwards — hook triggers/dialog/combat/rewards
- [ ] Q057 Borrowed Fire — hook triggers/dialog/combat/rewards
- [ ] Q058 The Price of a Name — hook triggers/dialog/combat/rewards
- [ ] Q059 Ink on Wet Ash — hook triggers/dialog/combat/rewards
- [ ] Q060 The Watch That Wasn’t — hook triggers/dialog/combat/rewards
- [ ] Q061 A White Tree’s Whisper — hook triggers/dialog/combat/rewards
- [ ] Q062 Debt to a Dead King — hook triggers/dialog/combat/rewards
- [ ] Q063 Flies on the Loaves — hook triggers/dialog/combat/rewards
- [ ] Q064 The Bridge-Keeper’s Son — hook triggers/dialog/combat/rewards
- [ ] Q065 Breath of the Cinderwyrm — hook triggers/dialog/combat/rewards
- [ ] Q066 The Quiet Orchard — hook triggers/dialog/combat/rewards
- [ ] Q067 Pilgrim’s Stone — hook triggers/dialog/combat/rewards
- [ ] Q068 Salt for the Fen — hook triggers/dialog/combat/rewards
- [ ] Q069 A Net of Thorns — hook triggers/dialog/combat/rewards
- [ ] Q070 The Boat with No Oars — hook triggers/dialog/combat/rewards
- [ ] Q071 Shard in a Cradle — hook triggers/dialog/combat/rewards
- [ ] Q072 Gallows Fishers — hook triggers/dialog/combat/rewards
- [ ] Q073 Black Bread, Hot Tears — hook triggers/dialog/combat/rewards
- [ ] Q074 The Veil at Noon — hook triggers/dialog/combat/rewards
- [ ] Q075 Two Lamps Going Out — hook triggers/dialog/combat/rewards
- [ ] Q076 The Cobbler’s Promise — hook triggers/dialog/combat/rewards
- [ ] Q077 Rust Under Nails — hook triggers/dialog/combat/rewards
- [ ] Q078 Skyreach Sermon — hook triggers/dialog/combat/rewards
- [ ] Q079 The Unwound Toy — hook triggers/dialog/combat/rewards
- [ ] Q080 A Needle for Night — hook triggers/dialog/combat/rewards
- [ ] Q081 Arena of Ash – Rank Trials — hook triggers/dialog/combat/rewards
- [ ] Q082 Fenmire Hunts – Contract Board — hook triggers/dialog/combat/rewards
- [ ] Q083 Stonebridge Salvage – Time Runs — hook triggers/dialog/combat/rewards
- [ ] Q084 Lantern Vigils – Night Watches — hook triggers/dialog/combat/rewards
- [ ] Q085 Cinderway Races – Ember Dash — hook triggers/dialog/combat/rewards
- [ ] Q086 Gallows Shoal – Drowned Relics — hook triggers/dialog/combat/rewards
- [ ] Q087 Umbral Reaches – Shadow Bounties — hook triggers/dialog/combat/rewards
- [ ] Q088 Sableglass Dunes – Mirage Chests — hook triggers/dialog/combat/rewards
- [ ] Q089 Whitespire – Frost-Brand Forays — hook triggers/dialog/combat/rewards
- [ ] Q090 Mirror Wastes – Echo Hunts — hook triggers/dialog/combat/rewards
- [ ] Q091 Nerenthis Depths – Infernal Incursions — hook triggers/dialog/combat/rewards
- [ ] Q092 Blightlands – Caravan Escorts — hook triggers/dialog/combat/rewards
- [ ] Q093 Hollow City – Disguise Raids — hook triggers/dialog/combat/rewards
- [ ] Q094 Forest of Lorn – Root Labyrinths — hook triggers/dialog/combat/rewards
- [ ] Q095 Vale of Bones – Ossuary Runs — hook triggers/dialog/combat/rewards
- [ ] Q096 Skyreach – Bellkeeper Gauntlet — hook triggers/dialog/combat/rewards
- [ ] Q097 Dreadmire – Bog Relay — hook triggers/dialog/combat/rewards
- [ ] Q098 Emberfall – Cliff Ascents — hook triggers/dialog/combat/rewards
- [ ] Q099 Ashen Steppe – Wind Trials — hook triggers/dialog/combat/rewards
- [ ] Q100 Temple of Choice – Balance Challenges — hook triggers/dialog/combat/rewards
