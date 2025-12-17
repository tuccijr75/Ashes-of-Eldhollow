import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();

const SKIP_DIRS = new Set([
  "node_modules",
  ".git",
]);

function isSkippableDir(name) {
  return SKIP_DIRS.has(name);
}

function listFilesRecursive(dir, out = []) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const ent of entries) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      if (isSkippableDir(ent.name)) continue;
      listFilesRecursive(full, out);
    } else if (ent.isFile()) {
      out.push(full);
    }
  }
  return out;
}

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

function pad3(n) {
  return String(n).padStart(3, "0");
}

function main() {
  const allFiles = listFilesRecursive(ROOT);
  const jsonFiles = allFiles
    .filter((p) => p.toLowerCase().endsWith(".json"))
    .map((p) => path.relative(ROOT, p));

  // Parse canonical quests.json to build the allowed set of quest locations.
  const quests = readJson(path.join(ROOT, "data", "quests.json"));
  const questLocations = new Set(
    quests
      .map((q) => String(q?.location || "").trim().toLowerCase())
      .filter(Boolean)
  );

  const parseErrors = [];
  const startNextBad = []; // {file, key}

  for (const rel of jsonFiles) {
    const abs = path.join(ROOT, rel);
    let data;
    try {
      data = readJson(abs);
    } catch (e) {
      parseErrors.push({ file: rel, error: String(e?.message || e) });
      continue;
    }

    walk(data, (obj) => {
      if (!Object.prototype.hasOwnProperty.call(obj, "start_next_available_quest")) return;
      const key = String(obj.start_next_available_quest || "").trim().toLowerCase();
      if (!key) return;
      if (!questLocations.has(key)) {
        startNextBad.push({ file: rel, key });
      }
    });
  }

  // Quest dialog spot-check: quest_id matches filename and contains a complete_quest effect.
  const questDialogDir = path.join(ROOT, "data", "dialogs");
  const questDialogFiles = fs
    .readdirSync(questDialogDir)
    .filter((f) => /^quest_\d{3}\.json$/i.test(f))
    .sort();

  const questDialogErrors = [];

  for (const fileName of questDialogFiles) {
    const abs = path.join(questDialogDir, fileName);
    const rel = path.relative(ROOT, abs);
    let data;
    try {
      data = readJson(abs);
    } catch (e) {
      questDialogErrors.push({ file: rel, error: `parse: ${String(e?.message || e)}` });
      continue;
    }

    const match = fileName.match(/quest_(\d{3})\.json/i);
    const qid = match ? Number(match[1]) : NaN;
    const declared = Number(data?.quest_id);

    if (!Number.isFinite(qid) || qid <= 0) {
      questDialogErrors.push({ file: rel, error: "bad_filename" });
      continue;
    }
    if (!Number.isFinite(declared) || declared !== qid) {
      questDialogErrors.push({ file: rel, error: `quest_id_mismatch declared=${data?.quest_id} expected=${qid}` });
    }

    const nodes = data?.nodes;
    const start = String(data?.start || "");
    if (!nodes || typeof nodes !== "object" || !start || !Object.prototype.hasOwnProperty.call(nodes, start)) {
      questDialogErrors.push({ file: rel, error: "schema_missing_start_or_nodes" });
      continue;
    }

    let hasComplete = false;
    walk(nodes, (obj) => {
      if (Object.prototype.hasOwnProperty.call(obj, "complete_quest")) {
        if (Number(obj.complete_quest) === qid) hasComplete = true;
      }
    });
    if (!hasComplete) {
      questDialogErrors.push({ file: rel, error: "missing_complete_quest_effect" });
    }
  }

  const summary = {
    jsonFiles: jsonFiles.length,
    parseErrors: parseErrors.length,
    startNextBad: startNextBad.length,
    questDialogFiles: questDialogFiles.length,
    questDialogErrors: questDialogErrors.length,
    questLocations: [...questLocations].sort(),
  };

  if (parseErrors.length || startNextBad.length || questDialogErrors.length) {
    console.error("FAIL audit-repo", summary);
    if (parseErrors.length) {
      console.error("\nJSON parse errors:");
      for (const e of parseErrors.slice(0, 50)) console.error(`- ${e.file}: ${e.error}`);
      if (parseErrors.length > 50) console.error(`...and ${parseErrors.length - 50} more`);
    }
    if (startNextBad.length) {
      console.error("\nInvalid start_next_available_quest keys:");
      for (const e of startNextBad.slice(0, 50)) console.error(`- ${e.file}: ${e.key}`);
      if (startNextBad.length > 50) console.error(`...and ${startNextBad.length - 50} more`);
    }
    if (questDialogErrors.length) {
      console.error("\nQuest dialog issues:");
      for (const e of questDialogErrors.slice(0, 50)) console.error(`- ${e.file}: ${e.error}`);
      if (questDialogErrors.length > 50) console.error(`...and ${questDialogErrors.length - 50} more`);
    }
    process.exit(2);
  }

  console.log("OK audit-repo", summary);
}

main();
