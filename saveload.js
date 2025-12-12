import { logger } from "./logger.js";
import { gameState, emit } from "./main.js";

const SAVE_KEY = "eldhollow-save";

export function saveGame(slot = 0) {
  try {
    const payload = {
      slot,
      map: gameState.currentMap,
      scene: gameState.currentScene,
      player: {
        ...gameState.player,
        flags: Array.from(gameState.player.flags || [])
      },
      quests: gameState.quests,
      inventory: gameState.player.inventory,
      flags: Array.from(gameState.flags)
    };
    const stored = JSON.stringify(payload);
    localStorage.setItem(`${SAVE_KEY}-${slot}`, stored);
    logger.info("Game saved", { slot });
    emit("save:completed", { slot });
    return true;
  } catch (err) {
    logger.error("Save failed", { error: err.message });
    return false;
  }
}

export function loadGame(slot = 0) {
  try {
    const raw = localStorage.getItem(`${SAVE_KEY}-${slot}`);
    if (!raw) throw new Error("No save found");
    const data = JSON.parse(raw);
    gameState.currentMap = data.map;
    gameState.currentScene = data.scene;
    gameState.player = { ...data.player, flags: new Set(data.player.flags || []) };
    gameState.player.inventory = Array.isArray(data.inventory) ? data.inventory : [];
    gameState.flags = new Set(data.flags || []);
    logger.info("Game loaded", { slot });
    return true;
  } catch (err) {
    logger.error("Load failed", { error: err.message });
    return false;
  }
}

export function backupSave(fromSlot = 0, toSlot = 99) {
  try {
    const raw = localStorage.getItem(`${SAVE_KEY}-${fromSlot}`);
    if (!raw) throw new Error("No save to backup");
    localStorage.setItem(`${SAVE_KEY}-${toSlot}`, raw);
    logger.info("Backup created", { fromSlot, toSlot });
    return true;
  } catch (err) {
    logger.error("Backup failed", { error: err.message });
    return false;
  }
}

export function validateSave(slot = 0) {
  try {
    const raw = localStorage.getItem(`${SAVE_KEY}-${slot}`);
    if (!raw) return false;
    JSON.parse(raw);
    return true;
  } catch (err) {
    logger.error("Malformed save JSON", { error: err.message });
    return false;
  }
}
