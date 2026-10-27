// Node 22.13+: node --experimental-vm-modules --test integrations/pi/local-llm-selection.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";
import * as fs from "node:fs";
import * as crypto from "node:crypto";
import { EventEmitter } from "node:events";
import { stripTypeScriptTypes } from "node:module";
import { join } from "node:path";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";

const source = stripTypeScriptTypes(fs.readFileSync(new URL("./iTermate-integration.ts", import.meta.url), "utf8"), { mode: "transform" });
const twoB = { name: "qwen3.5:2b", digest: "dfaf2605162e689c8cac330dc4a190c4c50ad30aa47814a8fe9b79fa5127e97e" };
const fourB = { name: "qwen3.5:4b", digest: "a".repeat(64) };
const selection = (model, revision = "11111111-1111-1111-1111-111111111111") => JSON.stringify({ model, revision });
const replyCases = JSON.parse(fs.readFileSync(new URL("./reply-classification-cases.json", import.meta.url), "utf8"));

// All HTTP and filesystem operations are isolated mocks; no model or preference is changed.
async function harness({ configuration = selection("qwen3.5:4b"), inventory = [twoB, fourB],
  questionReply = '{"label":"question"}', titleReplies = [], onChat } = {}) {
  const requests = [];
  let titleReplyIndex = 0;
  const unavailable = () => { throw new Error("Unexpected side effect"); };
  const context = createContext({
    Buffer, URL, AbortController, setTimeout, clearTimeout,
    process: { pid: 123, env: {} }, performance: { now: () => 0 },
  });
  const mocks = {
    "node:crypto": { createHash: crypto.createHash, randomBytes: crypto.randomBytes,
      randomUUID: crypto.randomUUID, timingSafeEqual: crypto.timingSafeEqual },
    "node:fs/promises": { readFile: unavailable },
    "node:fs": {
      ...Object.fromEntries(["appendFileSync", "chmodSync", "closeSync", "existsSync", "fsyncSync", "mkdirSync",
        "mkdtempSync", "openSync", "readdirSync", "renameSync", "rmSync", "statSync", "writeFileSync"].map(name => [name, unavailable])),
      readFileSync: path => {
        assert.ok(path.endsWith("/LocalLLM/configuration.json"));
        if (configuration === null) throw Object.assign(new Error("Missing selection"), { code: "ENOENT" });
        return configuration;
      },
    },
    "node:child_process": { execFileSync: () => "" },
    "node:net": { connect: unavailable, createServer: unavailable },
    "node:os": { homedir: () => "/isolated" },
    "node:path": { join },
    "node:http": { request: (options, receive) => {
      assert.equal(options.hostname, "127.0.0.1");
      assert.equal(options.port, 11434);
      assert.equal(options.agent, false);
      assert.equal(options.headers.Authorization, undefined);
      const request = new EventEmitter();
      let destroyed = false;
      request.destroy = () => { destroyed = true; };
      request.end = encoded => {
        const body = encoded === undefined ? undefined : JSON.parse(encoded);
        requests.push({ options, body });
        queueMicrotask(() => {
          if (destroyed) return;
          const response = new EventEmitter();
          response.statusCode = 200;
          receive(response);
          let payload;
          if (options.path === "/api/tags") {
            payload = { models: inventory };
          } else {
            assert.equal(options.path, "/api/chat");
            const isQuestion = body.messages[0].content.startsWith("Classify");
            const titleReply = isQuestion ? undefined : titleReplies[titleReplyIndex++];
            payload = { model: body.model, done: true, done_reason: titleReply?.reason ?? "stop", message: {
              content: isQuestion ? questionReply : titleReply?.content ?? "修复分页",
            } };
            onChat?.();
          }
          response.emit("data", Buffer.from(JSON.stringify(payload)));
          response.emit("end");
        });
      };
      return request;
    } },
  };
  const module = new SourceTextModule(source, { context });
  await module.link(name => {
    const values = mocks[name];
    assert.ok(values, name);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate();
  return { api: module.namespace, requests,
    setConfiguration: value => { configuration = value; },
    setInventory: value => { inventory = value; } };
}

const title = h => h.api.summarizeTask({}, "[user]\n修复分页", new AbortController().signal);

test("a length-limited first title is only a refinement draft", async () => {
  const h = await harness({ titleReplies: [
    { content: "修复分页", reason: "length" }, { content: "重新概括分页", reason: "stop" },
  ] });
  assert.equal(await title(h), "重新概括分页");
  const chats = h.requests.filter(row => row.options.path === "/api/chat");
  assert.equal(chats.length, 2);
  assert.match(chats[1].body.messages[1].content, /修复分页/);
});

test("a length-limited second title fails without another inference", async () => {
  const h = await harness({ titleReplies: [
    { content: "多行\n草稿", reason: "stop" }, { content: "截断结果", reason: "length" },
  ] });
  await assert.rejects(title(h));
  assert.equal(h.requests.filter(row => row.options.path === "/api/chat").length, 2);
});

test("saved 4B choice drives both question and title requests with ten-minute residency", async () => {
  const h = await harness();
  assert.equal(await h.api.classifyReplyWithModel("请确认后我再继续"), true);
  assert.equal(await title(h), "修复分页");
  const chats = h.requests.filter(row => row.options.path === "/api/chat");
  assert.equal(chats.length, 2);
  for (const row of chats) {
    assert.equal(row.body.model, "qwen3.5:4b");
    assert.equal(row.body.keep_alive, "10m");
    assert.equal(row.body.think, false);
  }
});

test("reply classification sends action-instruction counterexamples separately from the reply", async () => {
  const text = "修复已完成，请退出旧版本并打开新版本验证。";
  const h = await harness({ questionReply: '{"label":"normal"}' });
  assert.equal(await h.api.classifyReplyWithModel(text), false);
  const { body } = h.requests.find(row => row.options.path === "/api/chat");
  assert.equal(body.messages.length, 2);
  assert.equal(body.messages[0].role, "system");
  const prompt = body.messages[0].content;
  assert.match(prompt, /currently waiting for a user response/);
  assert.match(prompt, /我没有替你重启/);
  assert.match(prompt, /仍需这一步验证。\n-> \{"label":"normal"\}/);
  assert.match(prompt, /是否允许我现在重启？\n-> \{"label":"question"\}/);
  assert.match(prompt, /你希望保留原来的交互，还是改成单击展开？\n-> \{"label":"question"\}/);
  assert.match(prompt, /请提供当前版本号和错误日志，我才能继续定位。\n-> \{"label":"question"\}/);
  assert.match(prompt, /Please restart the app to load it and verify the behavior\.\n-> \{"label":"normal"\}/);
  assert.match(prompt, /我会继续检查其他调用方，完成后汇报。\n-> \{"label":"normal"\}/);
  assert.equal(body.messages[1].role, "user");
  assert.equal(body.messages[1].content, text);
  assert.equal(body.options.temperature, 0);
  assert.equal(body.options.num_predict, 32);
});

test("structured Task Target confirmation is sent as reply data with explicit prompt guidance", async () => {
  const text = "Task Target\n\n - 目标：分别提交并推送 iOS、Android 本次 API-only 完读修复的全部相关改动。\n - 完成条件：两端提交均推送至各自当前分支对应的远程分支，并核实远程包含这些提交。\n - 边界：不包含无关改动，不强制推送，不运行测试。\n\n 请确认，之后我会核对差异、提交并推送。";
  const h = await harness();
  assert.equal(await h.api.classifyReplyWithModel(text), true);
  const chats = h.requests.filter(row => row.options.path === "/api/chat");
  assert.equal(chats.length, 1);
  const messages = chats[0].body.messages;
  assert.equal(messages.length, 2);
  assert.equal(messages[1].role, "user");
  assert.equal(messages[1].content, text);
  const prompt = messages[0].content;
  assert.equal(messages[0].role, "system");
  assert.match(prompt, /Task Target.*proposed future work/);
  assert.ok(prompt.includes(`${text}\n-> {"label":"question"}`));
  assert.match(prompt, /不需要你确认或回复。\n-> \{"label":"normal"\}/);
  assert.match(prompt, /仅是格式示例，无需回复。\n-> \{"label":"normal"\}/);
});

test("local commit reports and explicit push approval reach the classifier with contrasting prompt examples", async () => {
  for (const id of ["local-commit-report", "english-local-commit-report", "commit-awaiting-push-approval"]) {
    const row = replyCases.find(row => row.id === id);
    assert.ok(row, id);
    const h = await harness({ questionReply: JSON.stringify({ label: row.expected }) });
    assert.equal(await h.api.classifyReplyWithModel(row.text), row.expected === "question");
    const { body } = h.requests.find(row => row.options.path === "/api/chat");
    assert.equal(body.messages[0].role, "system");
    assert.ok(body.messages[0].content.includes(`${row.text}\n-> ${JSON.stringify({ label: row.expected })}`));
    assert.match(body.messages[0].content, /Do not infer a confirmation gate merely because an action has not happened/);
    assert.equal(body.messages[1].role, "user");
    assert.equal(body.messages[1].content, row.text);
  }
});

// Mock responses check protocol handling and prompt coverage, not the model's semantic accuracy.
for (const [output, expected] of [
  ['{"label":"normal"}', false],
  ['{"label":"question"}', true],
  ['{"label":"other"}', undefined],
  ['{"label":"normal","confidence":1}', undefined],
  ['normal', undefined],
]) {
  test(`reply classification handles ${output} without another model request`, async () => {
    const h = await harness({ questionReply: output });
    assert.equal(await h.api.classifyReplyWithModel("请确认后我再继续"), expected);
    assert.equal(h.requests.filter(row => row.options.path === "/api/chat").length, 1);
  });
}

test("empty or oversized replies never invoke the classifier", async () => {
  const h = await harness();
  for (const text of ["", " \n", "字".repeat(20000)]) {
    assert.equal(await h.api.classifyReplyWithModel(text), undefined);
  }
  assert.equal(h.requests.length, 0);
});

test("replies over 3000 characters retain the complete question context", async () => {
  const h = await harness();
  const text = "Work completed. ".repeat(220) + "Please confirm before I continue.";
  assert.ok(text.length > 3000);
  assert.equal(await h.api.classifyReplyWithModel(text), true);
  const chat = h.requests.find(row => row.options.path === "/api/chat");
  assert.equal(chat.body.messages[1].content, text);
});

test("cancelling classification aborts the active request without a negative decision", async () => {
  const request = new AbortController();
  const h = await harness({ onChat: () => request.abort() });
  assert.equal(await h.api.classifyReplyWithModel("请确认后我再继续。", request.signal), undefined);
  assert.equal(h.requests.filter(row => row.options.path === "/api/tags").length, 1);
});

test("missing choice keeps 2B without writing preferences", async () => {
  const h = await harness({ configuration: null });
  assert.equal(await title(h), "修复分页");
  assert.equal(h.requests.find(row => row.body).body.model, "qwen3.5:2b");
});

test("unavailable 4B never falls back to installed 2B", async () => {
  const h = await harness({ inventory: [twoB] });
  await assert.rejects(title(h));
  assert.equal(await h.api.classifyReplyWithModel("请确认"), undefined);
  assert.equal(h.requests.filter(row => row.options.path === "/api/chat").length, 0);
});

test("malformed and unsupported saved choices do not use default 2B", async () => {
  for (const configuration of ["{", "{}", selection("other:4b"), selection("qwen3.5:4b", "invalid")]) {
    const h = await harness({ configuration });
    await assert.rejects(title(h));
    assert.equal(h.requests.length, 0);
  }
});

test("changed selection or configuration revision invalidates in-flight replies", async () => {
  for (const model of ["qwen3.5:2b", "qwen3.5:4b"]) {
    for (const kind of ["title", "question"]) {
      let h;
      h = await harness({ onChat: () => h.setConfiguration(selection(model, "22222222-2222-2222-2222-222222222222")) });
      if (kind === "title") await assert.rejects(title(h));
      else assert.equal(await h.api.classifyReplyWithModel("请确认"), undefined);
    }
  }
});

test("changed installed model digest invalidates an otherwise complete reply", async () => {
  let h;
  h = await harness({ onChat: () => h.setInventory([{ ...fourB, digest: "b".repeat(64) }]) });
  await assert.rejects(title(h));
});
