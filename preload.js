const { contextBridge } = require("electron");

// Expose minimal API surface if needed later
contextBridge.exposeInMainWorld("eldhollow", {
  version: "0.1.0"
});
