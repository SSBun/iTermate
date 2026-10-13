import assert from "node:assert/strict";
import { test } from "node:test";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { summarizeTask, taskSummaryExcerpt } from "./iTermate-integration";

function context(messages: unknown[], complete: (...args: any[]) => Promise<unknown>) {
  return {
    model: { id: "isolated-model" },
    sessionManager: { buildSessionProjection: () => ({ messages }) },
    modelRegistry: { complete },
  } as unknown as ExtensionContext;
}

const reply = { stopReason: "stop", content: [{ type: "text", text: "修复文章列表分页" }] };

test("task labels use current model and visible user/assistant text only", async () => {
  const ctx = context([
    { role: "system", content: "private system" },
    { role: "compactionSummary", summary: "private compaction" },
    { role: "user", content: [{ type: "text", text: "修复文章列表分页" }, { type: "image", data: "private image" }] },
    { role: "assistant", content: [{ type: "thinking", thinking: "private reasoning" }, { type: "toolCall", name: "private tool" }, { type: "text", text: "正在检查分页边界。" }] },
    { role: "toolResult", content: [{ type: "text", text: "private tool result" }] },
  ], async (model, request, options) => {
    assert.equal(model, ctx.model);
    assert.equal(request.tools, undefined);
    assert.match(request.messages[0].content, /修复文章列表分页/);
    assert.match(request.messages[0].content, /正在检查分页边界/);
    assert.doesNotMatch(request.messages[0].content, /private/);
    assert.match(request.systemPrompt, /当前工作任务/);
    assert.equal(options.cacheRetention, "none");
    assert.ok(options.signal instanceof AbortSignal);
    return reply;
  });
  assert.equal(await summarizeTask(ctx, taskSummaryExcerpt(ctx), new AbortController().signal), reply.content[0].text);
});

test("excerpt bounds each message and keeps the latest eight visible messages", () => {
  const messages = Array.from({ length: 20 }, (_, index) => ({
    role: index % 2 ? "assistant" : "user", content: `START-${index}:` + "x".repeat(30000) + `:END-${index}`,
  }));
  const excerpt = taskSummaryExcerpt(context(messages, async () => reply));
  assert.doesNotMatch(excerpt, /START-11:/);
  assert.match(excerpt, /START-12:/);
  assert.match(excerpt, /:END-19$/);
  assert.ok(excerpt.length < 16200);
});

test("many assistant progress messages cannot evict the latest user goal", () => {
  const ctx = context([
    { role: "user", content: "修复分页逻辑" },
    ...Array.from({ length: 20 }, (_, index) => ({ role: "assistant", content: `正在执行步骤 ${index}` })),
  ], async () => reply);
  const excerpt = taskSummaryExcerpt(ctx);
  assert.match(excerpt, /修复分页逻辑/);
  assert.match(excerpt, /正在执行步骤 19/);
  assert.doesNotMatch(excerpt, /正在执行步骤 15/);
});

test("invalid responses fail, and text is normalized to a single line", async () => {
  for (const response of [
    { stopReason: "error", content: [] },
    { stopReason: "length", content: reply.content },
    { stopReason: "stop", content: [{ type: "text", text: " " }] },
    { stopReason: "stop", content: [{ type: "text", text: "x".repeat(81) }] },
    { stopReason: "stop", content: [{ type: "thinking", thinking: "not a title" }] },
  ]) {
    await assert.rejects(summarizeTask(context([], async () => response), "[user]\nGoal", new AbortController().signal));
  }
  const ctx = context([], async () => ({ stopReason: "stop", content: [{ type: "text", text: "修复\n分页\t逻辑\u0000" }] }));
  assert.equal(await summarizeTask(ctx, "[user]\nGoal", new AbortController().signal), "修复 分页 逻辑");
});

test("empty input, missing model and cancellation never call the provider", async () => {
  let calls = 0;
  const ctx = context([], async () => { calls += 1; return reply; });
  await assert.rejects(summarizeTask(ctx, " ", new AbortController().signal));
  const controller = new AbortController();
  controller.abort();
  await assert.rejects(summarizeTask(ctx, "Goal", controller.signal));
  await assert.rejects(summarizeTask({ ...ctx, model: undefined }, "Goal", new AbortController().signal));
  assert.equal(calls, 0);
});

test("task generation has a deadline even if the provider ignores cancellation", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  const ctx = context([], async () => new Promise(() => {}));
  const rejected = assert.rejects(summarizeTask(ctx, "Goal", new AbortController().signal));
  t.mock.timers.tick(60000);
  await rejected;
});
