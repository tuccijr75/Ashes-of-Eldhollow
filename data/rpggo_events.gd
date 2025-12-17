class_name RPGGOEvents

# Canonical, immutable event ID registry.
# Do not inline narrative event IDs elsewhere in code; reference constants here.

# --- Quests (examples; extend as quests are canonized) ---
const QUEST_CHAPEL_CLEANSED := "quest.eldhollow.chapel.cleansed"
const QUEST_WITCH_DEFEATED := "quest.fenmire.witch_defeated"

# --- Choices ---
const CHOICE_LIGHT_PATH := "choice.temple.light_path"
const CHOICE_SHADOW_PATH := "choice.temple.shadow_path"

# --- Bosses ---
const BOSS_HOLLOW_KING_DEFEATED := "boss.hollow_king.defeated"

# --- Factions ---
const FACTION_FENMIRE_ALLIED := "faction.fenmire.allied"

# --- Endings ---
const ENDING_WORLD_RENEWED := "ending.world_renewed"
