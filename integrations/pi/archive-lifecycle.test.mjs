import assert from "node:assert/strict";
import { test } from "node:test";
import * as fs from "node:fs";
import * as crypto from "node:crypto";
import { EventEmitter } from "node:events";
import { stripTypeScriptTypes } from "node:module";
import { join } from "node:path";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";

const source = stripTypeScriptTypes(fs.readFileSync(new URL("./iTermate-integration.ts", import.meta.url), "utf8"));

async function harness({ complete, disconnectAfterResponse = false, writeError = false, fleetCount = 0, fleetAvailable = true, hasSubagentTool = false } = {}) {
  const home = fs.mkdtempSync("/tmp/itermate-archive-");
  const handlers = new Map();
  const events = new EventEmitter();
  const timers = new Set();
  const interval = { unref() {} };
  let accept;
  let shutdowns = 0;
  let leaf = "leaf";
  let busy = false;
  const responses = [];
  const snapshots = [];
  const reports = [];
  let sessionId = "native-session";
  const setTimeout = (fn, delay) => {
    const timer = globalThis.setTimeout(() => { timers.delete(timer); fn(); }, delay);
    timers.add(timer);
    return timer;
  };
  const clearTimeout = (timer) => { timers.delete(timer); globalThis.clearTimeout(timer); };
  const context = createContext({
    Buffer, URL, AbortController, AbortSignal,
    process: { pid: 12345, ppid: 12344, env: { TERM_PROGRAM: "iTerm.app", ITERM_SESSION_ID: "w0:target-pane" } },
    performance: { now: () => 10000 }, setTimeout, clearTimeout,
    setInterval: () => interval, clearInterval: () => {},
  });
  const mocks = {
    "node:crypto": { createHash: crypto.createHash, randomBytes: crypto.randomBytes, randomUUID: crypto.randomUUID, timingSafeEqual: crypto.timingSafeEqual },
    "node:fs/promises": { readFile: async () => { throw new Error("No Laya access"); }, access: async () => { throw new Error("No Laya access"); } },
    "node:fs": {
      ...Object.fromEntries(["closeSync", "existsSync", "fsyncSync", "mkdirSync", "mkdtempSync", "openSync", "readFileSync", "renameSync", "rmSync", "writeFileSync"].map(name => [name, fs[name]])),
      // The listener is a mock, so there is deliberately no actual socket file.
      chmodSync: (path, mode) => { if (!path.endsWith(".sock")) fs.chmodSync(path, mode); },
    },
    "node:http": { request: () => { throw new Error("No real network calls"); } },
    "node:child_process": { execFileSync: () => "ttys-isolated" },
    "node:os": { homedir: () => home },
    "node:path": { join },
    "node:net": {
      createServer: (handler) => {
        accept = handler;
        const server = new EventEmitter();
        server.listen = (_path, ready) => { ready(); return server; };
        server.unref = () => server;
        server.close = () => server;
        return server;
      },
      connect: (_path, connected) => {
        const socket = new EventEmitter();
        socket.destroy = () => {};
        socket.setTimeout = () => socket;
        socket.write = (line) => {
          const request = JSON.parse(line);
          reports.push(request);
          queueMicrotask(() => socket.emit("data", Buffer.from(JSON.stringify({ type: "actionResult", requestId: request.requestId, ok: true }) + "\n")));
        };
        queueMicrotask(connected);
        return socket;
      },
    },
  };
  const module = new SourceTextModule(source, { context });
  await module.link((name) => {
    const values = mocks[name];
    assert.ok(values, name);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate();
  const ctx = {
    mode: "tui", model: { id: "mock-model" }, isIdle: () => !busy,
    hasPendingMessages: () => false, ui: { getEditorText: () => "" },
    shutdown: () => { shutdowns += 1; },
    modelRegistry: { complete: complete ?? (async () => ({ stopReason: "stop", content: [{ type: "text", text: "修改分页逻辑，待运行验证。" }] })) },
    sessionManager: {
      getSessionId: () => sessionId, getSessionFile: () => "/original/native-session.jsonl",
      getCwd: () => "/original/project", getSessionName: () => "Archive fixture", getLeafId: () => leaf,
      getHeader: () => ({ type: "session", version: 3, id: "native-session", cwd: "/original/project", timestamp: "2026-01-01T00:00:00Z" }),
      getEntries: () => [{ type: "message", id: "leaf", parentId: null, timestamp: "2026-01-01T00:00:01Z", message: { role: "user", content: "修改分页逻辑", timestamp: 1 } }],
      buildSessionProjection: () => ({ messages: [{ role: "user", content: "修改分页逻辑", timestamp: 1 }] }),
    },
  };
  module.namespace.default({
    on: (name, handler) => handlers.set(name, handler), getAllTools: () => hasSubagentTool ? [{ name: "subagent" }] : [],
    events: {
      on: (name, handler) => { events.on(name, handler); return () => events.off(name, handler); },
      emit: (_name, request) => {
        if (fleetAvailable) queueMicrotask(() => events.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
          version: 1, requestId: request.requestId, success: true, data: { fleet: { version: 1, totalActive: fleetCount } },
        }));
      },
    },
  });
  await handlers.get("session_start")({}, ctx);
  const livePath = join(home, ".iTermate/pi-live");
  const descriptor = JSON.parse(fs.readFileSync(join(livePath, fs.readdirSync(livePath).find(path => path.endsWith(".json"))), "utf8"));
  assert.equal(descriptor.supportsSummary, true);
  const socket = new EventEmitter();
  socket.destroyed = false;
  socket.setTimeout = () => socket;
  socket.destroy = () => { if (!socket.destroyed) { socket.destroyed = true; socket.emit("close"); } };
  socket.end = (data) => { if (data) responses.push(JSON.parse(data)); };
  socket.write = (data, callback) => {
    const response = JSON.parse(data);
    responses.push(response);
    if (response.ok) {
      const directory = join(home, "Library/Application Support/iTermate/ArchivedPiSessions", response.archiveId);
      const manifest = JSON.parse(fs.readFileSync(join(directory, "manifest.json"), "utf8"));
      const transcript = fs.readFileSync(join(directory, manifest.filename), "utf8");
      snapshots.push({ manifest, transcript });
      assert.equal(shutdowns, 0, "Durable archive must precede shutdown");
      assert.equal(crypto.createHash("sha256").update(transcript).digest("hex"), manifest.sha256);
    }
    queueMicrotask(() => {
      if (disconnectAfterResponse) socket.destroy();
      callback(writeError ? new Error("mock write failure") : undefined);
    });
    return true;
  };
  accept(socket);
  return {
    responses, snapshots, socket, reports, descriptor,
    emit: (name, event = {}) => handlers.get(name)?.(event, ctx),
    setSessionId: (value) => { sessionId = value; },
    get shutdowns() { return shutdowns; },
    get inputBlocked() { return handlers.get("input")({}, ctx)?.action === "handled"; },
    setLeaf: (value) => { leaf = value; }, setBusy: (value) => { busy = value; },
    archive: (overrides = {}) => socket.listeners("data")[0](Buffer.from(JSON.stringify({ action: "archive", sessionId: descriptor.sessionId, token: descriptor.token, ...overrides }) + "\n")),
    dispose: async () => {
      await handlers.get("session_shutdown")({}, ctx);
      for (const timer of timers) clearTimeout(timer);
      fs.rmSync(home, { recursive: true, force: true });
    },
  };
}

