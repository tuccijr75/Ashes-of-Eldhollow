import fs from 'node:fs';
import path from 'node:path';

const ROOT = process.cwd();

function* walk(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const p = path.join(dir, e.name);
    const rel = path.relative(ROOT, p);
    if (e.isDirectory()) {
      // Skip typical generated folders.
      if (e.name === 'node_modules' || e.name === '.git' || e.name === '.godot') continue;
      yield* walk(p);
    } else {
      yield { abs: p, rel };
    }
  }
}

function readText(fileAbs) {
  return fs.readFileSync(fileAbs, 'utf8');
}

function linesWithNumbers(text) {
  return text.split(/\r?\n/).map((line, idx) => ({ line, n: idx + 1 }));
}

function isTargetExt(rel, exts) {
  const ext = path.extname(rel).toLowerCase();
  return exts.includes(ext);
}

function scanRegexInFiles({ exts, regex, include = () => true }) {
  const hits = [];
  for (const f of walk(ROOT)) {
    if (!isTargetExt(f.rel, exts)) continue;
    if (!include(f.rel)) continue;
    const text = readText(f.abs);
    for (const { line, n } of linesWithNumbers(text)) {
      if (regex.test(line)) hits.push({ file: f.rel, line: n, text: line });
      regex.lastIndex = 0;
    }
  }
  return hits;
}

function gateHotloop({ forbiddenRegex, contextLines }) {
  const files = [];
  for (const f of walk(ROOT)) {
    if (path.extname(f.rel).toLowerCase() === '.gd') files.push(f);
  }

  const offenders = [];
  const procRegex = /\b_process\s*\(|\b_physics_process\s*\(/;

  for (const f of files) {
    const text = readText(f.abs);
    const lines = linesWithNumbers(text);
    for (let i = 0; i < lines.length; i++) {
      if (!procRegex.test(lines[i].line)) continue;
      const start = i;
      const end = Math.min(lines.length - 1, i + contextLines);
      const ctx = lines.slice(start, end + 1);
      for (const l of ctx) {
        if (forbiddenRegex.test(l.line)) {
          offenders.push({ file: f.rel, line: l.n, msg: `Forbidden pattern near _process/_physics_process: ${forbiddenRegex}` });
          forbiddenRegex.lastIndex = 0;
          break;
        }
        forbiddenRegex.lastIndex = 0;
      }
    }
  }

  return offenders;
}

function printHits(hits) {
  for (const h of hits) {
    process.stdout.write(`${h.file}:${h.line}:${h.text ?? h.msg}\n`);
  }
}

function usage() {
  console.log(`Usage: node scripts/aoe-gates.mjs <command>\n\nCommands:\n  validate-rpggo-usage\n  gate-rpggo-hotloop\n  gate-httprequest-hotloop\n  gate-secrets\n  gate-rpggo-event-ids\n`);
}

const cmd = process.argv[2];
if (!cmd) {
  usage();
  process.exit(2);
}

if (cmd === 'validate-rpggo-usage') {
  const hits = scanRegexInFiles({ exts: ['.gd'], regex: /\brpggo\b|\bRPGGO\b/ });
  printHits(hits);
  process.exit(0);
}

if (cmd === 'gate-rpggo-hotloop') {
  const offenders = gateHotloop({ forbiddenRegex: /\brpggo\b|\bRPGGO\b/, contextLines: 15 });
  printHits(offenders);
  process.exit(offenders.length ? 1 : 0);
}

if (cmd === 'gate-httprequest-hotloop') {
  const offenders = gateHotloop({ forbiddenRegex: /\bHTTPRequest\b|\.request\s*\(/, contextLines: 20 });
  printHits(offenders);
  process.exit(offenders.length ? 1 : 0);
}

if (cmd === 'gate-secrets') {
  const patterns = [
    // Require a token-like value (avoid flagging placeholders like "%s").
    /Authorization:\s*Bearer\s+[A-Za-z0-9_\-\.=]{20,}/i,
    /api_key\s*=\s*"[^"]+"/i,
    /RPGGO_API_KEY\s*=\s*"[^"]+"/i,
  ];
  const exts = ['.gd', '.json', '.env', '.cfg', '.ini', '.md'];

  const hits = [];
  for (const f of walk(ROOT)) {
    if (!isTargetExt(f.rel, exts)) continue;
    const text = readText(f.abs);
    for (const { line, n } of linesWithNumbers(text)) {
      for (const re of patterns) {
        if (re.test(line)) {
          hits.push({ file: f.rel, line: n, msg: 'Potential secret detected' });
          break;
        }
      }
    }
  }

  printHits(hits);
  process.exit(hits.length ? 1 : 0);
}

if (cmd === 'gate-rpggo-event-ids') {
  // Enforce: event ID strings only live in res://data/rpggo_events.gd
  // We flag any literal occurrences matching the canonical schemas.
  const exts = ['.gd'];
  const allowFile = path.normalize('data/rpggo_events.gd');
  const idRegex = /\b(?:quest|choice|boss|faction|world|ending)\.[a-z0-9_\-]+(?:\.[a-z0-9_\-]+){1,5}\b/ig;

  const hits = [];
  for (const f of walk(ROOT)) {
    if (!isTargetExt(f.rel, exts)) continue;
    const relNorm = path.normalize(f.rel);
    const text = readText(f.abs);
    for (const { line, n } of linesWithNumbers(text)) {
      // Ignore comments-only lines to reduce noise.
      const trimmed = line.trim();
      if (trimmed.startsWith('#') || trimmed.startsWith('//')) continue;

      if (idRegex.test(line)) {
        if (relNorm !== allowFile) {
          hits.push({ file: f.rel, line: n, msg: 'Inline RPGGO event id detected (must reference RPGGOEvents constants)' });
        }
      }
      idRegex.lastIndex = 0;
    }
  }

  printHits(hits);
  process.exit(hits.length ? 1 : 0);
}

usage();
process.exit(2);
