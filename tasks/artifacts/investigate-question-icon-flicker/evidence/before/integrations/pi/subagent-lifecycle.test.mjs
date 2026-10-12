// Run with Node 22.13+: node --experimental-vm-modules --test integrations/pi/subagent-lifecycle.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";
import { readFile } from "node:fs/promises";
import { stripTypeScriptTypes } from "node:module";
import { EventEmitter } from "node:events";
import { createHash, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import { join } from "node:path";
import { SourceTextModule, SyntheticModule, createContext } from "node:vm";

const source = stripTypeScriptTypes(await readFile(
  new URL("./iTermate-integration.ts", import.meta.url), "utf8",
));

async function harness({ count = 2, terminal = "iTerm.app", mode = "tui", model } = {}) {
  let modelEnabled = model !== undefined;
  let modelProvider = "laya";
  let modelEpoch = 0;
  const configuration = () => JSON.stringify({ provider: modelProvider, revision: `epoch-${modelEpoch}`, analysisEnabled: modelEnabled, serviceEnabled: true });
  const modelRequests = [];
  let now = 10000;
  let timerID = 0;
  let idle = true;
  const timers = new Map();
  const handlers = new Map();
  const events = new EventEmitter();
  const reports = [];
  const queries = [];
  const responses = [];
  let defaultResponse = { count };
  const flush = async () => {
    for (let index = 0; index < 30; index += 1) await Promise.resolve();
  };
  const setTimeout = (callback, delay = 0) => {
    const id = ++timerID;
    timers.set(id, { at: now + delay, callback });
    return id;
  };
  const clearTimeout = (id) => timers.delete(id);
  async function advance(milliseconds) {
    const target = now + milliseconds;
    await flush();
    for (;;) {
      const next = [...timers].sort((a, b) => a[1].at - b[1].at || a[0] - b[0])
        .find(([, timer]) => timer.at <= target);
      if (!next) break;
      now = Math.max(now, next[1].at);
      timers.delete(next[0]);
      next[1].callback();
      await flush();
    }
    now = target;
    await flush();
  }
  const context = createContext({
    process: { pid: 123, env: { TERM_PROGRAM: terminal, ITERM_SESSION_ID: "w0:session-1" } },
    performance: { now: () => now }, setTimeout, clearTimeout, clearInterval: clearTimeout, Buffer, URL,
  });
  const unavailable = () => { throw new Error("Archive I/O is unavailable in lifecycle tests"); };
  const mocks = {
    "node:crypto": { createHash, randomBytes, randomUUID, timingSafeEqual },
    "node:fs/promises": {
      readFile: async (path) => {
        if (path.endsWith("configuration.json")) return configuration();
        assert.ok(modelEnabled);
        if (path.endsWith("analysis-enabled")) return `epoch-${modelEpoch}`;
        if (path.endsWith("endpoint.json")) return JSON.stringify({ url: "http://127.0.0.1:1234", provider: modelProvider, instance: `worker-${modelEpoch}` });
        assert.ok(path.endsWith("api-token"));
        return "isolated-token";
      },
    },
    "node:fs": {
      ...Object.fromEntries([
        "chmodSync", "closeSync", "fsyncSync", "mkdirSync", "mkdtempSync",
        "openSync", "renameSync", "writeFileSync",
      ].map((name) => [name, unavailable])),
      readFileSync: (path) => path.endsWith("configuration.json") ? configuration() : unavailable(),
      rmSync: () => {},
      existsSync: () => modelEnabled,
    },
    "node:http": { request: (options, receive) => {
      assert.equal(options.path, "/v1/question");
      assert.ok(modelEnabled, "Unexpected model request");
      const provider = modelProvider;
      const instance = `worker-${modelEpoch}`;
      const request = new EventEmitter();
      let destroyed = false;
      request.destroy = () => { destroyed = true; };
      request.end = (body) => {
        modelRequests.push(JSON.parse(body));
        queueMicrotask(() => {
          if (destroyed) return;
          const response = new EventEmitter();
          response.statusCode = model.statusCode ?? 200;
          receive(response);
          model.onResponse?.();
          response.emit("data", JSON.stringify({ answers: model.answers, provider, instance }));
          response.emit("end");
        });
      };
      return request;
    } },
    "node:child_process": { execFileSync: () => "ttys001" },
    "node:net": {
      // Archive startup reaches the intentional mkdirSync failure above;
      // no real listener or filesystem operation is used by this harness.
      createServer: () => Object.assign(new EventEmitter(), { close: () => {} }),
      connect: (path, connected) => {
        const socket = new EventEmitter();
        socket.setTimeout = () => socket;
        socket.destroy = () => {};
        socket.write = (line) => {
          const request = JSON.parse(line);
          reports.push({ at: now, path, ...request });
          queueMicrotask(() => socket.emit("data", Buffer.from(JSON.stringify({
            type: "actionResult", requestId: request.requestId, ok: true,
          }) + "\n")));
        };
        queueMicrotask(connected);
        return socket;
      },
    },
    "node:os": { homedir: () => "/isolated-home" },
    "node:path": { join },
  };
  const module = new SourceTextModule(source, { context });
  await module.link((specifier) => {
    assert.ok(mocks[specifier], `Unexpected import: ${specifier}`);
    const values = mocks[specifier];
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate();
  module.namespace.default({
    on: (name, handler) => handlers.set(name, handler),
    events: {
      on: (name, handler) => {
        events.on(name, handler);
        return () => events.off(name, handler);
      },
      emit: (name, request) => {
        assert.equal(name, "subagents:rpc:v1:request");
        assert.equal(request.method, "status");
        queries.push({ at: now, request });
        const response = responses.shift() ?? defaultResponse;
        if (response.drop) return;
        const reply = () => events.emit(`subagents:rpc:v1:reply:${request.requestId}`, {
          version: 1, requestId: request.requestId, success: response.success ?? true,
          data: { fleet: { version: response.version ?? 1, totalActive: response.count } },
        });
        if (response.delay) setTimeout(reply, response.delay);
        else queueMicrotask(reply);
      },
    },
  });
  const ctx = { mode, isIdle: () => idle };
  async function emit(name, event = {}) {
    if (name === "agent_start") idle = false;
    if (name === "agent_settled") idle = true;
    await handlers.get(name)?.(event, ctx);
    await flush();
  }
  return {
    reports, queries, responses, modelRequests, advance, emit,
    setModelEnabled: (enabled) => { modelEnabled = enabled; modelEpoch += 1; },
    setProvider: (provider) => { modelProvider = provider; modelEpoch += 1; },
    elapseWithoutCallbacks: (milliseconds) => { now += milliseconds; },
    setResponse: (response) => { defaultResponse = response; },
    get now() { return now; },
    get replyListeners() { return events.eventNames().length; },
    get pendingTimers() { return timers.size; },
  };
}

async function settledHarness(options) {
  const h = await harness(options);
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  await h.emit("agent_end", {
    messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text: "Work complete." }] }],
  });
  await h.emit("agent_settled");
  return h;
}

