import assert from "node:assert/strict";
import { test } from "node:test";
import * as fs from "node:fs";
import * as crypto from "node:crypto";
import { EventEmitter } from "node:events";
import { stripTypeScriptTypes } from "node:module";
import { join } from "node:path";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";

const source = stripTypeScriptTypes(fs.readFileSync(new URL("./iTermate-integration.ts", import.meta.url), "utf8"));

async function harness({ complete, disconnectAfterResponse = false, writeError = false, fleetCount = 0, fleetAvailable = true, hasSubagentTool = false, mode = "tui", termProgram = "iTerm.app" } = {}) {
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
  let messages = [{ role: "user", content: "修改分页逻辑", timestamp: 1 }];
  const setTimeout = (fn, delay) => {
    const timer = globalThis.setTimeout(() => { timers.delete(timer); fn(); }, delay);
    timers.add(timer);
    return timer;
  };
  const clearTimeout = (timer) => { timers.delete(timer); globalThis.clearTimeout(timer); };
  const context = createContext({
    Buffer, URL, AbortController, AbortSignal,
    // Inject an isolated local-title transport; archive summaries keep their separate Pi adapter.
    mockLocalTitle: async (systemPrompt, text, signal, maxTokens) => {
      const result = await (complete ?? (async () => taskReply("修改分页逻辑")))(
        { id: "isolated-local-llm" },
        { systemPrompt, messages: [{ role: "user", content: text }] }, { signal, maxTokens },
      );
      if (result.stopReason !== "stop") throw new Error("Incomplete local title");
      return result.content.filter(block => block.type === "text").map(block => block.text).join("\n");
    },
    process: { pid: 12345, ppid: 12344, env: { TERM_PROGRAM: termProgram, ITERM_SESSION_ID: "w0:target-pane" } },
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
  const isolatedSource = source.replace(/generate\s*=\s*completeLocalLLM/, "generate = globalThis.mockLocalTitle");
  const module = new SourceTextModule(isolatedSource, { context });
  await module.link((name) => {
    const values = mocks[name];
    assert.ok(values, name);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate();
  const ctx = {
    mode, model: { id: "mock-model" }, isIdle: () => !busy,
    hasPendingMessages: () => false, ui: { getEditorText: () => "", notify: () => {} },
    shutdown: () => { shutdowns += 1; },
    modelRegistry: { complete: complete ?? (async () => ({ stopReason: "stop", content: [{ type: "text", text: "修改分页逻辑，待运行验证。" }] })) },
    sessionManager: {
      getSessionId: () => sessionId, getSessionFile: () => "/original/native-session.jsonl",
      getCwd: () => "/original/project", getSessionName: () => "Archive fixture", getLeafId: () => leaf,
      getHeader: () => ({ type: "session", version: 3, id: "native-session", cwd: "/original/project", timestamp: "2026-01-01T00:00:00Z" }),
      getEntries: () => [{ type: "message", id: "leaf", parentId: null, timestamp: "2026-01-01T00:00:01Z", message: { role: "user", content: "修改分页逻辑", timestamp: 1 } }],
      buildSessionProjection: () => ({ messages }),
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
  const readDescriptor = () => {
    const file = fs.existsSync(livePath) && fs.readdirSync(livePath).find(path => path.endsWith(".json"));
    return file ? JSON.parse(fs.readFileSync(join(livePath, file), "utf8")) : undefined;
  };
  const descriptor = readDescriptor();
  if (mode === "tui") assert.equal(descriptor.supportsSummary, true);
  const makeClient = () => {
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
    accept?.(socket);
    return socket;
  };
  const socket = makeClient();
  return {
    responses, snapshots, socket, reports, descriptor, readDescriptor, makeClient,
    refreshTitle: (overrides = {}, client = socket) => client.listeners("data")[0](Buffer.from(JSON.stringify({ action: "refreshTitle", sessionId: descriptor.sessionId, token: descriptor.token, ...overrides }) + "\n")),
    setMessages: (value) => { messages = value; },
    emit: (name, event = {}) => handlers.get(name)?.(event, ctx),
    setSessionId: (value) => { sessionId = value; },
    queryStatus: (overrides = {}) => socket.listeners("data")[0](Buffer.from(JSON.stringify({ action: "status", sessionId: descriptor.sessionId, token: descriptor.token, ...overrides }) + "\n")),
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

const assistantReply = { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "已检查分页边界。" }] };
const taskReply = text => ({ stopReason: "stop", content: [{ type: "text", text }] });
const flushSummary = () => new Promise(resolve => setImmediate(resolve));
async function settleTask(h) {
  await h.emit("agent_start");
  await h.emit("agent_end", { messages: [assistantReply] });
  await h.emit("agent_settled");
  await flushSummary();
}

test("manual title refresh works immediately after reload without another reply", async () => {
  let calls = 0;
  const h = await harness({ complete: async () => { calls += 1; return taskReply("修复分页逻辑"); } });
  try {
    assert.equal(h.readDescriptor().supportsTitleRefresh, true);
    assert.equal(h.readDescriptor().canRefreshTitle, true);
    const reportCount = h.reports.length;
    await h.refreshTitle();
    assert.equal(calls, 1);
    assert.equal(h.responses[0].ok, true);
    assert.equal(h.responses[0].instanceId, h.descriptor.id);
    assert.equal(h.responses[0].taskSummary, "修复分页逻辑");
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    assert.equal(h.readDescriptor().canRefreshTitle, true);
    assert.equal(h.reports.length, reportCount);
    assert.equal(h.shutdowns, 0);
    assert.equal(h.snapshots.length, 0);
    assert.equal(h.inputBlocked, false);
  } finally { await h.dispose(); }
});

test("automatic publishing and manual refresh retain titles outside prompt style guidance", async () => {
  const title = " 控制 Tab 切换跳过 Codex 2。\n";
  const h = await harness({ complete: async () => taskReply(title) });
  try {
    await settleTask(h);
    assert.equal(h.readDescriptor().taskSummary, title);
    await h.refreshTitle();
    assert.equal(h.responses.at(-1).ok, true);
    assert.equal(h.responses.at(-1).taskSummary, title);
    assert.equal(h.readDescriptor().taskSummary, title);
    assert.equal(h.shutdowns, 0);
    assert.equal(h.inputBlocked, false);
  } finally { await h.dispose(); }
});

test("manual refresh bypasses automatic deduplication and keeps old labels on failure", async () => {
  let calls = 0;
  const h = await harness({ complete: async () => {
    calls += 1;
    if (calls === 3) throw new Error("Provider failed");
    return taskReply(calls === 1 ? "旧标题" : "新标题");
  } });
  try {
    await settleTask(h);
    await h.refreshTitle();
    assert.equal(calls, 2);
    assert.equal(h.readDescriptor().taskSummary, "新标题");
    await h.refreshTitle({}, h.makeClient());
    assert.equal(calls, 3);
    assert.equal(h.responses.at(-1).ok, false);
    assert.equal(h.readDescriptor().taskSummary, "新标题");
    assert.equal(h.readDescriptor().canRefreshTitle, true);
  } finally { await h.dispose(); }
});

test("manual refresh authenticates before invoking a model and rejects busy or empty sessions", async () => {
  for (const scenario of ["token", "identity", "busy", "empty"]) {
    let calls = 0;
    const h = await harness({ complete: async () => { calls += 1; return taskReply("不应调用"); } });
    try {
      if (scenario === "busy") h.setBusy(true);
      if (scenario === "empty") h.setMessages([]);
      await h.refreshTitle(scenario === "token" ? { token: "wrong" }
        : scenario === "identity" ? { sessionId: "wrong" } : {});
      assert.equal(h.responses[0].ok, false, scenario);
      assert.equal(calls, 0, scenario);
      assert.equal(h.readDescriptor().taskSummary, undefined);
      assert.equal(h.inputBlocked, false);
    } finally { await h.dispose(); }
  }
});

test("concurrent refreshes do not duplicate model calls or lock conversation input", async () => {
  let finish;
  let calls = 0;
  const h = await harness({ complete: async () => { calls += 1; return new Promise(resolve => { finish = resolve; }); } });
  try {
    const pending = h.refreshTitle();
    assert.equal(h.readDescriptor().canRefreshTitle, false);
    assert.equal(h.readDescriptor().canArchive, false);
    assert.equal(h.inputBlocked, false);
    await h.refreshTitle({}, h.makeClient());
    assert.equal(h.responses[0].ok, false);
    assert.equal(calls, 1);
    finish(taskReply("刷新后的标题"));
    await pending;
    assert.equal(h.responses.at(-1).ok, true);
    assert.equal(h.readDescriptor().taskSummary, "刷新后的标题");
  } finally { await h.dispose(); }
});

test("manual refresh discards disconnected or obsolete results", async () => {
  for (const change of ["disconnect", "turn", "branch", "session"]) {
    let finish;
    let signal;
    const h = await harness({ complete: async (_model, _request, options) => {
      signal = options.signal;
      return new Promise(resolve => { finish = resolve; });
    } });
    try {
      const pending = h.refreshTitle();
      if (change === "disconnect") h.socket.destroy();
      if (change === "turn") await h.emit("agent_start");
      if (change === "branch") { h.setLeaf("new-leaf"); await h.emit("session_tree"); }
      if (change === "session") h.setSessionId("different-session");
      if (change !== "session") assert.equal(signal.aborted, true, change);
      finish(taskReply("过期标题"));
      await pending;
      assert.equal(h.responses.at(-1).ok, false, change);
      assert.equal(h.readDescriptor().taskSummary, undefined, change);
    } finally { await h.dispose(); }
  }
});

test("live labels publish without blocking settled status and deduplicate repeated notifications", async () => {
  let finish;
  let calls = 0;
  const h = await harness({ complete: async () => { calls += 1; return new Promise(resolve => { finish = resolve; }); } });
  try {
    assert.equal(h.readDescriptor().taskSummary, undefined);
    await settleTask(h);
    assert.equal(calls, 1);
    assert.equal(h.reports.at(-1).status, "finished", "Status must not wait for the model");
    await h.emit("agent_settled");
    assert.equal(calls, 1);
    finish(taskReply("修复分页逻辑"));
    await flushSummary();
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    assert.equal(h.shutdowns, 0);
    assert.equal(h.snapshots.length, 0, "Generating a task label must not archive the session");
  } finally { await h.dispose(); }
});

test("Ghostty publishes the label with TTY identity, ignoring inherited iTerm IDs", async () => {
  const h = await harness({ termProgram: "ghostty", complete: async () => taskReply("修复分页逻辑") });
  try {
    await settleTask(h);
    const live = h.readDescriptor();
    assert.equal(live.taskSummary, "修复分页逻辑");
    assert.equal(live.terminal, "Ghostty");
    assert.equal(live.terminalSessionId, null);
    assert.equal(live.tty, "/dev/ttys-isolated");
  } finally { await h.dispose(); }
});

test("next generation preserves the previous label while pending and on failure", async () => {
  let reject;
  let calls = 0;
  const h = await harness({ complete: async () => ++calls === 1 ? taskReply("修复分页逻辑")
    : new Promise((_resolve, fail) => { reject = fail; }) });
  try {
    await settleTask(h);
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    h.setMessages([{ role: "user", content: "现在增加任务标题" }]);
    await settleTask(h);
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    reject(new Error("Provider unavailable"));
    await flushSummary();
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    assert.equal(h.reports.at(-1).status, "finished");
  } finally { await h.dispose(); }
});

test("late model results cannot cross turns, branches, sessions, or shutdown", async () => {
  for (const change of ["turn", "tree", "session", "shutdown", "leaf"]) {
    let finish;
    let signal;
    const h = await harness({ complete: async (_model, _request, options) => {
      signal = options.signal;
      return new Promise(resolve => { finish = resolve; });
    } });
    try {
      await settleTask(h);
      if (change === "turn") await h.emit("agent_start");
      if (change === "tree") { h.setLeaf("different-branch"); await h.emit("session_tree"); }
      if (change === "session") { h.setSessionId("different-session"); await h.emit("session_start"); }
      if (change === "shutdown") await h.emit("session_shutdown");
      if (change === "leaf") h.setLeaf("different-leaf");
      if (change !== "leaf") assert.equal(signal.aborted, true, change);
      finish(taskReply("过期的任务标题"));
      await flushSummary();
      assert.equal(h.readDescriptor()?.taskSummary, undefined, change);
    } finally { await h.dispose(); }
  }
});

test("an older result cannot overwrite a newer successful task label", async () => {
  const pending = [];
  const h = await harness({ complete: async () => new Promise(resolve => pending.push(resolve)) });
  try {
    await settleTask(h);
    h.setMessages([{ role: "user", content: "添加会话摘要" }]);
    await settleTask(h);
    assert.equal(pending.length, 2);
    pending[1](taskReply("添加会话摘要"));
    await flushSummary();
    pending[0](taskReply("过期任务"));
    await flushSummary();
    assert.equal(h.readDescriptor().taskSummary, "添加会话摘要");
  } finally { await h.dispose(); }
});

test("projection failures cannot suppress normal settled status", async () => {
  let calls = 0;
  const h = await harness({ complete: async () => { calls += 1; return taskReply("不应调用"); } });
  try {
    h.setMessages(undefined);
    await settleTask(h);
    assert.equal(h.reports.at(-1).status, "finished");
    assert.equal(h.readDescriptor().taskSummary, undefined);
    assert.equal(calls, 0);
  } finally { await h.dispose(); }
});

test("navigation clears a previously published label, while a new turn keeps it", async () => {
  const h = await harness({ complete: async () => taskReply("修复分页逻辑") });
  try {
    await settleTask(h);
    await h.emit("agent_start");
    assert.equal(h.readDescriptor().taskSummary, "修复分页逻辑");
    h.setLeaf("different-branch");
    await h.emit("session_tree");
    assert.equal(h.readDescriptor().taskSummary, undefined);
  } finally { await h.dispose(); }
});

test("background modes and failed or empty replies do not spend a summary call", async () => {
  let calls = 0;
  for (const mode of ["tui", "print", "rpc"]) {
    const h = await harness({ mode, complete: async () => { calls += 1; return taskReply("不应调用"); } });
    try {
      await h.emit("agent_start");
      await h.emit("agent_end", { messages: [{ ...assistantReply, stopReason: "error" }] });
      await h.emit("agent_settled");
      await h.emit("agent_start");
      await h.emit("agent_end", { messages: [] });
      await h.emit("agent_settled");
      if (mode !== "tui") await settleTask(h);
      await flushSummary();
      assert.equal(calls, 0);
    } finally { await h.dispose(); }
  }
});

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

for (const state of ["idle", "running", "awaitingInput", "finished"]) {
  test(`readonly status returns ${state} without publishing, invoking a model, or closing Pi`, async () => {
    let modelCalls = 0;
    const h = await harness({ complete: async () => { modelCalls += 1; throw new Error("Unexpected model call"); } });
    try {
      assert.equal(h.descriptor.supportsStatus, true);
      if (state === "running") h.setBusy(true);
      if (state === "awaitingInput") await h.emit("ui_prompt_start", { kind: "confirm" });
      if (state === "finished") {
        await h.emit("agent_start");
        await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text: "Done." }] }] });
        await h.emit("agent_settled");
      }
      const sent = h.reports.length;
      const callsBeforeQuery = modelCalls;
      await h.queryStatus();
      const response = h.responses[0];
      assert.equal(response.ok, true);
      assert.equal(response.status, state);
      assert.equal(response.instanceId, h.descriptor.id);
      assert.equal(response.sessionId, h.descriptor.sessionId);
      assert.equal(response.reporterId, h.reports.at(-1).reporterId);
      assert.ok(response.sequence > h.reports.at(-1).sequence);
      assert.equal(h.reports.length, sent);
      assert.equal(modelCalls, callsBeforeQuery);
      assert.equal(h.shutdowns, 0);
      assert.equal(h.inputBlocked, false);
      assert.equal(h.snapshots.length, 0);
      await h.emit("agent_start");
      assert.ok(h.reports.at(-1).sequence > response.sequence);
    } finally { await h.dispose(); }
  });
}

