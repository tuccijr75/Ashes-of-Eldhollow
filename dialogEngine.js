import { logger } from "./logger.js";
import { gameState, emit, loadScene, setMap } from "./main.js";
import { renderDialog } from "./ui.js";
import { addItem, removeItem, hasItem } from "./inventory.js";

const cache = new Map();
let active = { location: null, nodeIndex: 0, data: [] };

async function loadDialogFile(location) {
  if (cache.has(location)) return cache.get(location);
  const path = `./dialogs/dlg_${location}.json`;
  const res = await fetch(path);
  if (!res.ok) {
    logger.error("Dialog file missing", { path, status: res.status });
    return [];
  }
  const data = await res.json();
  cache.set(location, data);
  return data;
}

function applyOutcome(choice) {
  if (!choice || !choice.outcome) return;
  switch (choice.outcome) {
    case "gain_item":
      if (choice.gain_item) addItem(choice.gain_item);
      break;
    case "lose_item":
      if (choice.lose_item && hasItem(choice.lose_item)) removeItem(choice.lose_item);
      break;
    case "start_quest":
      if (choice.start_quest) gameState.flags.add(`quest_${choice.start_quest}`);
      break;
    case "toggle_flag":
      if (choice.toggle_flag) {
        if (gameState.flags.has(choice.toggle_flag)) gameState.flags.delete(choice.toggle_flag);
        else gameState.flags.add(choice.toggle_flag);
      }
      break;
    case "set_checkpoint":
      gameState.checkpoint = choice.checkpoint || active.location;
      break;
    case "teleport":
      if (choice.teleport?.map) setMap(choice.teleport.map, {});
      if (choice.teleport?.scene) loadScene(choice.teleport.scene);
      break;
    default:
      logger.debug("Unhandled dialog outcome", { outcome: choice.outcome });
  }
  emit("dialog:choice", { choice });
}

function renderNode() {
  const node = active.data[active.nodeIndex];
  if (!node) return;
  renderDialog(node, choose);
  emit("dialog:node", { location: active.location, nodeIndex: active.nodeIndex });
}

function choose(idx, choice) {
  applyOutcome(choice || active.data[active.nodeIndex]?.choices?.[idx]);
  if (choice?.next != null) {
    active.nodeIndex = choice.next;
    renderNode();
  } else {
    emit("dialog:end", { location: active.location });
  }
}

export async function startDialog(location, nodeIndex = 0) {
  const data = await loadDialogFile(location);
  if (!Array.isArray(data) || !data.length) {
    logger.warn("Dialog has no nodes", { location });
    return;
  }
  active = { location, nodeIndex, data };
  renderNode();
}

// Convenience for console debugging
window.dialogEngine = { startDialog };