test("active children keep a settled parent running; only zero completes", async () => {
  const h = await settledHarness();
  assert.equal(h.reports.at(-1).status, "running");
  assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  h.setResponse({ count: 1 });
  await h.advance(2000);
  assert.equal(h.reports.at(-1).status, "running");
  h.setResponse({ count: 0 });
  await h.advance(2000);
  assert.equal(h.reports.at(-1).status, "finished");
  assert.equal(h.reports.at(-1).hasRunningSubagents, false);
  assert.equal(h.reports.filter((report) => report.status === "finished").length, 1);
  await h.emit("session_shutdown");
  assert.equal(h.replyListeners, 0);
  assert.equal(h.pendingTimers, 0);
});

test("TR-1: RPC spanning expiry restarts the paused heartbeat with unchanged positive count", async () => {
  const h = await settledHarness();
  // Last confirmation: 10s. Shift heartbeat cadence to 12.1/14.1/16.1s.
  await h.advance(100);
  await h.emit("ui_prompt_start", { kind: "confirm" });
  await h.emit("ui_prompt_end");
  h.setResponse({ drop: true });
  await h.advance(4700); // Poll at 12s times out at 13s; next poll is due at 15s.
  h.responses.push({ count: 2, delay: 900 });
  // A busy event loop delays that poll until 15.8s (confirmation age 5.8s).
  h.elapseWithoutCallbacks(1000);
  await h.advance(0);
  assert.equal(h.queries.at(-1).at, 15800);
  await h.advance(300); // 16.1s: heartbeat pauses while the RPC is pending.
  assert.equal(h.reports.at(-1).at, 14100);
  await h.advance(600); // 16.7s: unchanged positive reply must fully republish.
  assert.equal(h.reports.at(-1).at, 16700);
  assert.equal(h.reports.at(-1).heartbeat, false);
  h.setResponse({ count: 2 });
  const recoveredAt = h.now;
  await h.advance(12000);
  const heartbeats = h.reports.filter((report) => report.at > recoveredAt && report.heartbeat);
  assert.ok(heartbeats.length >= 4, JSON.stringify(h.reports));
  assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  assert.ok(h.now - h.reports.at(-1).at <= 2000);
  await h.emit("session_shutdown");
});

