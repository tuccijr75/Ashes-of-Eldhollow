// Simple logger with timestamped entries and optional localStorage persistence
const LEVELS = { DEBUG: "DEBUG", INFO: "INFO", WARN: "WARN", ERROR: "ERROR" };

class Logger {
  constructor(options = {}) {
    this.developerMode = Boolean(options.developerMode);
    this.maxEntries = options.maxEntries || 500;
    this.logKey = options.logKey || "eldhollow-log";
    this.entries = [];
  }

  setDeveloperMode(enabled) {
    this.developerMode = Boolean(enabled);
  }

  timestamp() {
    return new Date().toISOString();
  }

  log(level, message, meta) {
    const entry = {
      ts: this.timestamp(),
      level,
      message,
      meta: meta || null
    };
    this.entries.push(entry);
    if (this.entries.length > this.maxEntries) {
      this.entries.shift();
    }

    // Console output
    const payload = meta ? `${message} :: ${JSON.stringify(meta)}` : message;
    if (level === LEVELS.ERROR) console.error(payload);
    else if (level === LEVELS.WARN) console.warn(payload);
    else if (this.developerMode || level !== LEVELS.DEBUG) console.log(payload);

    this.persist();
    return entry;
  }

  debug(message, meta) {
    return this.log(LEVELS.DEBUG, message, meta);
  }

  info(message, meta) {
    return this.log(LEVELS.INFO, message, meta);
  }

  warn(message, meta) {
    return this.log(LEVELS.WARN, message, meta);
  }

  error(message, meta) {
    return this.log(LEVELS.ERROR, message, meta);
  }

  logValidation(message, meta) {
    return this.warn(`[VALIDATION] ${message}`, meta);
  }

  persist() {
    try {
      const serialized = JSON.stringify(this.entries.slice(-this.maxEntries));
      localStorage.setItem(this.logKey, serialized);
    } catch (err) {
      console.error("Failed to persist logs", err);
    }
  }

  loadFromStorage() {
    try {
      const stored = localStorage.getItem(this.logKey);
      if (stored) {
        this.entries = JSON.parse(stored);
      }
    } catch (err) {
      console.error("Failed to load logs", err);
    }
  }

  exportAsFile(filename = "eldhollow-log.txt") {
    const blob = new Blob(
      [this.entries.map(e => `${e.ts} [${e.level}] ${e.message}`).join("\n")],
      { type: "text/plain" }
    );
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
  }
}

export const logger = new Logger({ developerMode: true, maxEntries: 500 });
export { LEVELS };
export default logger;
