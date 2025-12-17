import fs from "node:fs";
import path from "node:path";

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function walk(value, visitor) {
  if (Array.isArray(value)) {
    for (const v of value) walk(v, visitor);
    return;
  }
  if (value && typeof value === "object") {
    visitor(value);
    for (const v of Object.values(value)) walk(v, visitor);
  }
}

function main() {
  const questsPath = path.join("data", "quests.json");
  const dialogsDir = "dialogs";

  const quests = readJson(questsPath);
  const questLocations = new Set(
    quests
      .map((q) => String(q?.location || "").trim().toLowerCase())
      .filter(Boolean)
  );

  const startNextUsed = new Map(); // locationKey -> [file...]

  const dialogFiles = fs
    .readdirSync(dialogsDir)
    .filter((f) => f.toLowerCase().endsWith(".json"))
    .sort();

  for (const fileName of dialogFiles) {
    const filePath = path.join(dialogsDir, fileName);
    const dialog = readJson(filePath);

    walk(dialog, (obj) => {
      if (!Object.prototype.hasOwnProperty.call(obj, "start_next_available_quest")) return;
      const key = String(obj.start_next_available_quest || "").trim().toLowerCase();
      if (!key) return;
      if (!startNextUsed.has(key)) startNextUsed.set(key, []);
      startNextUsed.get(key).push(fileName);
    });
  }

  const missingKeys = [...startNextUsed.keys()].filter((k) => !questLocations.has(k));

  const summary = {
    questLocationCount: questLocations.size,
    startNextKeyCount: startNextUsed.size,
    missingKeyCount: missingKeys.length,
    missingKeys,
  };

  if (missingKeys.length) {
    console.error("FAIL dialogs start_next_available_quest contains unknown location keys", summary);
    for (const k of missingKeys) {
      console.error(`  - ${k}: ${startNextUsed.get(k).join(", ")}`);
    }
    process.exitCode = 2;
    return;
  }

  console.log("OK audit-dialogs", summary);
}

main();