test("unavailable fleet expires child-only reporting without false completion, then recovers", async () => {
  const h = await settledHarness();
  h.setResponse({ drop: true });
  await h.advance(16000);
  const pausedReports = h.reports.length;
  assert.ok(h.now - h.reports.at(-1).at > 8000);
  assert.equal(h.reports.some((report) => report.status === "finished"), false);
  h.setResponse({ count: 2 });
  await h.advance(6000);
  assert.ok(h.reports.length > pausedReports);
  assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  await h.emit("session_shutdown");
});

test("explicit questions retain awaitingInput alongside child activity", async () => {
  const h = await settledHarness();
  await h.emit("ui_prompt_start", { kind: "confirm" });
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  h.setResponse({ count: 0 });
  await h.advance(2000);
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  assert.equal(h.reports.at(-1).hasRunningSubagents, false);
  await h.emit("ui_prompt_end");
  assert.equal(h.reports.at(-1).status, "finished");
  await h.emit("session_shutdown");
});

for (const terminal of ["iTerm.app", "ghostty"]) {
  test(`${terminal}: a positive participation decision retains implicit confirmation`, async () => {
    const h = await harness({ count: 0, terminal, model: { answers: {
      question: { type: "choice", choice: "question", probabilities: { normal: 0.01, question: 0.99 } },
    } } });
    await h.emit("session_start");
    await h.advance(0);
    await h.emit("agent_start");
    await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
      content: [{ type: "text", text: "确认后我写入并校验。" }] }] });
    await h.emit("agent_settled");
    assert.equal(h.modelRequests.length, 1);
    assert.equal(h.reports.at(-1).status, "awaitingInput");
    await h.advance(10000);
    assert.equal(h.reports.at(-1).status, "awaitingInput");
    assert.equal(h.reports.at(-1).heartbeat, true);
    await h.emit("agent_start");
    assert.equal(h.reports.at(-1).status, "running");
    await h.emit("session_shutdown");
  });

  test(`${terminal}: model-only question remains pending when analysis is disabled`, async () => {
    const h = await harness({ count: 0, terminal, model: { answers: {
      question: { type: "choice", choice: "question", probabilities: { normal: 0.01, question: 0.99 } },
    } } });
    await h.emit("session_start");
    await h.advance(0);
    await h.emit("agent_start");
    await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
      content: [{ type: "text", text: "Continue?" }] }] });
    await h.emit("agent_settled");
    assert.equal(h.modelRequests.length, 1);
    assert.equal(h.reports.at(-1).status, "awaitingInput");
    h.setModelEnabled(false);
    await h.advance(10000);
    assert.equal(h.reports.at(-1).status, "awaitingInput");
    assert.equal(h.reports.at(-1).heartbeat, true);
    assert.equal(h.modelRequests.length, 1);
    await h.emit("agent_start");
    await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
      content: [{ type: "text", text: "Work complete." }] }] });
    await h.emit("agent_settled");
    assert.equal(h.reports.at(-1).status, "finished");
    await h.emit("session_shutdown");
  });
}