test("readonly status rejects invalid token and stale session identity", async () => {
  for (const overrides of [{ token: "wrong" }, { sessionId: "old-session" }]) {
    const h = await harness();
    try {
      await h.queryStatus(overrides);
      assert.equal(h.responses[0].ok, false);
      assert.equal(h.shutdowns, 0);
      assert.equal(h.inputBlocked, false);
    } finally { await h.dispose(); }
  }
});

test("readonly status refuses an identity change during the asynchronous observation", async () => {
  const h = await harness();
  try {
    const query = h.queryStatus();
    h.setSessionId("new-session");
    await query;
    assert.equal(h.responses[0].ok, false);
    assert.equal(h.shutdowns, 0);
  } finally { await h.dispose(); }
});

test("readonly status keeps unknown fleet unknown rather than reporting idle", async () => {
  const h = await harness({ hasSubagentTool: true, fleetAvailable: false });
  try {
    await h.queryStatus();
    assert.equal(h.responses[0].ok, true);
    assert.equal(h.responses[0].status, null);
    assert.equal(h.responses[0].hasRunningSubagents, false);
  } finally { await h.dispose(); }
});

test("readonly status includes confirmed child activity after the parent settles", async () => {
  const h = await harness({ hasSubagentTool: true, fleetCount: 2 });
  try {
    await h.queryStatus();
    assert.equal(h.responses[0].status, "running");
    assert.equal(h.responses[0].hasRunningSubagents, true);
  } finally { await h.dispose(); }
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
