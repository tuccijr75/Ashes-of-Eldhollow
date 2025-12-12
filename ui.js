import { gameState, on, setActiveQuest, markQuestComplete } from "./main.js";
import { logger } from "./logger.js";

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
  const activeId = gameState.activeQuestId;
  const completed = new Set(Array.from(gameState.flags).filter(f => f.endsWith("_done")).map(f => parseInt(f.replace("quest_", "").replace("_done", ""), 10)));

  quests.forEach(q => {
    const wrap = document.createElement("div");
    const isActive = q.quest_id === activeId;
    const isDone = completed.has(q.quest_id);
    wrap.className = "quest-item" + (isActive ? " quest-active" : "") + (isDone ? " quest-complete" : "");
    const title = document.createElement("div");
    title.className = "quest-title";
    title.textContent = `${q.quest_id}. ${q.name}`;
    const meta = document.createElement("div");
    meta.className = "quest-meta";
    meta.textContent = `${q.region} • tags: ${(q.tags || []).join(", ")} ${isDone ? "• COMPLETE" : ""}`;
    const obj = document.createElement("div");
    obj.className = "quest-objectives";
    obj.textContent = `Objectives: ${(q.objectives || []).join("; ")}`;
    const actions = document.createElement("div");
    actions.className = "quest-actions";
    const setBtn = document.createElement("button");
    setBtn.textContent = "Set Active";
    setBtn.onclick = () => setActiveQuest(q.quest_id);
    const doneBtn = document.createElement("button");
    doneBtn.textContent = "Mark Complete";
    doneBtn.onclick = () => markQuestComplete(q.quest_id);
    actions.appendChild(setBtn);
    actions.appendChild(doneBtn);
    wrap.appendChild(title);
    wrap.appendChild(meta);
    wrap.appendChild(obj);
    wrap.appendChild(actions);
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

on("quest:active", () => renderQuests(gameState.quests));
on("quest:completed", () => renderQuests(gameState.quests));
