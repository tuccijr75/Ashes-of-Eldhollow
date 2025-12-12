import { logger } from "./logger.js";
import { gameState } from "./main.js";

function currentWeight(inventory, itemsIndex) {
  return inventory.reduce((sum, id) => {
    const item = itemsIndex[id];
    return sum + (item?.weight || 0);
  }, 0);
}

export function indexItems(items) {
  return Object.fromEntries(items.map(item => [item.id, item]));
}

export function addItem(itemId) {
  const itemsIndex = indexItems(gameState.items);
  const item = itemsIndex[itemId];
  if (!item) {
    logger.logValidation("Attempted to add missing item", { itemId });
    return false;
  }
  const weight = currentWeight(gameState.player.inventory, itemsIndex) + (item.weight || 0);
  if (weight > gameState.config.carryWeight) {
    logger.warn("Carry weight exceeded", { weight });
    return false;
  }
  gameState.player.inventory.push(itemId);
  logger.info("Item added", { itemId, weight });
  return true;
}

export function removeItem(itemId) {
  const idx = gameState.player.inventory.indexOf(itemId);
  if (idx === -1) {
    logger.warn("Item not in inventory", { itemId });
    return false;
  }
  gameState.player.inventory.splice(idx, 1);
  logger.info("Item removed", { itemId });
  return true;
}

export function hasItem(itemId) {
  return gameState.player.inventory.includes(itemId);
}

export function useItem(itemId) {
  const itemsIndex = indexItems(gameState.items);
  const item = itemsIndex[itemId];
  if (!item) return false;
  const effect = item.use_effect || {};
  // Basic effect handling; extend with event bus if needed
  if (effect.heal) gameState.player.health = Math.min(gameState.player.health + effect.heal, gameState.config.statBounds.health[1]);
  if (effect.flag) gameState.player.flags.add(effect.flag);
  removeItem(itemId);
  logger.info("Item used", { itemId, effect });
  return true;
}

export function dragDropSwap(fromIndex, toIndex) {
  const inv = gameState.player.inventory;
  if (fromIndex < 0 || toIndex < 0 || fromIndex >= inv.length || toIndex >= inv.length) return false;
  [inv[fromIndex], inv[toIndex]] = [inv[toIndex], inv[fromIndex]];
  logger.debug("Inventory reordered", { fromIndex, toIndex, inventory: inv });
  return true;
}
