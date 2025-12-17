import fs from "node:fs";
import path from "node:path";

const root = process.cwd();

function readJson(relPath) {
  const full = path.join(root, relPath);
  const raw = fs.readFileSync(full, "utf8");
  return JSON.parse(raw);
}

function exists(relPath) {
  return fs.existsSync(path.join(root, relPath));
}

function listJsonFiles(relDir) {
  const fullDir = path.join(root, relDir);
  if (!fs.existsSync(fullDir)) return [];
  return fs
    .readdirSync(fullDir)
    .filter((f) => f.toLowerCase().endsWith(".json"))
    .sort();
}

function pad3(n) {
  return String(n).padStart(3, "0");
}

function assert(cond, msg) {
  if (!cond) throw new Error(msg);
}

function validateQuestDialogSchema(dialog, questId, relPath) {
  assert(dialog && typeof dialog === "object", `Invalid dialog JSON object: ${relPath}`);
  const start = String(dialog.start || "");
  const nodes = dialog.nodes;
  assert(start.length > 0, `Dialog missing 'start': ${relPath}`);
  assert(nodes && typeof nodes === "object" && !Array.isArray(nodes), `Dialog missing/invalid 'nodes': ${relPath}`);
  assert(Object.prototype.hasOwnProperty.call(nodes, start), `Dialog start node not found: ${relPath} start=${start}`);

  // Ensure there exists at least one choice effect completing this quest.
  let hasComplete = false;
  for (const nodeId of Object.keys(nodes)) {
    const node = nodes[nodeId];
    if (!node || typeof node !== "object") continue;
    if (node.end === true) continue;
    const choices = Array.isArray(node.choices) ? node.choices : [];
    // If a non-end node has no choices, it's a dead-end (treat as error).
    assert(choices.length > 0, `Dialog dead-end (no choices): ${relPath} node=${nodeId}`);
    for (const choice of choices) {
      assert(choice && typeof choice === "object", `Dialog choice not an object: ${relPath} node=${nodeId}`);
      assert(typeof choice.next === "string" && choice.next.length > 0, `Dialog choice missing 'next': ${relPath} node=${nodeId}`);
      assert(Object.prototype.hasOwnProperty.call(nodes, choice.next), `Dialog choice next missing target: ${relPath} node=${nodeId} next=${choice.next}`);
      const effects = Array.isArray(choice.effects) ? choice.effects : [];
      for (const eff of effects) {
        if (eff && typeof eff === "object" && Number(eff.complete_quest) === questId) {
          hasComplete = true;
        }
      }
    }
  }
  assert(hasComplete, `Dialog missing completion effect for quest ${questId}: ${relPath}`);
}

function validateQuestDepsAcyclic(questDeps) {
  const visiting = new Set();
  const visited = new Set();

  function dfs(qid) {
    if (visited.has(qid)) return false;
    if (visiting.has(qid)) return true;
    visiting.add(qid);
    const deps = questDeps.get(qid) || [];
    for (const d of deps) {
      if (dfs(d)) return true;
    }
    visiting.delete(qid);
    visited.add(qid);
    return false;
  }

  for (const qid of questDeps.keys()) {
    if (dfs(qid)) return true;
  }
  return false;
}