test("negated requests and completed confirmation narratives do not retain a question", async () => {
  const h = await harness({ count: 0, model: { answers: {
    question: { type: "choice", choice: "normal", probabilities: { normal: 0.99, question: 0.01 } },
  } } });
  await h.emit("session_start");
  await h.advance(0);
  const completedReplies = [
    "请勿回复。", "确认后我已经提交。", "确认后我保存好了文件。",
    "确认后我开始了测试。", "确认后我提交成功，测试通过。",
  ];
  for (const text of completedReplies) {
    await h.emit("agent_start");
    await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
      content: [{ type: "text", text }] }] });
    await h.emit("agent_settled");
    assert.equal(h.reports.at(-1).status, "finished", text);
    await h.advance(10000);
    assert.equal(h.reports.at(-1).status, "finished", text);
  }
  assert.equal(h.modelRequests.length, completedReplies.length);
  assert.equal(h.reports.some((report) => report.status === "awaitingInput"), false);
  await h.emit("session_shutdown");
});

test("unavailable selected model keeps lifecycle completion without heuristic fallback", async () => {
  const h = await harness({ count: 0, model: { statusCode: 429 } });
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
    content: [{ type: "text", text: "Which option do you prefer?" }] }] });
  await h.emit("agent_settled");
  assert.equal(h.modelRequests.length, 1);
  assert.equal(h.reports.at(-1).status, "finished");
  await h.emit("session_shutdown");
});

test("a negated old request cannot cancel the new closing question", async () => {
  const h = await harness({ count: 0 });
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
    content: [{ type: "text", text: "请勿回复旧问题。按这个范围实现，可以吗？" }] }] });
  await h.emit("agent_settled");
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  await h.advance(10000);
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  assert.equal(h.reports.at(-1).heartbeat, true);
  await h.emit("session_shutdown");
});

test("a future confirmation remains leased with model analysis disabled", async () => {
  const h = await harness({ count: 0 });
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop",
    content: [{ type: "text", text: "确认后我会继续执行，直到测试通过。" }] }] });
  await h.emit("agent_settled");
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  await h.advance(10000);
  assert.equal(h.reports.at(-1).status, "awaitingInput");
  assert.equal(h.reports.at(-1).heartbeat, true);
  assert.equal(h.modelRequests.length, 0);
  await h.emit("session_shutdown");
});

test("Ghostty uses TTY and ignores inherited iTerm session identity", async () => {
  const h = await settledHarness({ terminal: "ghostty" });
  const report = h.reports.at(-1);
  assert.equal(report.type, "setTerminalStatus");
  assert.equal(report.tty, "/dev/ttys001");
  assert.equal(report.sessionId, undefined);
  assert.equal(report.hasRunningSubagents, true);
  await h.emit("session_shutdown");
});

test("shutdown cancels in-flight observation and prevents stale replies from publishing", async () => {
  const h = await settledHarness();
  h.setResponse({ count: 2, delay: 500 });
  await h.advance(2000);
  assert.equal(h.replyListeners, 1);
  await h.emit("session_shutdown");
  const reports = h.reports.length;
  assert.equal(h.reports.at(-1).status, "detached");
  assert.equal(h.replyListeners, 0);
  await h.advance(10000);
  assert.equal(h.reports.length, reports);
  assert.equal(h.pendingTimers, 0);
});

