
# Rules – Michael: Ashes of Eldhollow

## 🎮 Gameplay Overview
- Top-down 2D pixel RPG
- Movement: tile-based (16x16 grid), 4 directions
- Player controls Michael in a medieval-fantasy world
- Interaction system for talking, opening, looting, activating

## 🎲 Stats System
Each character (player + enemy) has:
- ❤️ Health (0–20)
- 🎲 Initiative (1–20) = 1d10 + Agility
- 💪 Strength (0–10)
- 🧠 Intelligence (0–10)
- 🤸 Agility (0–10)
- 😎 Charisma (0–10)

### 🎯 Action Resolution
- Use Combined Trait Total (CTT) = Trait1 + Trait2
- Roll 1d20:  
  - If CTT > 1d20 → ✅ Success  
  - If CTT < 1d20 → ❌ Failure  
  - If CTT = 1d20 → 💥 Critical Success

### Combat
- Turn-based combat ordered by Initiative
- Player can:
  - Attack (STR-based)
  - Use item
  - Flee (AGI check)
- Weapon damage based on STR
- Enemies act after player based on Initiative
- Death at 0 HP → Game Over

### Inventory System
- Max Carry Weight: 15kg
- Items have weight and price
- Buying/selling possible in towns
- Inventory limited by weight, not slots

### Dialogue System
- Branching choices with flags
- Charisma can unlock new responses
- Some interactions unlock new quests

### Save System
- Save/load via localStorage (JSON)
- Auto-save on scene change
