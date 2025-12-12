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

const CLASS_PRESETS = {
  warrior: { health: 16, strength: 7, intelligence: 3, agility: 5, charisma: 4 },
  rogue: { health: 14, strength: 5, intelligence: 4, agility: 7, charisma: 5 },
  mage: { health: 13, strength: 3, intelligence: 7, agility: 5, charisma: 5 }
};

const NAME_BANK = [
  "Eira", "Kael", "Sylas", "Rowan", "Thorne", "Mira", "Anwen", "Corin", "Lyra", "Bram",
  "Isolde", "Fen", "Varyn", "Lysa", "Doran", "Neris", "Hale", "Talwyn", "Riven", "Sable"
];

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

function applyClassPreset(player) {
  const classType = CLASS_PRESETS[player.classType] ? player.classType : "warrior";
  const preset = CLASS_PRESETS[classType];
  return {
    ...preset,
    ...player,
    classType
  };
}

function sanitizeName(name) {
  if (typeof name !== "string") return "Adventurer";
  const trimmed = name.trim();
  if (!trimmed.length) return "Adventurer";
  return trimmed.slice(0, 24);
}

function randomName() {
  return NAME_BANK[Math.floor(Math.random() * NAME_BANK.length)];
}

function validatePlayer(player, statBounds) {
  if (!player) return null;
  const withPreset = applyClassPreset(player);
  const normalized = { ...withPreset };
  normalized.name = sanitizeName(withPreset.name || "Adventurer");
  normalized.health = clamp(withPreset.health ?? 15, statBounds.health);
  normalized.strength = clamp(withPreset.strength ?? 5, statBounds.strength);
  normalized.intelligence = clamp(withPreset.intelligence ?? 4, statBounds.intelligence);
  normalized.agility = clamp(withPreset.agility ?? 5, statBounds.agility);
  normalized.charisma = clamp(withPreset.charisma ?? 4, statBounds.charisma);
  normalized.inventory = Array.isArray(withPreset.inventory) ? withPreset.inventory : [];
  normalized.flags = new Set(withPreset.flags || []);
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
  emit("data:loaded", { quests: gameState.quests });
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

// Bind identity form if present
function bindIdentityForm() {
  const nameInput = document.getElementById("name-input");
  const classSelect = document.getElementById("class-select");
  const applyBtn = document.getElementById("apply-identity");
  const form = document.getElementById("identity-form");
  const randomBtn = document.getElementById("random-name");
  if (!applyBtn || !nameInput || !classSelect || !form) return;
  applyBtn.onclick = () => {
    setPlayerIdentity({ name: nameInput.value, classType: classSelect.value });
    form.style.display = "none";
  };
  if (randomBtn) {
    randomBtn.onclick = () => {
      nameInput.value = randomName();
    };
  }

  // Auto-hide if a save exists
  if (localStorage.getItem("eldhollow-save-0")) {
    form.style.display = "none";
  }
  emit("ui:identity-ready", {});
}

export function setPlayerIdentity({ name, classType, applyPreset = true } = {}) {
  if (!gameState.player) return;
  if (name) gameState.player.name = sanitizeName(name);
  if (classType && CLASS_PRESETS[classType]) {
    gameState.player.classType = classType;
    if (applyPreset) {
      const preset = CLASS_PRESETS[classType];
      gameState.player = validatePlayer({ ...gameState.player, ...preset }, gameState.config.statBounds);
    }
  }
  emit("player:identity", { name: gameState.player.name, classType: gameState.player.classType });
}

export { gameState, on, emit, loadScene, setMap };

bootstrap().then(bindIdentityForm);