test("session startup restores active child work without replaying conversation history", async () => {
  const h = await harness();
  await h.emit("session_start");
  await h.advance(0);
  assert.equal(h.reports.at(-1).status, "running");
  assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  h.setResponse({ count: 0 });
  await h.advance(2000);
  assert.equal(h.reports.at(-1).status, "idle");
  assert.equal(h.reports.at(-1).hasRunningSubagents, false);
  await h.emit("session_shutdown");
});

test("malformed or failed observations cannot clear active children or fabricate success", async () => {
  const h = await settledHarness();
  for (const response of [
    { count: -1 }, { count: 0.5 }, { count: "0" },
    { count: 0, version: 2 }, { count: 0, success: false },
  ]) {
    h.responses.push(response);
    await h.emit("tool_execution_end", { toolName: "subagent" });
    assert.equal(h.reports.at(-1).status, "running");
    assert.equal(h.reports.at(-1).hasRunningSubagents, true);
  }
  await h.emit("session_shutdown");
});

test("known parent activity remains leased when only the child observation becomes unavailable", async () => {
  const h = await settledHarness();
  await h.emit("agent_start");
  h.setResponse({ drop: true });
  await h.advance(16000);
  assert.equal(h.reports.at(-1).status, "running");
  assert.equal(h.reports.at(-1).hasRunningSubagents, false);
  assert.ok(h.now - h.reports.at(-1).at <= 2000);
  await h.emit("session_shutdown");
});

for (const provider of ["laya", "vela"]) {
  test(`${provider}: selected question model is used and full text is preserved`, async () => {
    const h = await harness({ count: 0, model: { answers: {
      question: { type: "choice", choice: "question", probabilities: { normal: 0.2, question: 0.8 } },
    } } });
    h.setProvider(provider);
    await h.emit("session_start");
    await h.advance(0);
    await h.emit("agent_start");
    const text = "Context. ".repeat(180) + "May I proceed?";
    await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text }] }] });
    await h.emit("agent_settled");
    assert.equal(h.modelRequests[0].state, text);
    assert.equal(h.reports.at(-1).status, "awaitingInput");
    await h.emit("session_shutdown");
  });
}

for (const provider of ["laya", "vela"]) {
  test(`${provider}: confirmation, choice and missing information keep user participation pending`, async () => {
    const h = await harness({ count: 0, model: { answers: {
      question: { type: "choice", choice: "question", probabilities: { normal: 0.1, question: 0.9 } },
    } } });
    h.setProvider(provider);
    await h.emit("session_start");
    await h.advance(0);
    for (const text of ["请确认范围。", "确认后我再继续。", "请选择方案 A 或 B。", "请提供项目路径。", "已完成，还需要更新示例吗？"]) {
      await h.emit("agent_start");
      await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text }] }] });
      await h.emit("agent_settled");
      assert.equal(h.reports.at(-1).status, "awaitingInput", text);
    }
    await h.emit("session_shutdown");
  });
}

test("provider changes reject the old worker's late positive response", async () => {
  const model = { answers: { question: { type: "choice", choice: "question", probabilities: { normal: 0.1, question: 0.9 } } } };
  const h = await harness({ count: 0, model });
  model.onResponse = () => h.setProvider("vela");
  await h.emit("session_start");
  await h.advance(0);
  await h.emit("agent_start");
  await h.emit("agent_end", { messages: [{ role: "assistant", stopReason: "stop", content: [{ type: "text", text: "May I proceed?" }] }] });
  await h.emit("agent_settled");
  assert.equal(h.modelRequests.length, 1);
  assert.equal(h.reports.at(-1).status, "finished");
  await h.emit("session_shutdown");
});

test("non-TUI child runtimes do not query or report parent terminal activity", async () => {
  const h = await harness({ mode: "json" });
  await h.emit("session_start");
  await h.emit("agent_start");
  await h.advance(10000);
  assert.equal(h.queries.length, 0);
  assert.equal(h.reports.length, 0);
  await h.emit("session_shutdown");
});