function main() {
  const quests = readJson("data/quests.json");
  const encounters = readJson("data/encounters.json");
  const items = readJson("data/items.json");

  if (!Array.isArray(quests) || quests.length === 0) throw new Error("quests.json missing/empty");
  if (!Array.isArray(encounters) || encounters.length === 0) throw new Error("encounters.json missing/empty");
  if (!Array.isArray(items)) throw new Error("items.json missing/invalid");

  const itemIds = new Set(items.map((it) => String(it?.id || "").trim()).filter(Boolean));

  const questNums = new Set(); // 1..N index-based quest numbers used by dialogs/saves
  const questEventIds = new Set(); // canonical string quest ids from quests.json
  const questDeps = new Map(); // quest_num -> [depNums]
  const missingLocationDialogs = new Set();
  const allowedDomains = new Set(["", "META", "INK", "BLOOD", "SILENCE", "DEBT", "WITNESS"]);
  // quest_id is the canonical string identifier used for narrative events.
  // Note: some authored IDs currently contain spaces (e.g. "hollow city");
  // we allow them here to match the data source-of-truth.
  const questIdPattern = /^quest\.[a-z0-9_\- ]+(?:\.[a-z0-9_\- ]+){1,8}$/i;
  for (let i = 0; i < quests.length; i++) {
    const q = quests[i];
    const questNum = i + 1;
    questNums.add(questNum);

    const eventId = String(q?.quest_id || "").trim();
    if (!eventId) throw new Error(`Quest missing quest_id string (canonical id): index=${questNum}`);
    if (!questIdPattern.test(eventId)) throw new Error(`Invalid quest_id format: index=${questNum} quest_id=${eventId}`);
    if (questEventIds.has(eventId)) throw new Error(`Duplicate quest_id string: ${eventId}`);
    questEventIds.add(eventId);

    const dom = String(q.authority_domain || "").toUpperCase();
    if (!allowedDomains.has(dom)) {
      throw new Error(`Invalid authority_domain for quest ${questNum} (${eventId}): ${q.authority_domain}`);
    }

    const deps = Array.isArray(q.dependencies) ? q.dependencies.map((n) => Number(n)).filter((n) => Number.isFinite(n)) : [];
    questDeps.set(questNum, deps);

    // Validate per-quest dialog file exists and is structurally sound.
    const qDlg = `data/dialogs/quest_${pad3(questNum)}.json`;
    if (!exists(qDlg)) {
      throw new Error(`Missing quest dialog: ${qDlg}`);
    }
    const qDlgJson = readJson(qDlg);
    validateQuestDialogSchema(qDlgJson, questNum, qDlg);

    const loc = q.location;
    if (loc) {
      const dlg = `dialogs/dlg_${loc}.json`;
      if (!exists(dlg)) {
        // Location dialogs are supplemental; track and summarize to avoid log spam.
        missingLocationDialogs.add(dlg);
      }
    }
  }

  if (missingLocationDialogs.size > 0) {
    const list = Array.from(missingLocationDialogs).sort();
    const maxShow = 20;
    const shown = list.slice(0, maxShow);
    console.warn(`WARN: Missing supplemental location dialogs: ${list.length}`);
    for (const p of shown) console.warn(`  - ${p}`);
    if (list.length > maxShow) console.warn(`  ...and ${list.length - maxShow} more`);
  }

  // Quest inventory expectation: allow growth beyond 100.
  if (quests.length < 100) throw new Error(`Expected at least 100 quests, got ${quests.length}`);
  for (let i = 1; i <= quests.length; i++) {
    if (!questNums.has(i)) throw new Error(`Missing quest number: ${i}`);
  }

  // Validate quest dependency references.
  for (const [qid, deps] of questDeps.entries()) {
    for (const dep of deps) {
      if (!questNums.has(dep)) throw new Error(`Quest ${qid} depends on missing quest ${dep}`);
    }
  }
  if (validateQuestDepsAcyclic(questDeps)) {
    throw new Error("Quest dependency cycle detected");
  }

  const encounterIds = new Set();
  for (const e of encounters) {
    // Accept either legacy schema: {id, ...}
    // or table schema: {region, act, spawns:[{id, ...}]}
    if (e?.id) {
      if (encounterIds.has(e.id)) throw new Error(`Duplicate encounter id: ${e.id}`);
      encounterIds.add(e.id);
      continue;
    }

    if (!e?.region || !e?.act || !Array.isArray(e?.spawns)) {
      throw new Error(`Encounter missing region/act/spawns: ${JSON.stringify(e).slice(0, 160)}`);
    }

    for (const s of e.spawns) {
      if (!s?.id) throw new Error(`Encounter spawn missing id: ${JSON.stringify(s).slice(0, 160)}`);
      if (encounterIds.has(s.id)) throw new Error(`Duplicate encounter id: ${s.id}`);
      encounterIds.add(s.id);
    }
  }

  // Maps: scan all json files under maps/ (no hardcoded list).
  const mapFiles = listJsonFiles("maps").map((f) => `maps/${f}`);
  if (mapFiles.length === 0) throw new Error("No maps found under maps/");

  const regionIds = new Set();
  for (const p of mapFiles) {
    const map = readJson(p);
    assert(Array.isArray(map?.regions) && map.regions.length > 0, `Map has no regions: ${p}`);
    for (const r of map.regions) {
      const rid = String(r?.id || "").trim();
      assert(rid.length > 0, `Region missing id in ${p}`);
      if (regionIds.has(rid)) {
        // Region IDs are used as global identifiers in WorldStream; enforce uniqueness.
        throw new Error(`Duplicate region id across maps: ${rid}`);
      }
      regionIds.add(rid);
    }
  }

  // Validate region references inside maps (exits + placed items).
  for (const p of mapFiles) {
    const map = readJson(p);
    for (const r of map.regions) {
      const rid = String(r?.id || "").trim();
      const exits = Array.isArray(r?.exits) ? r.exits : [];
      for (const ex of exits) {
        const to = String(ex?.to || "").trim();
        assert(to.length > 0, `Exit missing 'to' in ${p} region=${rid}`);
        assert(regionIds.has(to), `Exit target region not found: ${p} region=${rid} -> ${to}`);
      }

      const placedItems = Array.isArray(r?.items) ? r.items : [];
      for (const it of placedItems) {
        const itemId = String(it?.id || "").trim();
        assert(itemId.length > 0, `Placed item missing id in ${p} region=${rid}`);
        assert(itemIds.has(itemId), `Placed item id not found in items.json: ${p} region=${rid} item=${itemId}`);
      }
    }
  }

  console.log("OK", {
    quests: quests.length,
    encounters: encounters.length,
    items: items.length,
    maps: mapFiles.length
  });
}

main();
