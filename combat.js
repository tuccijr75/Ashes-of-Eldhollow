import { logger } from "./logger.js";
import { emit, gameState } from "./main.js";

function d20() {
  return Math.floor(Math.random() * 20) + 1;
}

function d10() {
  return Math.floor(Math.random() * 10) + 1;
}

export function rollCTT(traitA, traitB) {
  const total = (traitA || 0) + (traitB || 0);
  const roll = d20();
  let outcome = "fail";
  if (roll < total) outcome = "success";
  else if (roll === total) outcome = "critical";
  return { roll, total, outcome };
}

export function initiative(agility) {
  return d10() + (agility || 0);
}

export function combatTurn(state) {
  const log = [];
  const playerInit = initiative(state.player.agility);
  const enemyInit = initiative(state.enemy.agility || 0);
  const order = playerInit >= enemyInit ? ["player", "enemy"] : ["enemy", "player"];

  order.forEach(actor => {
    if (state.player.health <= 0 || state.enemy.health <= 0) return;
    if (actor === "player") {
      const roll = rollCTT(state.player.strength, state.player.agility);
      const dmg = roll.outcome === "critical" ? 6 : roll.outcome === "success" ? 3 : 0;
      state.enemy.health -= dmg;
      log.push({ actor, roll, dmg });
      emit("combat:log", { actor, roll, dmg });
    } else {
      const roll = rollCTT(state.enemy.strength || 3, state.enemy.agility || 2);
      const dmg = roll.outcome === "critical" ? 4 : roll.outcome === "success" ? 2 : 0;
      state.player.health -= dmg;
      log.push({ actor, roll, dmg });
      emit("combat:log", { actor, roll, dmg });
    }
  });

  logger.info("Combat turn resolved", { log });
  return { ...state, log };
}

export function enemyAI(enemy, context) {
  // Simple AI: attack unless low health, then attempt flee
  if (enemy.health < 5 && Math.random() < 0.25) {
    return { action: "flee", reason: "low_health" };
  }
  if (context.playerUsedItem) {
    return { action: "attack", target: "player", focus: "interrupt" };
  }
  return { action: "attack", target: "player" };
}

export function combatLog(message, meta) {
  logger.info(`[COMBAT] ${message}`, meta);
}
