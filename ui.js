import { gameState } from "./main.js";
import { logger } from "./logger.js";
import { on } from "./main.js";

// Basic UI binding placeholders. Works with HTML overlays; extend for canvas later.
const ui = {
  health: document.getElementById("ui-health"),
  money: document.getElementById("ui-money"),
  traits: document.getElementById("ui-traits"),
  inventory: document.getElementById("ui-inventory"),
  dialog: document.getElementById("ui-dialog"),
  quests: document.getElementById("ui-quests"),
  identityForm: document.getElementById("identity-form")
};

export function renderHUD() {
  if (!ui.health) return;
  const name = gameState.player.name || "Adventurer";
  const classType = gameState.player.classType || "";
  ui.health.textContent = `${name}${classType ? " (" + classType + ")" : ""} — HP: ${gameState.player.health}`;
  ui.money.textContent = `Money: ${gameState.player.money}`;
  ui.traits.textContent = `STR ${gameState.player.strength} | INT ${gameState.player.intelligence} | AGI ${gameState.player.agility} | CHA ${gameState.player.charisma}`;
  renderInventory();
}

export function renderInventory() {
  if (!ui.inventory) return;
  ui.inventory.innerHTML = "";
  gameState.player.inventory.forEach(id => {
    const el = document.createElement("div");
    el.className = "inv-item";
    el.textContent = id;
    ui.inventory.appendChild(el);
  });
}

export function renderDialog(node, onChoice) {
  if (!ui.dialog || !node) return;
  ui.dialog.innerHTML = "";
  const speaker = document.createElement("div");
  speaker.className = "dlg-speaker";
  speaker.textContent = node.speaker;
  const line = document.createElement("div");
  line.className = "dlg-line";
  line.textContent = node.line;
  ui.dialog.appendChild(speaker);
  ui.dialog.appendChild(line);

  const choices = document.createElement("div");
  choices.className = "dlg-choices";
  (node.choices || []).forEach((choice, idx) => {
    const btn = document.createElement("button");
    btn.textContent = choice.text;
    btn.onclick = () => {
      logger.info("Dialog choice", { choice: choice.text, flags: choice.flags });
      if (typeof onChoice === "function") onChoice(idx, choice);
    };
    choices.appendChild(btn);
  });
  ui.dialog.appendChild(choices);
}

export function promptForUITarget() {
  logger.warn("Do you plan to use HTML/CSS UI or Canvas-based display? Please upload index.html or UI mockup.");
}

export function renderQuests(quests = []) {
  if (!ui.quests) return;
  ui.quests.innerHTML = "";
  quests.forEach(q => {
    const wrap = document.createElement("div");
    wrap.className = "quest-item";
    const title = document.createElement("div");
    title.className = "quest-title";
    title.textContent = `${q.quest_id}. ${q.name}`;
    const meta = document.createElement("div");
    meta.className = "quest-meta";
    meta.textContent = `${q.region} • tags: ${(q.tags || []).join(", ")}`;
    const obj = document.createElement("div");
    obj.className = "quest-objectives";
    obj.textContent = `Objectives: ${(q.objectives || []).join("; ")}`;
    wrap.appendChild(title);
    wrap.appendChild(meta);
    wrap.appendChild(obj);
    ui.quests.appendChild(wrap);
  });
}

// Wire events
on("data:loaded", ({ detail }) => {
  renderQuests(detail?.quests || []);
});

on("save:completed", () => {
  if (ui.identityForm) ui.identityForm.style.display = "none";
});
