import { logger } from "./logger.js";

const eventBus = new EventTarget();

const gameState = {
  config: null,
  player: null,
  quests: [],
  items: [],
  encounters: [],
  maps: {},
  flags: new Set(),
  currentScene: null,
  currentMap: null,
  lastTick: 0,
  running: false
};

function on(event, handler) {
  eventBus.addEventListener(event, handler);
}

function emit(event, detail) {
  eventBus.dispatchEvent(new CustomEvent(event, { detail }));
}

async function loadJSON(path) {
  try {
    const res = await fetch(path);
    if (!res.ok) throw new Error(`${path} responded ${res.status}`);
    return await res.json();
  } catch (err) {
    logger.error(`Failed to load ${path}`, { error: err.message });
    return null;
  }
}

function clamp(value, [min, max]) {
  return Math.max(min, Math.min(max, value));
}

function validateConfig(config) {
  if (!config) return false;
  const required = ["statBounds", "xpScaling", "carryWeight"];
  const missing = required.filter(key => !(key in config));
  if (missing.length) {
    logger.logValidation(`Missing config keys: ${missing.join(", ")}`);
  }
  return true;
}

function validatePlayer(player, statBounds) {
  if (!player) return null;
  const normalized = { ...player };
  normalized.health = clamp(player.health ?? 15, statBounds.health);
  normalized.strength = clamp(player.strength ?? 5, statBounds.strength);
  normalized.intelligence = clamp(player.intelligence ?? 4, statBounds.intelligence);
  normalized.agility = clamp(player.agility ?? 5, statBounds.agility);
  normalized.charisma = clamp(player.charisma ?? 4, statBounds.charisma);
  normalized.inventory = Array.isArray(player.inventory) ? player.inventory : [];
  normalized.flags = new Set(player.flags || []);
  return normalized;
}

function validateItems(items, config) {
  if (!Array.isArray(items)) return [];
  const maxWeight = config.validation?.maxItemWeight ?? Infinity;
  return items.map(item => {
    if (item.weight > maxWeight) {
      logger.logValidation("Item weight exceeds max", { item: item.id || item.name, weight: item.weight });
    }
    if (!item.id) logger.logValidation("Item missing id", { item });
    return item;
  });
}

function validateQuests(quests, config) {
  if (!Array.isArray(quests)) return [];
  const maxObj = config.validation?.maxQuestObjectives ?? 10;
  return quests.map(q => {
    if (!q.quest_id) logger.logValidation("Quest missing quest_id", { quest: q });
    if ((q.objectives || []).length > maxObj) logger.logValidation("Quest has too many objectives", { quest: q.quest_id });
    return q;
  });
}

function validateEncounters(encounters) {
  if (!Array.isArray(encounters)) return [];
  encounters.forEach(enc => {
    if (!enc.id) logger.logValidation("Encounter missing id", enc);
    if (!enc.enemies || !enc.enemies.length) logger.logValidation("Encounter has no enemies", enc.id);
  });
  return encounters;
}

async function checkRequiredAssets(config) {
  if (!config?.assets?.tileset) return;
  try {
    const res = await fetch(config.assets.tileset);
    if (!res.ok) throw new Error(`Missing tileset at ${config.assets.tileset}`);
  } catch (err) {
    logger.warn("Tileset image not uploaded. Please provide /assets/tilesets/tiles.png and matching tilemap config.");
  }
}

async function loadCoreData() {
  const config = await loadJSON("./config.json");
  validateConfig(config);
  gameState.config = config;

  const [player, items, quests, encounters] = await Promise.all([
    loadJSON("./data/player.json"),
    loadJSON("./data/items.json"),
    loadJSON("./data/quests.json"),
    loadJSON("./data/encounters.json")
  ]);

  gameState.player = validatePlayer(player, config.statBounds);
  gameState.items = validateItems(items, config);
  gameState.quests = validateQuests(quests, config);
  gameState.encounters = validateEncounters(encounters);

  await checkRequiredAssets(config);
}

function startGameLoop() {
  gameState.running = true;
  gameState.lastTick = performance.now();
  requestAnimationFrame(tick);
}

function tick(timestamp) {
  if (!gameState.running) return;
  const delta = (timestamp - gameState.lastTick) / 1000;
  gameState.lastTick = timestamp;
  update(delta);
  render();
  requestAnimationFrame(tick);
}

function update(delta) {
  // Placeholder: update timers, animations, AI, etc.
  emit("update", { delta, gameState });
}

function render() {
  // Placeholder: draw scene. Integrate with UI/canvas layer when ready.
  emit("render", { gameState });
}

function loadScene(sceneId) {
  gameState.currentScene = sceneId;
  emit("scene:changed", { sceneId });
}

function setMap(mapId, mapData) {
  gameState.currentMap = mapId;
  gameState.maps[mapId] = mapData;
  emit("map:changed", { mapId });
}

export async function bootstrap() {
  await loadCoreData();
  loadScene("prologue");
  startGameLoop();
  logger.info("Game booted", { scene: gameState.currentScene });
}

export { gameState, on, emit, loadScene, setMap };

bootstrap();
