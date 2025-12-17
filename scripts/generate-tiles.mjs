import fs from "node:fs";
import path from "node:path";

const ROOT = process.cwd();
const LOG_PATH = path.join(ROOT, "logs", "tiles.log");

function log(line) {
  const msg = `[${new Date().toISOString()}] ${line}\n`;
  fs.mkdirSync(path.dirname(LOG_PATH), { recursive: true });
  fs.appendFileSync(LOG_PATH, msg, "utf8");
  process.stdout.write(msg);
}

function readJson(relPath) {
  const full = path.join(ROOT, relPath);
  return JSON.parse(fs.readFileSync(full, "utf8"));
}

function writeFile(relPath, buffer) {
  const full = path.join(ROOT, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, buffer);
}

function requiredEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env var ${name}`);
  return v;
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function retryWithBackoff(fn, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxRetries) throw err;
      const delay = Math.min(1000 * (2 ** attempt), 10000);
      await sleep(delay);
    }
  }
}

async function openaiImageGen({ prompt, size = "1024x1024" }) {
  const apiKey = requiredEnv("OPENAI_API_KEY");

  const body = JSON.stringify({
    model: "dall-e-3",
    prompt,
    size,
    n: 1,
    response_format: "b64_json",
    quality: "standard"
  });

  const res = await fetch("https://api.openai.com/v1/images/generations", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text.slice(0, 400)}`);
  }

  const json = await res.json();
  const b64 = json?.data?.[0]?.b64_json;
  if (!b64) throw new Error("No b64_json in response");
  
  return Buffer.from(b64, "base64");
}

async function main() {
  const manifest = readJson("assets/tilesets/tileset_manifest.json");
  const outDir = manifest.tileset.outputDir;

  log(`START tileset=${manifest.tileset.id} tileSize=${manifest.tileset.tileSize} outDir=${outDir}`);

  // Optional dependency: pngjs for downscaling (only needed if your API can't return 32x32).
  // If installed, set DOWNSCALE=1 to force generating 1024x1024 and downscaling to 32x32.
  const doDownscale = process.env.DOWNSCALE === "1";
  let PNG;
  if (doDownscale) {
    try {
      ({ PNG } = await import("pngjs"));
    } catch (e) {
      throw new Error("DOWNSCALE=1 requires pngjs. Run: npm i -D pngjs");
    }
  }

  for (const tile of manifest.tiles) {
    const outPath = `${outDir}/${tile.id}.png`;
    
    // Skip if already exists
    if (fs.existsSync(path.join(ROOT, outPath))) {
      log(`SKIP id=${tile.id} (already exists)`);
      continue;
    }
    
    try {
      log(`GEN id=${tile.id} key=${tile.key}`);

      const size = doDownscale ? "1024x1024" : "1024x1024";
      const pngBuffer = await retryWithBackoff(() => openaiImageGen({
        prompt: tile.prompt,
        size
      }));

      let finalBuffer = pngBuffer;

      if (doDownscale) {
        const src = PNG.sync.read(pngBuffer);
        const dstSize = manifest.tileset.tileSize;
        const dst = new PNG({ width: dstSize, height: dstSize });

        // Nearest-neighbor downscale
        for (let y = 0; y < dstSize; y++) {
          for (let x = 0; x < dstSize; x++) {
            const sx = Math.floor((x / dstSize) * src.width);
            const sy = Math.floor((y / dstSize) * src.height);
            const si = (sy * src.width + sx) * 4;
            const di = (y * dstSize + x) * 4;
            dst.data[di] = src.data[si];
            dst.data[di + 1] = src.data[si + 1];
            dst.data[di + 2] = src.data[si + 2];
            dst.data[di + 3] = src.data[si + 3];
          }
        }

        finalBuffer = PNG.sync.write(dst);
      }

      writeFile(outPath, finalBuffer);
      log(`OK  id=${tile.id} -> ${outPath}`);

      // Lava animation frames (extra files) if this is the lava tile.
      if (tile.key === "lava") {
        const frames = manifest?.animation?.lava?.frames || [];
        if (frames.length) {
          for (let i = 0; i < frames.length; i++) {
            const frameName = frames[i];
            const framePrompt = `${tile.prompt}. Frame ${i + 1} of 4, subtle animated variation, loopable with other frames.`;
            const framePng = await openaiImageGen({ prompt: framePrompt, size });
            let frameFinal = framePng;
            if (doDownscale) {
              const src = PNG.sync.read(framePng);
              const dstSize = manifest.tileset.tileSize;
              const dst = new PNG({ width: dstSize, height: dstSize });
              for (let y = 0; y < dstSize; y++) {
                for (let x = 0; x < dstSize; x++) {
                  const sx = Math.floor((x / dstSize) * src.width);
                  const sy = Math.floor((y / dstSize) * src.height);
                  const si = (sy * src.width + sx) * 4;
                  const di = (y * dstSize + x) * 4;
                  dst.data[di] = src.data[si];
                  dst.data[di + 1] = src.data[si + 1];
                  dst.data[di + 2] = src.data[si + 2];
                  dst.data[di + 3] = src.data[si + 3];
                }
              }
              frameFinal = PNG.sync.write(dst);
            }
            writeFile(`${outDir}/${frameName}`, frameFinal);
            log(`OK  lava-frame ${frameName}`);
          }
        }
      }
    } catch (err) {
      log(`FAIL id=${tile.id} key=${tile.key} err=${err.message}`);
    }
  }

  log("DONE");
}

main().catch(err => {
  log(`FATAL ${err.message}`);
  process.exitCode = 1;
});
