import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { summarizeArchive } from "./iTermate-integration";

function context(messages: unknown[], complete: (...args: any[]) => Promise<unknown>) {
  return {
    model: { id: "isolated-model" },
    sessionManager: { buildSessionProjection: () => ({ messages }) },
    modelRegistry: { complete },
  } as unknown as ExtensionContext;
}

const reply = { stopReason: "stop", content: [{ type: "text", text: "修复分页解析，待运行验证。" }] };

test("summary uses the active projection's visible text and the current Pi model without tools", async () => {
  let called = false;
  const ctx = context([
    { role: "system", content: "private system instructions" },
    { role: "compactionSummary", summary: "此前决定整批失败。" },
    { role: "user", content: "修复分页解析。" },
    { role: "assistant", content: [{ type: "thinking", thinking: "private reasoning" }, { type: "text", text: "已修改，尚未验证。" }] },
    { role: "toolResult", content: [{ type: "text", text: "raw tool output" }] },
  ], async (model, request, options) => {
    called = true;
    assert.equal(model, ctx.model);
    assert.equal(request.tools, undefined);
    const text = request.messages[0].content;
    assert.match(text, /此前决定整批失败/);
    assert.match(text, /修复分页解析/);
    assert.doesNotMatch(text, /private|raw tool output/);
    assert.equal(options.cacheRetention, "none");
    assert.ok(options.signal instanceof AbortSignal);
    return reply;
  });
  assert.equal(await summarizeArchive(ctx, new AbortController().signal), reply.content[0].text);
  assert.equal(called, true);
});

test("summary input preserves the beginning and ending of a bounded excerpt", async () => {
  const ctx = context([{ role: "user", content: "BEGIN" + "x".repeat(30000) + "END" }], async (_model, request) => {
    const text = request.messages[0].content;
    assert.match(text, /^\[user\]\nBEGIN/);
    assert.match(text, /END$/);
    assert.match(text, /中间内容已省略/);
    assert.ok(text.length < 16100);
    return reply;
  });
  await summarizeArchive(ctx, new AbortController().signal);
});

test("empty, incomplete, failed, and oversized summaries fail instead of authorizing closure", async () => {
  for (const result of [
    { stopReason: "error", content: [] },
    { stopReason: "length", content: reply.content },
    { stopReason: "stop", content: [{ type: "text", text: " " }] },
    { stopReason: "stop", content: [{ type: "text", text: "x".repeat(1201) }] },
  ]) {
    const ctx = context([{ role: "user", content: "Archive this work" }], async () => result);
    await assert.rejects(summarizeArchive(ctx, new AbortController().signal));
  }
});

test("cancellation rejects even when the provider does not settle", async () => {
  const controller = new AbortController();
  const ctx = context([{ role: "user", content: "Archive this work" }], async () => {
    queueMicrotask(() => controller.abort());
    return new Promise(() => {});
  });
  await assert.rejects(summarizeArchive(ctx, controller.signal));
});

test("the summary deadline bounds a provider that never settles", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const ctx = context([{ role: "user", content: "Archive this work" }], async () => new Promise(() => {}));
  const rejected = assert.rejects(summarizeArchive(ctx, new AbortController().signal));
  t.mock.timers.tick(60000);
  await rejected;
});

test("a cancelled request never starts a model call", async () => {
  const controller = new AbortController();
  controller.abort();
  let modelCalls = 0;
  const ctx = context([{ role: "user", content: "Archive this work" }], async () => {
    modelCalls += 1;
    return reply;
  });
  await assert.rejects(summarizeArchive(ctx, controller.signal));
  assert.equal(modelCalls, 0);
});