test("verified summary and archive precede exit, even if the client disconnects after receiving success", async () => {
  const h = await harness({ disconnectAfterResponse: true });
  try {
    await h.archive();
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(h.responses[0].ok, true);
    assert.equal(h.snapshots[0].manifest.summary, "修改分页逻辑，待运行验证。");
    const entries = h.snapshots[0].transcript.trim().split("\n").map(JSON.parse);
    assert.equal(entries.at(-1).customType, "itermate.archive");
    assert.equal(entries.at(-1).parentId, "leaf");
    assert.equal(h.shutdowns, 1);
    assert.equal(h.inputBlocked, true);
  } finally { await h.dispose(); }
});

test("invalid credentials or session identity never start summary generation", async () => {
  for (const overrides of [{ token: "wrong-token" }, { sessionId: "another-session" }]) {
    let modelCalls = 0;
    const h = await harness({ complete: async () => {
      modelCalls += 1;
      return { stopReason: "stop", content: [{ type: "text", text: "摘要" }] };
    } });
    try {
      await h.archive(overrides);
      assert.equal(modelCalls, 0);
      assert.equal(h.responses[0].ok, false);
      assert.equal(h.snapshots.length, 0);
      assert.equal(h.shutdowns, 0);
      assert.equal(h.inputBlocked, false);
    } finally { await h.dispose(); }
  }
});

test("summary failure leaves input unlocked without an archive or exit", async () => {
  const h = await harness({ complete: async () => { throw new Error("mock model failure"); } });
  try {
    await h.archive();
    assert.equal(h.responses[0].ok, false);
    assert.equal(h.snapshots.length, 0);
    assert.equal(h.shutdowns, 0);
    assert.equal(h.inputBlocked, false);
  } finally { await h.dispose(); }
});

test("disconnect during summary cancels even a provider that never settles", async () => {
  let started;
  const ready = new Promise(resolve => { started = resolve; });
  const h = await harness({ complete: async () => { started(); return new Promise(() => {}); } });
  try {
    const archive = h.archive();
    await ready;
    assert.equal(h.inputBlocked, true);
    h.socket.destroy();
    await archive;
    assert.equal(h.snapshots.length, 0);
    assert.equal(h.shutdowns, 0);
    assert.equal(h.inputBlocked, false);
  } finally { await h.dispose(); }
});

test("branch or activity changes during summary prevent archival and exit", async () => {
  for (const change of [h => h.setLeaf("new-leaf"), h => h.setBusy(true)]) {
    let h;
    h = await harness({ complete: async () => {
      change(h);
      return { stopReason: "stop", content: [{ type: "text", text: "摘要" }] };
    } });
    try {
      await h.archive();
      assert.equal(h.responses[0].ok, false);
      assert.equal(h.snapshots.length, 0);
      assert.equal(h.shutdowns, 0);
      assert.equal(h.inputBlocked, false);
    } finally { await h.dispose(); }
  }
});

test("a failed response write retains the archive but does not exit", async () => {
  const h = await harness({ writeError: true });
  try {
    await h.archive();
    await new Promise(resolve => setImmediate(resolve));
    assert.equal(h.snapshots.length, 1);
    assert.equal(h.shutdowns, 0);
    assert.equal(h.inputBlocked, false);
  } finally { await h.dispose(); }
});
